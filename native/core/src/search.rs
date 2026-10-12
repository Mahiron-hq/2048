//! Expectimax over the player's moves and every tile the game could spawn, deepening one level at
//! a time within a time budget. The spawns under the root moves are shared out to worker threads;
//! each worker keeps its own transposition table and line cache, so they never contend.

use std::num::NonZeroUsize;
use std::sync::atomic::{AtomicBool, AtomicU8, AtomicU64, AtomicUsize, Ordering};
use std::time::{Duration, Instant};

use crate::grid::{Dir, Grid, MAX_CELLS};
use crate::heuristic::LineCache;

/// Chance that a spawned tile is a 4 instead of a 2.
pub const SPAWN_FOUR_CHANCE: f64 = 0.1;

/// How hard a search may work.
#[derive(Clone, Debug, PartialEq)]
pub struct Limits {
    /// Wall-clock time the search may take; an iteration that would overrun it is not started,
    /// and one that does overrun is dropped.
    pub budget: Duration,
    pub threads: NonZeroUsize,
    /// Chance branches less likely than this are scored by the heuristic instead of searched.
    pub min_probability: f64,
    pub max_depth: u8,
    /// Stop early once the best move has held for several depths with a clear lead.
    pub stop_when_stable: bool,
    /// Each thread's transposition table holds 2^`table_bits` positions, 24 bytes each; its line
    /// cache uses up to 2^16 slots. Small for quick searches, which would spend more time
    /// clearing a large table than searching.
    pub table_bits: u8,
}

/// Lets the starter of a search cancel it and watch its progress from another thread.
#[derive(Debug, Default)]
pub struct Control {
    cancelled: AtomicBool,
    depth: AtomicU8,
    nodes: AtomicU64,
}

impl Control {
    pub fn new() -> Control {
        Control::default()
    }

    /// Asks the search to stop; it returns the best move of its deepest finished iteration.
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::Relaxed);
    }

    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Relaxed)
    }

    /// Deepest iteration finished so far.
    pub fn completed_depth(&self) -> u8 {
        self.depth.load(Ordering::Relaxed)
    }

    /// Chance nodes searched in the finished iterations.
    pub fn nodes(&self) -> u64 {
        self.nodes.load(Ordering::Relaxed)
    }
}

/// Why a search ended.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Finish {
    /// No move changes the board.
    NoMove,
    /// Exactly one move changes the board.
    OnlyMove,
    /// Every leaf was cut by probability or by the end of the game: deeper search changes nothing.
    Exhausted,
    /// The best move held with a clear lead (only with [`Limits::stop_when_stable`]).
    Stable,
    /// The time budget ran out, or the next iteration could not have finished within it.
    Budget,
    MaxDepth,
    Cancelled,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Outcome {
    pub best: Option<Dir>,
    /// Deepest finished iteration; 0 means the moves were ranked by the heuristic alone.
    pub depth: u8,
    pub nodes: u64,
    pub elapsed: Duration,
    pub finish: Finish,
}

/// Depths the best move must hold for, with a lead of STABLE_LEAD, before a stable stop.
const STABLE_DEPTHS: usize = 3;
const STABLE_MIN_DEPTH: u8 = 4;
/// Lead of the best move over the second, as a share of the best value.
const STABLE_LEAD: f64 = 0.01;
/// Bounds for the guess of how much longer the next iteration takes than the last one.
const GROWTH_MIN: f64 = 2.0;
const GROWTH_MAX: f64 = 60.0;
const GROWTH_UNKNOWN: f64 = 8.0;

/// Finds the best move for `grid` within `limits`. Never panics; with no move possible it
/// returns `best: None`.
pub fn search(grid: &Grid, limits: &Limits, control: &Control) -> Outcome {
    let start = Instant::now();
    let deadline = start + limits.budget;
    let candidates: Vec<(Dir, Grid)> = Dir::PREFERENCE
        .iter()
        .map(|&d| (d, grid.slid(d)))
        .filter(|(_, moved)| moved != grid)
        .collect();
    let finish_with = |best, depth, finish| Outcome {
        best,
        depth,
        nodes: control.nodes(),
        elapsed: start.elapsed(),
        finish,
    };
    match candidates.len() {
        0 => return finish_with(None, 0, Finish::NoMove),
        1 => return finish_with(Some(candidates[0].0), 0, Finish::OnlyMove),
        _ => {}
    }

    let mut workers: Vec<Worker> = (0..limits.threads.get())
        .map(|_| Worker::new(deadline, limits))
        .collect();
    let heuristic: Vec<f64> = candidates
        .iter()
        .map(|(_, moved)| workers[0].cache.evaluate(moved))
        .collect();
    let mut best = candidates[pick_best(&heuristic).0].0;
    let mut history: Vec<Dir> = Vec::new();
    let mut last_time: Option<Duration> = None;
    let mut growth = GROWTH_UNKNOWN;
    let mut finish = Finish::MaxDepth;

    for depth in 1..=limits.max_depth {
        if control.is_cancelled() {
            finish = Finish::Cancelled;
            break;
        }
        if let Some(last) = last_time {
            let projected = start.elapsed().as_secs_f64() + last.as_secs_f64() * growth;
            if projected > limits.budget.as_secs_f64() {
                finish = Finish::Budget;
                break;
            }
        }
        let began = Instant::now();
        let Some(round) = run_depth(&candidates, depth, &mut workers, control) else {
            finish = if control.is_cancelled() {
                Finish::Cancelled
            } else {
                Finish::Budget
            };
            break;
        };
        let took = began.elapsed();
        if let Some(last) = last_time.filter(|l| !l.is_zero()) {
            growth = (took.as_secs_f64() / last.as_secs_f64()).clamp(GROWTH_MIN, GROWTH_MAX);
        }
        last_time = Some(took);
        let (index, lead) = pick_best(&round.values);
        best = candidates[index].0;
        history.push(best);
        control.depth.store(depth, Ordering::Relaxed);
        control.nodes.fetch_add(round.nodes, Ordering::Relaxed);
        if !round.depth_limited {
            finish = Finish::Exhausted;
            break;
        }
        if limits.stop_when_stable && is_stable(&history, depth, lead) {
            finish = Finish::Stable;
            break;
        }
        if Instant::now() >= deadline {
            finish = Finish::Budget;
            break;
        }
    }
    finish_with(Some(best), control.completed_depth(), finish)
}

fn is_stable(history: &[Dir], depth: u8, lead: f64) -> bool {
    depth >= STABLE_MIN_DEPTH
        && history.len() >= STABLE_DEPTHS
        && history[history.len() - STABLE_DEPTHS..]
            .windows(2)
            .all(|w| w[0] == w[1])
        && lead >= STABLE_LEAD
}

/// Index of the highest value (the first one on a tie, which follows [`Dir::PREFERENCE`]) and its
/// lead over the runner-up as a share of its own size.
fn pick_best(values: &[f64]) -> (usize, f64) {
    let mut best = 0;
    for (i, &v) in values.iter().enumerate() {
        if v > values[best] {
            best = i;
        }
    }
    let runner_up = values
        .iter()
        .enumerate()
        .filter(|(i, _)| *i != best)
        .map(|(_, &v)| v)
        .fold(f64::NEG_INFINITY, f64::max);
    let lead = (values[best] - runner_up) / values[best].abs().max(1.0);
    (best, lead)
}

struct Round {
    values: Vec<f64>,
    nodes: u64,
    depth_limited: bool,
}

/// One spawn under a root move: tile `rank` at `cell` of candidate `candidate`, reached with
/// probability `probability`.
struct Task {
    candidate: usize,
    cell: u8,
    rank: u8,
    probability: f64,
}

/// Searches every root move to `depth`, in parallel. `None` when the deadline or a cancel cut
/// the iteration short.
fn run_depth(
    candidates: &[(Dir, Grid)],
    depth: u8,
    workers: &mut [Worker],
    control: &Control,
) -> Option<Round> {
    let mut tasks = Vec::new();
    for (candidate, (_, moved)) in candidates.iter().enumerate() {
        let empty: Vec<usize> = moved.empty_cells().collect();
        let share = 1.0 / empty.len() as f64;
        for &cell in &empty {
            // Cell indices are below MAX_CELLS = 36.
            let cell = cell as u8;
            tasks.push(Task {
                candidate,
                cell,
                rank: 1,
                probability: share * (1.0 - SPAWN_FOUR_CHANCE),
            });
            tasks.push(Task {
                candidate,
                cell,
                rank: 2,
                probability: share * SPAWN_FOUR_CHANCE,
            });
        }
    }
    let next = AtomicUsize::new(0);
    let active = workers.len().min(tasks.len()).max(1);
    for w in workers.iter_mut() {
        w.begin_round(candidates.len());
    }
    std::thread::scope(|scope| {
        for worker in workers[..active].iter_mut() {
            let tasks = &tasks;
            let next = &next;
            scope.spawn(move || {
                while !worker.aborted {
                    let i = next.fetch_add(1, Ordering::Relaxed);
                    let Some(task) = tasks.get(i) else { break };
                    let (_, moved) = &candidates[task.candidate];
                    let child = moved.with_tile(usize::from(task.cell), task.rank);
                    let value = worker.max_node(&child, depth - 1, task.probability, control);
                    if !worker.aborted {
                        worker.sums[task.candidate] += task.probability * value;
                    }
                }
            });
        }
    });
    let workers = &workers[..active];
    if workers.iter().any(|w| w.aborted) {
        return None;
    }
    let mut values = vec![0.0; candidates.len()];
    for w in workers {
        for (v, s) in values.iter_mut().zip(&w.sums) {
            *v += s;
        }
    }
    Some(Round {
        values,
        nodes: workers.iter().map(|w| w.round_nodes).sum(),
        depth_limited: workers.iter().any(|w| w.depth_limited),
    })
}

/// Search state owned by one thread.
struct Worker {
    cache: LineCache,
    table: Table,
    deadline: Instant,
    min_probability: f64,
    sums: Vec<f64>,
    round_nodes: u64,
    /// A leaf of this round was cut by depth rather than by probability or the end of the game.
    depth_limited: bool,
    aborted: bool,
}

/// Nodes between two looks at the clock and the cancel flag.
const CLOCK_EVERY: u64 = 64;

impl Worker {
    fn new(deadline: Instant, limits: &Limits) -> Worker {
        let bits = u32::from(limits.table_bits).clamp(4, 22);
        Worker {
            cache: LineCache::with_bits(bits.min(16)),
            table: Table::new(bits),
            deadline,
            min_probability: limits.min_probability,
            sums: Vec::new(),
            round_nodes: 0,
            depth_limited: false,
            aborted: false,
        }
    }

    fn begin_round(&mut self, candidates: usize) {
        self.sums = vec![0.0; candidates];
        self.round_nodes = 0;
        self.depth_limited = false;
        self.aborted = false;
    }

    /// Best value over the player's moves; a board with no move left is worth nothing.
    fn max_node(&mut self, grid: &Grid, depth: u8, probability: f64, control: &Control) -> f64 {
        let mut best = 0.0f64;
        for dir in Dir::PREFERENCE {
            let moved = grid.slid(dir);
            if moved == *grid {
                continue;
            }
            let value = self.chance_node(&moved, depth, probability, control);
            if self.aborted {
                return 0.0;
            }
            best = best.max(value);
        }
        best
    }

    /// Expected value over every tile the game could spawn on `grid`.
    fn chance_node(&mut self, grid: &Grid, depth: u8, probability: f64, control: &Control) -> f64 {
        if probability < self.min_probability {
            return self.cache.evaluate(grid);
        }
        if depth == 0 {
            self.depth_limited = true;
            return self.cache.evaluate(grid);
        }
        self.round_nodes += 1;
        if self.round_nodes.is_multiple_of(CLOCK_EVERY)
            && (control.is_cancelled() || Instant::now() >= self.deadline)
        {
            self.aborted = true;
            return 0.0;
        }
        let key = grid.fingerprint();
        if let Some(hit) = self.table.get(key, depth) {
            self.depth_limited |= hit.depth_limited;
            return hit.value;
        }
        let mut empty = [0u8; MAX_CELLS];
        let mut count = 0;
        for cell in grid.empty_cells() {
            // Cell indices are below MAX_CELLS = 36.
            empty[count] = cell as u8;
            count += 1;
        }
        if count == 0 {
            return self.cache.evaluate(grid);
        }
        let outer_limited = std::mem::replace(&mut self.depth_limited, false);
        let share = probability / count as f64;
        let mut total = 0.0;
        for &cell in &empty[..count] {
            let cell = usize::from(cell);
            let two = self.max_node(
                &grid.with_tile(cell, 1),
                depth - 1,
                share * (1.0 - SPAWN_FOUR_CHANCE),
                control,
            );
            let four = self.max_node(
                &grid.with_tile(cell, 2),
                depth - 1,
                share * SPAWN_FOUR_CHANCE,
                control,
            );
            if self.aborted {
                return 0.0;
            }
            total += (1.0 - SPAWN_FOUR_CHANCE) * two + SPAWN_FOUR_CHANCE * four;
        }
        let value = total / count as f64;
        let limited = self.depth_limited;
        self.table.put(key, depth, value, limited);
        self.depth_limited = outer_limited || limited;
        value
    }
}

/// Transposition table: a fixed-size direct-mapped array, so memory stays bounded however long
/// the search runs. A newer entry simply replaces an older one.
struct Table {
    entries: Vec<Entry>,
    bits: u32,
}

#[derive(Clone, Copy, Default)]
struct Entry {
    key: u64,
    value: f64,
    depth: u8,
    depth_limited: bool,
}

struct Hit {
    value: f64,
    depth_limited: bool,
}

impl Table {
    fn new(bits: u32) -> Table {
        Table {
            entries: vec![Entry::default(); 1 << bits],
            bits,
        }
    }

    fn slot(&self, key: u64) -> usize {
        (key >> (64 - self.bits)) as usize
    }

    /// A value searched at least `depth` deep for the board with fingerprint `key`.
    fn get(&self, key: u64, depth: u8) -> Option<Hit> {
        let e = self.entries[self.slot(key)];
        (e.key == key && e.depth >= depth && e.depth > 0).then_some(Hit {
            value: e.value,
            depth_limited: e.depth_limited,
        })
    }

    fn put(&mut self, key: u64, depth: u8, value: f64, depth_limited: bool) {
        let slot = self.slot(key);
        self.entries[slot] = Entry {
            key,
            value,
            depth,
            depth_limited,
        };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn grid(rows: &[&[i64]]) -> Grid {
        let flat: Vec<i64> = rows.iter().flat_map(|r| r.iter().copied()).collect();
        Grid::from_values(&flat, rows.len()).expect("test boards are valid")
    }

    fn limits(ms: u64, threads: usize) -> Limits {
        Limits {
            budget: Duration::from_millis(ms),
            threads: NonZeroUsize::new(threads).expect("tests use at least one thread"),
            min_probability: 1e-4,
            max_depth: 8,
            stop_when_stable: false,
            table_bits: 16,
        }
    }

    #[test]
    fn no_hint_without_a_move() {
        let g = grid(&[&[2, 4, 2, 4], &[4, 2, 4, 2], &[2, 4, 2, 4], &[4, 2, 4, 2]]);
        let out = search(&g, &limits(50, 1), &Control::new());
        assert_eq!((out.best, out.finish), (None, Finish::NoMove));
    }

    #[test]
    fn forced_move_returns_at_once() {
        let g = grid(&[&[2, 4, 2, 4], &[4, 2, 4, 2], &[2, 4, 2, 4], &[4, 2, 4, 0]]);
        let out = search(&g, &limits(50, 1), &Control::new());
        assert!(matches!(out.best, Some(Dir::Right) | Some(Dir::Down)));
    }

    #[test]
    fn never_suggests_a_move_that_changes_nothing() {
        let g = grid(&[
            &[0, 2, 4, 8],
            &[2, 4, 8, 16],
            &[4, 8, 16, 32],
            &[8, 16, 32, 64],
        ]);
        let out = search(&g, &limits(100, 2), &Control::new());
        let best = out.best.expect("left and up both move");
        assert_ne!(g.slid(best), g);
    }

    #[test]
    fn small_board_search_is_exhausted() {
        // Two tiles on 3x3: probability cuts every branch long before depth 8.
        let g = grid(&[&[2, 0, 0], &[0, 0, 0], &[0, 0, 2]]);
        let mut l = limits(5_000, 2);
        l.min_probability = 1e-3;
        let out = search(&g, &l, &Control::new());
        assert_eq!(out.finish, Finish::Exhausted);
        assert!(out.best.is_some());
    }

    #[test]
    fn respects_the_budget() {
        let g = grid(&[
            &[2, 0, 0, 0, 0, 2],
            &[0, 0, 4, 0, 0, 0],
            &[0, 0, 0, 0, 0, 0],
            &[0, 8, 0, 0, 0, 0],
            &[0, 0, 0, 0, 2, 0],
            &[0, 0, 0, 0, 0, 0],
        ]);
        let mut l = limits(150, 2);
        l.min_probability = 1e-9;
        l.max_depth = 30;
        let out = search(&g, &l, &Control::new());
        assert!(
            out.elapsed < Duration::from_millis(400),
            "took {:?}",
            out.elapsed
        );
        assert!(out.best.is_some());
    }

    #[test]
    fn cancel_stops_a_long_search() {
        let g = grid(&[
            &[2, 0, 0, 0, 0, 2],
            &[0, 0, 4, 0, 0, 0],
            &[0, 0, 0, 0, 0, 0],
            &[0, 8, 0, 0, 0, 0],
            &[0, 0, 0, 0, 2, 0],
            &[0, 0, 0, 0, 0, 0],
        ]);
        let mut l = limits(60_000, 2);
        l.min_probability = 1e-12;
        l.max_depth = 40;
        let control = Control::new();
        let out = std::thread::scope(|s| {
            let h = s.spawn(|| search(&g, &l, &control));
            std::thread::sleep(Duration::from_millis(100));
            control.cancel();
            h.join()
        })
        .expect("the search thread does not panic");
        assert_eq!(out.finish, Finish::Cancelled);
        assert!(out.elapsed < Duration::from_secs(2));
        assert!(out.best.is_some(), "a cancelled search still answers");
    }

    #[test]
    fn threads_agree_with_a_single_thread() {
        let g = grid(&[&[2, 4, 8, 0], &[0, 2, 0, 0], &[4, 0, 0, 2], &[16, 8, 0, 0]]);
        let mut l = limits(30_000, 1);
        l.max_depth = 3;
        let one = search(&g, &l, &Control::new());
        l.threads = NonZeroUsize::new(4).expect("four is not zero");
        let four = search(&g, &l, &Control::new());
        assert_eq!(one.best, four.best);
        assert_eq!(one.depth, 3);
        assert_eq!(four.depth, 3);
    }

    #[test]
    fn pick_best_breaks_ties_by_preference() {
        assert_eq!(pick_best(&[1.0, 3.0, 3.0]).0, 1);
        let (i, lead) = pick_best(&[100.0, 50.0]);
        assert_eq!(i, 0);
        assert!((lead - 0.5).abs() < 1e-9);
    }
}

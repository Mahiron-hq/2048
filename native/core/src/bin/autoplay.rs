//! Plays whole games with the hint search choosing every move, to measure its strength.
//!
//! cargo run --release -p hint-core --bin autoplay -- --level 1 --side 4 --games 10
//! Options: --level 0|1|2, --side 3..6, --games N, --seed N, and overrides of the level's
//! limits: --budget-ms N, --threads N, --min-probability X, --max-depth N, --max-moves N.

use std::process::ExitCode;
use std::time::{Duration, Instant};

use hint_core::{Control, Dir, Grid, Level, Side, available_cores, search};

struct Options {
    level: Level,
    side: usize,
    games: usize,
    seed: u64,
    budget_ms: Option<u64>,
    threads: Option<usize>,
    min_probability: Option<f64>,
    max_depth: Option<u8>,
    max_moves: usize,
}

fn parse() -> Result<Options, String> {
    let mut o = Options {
        level: Level::Medium,
        side: 4,
        games: 5,
        seed: 1,
        budget_ms: None,
        threads: None,
        min_probability: None,
        max_depth: None,
        max_moves: 1_000_000,
    };
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut i = 0;
    while i < args.len() {
        let value = args
            .get(i + 1)
            .ok_or(format!("{} needs a value", args[i]))?;
        let bad = || format!("bad value {value} for {}", args[i]);
        match args[i].as_str() {
            "--level" => {
                let code = value.parse::<i64>().map_err(|_| bad())?;
                o.level = Level::from_code(code).ok_or(format!("no level {code}"))?;
            }
            "--side" => o.side = value.parse().map_err(|_| bad())?,
            "--games" => o.games = value.parse().map_err(|_| bad())?,
            "--seed" => o.seed = value.parse().map_err(|_| bad())?,
            "--budget-ms" => o.budget_ms = Some(value.parse().map_err(|_| bad())?),
            "--threads" => o.threads = Some(value.parse().map_err(|_| bad())?),
            "--min-probability" => o.min_probability = Some(value.parse().map_err(|_| bad())?),
            "--max-depth" => o.max_depth = Some(value.parse().map_err(|_| bad())?),
            "--max-moves" => o.max_moves = value.parse().map_err(|_| bad())?,
            other => return Err(format!("unknown option {other}")),
        }
        i += 2;
    }
    Ok(o)
}

/// xorshift64*: deterministic spawns for a given seed, no dependency needed.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_f491_4f6c_dd1d)
    }

    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

fn spawn(grid: &Grid, rng: &mut Rng) -> Grid {
    let empty: Vec<usize> = grid.empty_cells().collect();
    if empty.is_empty() {
        return *grid;
    }
    let cell = empty[rng.below(empty.len())];
    let rank = if rng.below(10) == 0 { 2 } else { 1 };
    grid.with_tile(cell, rank)
}

/// Points scored by sliding `grid` towards `dir`: the value of every tile a merge creates.
fn score_gain(grid: &Grid, dir: Dir) -> i64 {
    let ranks = grid.ranks();
    let n = grid.side().get();
    let mut gain = 0;
    for line in grid.side().lines(dir) {
        let mut last = 0u8;
        for &cell in &line[..n] {
            let rank = ranks[usize::from(cell)];
            if rank == 0 {
                continue;
            }
            if rank == last {
                gain += 1i64 << (rank + 1);
                last = 0;
            } else {
                last = rank;
            }
        }
    }
    gain
}

fn main() -> ExitCode {
    let o = match parse() {
        Ok(o) => o,
        Err(e) => {
            eprintln!("{e}");
            return ExitCode::FAILURE;
        }
    };
    let Ok(side) = Side::new(o.side) else {
        eprintln!("side must be 3..=6");
        return ExitCode::FAILURE;
    };
    let mut limits = o.level.limits(available_cores());
    if let Some(ms) = o.budget_ms {
        limits.budget = Duration::from_millis(ms);
    }
    if let Some(t) = o.threads.and_then(std::num::NonZeroUsize::new) {
        limits.threads = t;
    }
    if let Some(p) = o.min_probability {
        limits.min_probability = p;
    }
    if let Some(d) = o.max_depth {
        limits.max_depth = d;
    }
    println!(
        "level {:?} side {} games {} budget {:?} threads {} min_p {} max_depth {}",
        o.level,
        o.side,
        o.games,
        limits.budget,
        limits.threads,
        limits.min_probability,
        limits.max_depth
    );
    let mut scores = Vec::new();
    let mut best_tiles = Vec::new();
    let mut total_moves = 0usize;
    let mut total_time = Duration::ZERO;
    let mut depth_sum = 0u64;
    for g in 0..o.games {
        let mut rng = Rng(o.seed.wrapping_mul(0x9e37_79b9_7f4a_7c15) ^ (g as u64 + 1) | 1);
        let mut grid = spawn(&spawn(&Grid::empty(side), &mut rng), &mut rng);
        let mut score = 0i64;
        let mut moves = 0usize;
        while moves < o.max_moves {
            let started = Instant::now();
            let out = search(&grid, &limits, &Control::new());
            total_time += started.elapsed();
            let Some(dir): Option<Dir> = out.best else {
                break;
            };
            depth_sum += u64::from(out.depth);
            score += score_gain(&grid, dir);
            let moved = grid.slid(dir);
            grid = spawn(&moved, &mut rng);
            moves += 1;
        }
        let best = grid.values().into_iter().max().unwrap_or(0);
        println!("game {g}: score {score}, best tile {best}, moves {moves}");
        scores.push(score);
        best_tiles.push(best);
        total_moves += moves;
    }
    let games = scores.len().max(1) as f64;
    let mean = scores.iter().sum::<i64>() as f64 / games;
    let mut sorted = scores.clone();
    sorted.sort_unstable();
    let median = sorted.get(sorted.len() / 2).copied().unwrap_or(0);
    let reach = |t: i64| best_tiles.iter().filter(|&&b| b >= t).count();
    println!(
        "mean score {mean:.0}, median {median}, reached 1024: {}, 2048: {}, 4096: {}, 8192: {}, 16384: {}",
        reach(1024),
        reach(2048),
        reach(4096),
        reach(8192),
        reach(16384)
    );
    println!(
        "moves {total_moves}, {:.1} ms per move, mean depth {:.2}",
        total_time.as_secs_f64() * 1000.0 / total_moves.max(1) as f64,
        depth_sum as f64 / total_moves.max(1) as f64
    );
    ExitCode::SUCCESS
}

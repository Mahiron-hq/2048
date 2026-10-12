//! `HintEngine`, a Godot class that runs the hint search on background threads and reports back
//! through polling, so the game's main thread never waits on it.

use std::sync::Arc;
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

use godot::prelude::*;
use hint_core::{Control, Finish, Grid, Level, Limits, Outcome, available_cores, search};

struct HintExtension;

// SAFETY: this is the only `ExtensionLibrary` in the library, so Godot finds exactly one entry
// point; the trait has no other invariant to uphold.
#[gdextension]
unsafe impl ExtensionLibrary for HintExtension {}

/// Value of [method HintEngine.poll] while a search is still running.
const RUNNING: i64 = -2;
/// Value of [method HintEngine.poll] when no move changes the board, or the search failed.
const NO_MOVE: i64 = -1;

/// Runs the hint search in the background: [method start] it, [method poll] each frame until it
/// returns a direction (`Board.Dir`) or -1, [method cancel] it when the board changes.
#[derive(GodotClass)]
#[class(base = RefCounted, init)]
pub struct HintEngine {
    running: Option<Running>,
    last: Option<Outcome>,
    base: Base<RefCounted>,
}

struct Running {
    control: Arc<Control>,
    handle: JoinHandle<Outcome>,
    started: Instant,
    budget: Duration,
    threads: usize,
}

#[godot_api]
impl HintEngine {
    #[constant]
    const RUNNING: i64 = RUNNING;
    #[constant]
    const NO_MOVE: i64 = NO_MOVE;

    /// Starts a search of `values` (tile values, row by row) on a `side` x `side` board at hint
    /// `level` (0 simple, 1 medium, 2 smart), cancelling any search still running.
    /// Returns false, and starts nothing, for an invalid board or level.
    #[func]
    fn start(&mut self, values: PackedInt64Array, side: i64, level: i64) -> bool {
        let Some(level) = Level::from_code(level) else {
            godot_error!("HintEngine: unknown hint level {level}");
            return false;
        };
        self.start_with_limits(&values, side, level.limits(available_cores()))
    }

    /// Like [method start], but with the time budget and thread count given explicitly, for
    /// tools and measurements; the level still sets the search depth and pruning.
    #[func]
    fn start_custom(
        &mut self,
        values: PackedInt64Array,
        side: i64,
        level: i64,
        budget_ms: i64,
        threads: i64,
    ) -> bool {
        let Some(level) = Level::from_code(level) else {
            godot_error!("HintEngine: unknown hint level {level}");
            return false;
        };
        let (Ok(budget_ms), Some(threads)) = (
            u64::try_from(budget_ms),
            usize::try_from(threads)
                .ok()
                .and_then(std::num::NonZeroUsize::new),
        ) else {
            godot_error!("HintEngine: the budget must be positive and the threads at least one");
            return false;
        };
        let limits = Limits {
            budget: Duration::from_millis(budget_ms),
            threads,
            ..level.limits(available_cores())
        };
        self.start_with_limits(&values, side, limits)
    }

    /// -2 while the search runs; then the best direction (`Board.Dir`), or -1 when no move
    /// changes the board. Keeps returning the last answer until the next [method start].
    #[func]
    fn poll(&mut self) -> i64 {
        if self.is_running() {
            return RUNNING;
        }
        self.collect();
        match &self.last {
            Some(Outcome {
                best: Some(dir), ..
            }) => dir.code(),
            _ => NO_MOVE,
        }
    }

    /// True while a search runs.
    #[func]
    fn is_running(&self) -> bool {
        self.running
            .as_ref()
            .is_some_and(|r| !r.handle.is_finished())
    }

    /// Stops the running search; [method poll] then reports its best move so far.
    #[func]
    fn cancel(&mut self) {
        if let Some(running) = &self.running {
            running.control.cancel();
        }
    }

    /// Share of the time budget used so far, 0 to 1; 1 once the search has finished.
    #[func]
    fn progress(&self) -> f64 {
        match &self.running {
            Some(r) if !r.handle.is_finished() => {
                (r.started.elapsed().as_secs_f64() / r.budget.as_secs_f64().max(1e-3)).min(0.99)
            }
            _ => 1.0,
        }
    }

    /// Deepest finished iteration of the running or last search.
    #[func]
    fn depth(&self) -> i64 {
        match (&self.running, &self.last) {
            (Some(r), _) => i64::from(r.control.completed_depth()),
            (None, Some(out)) => i64::from(out.depth),
            _ => 0,
        }
    }

    /// Chance nodes searched by the last search.
    #[func]
    fn nodes(&self) -> i64 {
        self.last
            .as_ref()
            .map_or(0, |o| i64::try_from(o.nodes).unwrap_or(i64::MAX))
    }

    /// Wall-clock milliseconds of the last search.
    #[func]
    fn elapsed_ms(&self) -> i64 {
        self.last.as_ref().map_or(0, |o| {
            i64::try_from(o.elapsed.as_millis()).unwrap_or(i64::MAX)
        })
    }

    /// Threads the running or last search uses.
    #[func]
    fn threads(&self) -> i64 {
        self.running
            .as_ref()
            .map_or(0, |r| i64::try_from(r.threads).unwrap_or(i64::MAX))
    }

    /// Why the last search ended: "no_move", "only_move", "exhausted", "stable", "budget",
    /// "max_depth" or "cancelled"; empty while none has ended.
    #[func]
    fn finish(&self) -> GString {
        let name = match self.last.as_ref().map(|o| o.finish) {
            Some(Finish::NoMove) => "no_move",
            Some(Finish::OnlyMove) => "only_move",
            Some(Finish::Exhausted) => "exhausted",
            Some(Finish::Stable) => "stable",
            Some(Finish::Budget) => "budget",
            Some(Finish::MaxDepth) => "max_depth",
            Some(Finish::Cancelled) => "cancelled",
            None => "",
        };
        GString::from(name)
    }

    /// Hardware threads available to the game.
    #[func]
    fn core_count() -> i64 {
        i64::try_from(available_cores().get()).unwrap_or(1)
    }
}

impl HintEngine {
    fn start_with_limits(&mut self, values: &PackedInt64Array, side: i64, limits: Limits) -> bool {
        let grid = match usize::try_from(side)
            .map_err(|_| hint_core::GridError::BadSide(0))
            .and_then(|n| Grid::from_values(values.as_slice(), n))
        {
            Ok(grid) => grid,
            Err(err) => {
                godot_error!("HintEngine: {err}");
                return false;
            }
        };
        self.stop();
        let control = Arc::new(Control::new());
        let worker_control = Arc::clone(&control);
        let worker_limits = limits.clone();
        let handle = std::thread::Builder::new()
            .name("hint search".into())
            .spawn(move || search(&grid, &worker_limits, &worker_control));
        match handle {
            Ok(handle) => {
                self.last = None;
                self.running = Some(Running {
                    control,
                    handle,
                    started: Instant::now(),
                    budget: limits.budget,
                    threads: limits.threads.get(),
                });
                true
            }
            Err(err) => {
                godot_error!("HintEngine: could not start the search thread: {err}");
                false
            }
        }
    }

    /// Takes the finished search's outcome; a search thread that panicked leaves no outcome.
    fn collect(&mut self) {
        if let Some(running) = self.running.take() {
            match running.handle.join() {
                Ok(outcome) => self.last = Some(outcome),
                Err(_) => {
                    godot_error!("HintEngine: the search thread stopped unexpectedly");
                    self.last = None;
                }
            }
        }
    }

    /// Cancels and waits for the running search, if any.
    fn stop(&mut self) {
        if let Some(running) = &self.running {
            running.control.cancel();
        }
        self.collect();
    }
}

impl Drop for HintEngine {
    fn drop(&mut self) {
        // The search thread must not outlive the object that can still be asked about it.
        self.stop();
    }
}

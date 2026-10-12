//! The three hint strengths offered in the game's settings.

use std::num::NonZeroUsize;
use std::time::Duration;

use crate::search::Limits;

/// Hint strength, numbered like the game's `SaveStore.HintLevel`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Level {
    /// Answers at once from a one-level search: sound moves, without looking far ahead.
    Simple = 0,
    /// About a third of a second on two threads.
    Medium = 1,
    /// As deep as the phone gets in 15 seconds on every core but one, stopping early once the
    /// answer is settled.
    Smart = 2,
}

impl Level {
    /// The level with the game's numeric code, or `None` for an unknown code.
    pub fn from_code(code: i64) -> Option<Level> {
        match code {
            0 => Some(Level::Simple),
            1 => Some(Level::Medium),
            2 => Some(Level::Smart),
            _ => None,
        }
    }

    /// Search limits for this level on a device with `cores` hardware threads.
    pub fn limits(self, cores: NonZeroUsize) -> Limits {
        let one = NonZeroUsize::MIN;
        match self {
            Level::Simple => Limits {
                budget: Duration::from_millis(40),
                threads: one,
                min_probability: 0.003,
                max_depth: 1,
                stop_when_stable: false,
                table_bits: 10,
            },
            Level::Medium => Limits {
                budget: Duration::from_millis(350),
                threads: cores.min(NonZeroUsize::new(2).unwrap_or(one)),
                min_probability: 1e-4,
                max_depth: 16,
                stop_when_stable: false,
                table_bits: 16,
            },
            Level::Smart => Limits {
                budget: Duration::from_secs(15),
                threads: NonZeroUsize::new(cores.get() - 1).unwrap_or(one),
                min_probability: 1e-5,
                max_depth: 32,
                stop_when_stable: true,
                table_bits: 18,
            },
        }
    }
}

/// Hardware threads available to this process, at least one.
pub fn available_cores() -> NonZeroUsize {
    std::thread::available_parallelism().unwrap_or(NonZeroUsize::MIN)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn levels_use_the_agreed_threads() {
        let eight = NonZeroUsize::new(8).expect("eight is not zero");
        assert_eq!(Level::Simple.limits(eight).threads.get(), 1);
        assert_eq!(Level::Medium.limits(eight).threads.get(), 2);
        assert_eq!(Level::Smart.limits(eight).threads.get(), 7);
        assert_eq!(Level::Smart.limits(NonZeroUsize::MIN).threads.get(), 1);
        assert_eq!(Level::Smart.limits(eight).budget, Duration::from_secs(15));
    }

    #[test]
    fn codes_round_trip() {
        for level in [Level::Simple, Level::Medium, Level::Smart] {
            assert_eq!(Level::from_code(level as i64), Some(level));
        }
        assert_eq!(Level::from_code(3), None);
    }
}

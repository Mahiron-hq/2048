//! Move hints for 2048 Merge: an expectimax search over boards from 3x3 to 6x6.
//!
//! [`Grid`] holds tile ranks and applies the slide-and-merge rule, [`heuristic`] scores a
//! position, and [`search()`] looks ahead over moves and spawns within [`Limits`], one level of
//! depth at a time, on several threads. [`Level`] maps the game's three hint strengths to limits.

pub mod grid;
pub mod heuristic;
pub mod level;
pub mod search;

pub use grid::{Dir, Grid, GridError, Side};
pub use level::{Level, available_cores};
pub use search::{Control, Finish, Limits, Outcome, search};

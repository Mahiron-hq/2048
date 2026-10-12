//! Property tests of the public board rules against a plain reference implementation.

use std::num::NonZeroUsize;
use std::time::Duration;

use hint_core::{Control, Dir, Grid, Limits, Side, search};
use proptest::prelude::*;

/// Any board from 3x3 to 6x6 with tiles up to 2^12, a quarter of the cells empty on average.
fn boards() -> impl Strategy<Value = Grid> {
    (3usize..=6).prop_flat_map(|n| {
        prop::collection::vec(prop_oneof![1 => Just(0u8), 3 => 0u8..=12], n * n).prop_map(
            move |ranks| {
                Grid::from_ranks(&ranks, Side::new(n).expect("3..=6 is a valid side"))
                    .expect("ranks are in range")
            },
        )
    })
}

/// Slides one line towards its start the obvious way: drop the gaps, merge equal neighbours once.
fn reference_line(line: &[u8]) -> Vec<u8> {
    let tiles: Vec<u8> = line.iter().copied().filter(|&r| r != 0).collect();
    let mut out = Vec::new();
    let mut i = 0;
    while i < tiles.len() {
        if i + 1 < tiles.len() && tiles[i] == tiles[i + 1] {
            out.push(tiles[i] + 1);
            i += 2;
        } else {
            out.push(tiles[i]);
            i += 1;
        }
    }
    out.resize(line.len(), 0);
    out
}

fn reference_left(g: &Grid) -> Vec<u8> {
    let n = g.side().get();
    g.ranks().chunks(n).flat_map(reference_line).collect()
}

fn mirrored(g: &Grid) -> Grid {
    let n = g.side().get();
    let ranks: Vec<u8> = g
        .ranks()
        .chunks(n)
        .flat_map(|row| row.iter().rev().copied())
        .collect();
    Grid::from_ranks(&ranks, g.side()).expect("same ranks")
}

fn transposed(g: &Grid) -> Grid {
    let n = g.side().get();
    let r = g.ranks();
    let ranks: Vec<u8> = (0..n * n).map(|i| r[(i % n) * n + i / n]).collect();
    Grid::from_ranks(&ranks, g.side()).expect("same ranks")
}

fn tile_sum(g: &Grid) -> i64 {
    g.values().iter().sum()
}

proptest! {
    #[test]
    fn left_matches_the_reference(g in boards()) {
        let slid = g.slid(Dir::Left);
        prop_assert_eq!(slid.ranks(), &reference_left(&g)[..]);
    }

    #[test]
    fn right_is_left_in_a_mirror(g in boards()) {
        prop_assert_eq!(g.slid(Dir::Right), mirrored(&mirrored(&g).slid(Dir::Left)));
    }

    #[test]
    fn up_and_down_are_left_and_right_transposed(g in boards()) {
        prop_assert_eq!(g.slid(Dir::Up), transposed(&transposed(&g).slid(Dir::Left)));
        prop_assert_eq!(g.slid(Dir::Down), transposed(&transposed(&g).slid(Dir::Right)));
    }

    #[test]
    fn moves_keep_the_tile_sum(g in boards()) {
        for dir in Dir::PREFERENCE {
            prop_assert_eq!(tile_sum(&g.slid(dir)), tile_sum(&g));
        }
    }

    #[test]
    fn values_round_trip(g in boards()) {
        let back = Grid::from_values(&g.values(), g.side().get());
        prop_assert_eq!(back, Ok(g));
    }

    #[test]
    fn equal_boards_share_a_fingerprint(g in boards()) {
        let copy = Grid::from_ranks(g.ranks(), g.side()).expect("same ranks");
        prop_assert_eq!(copy.fingerprint(), g.fingerprint());
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(48))]

    #[test]
    fn a_hint_always_changes_the_board(g in boards()) {
        let limits = Limits {
            budget: Duration::from_millis(20),
            threads: NonZeroUsize::new(2).expect("two is not zero"),
            min_probability: 1e-3,
            max_depth: 3,
            stop_when_stable: false,
            table_bits: 12,
        };
        let out = search(&g, &limits, &Control::new());
        match out.best {
            Some(dir) => prop_assert_ne!(g.slid(dir), g),
            None => prop_assert!(!g.can_move()),
        }
    }
}

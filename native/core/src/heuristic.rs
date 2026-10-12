//! Static board evaluation: nneonneo's row heuristic, which rewards empty cells, pending merges
//! and monotonic lines, applied to every row and column.

use crate::grid::{Dir, Grid, MAX_SIDE};

const LOST_PENALTY: f32 = 200_000.0;
const MONOTONICITY_POWER: f32 = 4.0;
const MONOTONICITY_WEIGHT: f32 = 47.0;
const SUM_POWER: f32 = 3.5;
const SUM_WEIGHT: f32 = 11.0;
const MERGES_WEIGHT: f32 = 700.0;
const EMPTY_WEIGHT: f32 = 270.0;

/// Score of one line of ranks, larger is better.
pub fn line_score(ranks: &[u8]) -> f32 {
    let mut sum = 0.0f32;
    let mut empty = 0u32;
    let mut merges = 0u32;
    let mut previous = 0u8;
    let mut run = 0u32;
    for &rank in ranks {
        sum += f32::from(rank).powf(SUM_POWER);
        if rank == 0 {
            empty += 1;
            continue;
        }
        if previous == rank {
            run += 1;
        } else if run > 0 {
            merges += 1 + run;
            run = 0;
        }
        previous = rank;
    }
    if run > 0 {
        merges += 1 + run;
    }
    let mut falling = 0.0f32;
    let mut rising = 0.0f32;
    for pair in ranks.windows(2) {
        let a = f32::from(pair[0]).powf(MONOTONICITY_POWER);
        let b = f32::from(pair[1]).powf(MONOTONICITY_POWER);
        if a > b {
            falling += a - b;
        } else {
            rising += b - a;
        }
    }
    LOST_PENALTY + EMPTY_WEIGHT * empty as f32 + MERGES_WEIGHT * merges as f32
        - MONOTONICITY_WEIGHT * falling.min(rising)
        - SUM_WEIGHT * sum
}

/// Memo of [`line_score`] keyed by the packed line; a fixed-size direct-mapped table, so its
/// memory stays bounded however long a search runs.
pub struct LineCache {
    keys: Vec<u64>,
    scores: Vec<f32>,
    bits: u32,
}

/// Slots of [`LineCache::new`]: 2^16, 768 KiB.
const LINE_CACHE_BITS: u32 = 16;

impl LineCache {
    pub fn new() -> LineCache {
        LineCache::with_bits(LINE_CACHE_BITS)
    }

    /// A cache of 2^`bits` slots (12 bytes each); `bits` is clamped to 4..=20.
    pub fn with_bits(bits: u32) -> LineCache {
        let bits = bits.clamp(4, 20);
        let size = 1usize << bits;
        LineCache {
            keys: vec![0; size],
            scores: vec![0.0; size],
            bits,
        }
    }

    /// Heuristic value of `grid`: the scores of all its rows and columns.
    pub fn evaluate(&mut self, grid: &Grid) -> f64 {
        let side = grid.side();
        let n = side.get();
        let ranks = grid.ranks();
        let mut total = 0.0;
        for dir in [Dir::Left, Dir::Up] {
            for line in side.lines(dir) {
                let mut cells = [0u8; MAX_SIDE];
                let mut key = n as u64;
                for (k, &cell) in line[..n].iter().enumerate() {
                    cells[k] = ranks[usize::from(cell)];
                    key = key << 6 | u64::from(cells[k] & 63);
                }
                // Bit 63 marks a used slot, so the all-empty line never matches a fresh table.
                total += f64::from(self.score(key | 1 << 63, &cells[..n]));
            }
        }
        total
    }

    fn score(&mut self, key: u64, cells: &[u8]) -> f32 {
        let slot = (crate::grid::mix(key) >> (64 - self.bits)) as usize;
        if self.keys[slot] == key {
            return self.scores[slot];
        }
        let score = line_score(cells);
        self.keys[slot] = key;
        self.scores[slot] = score;
        score
    }
}

impl Default for LineCache {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::grid::Grid;

    #[test]
    fn empty_cells_and_merges_score_higher() {
        assert!(line_score(&[0, 0, 0, 0]) > line_score(&[1, 2, 3, 4]));
        assert!(line_score(&[3, 3, 0, 0]) > line_score(&[3, 4, 0, 0]));
    }

    #[test]
    fn monotonic_lines_beat_zigzags() {
        assert!(line_score(&[5, 4, 3, 2]) > line_score(&[5, 2, 4, 3]));
    }

    #[test]
    fn cache_returns_what_it_computes() {
        let g = Grid::from_values(&[2, 4, 8, 16, 0, 0, 2, 2, 4, 0, 0, 8, 0, 0, 0, 2], 4)
            .expect("valid board");
        let mut cache = LineCache::new();
        let first = cache.evaluate(&g);
        assert_eq!(first, cache.evaluate(&g));
        let mut uncached = 0.0f64;
        for dir in [Dir::Left, Dir::Up] {
            for line in g.side().lines(dir) {
                let ranks: Vec<u8> = line[..4]
                    .iter()
                    .map(|&c| g.ranks()[usize::from(c)])
                    .collect();
                uncached += f64::from(line_score(&ranks));
            }
        }
        assert_eq!(first, uncached);
    }
}

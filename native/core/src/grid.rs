//! Board representation: tile ranks on a square grid of side 3 to 6, and the slide-and-merge
//! rule of 2048 (each tile merges at most once per move).

use std::fmt;

/// Smallest supported side length.
pub const MIN_SIDE: usize = 3;
/// Largest supported side length.
pub const MAX_SIDE: usize = 6;
/// Cells of the largest board.
pub const MAX_CELLS: usize = MAX_SIDE * MAX_SIDE;
/// Largest tile rank a game can produce: a full 6x6 board tops out at 2^37.
pub const MAX_RANK: u8 = 37;

/// A move direction, numbered like the game's `Board.Dir` (UP, DOWN, LEFT, RIGHT).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Dir {
    Up = 0,
    Down = 1,
    Left = 2,
    Right = 3,
}

impl Dir {
    /// Every direction, in the order ties are broken: left, down, right, up.
    pub const PREFERENCE: [Dir; 4] = [Dir::Left, Dir::Down, Dir::Right, Dir::Up];

    /// The game's numeric code for this direction.
    pub fn code(self) -> i64 {
        self as i64
    }
}

/// Reasons a list of tile values cannot be read as a board.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum GridError {
    #[error("board side {0} is outside {MIN_SIDE}..={MAX_SIDE}")]
    BadSide(usize),
    #[error("a {side}x{side} board has {expected} cells, got {got}")]
    WrongCellCount {
        side: usize,
        expected: usize,
        got: usize,
    },
    #[error("cell {index} holds {value}, which is not 0 or a power of two from 2 to 2^{MAX_RANK}")]
    NotATile { index: usize, value: i64 },
}

/// A validated side length.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Side(u8);

impl Side {
    /// Returns an error unless `n` is a supported side length.
    pub fn new(n: usize) -> Result<Side, GridError> {
        if (MIN_SIDE..=MAX_SIDE).contains(&n) {
            // The range check above bounds `n` to 3..=6, which fits a u8.
            Ok(Side(n as u8))
        } else {
            Err(GridError::BadSide(n))
        }
    }

    pub fn get(self) -> usize {
        usize::from(self.0)
    }

    pub fn cells(self) -> usize {
        self.get() * self.get()
    }

    /// The cell indices of every line moving towards `dir`, each ordered from the edge the
    /// tiles slide to.
    pub fn lines(self, dir: Dir) -> &'static [[u8; MAX_SIDE]] {
        &LINES[self.get() - MIN_SIDE][dir as usize][..self.get()]
    }
}

type LineTable = [[[u8; MAX_SIDE]; MAX_SIDE]; 4];

const fn line_table(side: usize) -> LineTable {
    let mut table = [[[0u8; MAX_SIDE]; MAX_SIDE]; 4];
    let mut line = 0;
    while line < side {
        let mut k = 0;
        while k < side {
            // Indices stay below MAX_CELLS = 36, so they fit a u8.
            table[Dir::Up as usize][line][k] = (k * side + line) as u8;
            table[Dir::Down as usize][line][k] = ((side - 1 - k) * side + line) as u8;
            table[Dir::Left as usize][line][k] = (line * side + k) as u8;
            table[Dir::Right as usize][line][k] = (line * side + side - 1 - k) as u8;
            k += 1;
        }
        line += 1;
    }
    table
}

static LINES: [LineTable; MAX_SIDE - MIN_SIDE + 1] =
    [line_table(3), line_table(4), line_table(5), line_table(6)];

/// Tile ranks on a board: 0 is an empty cell, rank r is the tile 2^r.
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub struct Grid {
    side: Side,
    cells: [u8; MAX_CELLS],
}

impl Grid {
    /// An empty board.
    pub fn empty(side: Side) -> Grid {
        Grid {
            side,
            cells: [0; MAX_CELLS],
        }
    }

    /// Reads tile values (0 or powers of two) in row-major order.
    ///
    /// # Errors
    /// Returns an error when the side is unsupported, the number of values does not match it, or
    /// a value is not a tile.
    pub fn from_values(values: &[i64], side: usize) -> Result<Grid, GridError> {
        let side = Side::new(side)?;
        if values.len() != side.cells() {
            return Err(GridError::WrongCellCount {
                side: side.get(),
                expected: side.cells(),
                got: values.len(),
            });
        }
        let mut grid = Grid::empty(side);
        for (index, &value) in values.iter().enumerate() {
            grid.cells[index] = rank_of(value).ok_or(GridError::NotATile { index, value })?;
        }
        Ok(grid)
    }

    /// Builds a board from ranks in row-major order.
    ///
    /// # Errors
    /// Returns an error when the number of ranks does not match the side or a rank is above
    /// [`MAX_RANK`].
    pub fn from_ranks(ranks: &[u8], side: Side) -> Result<Grid, GridError> {
        if ranks.len() != side.cells() {
            return Err(GridError::WrongCellCount {
                side: side.get(),
                expected: side.cells(),
                got: ranks.len(),
            });
        }
        let mut grid = Grid::empty(side);
        for (index, &rank) in ranks.iter().enumerate() {
            if rank > MAX_RANK {
                return Err(GridError::NotATile {
                    index,
                    value: i64::from(rank),
                });
            }
            grid.cells[index] = rank;
        }
        Ok(grid)
    }

    pub fn side(&self) -> Side {
        self.side
    }

    /// Ranks of the board's cells in row-major order.
    pub fn ranks(&self) -> &[u8] {
        &self.cells[..self.side.cells()]
    }

    /// Tile values in row-major order.
    pub fn values(&self) -> Vec<i64> {
        self.ranks()
            .iter()
            .map(|&r| if r == 0 { 0 } else { 1i64 << r })
            .collect()
    }

    /// Indices of the empty cells.
    pub fn empty_cells(&self) -> impl Iterator<Item = usize> + '_ {
        self.ranks()
            .iter()
            .enumerate()
            .filter(|(_, r)| **r == 0)
            .map(|(i, _)| i)
    }

    /// This board with `rank` placed at the empty cell `index`.
    pub fn with_tile(&self, index: usize, rank: u8) -> Grid {
        let mut next = *self;
        next.cells[index] = rank;
        next
    }

    /// The board after sliding and merging every line towards `dir`, without a new tile.
    /// Equal to `self` when the move changes nothing.
    pub fn slid(&self, dir: Dir) -> Grid {
        let mut next = Grid::empty(self.side);
        for line in self.side.lines(dir) {
            let mut write = 0;
            let mut last = 0u8;
            for &cell in &line[..self.side.get()] {
                let rank = self.cells[usize::from(cell)];
                if rank == 0 {
                    continue;
                }
                if rank == last {
                    next.cells[usize::from(line[write - 1])] = rank + 1;
                    last = 0;
                } else {
                    next.cells[usize::from(line[write])] = rank;
                    last = rank;
                    write += 1;
                }
            }
        }
        next
    }

    /// True while some move would change the board.
    pub fn can_move(&self) -> bool {
        Dir::PREFERENCE.iter().any(|&d| self.slid(d) != *self)
    }

    /// A 64-bit fingerprint of the board for transposition tables.
    pub fn fingerprint(&self) -> u64 {
        let mut words = [0u64; 4];
        for (i, &rank) in self.ranks().iter().enumerate() {
            words[i / 10] |= u64::from(rank & 63) << ((i % 10) * 6);
        }
        let mut h = 0x9e37_79b9_7f4a_7c15u64 ^ self.side.get() as u64;
        for w in words {
            h = mix(h ^ w);
        }
        h
    }
}

impl fmt::Debug for Grid {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let n = self.side.get();
        let rows: Vec<&[u8]> = self.ranks().chunks(n).collect();
        f.debug_struct("Grid").field("ranks", &rows).finish()
    }
}

/// The rank of tile `value`, or `None` when it is not 0 or a power of two up to 2^MAX_RANK.
pub fn rank_of(value: i64) -> Option<u8> {
    if value == 0 {
        return Some(0);
    }
    if value < 2 || value.count_ones() != 1 {
        return None;
    }
    // A positive power of two below 2^63 has at most 62 trailing zeros, which fits a u8.
    let rank = value.trailing_zeros() as u8;
    (rank <= MAX_RANK).then_some(rank)
}

/// SplitMix64 finalizer: spreads every input bit over the whole output.
pub(crate) fn mix(mut z: u64) -> u64 {
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
    z ^ (z >> 31)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn grid(rows: &[&[i64]]) -> Grid {
        let flat: Vec<i64> = rows.iter().flat_map(|r| r.iter().copied()).collect();
        Grid::from_values(&flat, rows.len()).expect("test boards are valid")
    }

    #[test]
    fn merges_each_pair_once() {
        let g = grid(&[&[2, 2, 2, 2], &[0; 4], &[0; 4], &[0; 4]]).slid(Dir::Left);
        assert_eq!(&g.values()[..4], &[4, 4, 0, 0]);
    }

    #[test]
    fn merged_tile_does_not_merge_again() {
        let g = grid(&[&[2, 2, 4, 0], &[0; 4], &[0; 4], &[0; 4]]).slid(Dir::Left);
        assert_eq!(&g.values()[..4], &[4, 4, 0, 0]);
    }

    #[test]
    fn slides_across_gaps_in_every_direction() {
        let g = grid(&[&[4, 0, 4], &[0, 0, 0], &[0, 0, 8]]);
        assert_eq!(g.slid(Dir::Left).values(), vec![8, 0, 0, 0, 0, 0, 8, 0, 0]);
        assert_eq!(g.slid(Dir::Right).values(), vec![0, 0, 8, 0, 0, 0, 0, 0, 8]);
        assert_eq!(g.slid(Dir::Up).values(), vec![4, 0, 4, 0, 0, 8, 0, 0, 0]);
        assert_eq!(g.slid(Dir::Down).values(), vec![0, 0, 0, 0, 0, 4, 4, 0, 8]);
    }

    #[test]
    fn stuck_board_cannot_move() {
        let g = grid(&[&[2, 4, 2], &[4, 2, 4], &[2, 4, 2]]);
        assert!(!g.can_move());
        assert!(grid(&[&[2, 4, 2], &[4, 2, 4], &[2, 4, 4]]).can_move());
    }

    #[test]
    fn rejects_values_that_are_not_tiles() {
        assert_eq!(
            Grid::from_values(&[3, 0, 0, 0, 0, 0, 0, 0, 0], 3),
            Err(GridError::NotATile { index: 0, value: 3 })
        );
        assert!(Grid::from_values(&[0; 9], 2).is_err());
        assert!(Grid::from_values(&[0; 8], 3).is_err());
        assert!(Grid::from_values(&[1 << 38, 0, 0, 0, 0, 0, 0, 0, 0], 3).is_err());
        assert!(Grid::from_values(&[1 << 37, 0, 0, 0, 0, 0, 0, 0, 0], 3).is_ok());
    }

    #[test]
    fn rank_of_matches_powers_of_two() {
        assert_eq!(rank_of(0), Some(0));
        assert_eq!(rank_of(2), Some(1));
        assert_eq!(rank_of(2048), Some(11));
        assert_eq!(rank_of(1), None);
        assert_eq!(rank_of(-4), None);
        assert_eq!(rank_of(6), None);
    }
}

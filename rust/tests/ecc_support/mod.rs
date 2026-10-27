#![allow(dead_code)]
// Shared by the message ECC integration tests (AZ-2684): the position fixture scheme and a seeded stream.
use packbin::{flags, i16, u16, u8, BoundField, Scheme};

pub const FIXTURE: &str = "4001000065cd1d00a3e1110100";

#[derive(Default, Clone, Debug, PartialEq, Eq)]
pub struct PositionRow {
    pub sid: u16,
    pub lat: i32,
    pub lon: i32,
    pub profile: u8,
    pub heading: Option<u16>,
    pub speed: Option<u8>,
    pub altitude: Option<i16>,
}

/// The position scheme of the ECC tests; `type_number` lets a dispatch hold two of them.
pub fn position_scheme(type_number: i32, parity: usize) -> Scheme<PositionRow> {
    Scheme::new(
        type_number,
        [
            BoundField::u16(
                0,
                |r: &PositionRow| r.sid,
                |r: &mut PositionRow, v| r.sid = v,
            )
            .into(),
            BoundField::i32(
                1,
                |r: &PositionRow| r.lat,
                |r: &mut PositionRow, v| r.lat = v,
            )
            .into(),
            BoundField::i32(
                2,
                |r: &PositionRow| r.lon,
                |r: &mut PositionRow, v| r.lon = v,
            )
            .into(),
            BoundField::u8(
                3,
                |r: &PositionRow| r.profile,
                |r: &mut PositionRow, v| r.profile = v,
            )
            .into(),
            flags(
                4,
                "motion",
                vec![u16("heading"), u8("speed"), i16("altitude")],
            )
            .into(),
        ],
    )
    .with_parity(parity)
}

pub fn position_row() -> PositionRow {
    PositionRow {
        sid: 1,
        lat: 500_000_000,
        lon: 300_000_000,
        profile: 1,
        heading: None,
        speed: None,
        altitude: None,
    }
}

pub fn from_hex(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).expect("hex"))
        .collect()
}

/// splitmix64: a seeded stream, the same on every run.
pub struct Rng(pub u64);

impl Rng {
    pub fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    pub fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }

    pub fn byte(&mut self) -> u8 {
        self.next() as u8
    }
}

/// Changes `k` distinct positions of `word` to other values; `keep` positions are always among them.
pub fn corrupt(word: &mut [u8], k: usize, first: Option<usize>, rng: &mut Rng) {
    let mut hit: Vec<usize> = first.into_iter().collect();
    while hit.len() < k {
        let p = rng.below(word.len());
        if !hit.contains(&p) {
            hit.push(p);
        }
    }
    for p in hit {
        word[p] ^= rng.byte() | 1;
    }
}

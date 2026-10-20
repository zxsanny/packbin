//! Random rows and the two-walker checks shared by the nostd differential tests.
#![allow(dead_code)]

use super::tree::{compare, values_of, Built, Leaf};
use super::Slots;
use packbin::nostd::{self, Error, Kind, Num, Row};
use Kind::*;

pub struct Rng(pub u64);

impl Rng {
    pub fn next(&mut self) -> u64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        self.0
    }
    pub fn one_in(&mut self, n: u64) -> bool {
        self.next() % n == 0
    }
    pub fn below(&mut self, n: u64) -> u64 {
        self.next() % n
    }
}

pub fn int_of(row: &Slots, id: u16) -> Option<i64> {
    match row.num(id)? {
        Num::U8(v) => Some(i64::from(v)),
        Num::U16(v) => Some(i64::from(v)),
        Num::U32(v) => Some(i64::from(v)),
        Num::U64(v) => i64::try_from(v).ok(),
        Num::I8(v) => Some(i64::from(v)),
        Num::I16(v) => Some(i64::from(v)),
        Num::I32(v) => Some(i64::from(v)),
        Num::I64(v) => Some(v),
        _ => None,
    }
}

pub fn number(rng: &mut Rng, kind: Kind) -> Num {
    let small = !rng.one_in(8);
    let r = if small { rng.below(4) } else { rng.next() };
    match kind {
        U8 => Num::U8(r as u8),
        U16 => Num::U16(r as u16),
        U32 => Num::U32(r as u32),
        U64 => Num::U64(r),
        I8 => Num::I8(if small { -(r as i8) } else { r as i8 }),
        I16 => Num::I16(if small { -(r as i16) } else { r as i16 }),
        I32 => Num::I32(r as i32),
        I64 => Num::I64(r as i64),
        F32 => Num::F32(f32::from_bits(rng.next() as u32)),
        F64 => Num::F64(f64::from_bits(rng.next())),
        other => panic!("not a number: {other:?}"),
    }
}

/// A row that mostly packs: counts mostly match their source, some values are absent or wrong.
pub fn random_row(rng: &mut Rng, leaves: &[(u16, Leaf)]) -> Slots {
    let mut row = Slots::default();
    for (id, leaf) in leaves {
        let id = *id;
        let count = |row: &Slots, c: u16, bias: i64| {
            int_of(row, c)
                .map(|v| v + bias)
                .filter(|v| (0..=12).contains(v))
                .unwrap_or(rng_free_count(id)) as usize
        };
        match leaf {
            Leaf::Num(k) => {
                if !rng.one_in(10) {
                    row.set_num(id, number(rng, *k));
                }
            }
            Leaf::U2 => {
                let v = if rng.one_in(30) {
                    4
                } else {
                    rng.below(4) as u8
                };
                if !rng.one_in(10) {
                    row.set_num(id, Num::U8(v));
                }
            }
            Leaf::Bool => {
                row.set_flag(id, rng.one_in(2));
            }
            Leaf::Bytes(len) => {
                if !rng.one_in(8) {
                    let len = usize::from(*len) + usize::from(rng.one_in(20));
                    let b: Vec<u8> = (0..len).map(|_| rng.next() as u8).collect();
                    row.set_bytes(id, &b);
                }
            }
            Leaf::Sized(c) | Leaf::Bits(c) | Leaf::Packed(_, c, _) => {
                if rng.one_in(16) {
                    continue;
                }
                let (bias, max) = match &leaf {
                    Leaf::Packed(w, _, b) => (i64::from(*b), (1u64 << w) - 1),
                    Leaf::Bits(_) => (0, 1),
                    _ => (0, 255),
                };
                let mut len = count(&row, *c, bias);
                if rng.one_in(30) {
                    len += 1;
                }
                let mut v: Vec<u8> = (0..len).map(|_| (rng.next() % (max + 1)) as u8).collect();
                if rng.one_in(30) {
                    if let Some(first) = v.first_mut() {
                        *first = (max + 1) as u8;
                    }
                }
                row.set_bytes(id, &v);
            }
            Leaf::Repeat(body) => {
                let n = rng.below(4) as usize;
                let rounds = (0..n).map(|_| random_row(rng, body)).collect();
                set_items(&mut row, id, rounds);
            }
            Leaf::Times(_, c, body) => {
                let mut n = count(&row, *c, 0);
                if rng.one_in(30) {
                    n += 1;
                }
                let rounds = (0..n).map(|_| random_row(rng, body)).collect();
                set_items(&mut row, id, rounds);
            }
            Leaf::List(element) => {
                if rng.one_in(16) {
                    continue;
                }
                let n = rng.below(4) as usize;
                let elements = [(0u16, (**element).clone())];
                let items = (0..n).map(|_| random_row(rng, &elements)).collect();
                set_items(&mut row, id, items);
            }
        }
    }
    row
}

/// Gives `row` the items of container `id`.
pub fn set_items(row: &mut Slots, id: u16, items: Vec<Slots>) {
    let at = usize::from(id);
    if row.items.len() <= at {
        row.items.resize(at + 1, None);
    }
    row.items[at] = Some(items);
}

pub fn rng_free_count(id: u16) -> i64 {
    i64::from(id % 3)
}

pub fn pack_both(built: &Built, row: &Slots) -> (Result<Vec<u8>, Error>, Result<Vec<u8>, String>) {
    let scheme = nostd::Scheme::new(0x21, &built.fields);
    let mut out = vec![0u8; 512];
    let ours = nostd::pack(&scheme, row, &mut out)
        .map(|n| out[..n].to_vec())
        .map_err(|f| f.error);
    let theirs = packbin::pack(&built.reference, &values_of(row, &built.leaves))
        .map_err(|e| format!("{e:?}"));
    (ours, theirs)
}

/// Both walkers read `wire` alike: both refuse it, or both accept it with the same values.
pub fn assert_read_alike(built: &Built, wire: &[u8], label: &str) -> bool {
    let scheme = nostd::Scheme::new(0x21, &built.fields);
    // Storage for every value a short packet can hold: capacity is a core-only limit.
    let mut back = Slots {
        cap: Some(1024),
        ..Slots::default()
    };
    let ours = nostd::unpack(&scheme, wire, &mut back);
    let theirs = packbin::unpack(&built.reference, wire);
    assert_eq!(
        ours.is_ok(),
        theirs.is_ok(),
        "{label}: {wire:02x?} {ours:?} {theirs:?}"
    );
    if let Ok(read) = theirs {
        if let Err(e) = compare(&read, &back, &built.leaves) {
            panic!("{label}: {e} for {wire:02x?}");
        }
    }
    ours.is_ok()
}

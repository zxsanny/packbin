//! The heap-free API `packbin::nostd`: the scheme is a flat table of entries; `when` and `group` name
//! how many table entries below them belong to them (a `u16`, so depth up to 65535), and a row is read
//! and written by field id through the `Row` trait. The lines carry `-nostd` after the depth.
use crate::{caught, hex, message, Cells};
use packbin::nostd::{
    group, pack_with, u8, unpack, validate, when, Field, Num, Row, Scheme, DICT_KEY,
    SCRATCH_WORDS_PER_CHAR,
};
use std::collections::BTreeMap;

/// A flat row: numbers by field id. The probe's shapes hold no item, key or string.
#[derive(Debug, Default, PartialEq)]
struct Slots {
    nums: BTreeMap<u16, Num>,
}

impl Row for Slots {
    fn num(&self, id: u16) -> Option<Num> {
        self.nums.get(&id).copied()
    }
    fn bytes(&self, _id: u16) -> Option<&[u8]> {
        None
    }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        self.nums.insert(id, value);
        true
    }
    fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
        false
    }
    fn clear(&mut self, id: u16) {
        if id != DICT_KEY {
            self.nums.remove(&id);
        }
    }
    fn slots(&mut self, _id: u16) -> Option<&mut [u8]> {
        None
    }
    fn set_count(&mut self, _id: u16, _n: usize) -> bool {
        false
    }
    fn count(&self, _id: u16) -> Option<usize> {
        None
    }
    fn item(&self, _id: u16, _k: usize) -> Option<&dyn Row> {
        None
    }
    fn item_mut(&mut self, _id: u16, _k: usize) -> Option<&mut dyn Row> {
        None
    }
}

/// `u8 id 0`, then `depth` whens (`id 0 == 1`) with `depth`, `depth - 1`, ... 1 entries below them,
/// then `u8 id 1`. Each `when` is numbered 1, the id of its first member.
fn when_table(depth: usize) -> Vec<Field> {
    let mut table = vec![u8(0)];
    for below in (1..=depth).rev() {
        table.push(when(1, 0, 1, below as u16));
    }
    table.push(u8(1));
    table
}

/// `depth` groups with `depth`, `depth - 1`, ... 1 entries below them, then `u8 id 0`.
fn group_table(depth: usize) -> Vec<Field> {
    let mut table = Vec::with_capacity(depth + 1);
    for below in (1..=depth).rev() {
        table.push(group(0, below as u16));
    }
    table.push(u8(0));
    table
}

pub fn run(shape: &str, depth: usize) -> Cells {
    let mut cells = Cells {
        shape: format!("{shape}-{depth}-nostd"),
        build: String::new(),
        pack: "-".to_string(),
        unpack: "-".to_string(),
    };
    if depth > usize::from(u16::MAX) {
        cells.build = "n/a: an entry counts its members in a u16".to_string();
        return cells;
    }
    let table = if shape == "when" {
        when_table(depth)
    } else {
        group_table(depth)
    };
    let scheme = Scheme::new(1, &table);
    // Build is `validate`, which `pack` and `unpack` call first.
    match caught(|| validate(&scheme)) {
        Ok(Ok(())) => cells.build = "built".to_string(),
        Ok(Err(fault)) => {
            cells.build = format!("refused: {}", message(&format!("{fault:?}")));
            return cells;
        }
        Err(text) => {
            cells.build = format!("refused: panic: {}", message(&text));
            return cells;
        }
    }
    let mut given = Slots::default();
    if shape == "when" {
        given.nums.insert(0, Num::U8(1));
        given.nums.insert(1, Num::U8(7));
    } else {
        given.nums.insert(0, Num::U8(7));
    }
    let mut out = [0u8; 64];
    let mut scratch = [0u32; SCRATCH_WORDS_PER_CHAR * 16];
    let n = match caught(|| pack_with(&scheme, &given, &mut out, &mut scratch)) {
        Ok(Ok(n)) => n,
        Ok(Err(fault)) => {
            cells.pack = format!("refused: {}", message(&format!("{fault:?}")));
            return cells;
        }
        Err(text) => {
            cells.pack = format!("threw: {}", message(&text));
            return cells;
        }
    };
    cells.pack = hex(&out[..n]);
    let mut back = Slots::default();
    cells.unpack = match caught(|| unpack(&scheme, &out[..n], &mut back)) {
        Ok(Ok(_)) if back == given => "same".to_string(),
        Ok(Ok(_)) => format!("differs: {}", message(&format!("{:?}", back.nums))),
        Ok(Err(fault)) => format!("refused: {}", message(&format!("{fault:?}"))),
        Err(text) => format!("threw: {}", message(&text)),
    };
    cells
}

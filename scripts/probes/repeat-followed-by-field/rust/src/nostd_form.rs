//! The heap-free API `packbin::nostd`: a scheme is a table of entries, a row is read and written by
//! field id through the `Row` trait, and errors are `Fault` values. The lines carry `-nostd` after
//! the shape name.
//!
//! - An entry names an order id, not a name: `repeat`, `when`, `flags` and `group` take the id of
//!   their first member, and `entries` counts the table entries below them.
//! - The rounds of a `repeat` are items of the row (`Row::count`, `Row::item`), one row a round,
//!   kept under the id of the `repeat`.
//! - `group` writes its members on the same row: there is no nested row, so shape `d` holds the same
//!   row as shape `a`.
//! - A `list` or `dict` element is one value, never a row; the nearest scheme for `b` and `c` is a
//!   `group` as the element.
//! - Build is `validate`, which `pack` and `unpack` call first.
use crate::{caught, compared, hex, line};
use packbin::nostd::{
    dict, flags, group, key, list, pack_with, repeat, u8, unpack, validate, when, Field, Num, Row,
    Scheme, DICT_KEY, SCRATCH_WORDS_PER_CHAR,
};
use std::collections::BTreeMap;

/// The longest dict key a row has room for on unpack.
const KEY_ROOM: usize = 16;

/// A row for any scheme of the probe: numbers and items by field id. `item_mut` always has room for
/// one more item, so a round too many is never refused for lack of storage.
#[derive(Clone, Debug, Default)]
struct Slots {
    nums: BTreeMap<u16, Num>,
    /// The items of a `repeat`, `list` or `dict`, by id.
    items: BTreeMap<u16, Vec<Slots>>,
    /// What a `dict` item holds under `DICT_KEY`.
    key: Option<Vec<u8>>,
}

impl Row for Slots {
    fn num(&self, id: u16) -> Option<Num> {
        self.nums.get(&id).copied()
    }
    fn bytes(&self, id: u16) -> Option<&[u8]> {
        if id == DICT_KEY {
            self.key.as_deref()
        } else {
            None
        }
    }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        self.nums.insert(id, value);
        true
    }
    fn set_bytes(&mut self, id: u16, value: &[u8]) -> bool {
        if id == DICT_KEY {
            self.key = Some(value.to_vec());
        }
        id == DICT_KEY
    }
    fn clear(&mut self, id: u16) {
        if id == DICT_KEY {
            self.key = None;
        } else {
            self.nums.remove(&id);
            self.items.remove(&id);
        }
    }
    fn slots(&mut self, id: u16) -> Option<&mut [u8]> {
        if id != DICT_KEY {
            return None;
        }
        self.key = Some(vec![0; KEY_ROOM]);
        self.key.as_deref_mut()
    }
    fn set_count(&mut self, id: u16, n: usize) -> bool {
        if id == DICT_KEY {
            return match self.key.as_mut() {
                Some(key) if n <= key.len() => {
                    key.truncate(n);
                    true
                }
                _ => false,
            };
        }
        let items = self.items.entry(id).or_default();
        if n > items.len() {
            return false;
        }
        items.truncate(n);
        true
    }
    fn count(&self, id: u16) -> Option<usize> {
        self.items.get(&id).map(Vec::len)
    }
    fn item(&self, id: u16, k: usize) -> Option<&dyn Row> {
        self.items.get(&id)?.get(k).map(|item| item as &dyn Row)
    }
    fn item_mut(&mut self, id: u16, k: usize) -> Option<&mut dyn Row> {
        let items = self.items.entry(id).or_default();
        if items.len() <= k {
            items.resize(k + 1, Slots::default());
        }
        items.get_mut(k).map(|item| item as &mut dyn Row)
    }
}

fn row(nums: &[(u16, u8)], items: Vec<(u16, Vec<Slots>)>) -> Slots {
    Slots {
        nums: nums.iter().map(|(id, n)| (*id, Num::U8(*n))).collect(),
        items: items.into_iter().collect(),
        key: None,
    }
}

/// One round per item, each holding `v` under `id`.
fn rounds(id: u16, items: &[u8]) -> Vec<Slots> {
    items.iter().map(|v| row(&[(id, *v)], vec![])).collect()
}

fn keyed(key: &str, item: Slots) -> Slots {
    Slots {
        key: Some(key.as_bytes().to_vec()),
        ..item
    }
}

/// A row as text, by field id. A container unpack filled with no item prints as `[]`.
fn shown(row: &Slots) -> String {
    let mut members = Vec::new();
    if let Some(key) = &row.key {
        members.push(format!("key: {:?}", String::from_utf8_lossy(key)));
    }
    for (id, num) in &row.nums {
        members.push(format!("{id}: {num:?}"));
    }
    for (id, items) in &row.items {
        let items: Vec<String> = items.iter().map(shown).collect();
        members.push(format!("{id}: [{}]", items.join(", ")));
    }
    format!("{{{}}}", members.join(", "))
}

fn probe(shape: &str, fields: &[Field], given: &Slots) {
    let shape = format!("{shape}-nostd");
    let scheme = Scheme::new(1, fields);
    match caught(|| validate(&scheme)) {
        Ok(Ok(())) => {}
        Ok(Err(fault)) => return line(&shape, &format!("refused: {fault:?}"), "-", "-"),
        Err(message) => return line(&shape, &format!("refused: panic: {message}"), "-", "-"),
    }
    let mut out = [0u8; 64];
    let mut scratch = [0u32; SCRATCH_WORDS_PER_CHAR * KEY_ROOM];
    let n = match caught(|| pack_with(&scheme, given, &mut out, &mut scratch)) {
        Ok(Ok(n)) => n,
        Ok(Err(fault)) => return line(&shape, "built", &format!("refused: {fault:?}"), "-"),
        Err(message) => return line(&shape, "built", &format!("refused: panic: {message}"), "-"),
    };
    let packed = &out[..n];
    let mut back = Slots::default();
    let unpacked = match caught(|| unpack(&scheme, packed, &mut back)) {
        Ok(Ok(_)) => compared(&shape, || {
            let came_back = shown(&back);
            if came_back == shown(given) {
                "same".to_string()
            } else {
                format!("differs: {came_back}")
            }
        }),
        Ok(Err(fault)) => format!("refused: {fault:?}"),
        Err(message) => format!("threw: {message}"),
    };
    line(&shape, "built", &hex(packed), &unpacked);
}

pub fn run() {
    // control: u8 x (id 0), then repeat { u8 v (id 1) }.
    probe(
        "control",
        &[u8(0), repeat(1, 1), u8(1)],
        &row(&[(0, 9)], vec![(1, rounds(1, &[5, 6]))]),
    );

    // a: repeat { u8 v (id 0) }, then u8 x (id 1).
    probe(
        "a",
        &[repeat(0, 1), u8(0), u8(1)],
        &row(&[(1, 9)], vec![(0, rounds(0, &[5, 6]))]),
    );

    // b: list (id 0) of group { u8 mode (id 0), repeat { u8 v (id 1) } }.
    let item_one = row(&[(0, 1)], vec![(1, rounds(1, &[5]))]);
    let item_two = row(&[(0, 2)], vec![(1, rounds(1, &[]))]);
    probe(
        "b",
        &[list(0, 4), group(0, 3), u8(0), repeat(1, 1), u8(1)],
        &row(&[], vec![(0, vec![item_one.clone(), item_two.clone()])]),
    );

    // c: dict (id 0) of key, group { u8 mode (id 0), repeat { u8 v (id 1) } }.
    probe(
        "c",
        &[dict(0, 5), key(), group(0, 3), u8(0), repeat(1, 1), u8(1)],
        &row(
            &[],
            vec![(0, vec![keyed("a", item_one), keyed("b", item_two)])],
        ),
    );

    // d: group { repeat { u8 v (id 0) } }, then u8 x (id 1). The group is on the same row.
    probe(
        "d",
        &[group(0, 2), repeat(0, 1), u8(0), u8(1)],
        &row(&[(1, 9)], vec![(0, rounds(0, &[5, 6]))]),
    );

    // e-when: u8 k (id 0), when (k == 1) { repeat { u8 v (id 1) } }, then u8 x (id 2).
    probe(
        "e-when",
        &[u8(0), when(1, 0, 1, 2), repeat(1, 1), u8(1), u8(2)],
        &row(&[(0, 1), (2, 9)], vec![(1, rounds(1, &[5, 6]))]),
    );

    // e-flags: flags { repeat { u8 v (id 0) } }, then u8 x (id 1).
    probe(
        "e-flags",
        &[flags(0, 2), repeat(0, 1), u8(0), u8(1)],
        &row(&[(1, 9)], vec![(0, rounds(0, &[5, 6]))]),
    );

    // f: repeat { u8 v (id 0) }, then repeat { u8 w (id 1) }. Each repeat keeps its own items.
    probe(
        "f",
        &[repeat(0, 1), u8(0), repeat(1, 1), u8(1)],
        &row(&[], vec![(0, rounds(0, &[5])), (1, rounds(1, &[6]))]),
    );
}

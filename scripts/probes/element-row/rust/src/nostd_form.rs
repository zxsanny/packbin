//! The heap-free API `packbin::nostd`: a scheme is a table of entries, a row is read and written by
//! field id through the `Row` trait, and errors are `Fault` values. The lines carry `-nostd` after
//! the shape name.
//!
//! - A `list` (or `dict`) entry is followed by its element: here a `group` of the members, ids from
//!   0 in each item. An item is a row of its own (`Row::count`, `Row::item`); a `dict` item holds its
//!   key under `DICT_KEY`, and keys go in ascending order.
//! - Build is `validate`, which `pack` and `unpack` call first. The API promises never to panic, so
//!   a panic anywhere is `threw:`.
use crate::{caught, compared, hex, line, na};
use packbin::nostd::{
    dict, group, key, list, pack_with, times, u32, u8, unpack, utf8, validate, when, Field, Num,
    Row, Scheme, DICT_KEY, SCRATCH_WORDS_PER_CHAR,
};
use std::collections::BTreeMap;

/// The longest string a row has room for on unpack.
const TEXT_ROOM: usize = 16;

/// A row for any scheme of the probe: numbers, strings and items by field id. An item may be
/// `None` (a null item). `item_mut` always has room for one more item.
#[derive(Clone, Debug, Default)]
struct Slots {
    nums: BTreeMap<u16, Num>,
    /// Strings by id; a `dict` item's key under `DICT_KEY`.
    texts: BTreeMap<u16, Vec<u8>>,
    /// The items of a `times`, `list` or `dict`, by id.
    items: BTreeMap<u16, Vec<Option<Slots>>>,
}

impl Row for Slots {
    fn num(&self, id: u16) -> Option<Num> {
        self.nums.get(&id).copied()
    }
    fn bytes(&self, id: u16) -> Option<&[u8]> {
        self.texts.get(&id).map(Vec::as_slice)
    }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        self.nums.insert(id, value);
        true
    }
    fn set_bytes(&mut self, id: u16, value: &[u8]) -> bool {
        self.texts.insert(id, value.to_vec());
        true
    }
    fn clear(&mut self, id: u16) {
        self.nums.remove(&id);
        self.texts.remove(&id);
        self.items.remove(&id);
    }
    fn slots(&mut self, id: u16) -> Option<&mut [u8]> {
        self.texts.insert(id, vec![0; TEXT_ROOM]);
        self.texts.get_mut(&id).map(Vec::as_mut_slice)
    }
    fn set_count(&mut self, id: u16, n: usize) -> bool {
        if let Some(text) = self.texts.get_mut(&id) {
            if n > text.len() {
                return false;
            }
            text.truncate(n);
            return true;
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
        self.items
            .get(&id)?
            .get(k)?
            .as_ref()
            .map(|item| item as &dyn Row)
    }
    fn item_mut(&mut self, id: u16, k: usize) -> Option<&mut dyn Row> {
        let items = self.items.entry(id).or_default();
        if items.len() <= k {
            items.resize(k + 1, None);
        }
        let slot = items.get_mut(k)?;
        Some(slot.get_or_insert_with(Slots::default) as &mut dyn Row)
    }
}

fn comment(id: &str, body: Option<&str>, author_id: u32, author: &str) -> Slots {
    let mut row = Slots::default();
    row.texts.insert(0, id.as_bytes().to_vec());
    if let Some(body) = body {
        row.texts.insert(1, body.as_bytes().to_vec());
    }
    row.nums.insert(2, Num::U32(author_id));
    row.texts.insert(3, author.as_bytes().to_vec());
    row
}

fn c1() -> Slots {
    comment("c1", Some("hi"), 7, "ann")
}
fn c2() -> Slots {
    comment("c2", Some("ok"), 258, "bo")
}
fn c3() -> Slots {
    comment("c3", Some("yes"), 1, "cy")
}

fn keyed(key: &str, mut item: Slots) -> Slots {
    item.texts.insert(DICT_KEY, key.as_bytes().to_vec());
    item
}

fn u8s(pairs: &[(u16, u8)]) -> Slots {
    Slots {
        nums: pairs.iter().map(|(id, n)| (*id, Num::U8(*n))).collect(),
        ..Slots::default()
    }
}

/// A row holding `items` under id 0.
fn holding(items: Vec<Option<Slots>>) -> Slots {
    Slots {
        items: [(0, items)].into_iter().collect(),
        ..Slots::default()
    }
}

/// A row as text, by field id. A container unpack filled with no item prints as `[]`.
fn shown(row: &Slots) -> String {
    let mut members = Vec::new();
    for (id, text) in &row.texts {
        let name = if *id == DICT_KEY {
            "key".to_string()
        } else {
            id.to_string()
        };
        members.push(format!("{name}: {:?}", String::from_utf8_lossy(text)));
    }
    for (id, num) in &row.nums {
        members.push(format!("{id}: {num:?}"));
    }
    for (id, items) in &row.items {
        let items: Vec<String> = items
            .iter()
            .map(|item| item.as_ref().map_or("null".to_string(), shown))
            .collect();
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
        Err(message) => return line(&shape, &format!("threw: panic: {message}"), "-", "-"),
    }
    let mut out = [0u8; 128];
    let mut scratch = [0u32; SCRATCH_WORDS_PER_CHAR * TEXT_ROOM];
    let n = match caught(|| pack_with(&scheme, given, &mut out, &mut scratch)) {
        Ok(Ok(n)) => n,
        Ok(Err(fault)) => return line(&shape, "built", &format!("refused: {fault:?}"), "-"),
        Err(message) => return line(&shape, "built", &format!("threw: panic: {message}"), "-"),
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
        Err(message) => format!("threw: panic: {message}"),
    };
    line(&shape, "built", &hex(packed), &unpacked);
}

/// list (id 0) of group { utf8 id (0), utf8 text (1), u32 authorId (2), utf8 author (3) }.
const LISTED: &[Field] = &[list(0, 5), group(0, 4), utf8(0), utf8(1), u32(2), utf8(3)];

/// dict (id 0) of key, group { the four members of `LISTED` }.
const KEYED: &[Field] = &[
    dict(0, 6),
    key(),
    group(0, 4),
    utf8(0),
    utf8(1),
    u32(2),
    utf8(3),
];

pub fn run() {
    probe("list-0", LISTED, &holding(vec![]));
    probe("list-1", LISTED, &holding(vec![Some(c1())]));
    probe(
        "list-3",
        LISTED,
        &holding(vec![Some(c1()), Some(c2()), Some(c3())]),
    );
    // Keys go in ascending order: the row gives a, then b.
    probe(
        "dict-2",
        KEYED,
        &holding(vec![Some(keyed("a", c1())), Some(keyed("b", c2()))]),
    );

    na(
        "coll-nostd",
        "a list or dict reads its items through Row::count and Row::item, whatever the row keeps \
         them in; no other collection type",
    );

    // when inside an element row: u8 mode (0), when (mode == 1) { u8 speed (1) }.
    probe(
        "when",
        &[list(0, 4), group(0, 3), u8(0), when(1, 0, 1, 1), u8(1)],
        &holding(vec![Some(u8s(&[(0, 1), (1, 7)])), Some(u8s(&[(0, 0)]))]),
    );

    // times inside an element row: u8 c (0), times (c) { u8 v (1) }.
    let mut two = u8s(&[(0, 2)]);
    two.items
        .insert(1, vec![Some(u8s(&[(1, 5)])), Some(u8s(&[(1, 6)]))]);
    let mut none = u8s(&[(0, 0)]);
    none.items.insert(1, vec![]);
    probe(
        "times",
        &[list(0, 4), group(0, 3), u8(0), times(1, 0, 1), u8(1)],
        &holding(vec![Some(two), Some(none)]),
    );

    na(
        "other-row-nostd",
        "no row types: a member is read by field id from any Row",
    );
    na(
        "nested-other-row-nostd",
        "no row types: a group's members are ids of the row around it",
    );

    // A required member (text, id 1) left out of an element.
    probe(
        "null-member",
        LISTED,
        &holding(vec![Some(comment("c1", None, 7, "ann"))]),
    );

    // A list that holds a null element: count 2, item 1 is None.
    probe("null-item", LISTED, &holding(vec![Some(c1()), None]));
}

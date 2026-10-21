//! A string, a dictionary and a nested scheme (a `repeat` of strings, a dictionary and a group),
//! packed with scratch words and read back.

use packbin::nostd::{
    dict, group, key, pack_with, repeat, u8, unpack, utf8, Field, Num, Row, Scheme, DICT_KEY,
};

// A string that the compact form shortens, and a dictionary of two entries.
static FIELDS: [Field; 4] = [utf8(0), dict(1, 2), key(), u8(0)];
static SCHEME: Scheme = Scheme::new(0x50, &FIELDS);
const TEXT: &[u8] = "привіт, світе".as_bytes();

#[derive(Clone, Copy, PartialEq)]
struct Entry {
    key: [u8; 8],
    klen: usize,
    value: u8,
}

impl Row for Entry {
    fn num(&self, id: u16) -> Option<Num> {
        (id == 0).then_some(Num::U8(self.value))
    }
    fn bytes(&self, id: u16) -> Option<&[u8]> {
        if id == DICT_KEY {
            self.key.get(..self.klen)
        } else {
            None
        }
    }
    fn set_num(&mut self, id: u16, value: Num) -> bool {
        match (id, value) {
            (0, Num::U8(v)) => {
                self.value = v;
                true
            }
            _ => false,
        }
    }
    fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
        false
    }
    fn slots(&mut self, id: u16) -> Option<&mut [u8]> {
        (id == DICT_KEY).then_some(&mut self.key[..])
    }
    fn set_count(&mut self, id: u16, n: usize) -> bool {
        id == DICT_KEY && n <= self.key.len() && {
            self.klen = n;
            true
        }
    }
}

#[derive(Clone, Copy, PartialEq)]
struct Message {
    text: [u8; 32],
    tlen: usize,
    entries: [Entry; 2],
    n: usize,
}

const NO_ENTRY: Entry = Entry {
    key: [0; 8],
    klen: 0,
    value: 0,
};

impl Row for Message {
    fn num(&self, _id: u16) -> Option<Num> {
        None
    }
    fn bytes(&self, id: u16) -> Option<&[u8]> {
        if id == 0 {
            self.text.get(..self.tlen)
        } else {
            None
        }
    }
    fn set_num(&mut self, _id: u16, _value: Num) -> bool {
        false
    }
    fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
        false
    }
    fn slots(&mut self, id: u16) -> Option<&mut [u8]> {
        (id == 0).then_some(&mut self.text[..])
    }
    fn set_count(&mut self, id: u16, n: usize) -> bool {
        match id {
            0 if n <= self.text.len() => {
                self.tlen = n;
                true
            }
            1 if n <= self.entries.len() => {
                self.n = n;
                true
            }
            _ => false,
        }
    }
    fn count(&self, id: u16) -> Option<usize> {
        (id == 1).then_some(self.n)
    }
    fn item(&self, id: u16, k: usize) -> Option<&dyn Row> {
        if id == 1 && k < self.n {
            self.entries.get(k).map(|e| e as &dyn Row)
        } else {
            None
        }
    }
    fn item_mut(&mut self, id: u16, k: usize) -> Option<&mut dyn Row> {
        if id == 1 {
            self.entries.get_mut(k).map(|e| e as &mut dyn Row)
        } else {
            None
        }
    }
}

// A nested scheme: a `repeat` of rounds, each with a string, a dictionary and a group that holds
// a string. It is the deepest walk the library makes in one call (repeat, dict, element, group),
// so the stack figure of the `text` set is measured on it.
static NESTED_FIELDS: [Field; 7] = [
    repeat(0, 6),
    utf8(0),
    dict(1, 2),
    key(),
    u8(0),
    group(2, 1),
    utf8(2),
];
static NESTED: Scheme = Scheme::new(0x51, &NESTED_FIELDS);

#[derive(Clone, Copy, PartialEq)]
struct Round {
    name: [u8; 16],
    nlen: usize,
    entries: [Entry; 2],
    en: usize,
    note: [u8; 16],
    olen: usize,
}

const NO_ROUND: Round = Round {
    name: [0; 16],
    nlen: 0,
    entries: [NO_ENTRY; 2],
    en: 0,
    note: [0; 16],
    olen: 0,
};

impl Row for Round {
    fn num(&self, _id: u16) -> Option<Num> {
        None
    }
    fn bytes(&self, id: u16) -> Option<&[u8]> {
        match id {
            0 => self.name.get(..self.nlen),
            2 => self.note.get(..self.olen),
            _ => None,
        }
    }
    fn set_num(&mut self, _id: u16, _value: Num) -> bool {
        false
    }
    fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
        false
    }
    fn slots(&mut self, id: u16) -> Option<&mut [u8]> {
        match id {
            0 => Some(&mut self.name[..]),
            2 => Some(&mut self.note[..]),
            _ => None,
        }
    }
    fn set_count(&mut self, id: u16, n: usize) -> bool {
        match id {
            0 if n <= self.name.len() => {
                self.nlen = n;
                true
            }
            2 if n <= self.note.len() => {
                self.olen = n;
                true
            }
            1 if n <= self.entries.len() => {
                self.en = n;
                true
            }
            _ => false,
        }
    }
    fn count(&self, id: u16) -> Option<usize> {
        (id == 1).then_some(self.en)
    }
    fn item(&self, id: u16, k: usize) -> Option<&dyn Row> {
        if id == 1 && k < self.en {
            self.entries.get(k).map(|e| e as &dyn Row)
        } else {
            None
        }
    }
    fn item_mut(&mut self, id: u16, k: usize) -> Option<&mut dyn Row> {
        if id == 1 {
            self.entries.get_mut(k).map(|e| e as &mut dyn Row)
        } else {
            None
        }
    }
}

#[derive(Clone, Copy, PartialEq)]
struct Rounds {
    rounds: [Round; 2],
    n: usize,
}

impl Row for Rounds {
    fn num(&self, _id: u16) -> Option<Num> {
        None
    }
    fn bytes(&self, _id: u16) -> Option<&[u8]> {
        None
    }
    fn set_num(&mut self, _id: u16, _value: Num) -> bool {
        false
    }
    fn set_bytes(&mut self, _id: u16, _value: &[u8]) -> bool {
        false
    }
    fn set_count(&mut self, id: u16, n: usize) -> bool {
        id == 0 && n <= self.rounds.len() && {
            self.n = n;
            true
        }
    }
    fn count(&self, id: u16) -> Option<usize> {
        (id == 0).then_some(self.n)
    }
    fn item(&self, id: u16, k: usize) -> Option<&dyn Row> {
        if id == 0 && k < self.n {
            self.rounds.get(k).map(|r| r as &dyn Row)
        } else {
            None
        }
    }
    fn item_mut(&mut self, id: u16, k: usize) -> Option<&mut dyn Row> {
        if id == 0 {
            self.rounds.get_mut(k).map(|r| r as &mut dyn Row)
        } else {
            None
        }
    }
}

fn fill(into: &mut [u8; 16], text: &[u8]) -> usize {
    for (slot, byte) in into.iter_mut().zip(text) {
        *slot = *byte;
    }
    text.len().min(into.len())
}

/// Packs and reads back two rounds of the nested scheme; 0 when they match.
pub fn nested_roundtrip() -> i32 {
    let mut sent = Rounds {
        rounds: [NO_ROUND; 2],
        n: 2,
    };
    for (k, round) in sent.rounds.iter_mut().enumerate() {
        round.nlen = fill(&mut round.name, "привіт".as_bytes());
        round.olen = fill(&mut round.note, b"hello world");
        round.en = 2;
        for (e, entry) in round.entries.iter_mut().enumerate() {
            entry.key[0] = b'a' + e as u8;
            entry.klen = 1;
            entry.value = (k * 2 + e) as u8;
        }
    }
    let mut out = [0u8; 160];
    let mut scratch = [0u32; 48];
    let n = match pack_with(&NESTED, &sent, &mut out, &mut scratch) {
        Ok(n) => n,
        Err(fault) => return fault.error as i32 + 1,
    };
    let mut back = Rounds {
        rounds: [NO_ROUND; 2],
        n: 0,
    };
    match out.get(..n).map(|wire| unpack(&NESTED, wire, &mut back)) {
        Some(Ok(_)) if back == sent => 0,
        Some(Ok(_)) => 100,
        Some(Err(fault)) => fault.error as i32 + 20,
        None => 101,
    }
}

pub fn roundtrip() -> i32 {
    let mut sent = Message {
        text: [0; 32],
        tlen: TEXT.len(),
        entries: [NO_ENTRY; 2],
        n: 2,
    };
    for (slot, byte) in sent.text.iter_mut().zip(TEXT) {
        *slot = *byte;
    }
    sent.entries[0].key[0] = b'a';
    sent.entries[0].klen = 1;
    sent.entries[0].value = 1;
    sent.entries[1].key[0] = b'b';
    sent.entries[1].klen = 1;
    sent.entries[1].value = 2;
    let mut out = [0u8; 64];
    let mut scratch = [0u32; 48];
    let n = match pack_with(&SCHEME, &sent, &mut out, &mut scratch) {
        Ok(n) => n,
        Err(fault) => return fault.error as i32 + 1,
    };
    let mut back = Message {
        text: [0; 32],
        tlen: 0,
        entries: [NO_ENTRY; 2],
        n: 0,
    };
    match out.get(..n).map(|wire| unpack(&SCHEME, wire, &mut back)) {
        Some(Ok(_)) if back == sent => match nested_roundtrip() {
            0 => 0,
            other => other + 400,
        },
        Some(Ok(_)) => 100,
        Some(Err(fault)) => fault.error as i32 + 20,
        None => 101,
    }
}

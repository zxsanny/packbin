//! The decoded bytes of a payload that has already decoded once, one at a time and with no storage
//! beyond a few integers (the C++ `Stream`). A dictionary compares two keys by it without keeping
//! the earlier one.

use super::decode::{begin_compact, is_raw, Cursor, Sink};
use super::NUM_MODE;

struct Stream<'a> {
    raw: &'a [u8],
    cursor: Option<Cursor<'a>>,
    buf: [u8; 4],
    have: usize,
    at: usize,
}

impl<'a> Stream<'a> {
    fn new(p: &'a [u8]) -> Self {
        let mut s = Stream {
            raw: &[],
            cursor: None,
            buf: [0; 4],
            have: 0,
            at: 0,
        };
        let Some(first) = p.first() else {
            return s;
        };
        if is_raw(*first) {
            s.raw = p.get(1..).unwrap_or(&[]);
        } else if usize::from((first >> 2) & 7) <= NUM_MODE {
            s.cursor = begin_compact(p);
        }
        s
    }

    /// The next byte, or `None` at the end. A payload the codec would refuse reads as ended where
    /// it fails.
    fn next(&mut self) -> Option<u8> {
        if self.at < self.have {
            let byte = self.buf.get(self.at).copied();
            self.at = self.at.saturating_add(1);
            return byte;
        }
        if let Some((first, rest)) = self.raw.split_first() {
            self.raw = rest;
            return Some(*first);
        }
        while let Some(c) = self.cursor.as_mut() {
            if c.pos >= c.total {
                break;
            }
            let mut out = [0u8; 4];
            let mut sink = Sink::new(&mut out);
            if !c.step(&mut sink) {
                self.cursor = None;
                break;
            }
            let len = sink.len;
            if len != 0 {
                self.buf = out;
                self.have = len;
                self.at = 1;
                return out.first().copied();
            }
        }
        None
    }
}

/// Compares the decoded bytes of two payloads as unsigned bytes (a prefix is smaller). The work is
/// the length of the common prefix plus one byte of each.
pub(crate) fn compare_payloads(a: &[u8], b: &[u8]) -> core::cmp::Ordering {
    let mut sa = Stream::new(a);
    let mut sb = Stream::new(b);
    loop {
        let (x, y) = (sa.next(), sb.next());
        if x != y {
            return x.cmp(&y);
        }
        if x.is_none() {
            return core::cmp::Ordering::Equal;
        }
    }
}

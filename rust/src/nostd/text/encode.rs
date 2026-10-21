//! The compact text encoder (the C++ `text_encode.hpp` port; contract `compact-text` 1.0.0,
//! "Encoding"): the optimal parse over the 8 states (mode, capital lock) with the contract's
//! tie-break, kept in the caller's scratch words (`parse.rs`), written as bits here.

use super::super::count::put_field;
use super::super::error::{Error, Fault};
use super::super::io::Writer;
use super::parse::{classify, controls, edges_of, solve, Costs, Ctrl, Edge};
use super::raw::{forget_raw, is_last_raw, put_raw};
use super::{
    code_len, code_of, decode_utf8, HEADER_BITS, MAX_TEXT, MIN_ESC, MIN_LENGTH,
    SCRATCH_WORDS_PER_CHAR,
};

/// Writes bits, most significant first, into a zeroed buffer.
struct BitOut<'a> {
    p: &'a mut [u8],
    pos: usize,
}

impl BitOut<'_> {
    fn put(&mut self, value: u32, mut n: usize) {
        while n != 0 {
            let room = 8usize.saturating_sub(self.pos & 7);
            let take = n.min(room);
            let bits = value
                .checked_shr(n.saturating_sub(take) as u32)
                .unwrap_or(0)
                & 1u32.checked_shl(take as u32).unwrap_or(0).wrapping_sub(1);
            if let Some(b) = self.p.get_mut(self.pos >> 3) {
                *b |= bits
                    .checked_shl(room.saturating_sub(take) as u32)
                    .unwrap_or(0) as u8;
            }
            self.pos = self.pos.saturating_add(take);
            n = n.saturating_sub(take);
        }
    }

    fn sym(&mut self, mode: usize, sym: u8) {
        self.put(
            u32::from(code_of(mode, usize::from(sym))),
            usize::from(code_len(mode, usize::from(sym))),
        );
    }
}

/// Writes the symbols of the winning parse: from the state, the edge whose cost plus the cost of
/// the rest equals the cheapest, the smallest first symbol among them.
/// False when no edge fits the cost table (the table and the parse disagree).
fn write_parse(
    s: &[u8],
    chars: usize,
    mut state: usize,
    costs: &Costs<'_>,
    out: &mut BitOut<'_>,
) -> bool {
    let mut at = 0usize;
    let mut i = 0usize;
    while i < chars {
        let (cp, nbytes) = s.get(at..).and_then(decode_utf8).unwrap_or((0, 1));
        let c = classify(cp);
        let want = costs.at(i, state);
        let m = state >> 1;
        let (e, ne) = edges_of(&c, state, nbytes);
        let mut best: Option<Edge> = None;
        let mut best_ctrl: Option<Ctrl> = None;
        let mut best_first = 256u32;
        for x in controls(state) {
            let to = usize::from(x.to);
            if u32::from(x.first) < best_first
                && u32::from(x.bits).saturating_add(costs.at(i, to)) == want
            {
                best_ctrl = Some(*x);
                best = None;
                best_first = u32::from(x.first);
            }
        }
        for x in e.iter().take(ne) {
            if u32::from(x.first) < best_first
                && u32::from(x.bits).saturating_add(costs.at(i.saturating_add(1), state)) == want
            {
                best = Some(*x);
                best_ctrl = None;
                best_first = u32::from(x.first);
            }
        }
        if let Some(x) = best_ctrl {
            out.sym(m, x.first);
            state = usize::from(x.to);
            continue;
        }
        let Some(x) = best else {
            return false;
        };
        if x.kind == 1 {
            // CAP is the first symbol of this edge, the letter follows
            out.sym(m, x.first);
        }
        out.sym(m, x.sym);
        if x.kind == 2 {
            for b in s.iter().skip(at).take(nbytes) {
                out.put(u32::from(*b), 8);
            }
        }
        at = at.saturating_add(nbytes);
        i = i.saturating_add(1);
    }
    true
}

/// Writes one string field (count, payload) for the UTF-8 text `s`. Nothing is written when the
/// text is not valid UTF-8 or too long (`BadValue`), the scratch is too small (`ScratchTooSmall`,
/// `needed` the scratch words) or the buffer is full (`BufferFull`, `needed` the field bytes).
pub(crate) fn encode_field(
    w: &mut Writer<'_>,
    scratch: &mut [u32],
    id: i32,
    s: &[u8],
) -> Result<(), Fault> {
    let len = s.len();
    if len > MAX_TEXT {
        return Err(Fault::bad(w.len(), id));
    }
    if len == 0 {
        put_field(w, 0, id)?;
        return Ok(());
    }
    if is_last_raw(w, scratch, s) {
        return put_raw(w, scratch, id, s);
    }
    // One pass: validate, count the characters and bound the compact size from below. A character
    // costs at least the shortest code, and one outside the tables at least ESC and its bytes.
    let mut chars = 0usize;
    let mut floor_bits = HEADER_BITS;
    let mut at = 0usize;
    while at < len {
        let (cp, n) = s
            .get(at..)
            .and_then(decode_utf8)
            .ok_or_else(|| Fault::bad(w.len(), id))?;
        at = at.saturating_add(n);
        chars = chars.saturating_add(1);
        let bits = if cp < 0x80 || (0x400..0x500).contains(&cp) {
            MIN_LENGTH
        } else {
            MIN_ESC.saturating_add(8usize.saturating_mul(n))
        };
        floor_bits = floor_bits.saturating_add(bits);
    }
    let raw = len.saturating_add(1);
    if floor_bits.div_ceil(8) < raw {
        let words = chars.saturating_mul(SCRATCH_WORDS_PER_CHAR);
        let Some(cells) = scratch.get_mut(..words) else {
            return Err(Fault::new(Error::ScratchTooSmall, w.len(), id, words));
        };
        let mut costs = Costs { w: cells, n: chars };
        let (cost, start) = solve(s, chars, &mut costs).ok_or_else(|| Fault::bad(w.len(), id))?;
        let bits = HEADER_BITS.saturating_add(usize::try_from(cost).unwrap_or(usize::MAX));
        let size = bits.div_ceil(8);
        if size < raw {
            let p = put_field(w, size, id)?;
            for b in p.iter_mut() {
                *b = 0;
            }
            let mut out = BitOut { p, pos: 0 };
            out.put(size.saturating_mul(8).saturating_sub(bits) as u32, 3);
            out.put(start as u32, 3);
            if !write_parse(s, chars, start.saturating_mul(2), &costs, &mut out) {
                return Err(Fault::bad(w.len(), id));
            }
            forget_raw(scratch);
            return Ok(());
        }
    }
    put_raw(w, scratch, id, s)
}

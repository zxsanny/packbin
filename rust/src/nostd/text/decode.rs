//! The compact text decoder (the C++ `text_decode.hpp` port). It reads the payload bit by bit,
//! writes UTF-8 into a bounded sink, and holds no state beyond a few integers: the work and the
//! output are bounded by the payload length (at most 6 bytes of text per payload byte + 8).

use super::{
    decode_utf8, layout, letter, tbl, utf8_size, valid_utf8, HEADER_BITS, MAX_TEXT, NUM_MODE,
    RAW_MODE, RAW_PREFIX, TAB,
};

const MAX_CODE: usize = 16;

/// Where decoded UTF-8 goes. A text that does not fit the buffer is still checked and counted
/// (`over`), so the error can name its full size.
pub(crate) struct Sink<'a> {
    out: &'a mut [u8],
    pub len: usize,
    pub over: bool,
}

impl<'a> Sink<'a> {
    pub(crate) fn new(out: &'a mut [u8]) -> Self {
        Sink {
            out,
            len: 0,
            over: false,
        }
    }

    /// False when the text would pass the 65,535 byte limit.
    fn put(&mut self, bytes: &[u8]) -> bool {
        let n = bytes.len();
        if n > MAX_TEXT.saturating_sub(self.len) {
            return false;
        }
        if !self.over {
            let end = self.len.saturating_add(n);
            match self.out.get_mut(self.len..end) {
                Some(dst) => {
                    for (slot, byte) in dst.iter_mut().zip(bytes) {
                        *slot = *byte;
                    }
                }
                None => self.over = true,
            }
        }
        self.len = self.len.saturating_add(n);
        true
    }

    fn put_cp(&mut self, cp: u32) -> bool {
        let n = utf8_size(cp);
        let low = |shift: u32, lead: u32| (lead | (cp.checked_shr(shift).unwrap_or(0))) as u8;
        let cont = |shift: u32| (0x80 | (cp.checked_shr(shift).unwrap_or(0) & 0x3F)) as u8;
        let b = match n {
            1 => [cp as u8, 0, 0, 0],
            2 => [low(6, 0xC0), cont(0), 0, 0],
            3 => [low(12, 0xE0), cont(6), cont(0), 0],
            _ => [low(18, 0xF0), cont(12), cont(6), cont(0)],
        };
        match b.get(..n) {
            Some(bytes) => self.put(bytes),
            None => false,
        }
    }
}

/// The symbol whose code starts at bit `pos` in mode `mode` (canonical decoding: the codes of one
/// length are consecutive): the symbol and the bits its code used. `None` when the bits run out
/// inside the code.
fn next_symbol(mode: usize, p: &[u8], pos: usize, total: usize) -> Option<(usize, usize)> {
    let counts = TAB.count.get(mode)?;
    let symbols = TAB.symbol.get(mode)?;
    let mut code = 0u32;
    let mut first = 0u32;
    let mut index = 0u32;
    for len in 1..=MAX_CODE {
        let bit = pos.saturating_add(len).saturating_sub(1);
        if bit >= total {
            return None;
        }
        let byte = *p.get(bit >> 3)?;
        code = (code << 1)
            | u32::from(
                byte.checked_shr(7u32.saturating_sub((bit & 7) as u32))
                    .unwrap_or(0)
                    & 1,
            );
        let count = u32::from(*counts.get(len)?);
        let offset = code.wrapping_sub(first);
        if offset < count {
            let at = usize::try_from(index.saturating_add(offset)).ok()?;
            return Some((usize::from(*symbols.get(at)?), len));
        }
        index = index.saturating_add(count);
        first = first.saturating_add(count) << 1;
    }
    None
}

/// The 8 bits starting at bit `bit`, with no alignment.
fn byte_at(p: &[u8], bit: usize) -> u8 {
    let shift = (bit & 7) as u32;
    let i = bit >> 3;
    let hi = p.get(i).copied().unwrap_or(0);
    if shift == 0 {
        return hi;
    }
    let lo = p.get(i.saturating_add(1)).copied().unwrap_or(0);
    (hi << shift) | lo.checked_shr(8u32.saturating_sub(shift)).unwrap_or(0)
}

/// The ESC payload at bit `pos`: 1 to 4 UTF-8 bytes of 8 bits each, no alignment. The bytes and
/// their count, or `None` when cut short or invalid.
fn read_escaped(p: &[u8], pos: usize, total: usize) -> Option<([u8; 4], usize)> {
    if pos.saturating_add(8) > total {
        return None;
    }
    let b0 = byte_at(p, pos);
    let n: usize = if b0 < 0x80 {
        1
    } else if (b0 >> 5) == 6 {
        2
    } else if (b0 >> 4) == 14 {
        3
    } else if (b0 >> 3) == 30 {
        4
    } else {
        return None;
    };
    if pos.saturating_add(8usize.saturating_mul(n)) > total {
        return None;
    }
    let mut b = [0u8; 4];
    for (k, slot) in b.iter_mut().enumerate().take(n) {
        *slot = byte_at(p, pos.saturating_add(8usize.saturating_mul(k)));
    }
    let whole = decode_utf8(b.get(..n)?)?;
    (whole.1 == n).then_some((b, n))
}

/// Where a compact payload stands between symbols. Both the full decode and the key order check
/// step through it, so the two read a payload the same way.
pub(super) struct Cursor<'a> {
    p: &'a [u8],
    pub total: usize,
    pub pos: usize,
    mode: usize,
    lock: bool,
    cap: bool,
}

/// Starts a compact payload (at least one byte, start mode 0 to 3). `None`: the header is refused.
pub(super) fn begin_compact(p: &[u8]) -> Option<Cursor<'_>> {
    let first = *p.first()?;
    let pad = usize::from(first >> 5);
    let total = p.len().checked_mul(8)?.checked_sub(pad)?;
    let last = *p.last()?;
    if total < HEADER_BITS || (pad != 0 && last.trailing_zeros() < pad as u32) {
        return None;
    }
    Some(Cursor {
        p,
        total,
        pos: HEADER_BITS,
        mode: usize::from((first >> 2) & 7),
        lock: false,
        cap: false,
    })
}

impl Cursor<'_> {
    /// True when the payload ended without a pending capital.
    pub(super) fn finished_clean(&self) -> bool {
        !self.cap
    }

    /// Reads one symbol (it may add no bytes, or one to four). False: the payload is refused.
    pub(super) fn step(&mut self, sink: &mut Sink<'_>) -> bool {
        let Some((sym, used)) = next_symbol(self.mode, self.p, self.pos, self.total) else {
            return false;
        };
        self.pos = self.pos.saturating_add(used);
        let lay = layout(self.mode);
        let s = sym;
        let (esc, sw, cap, lock) = (
            usize::from(lay.esc),
            usize::from(lay.sw),
            usize::from(lay.cap),
            usize::from(lay.lock),
        );
        if s == esc {
            let got = if self.cap {
                None
            } else {
                read_escaped(self.p, self.pos, self.total)
            };
            let Some((b, n)) = got else {
                return false;
            };
            let Some(bytes) = b.get(..n) else {
                return false;
            };
            if !sink.put(bytes) {
                return false;
            }
            self.pos = self.pos.saturating_add(8usize.saturating_mul(n));
        } else if s >= sw && s < sw.saturating_add(3) {
            if self.cap {
                return false;
            }
            let j = s.saturating_sub(sw);
            self.mode = if j < self.mode {
                j
            } else {
                j.saturating_add(1)
            };
        } else if self.mode != NUM_MODE && s == cap {
            if self.lock || self.cap {
                return false;
            }
            self.cap = true;
        } else if self.mode != NUM_MODE && s == lock {
            if self.cap {
                return false;
            }
            self.lock = !self.lock;
        } else if s < usize::from(lay.letters) {
            let mut cp = letter(false, self.mode, s);
            let up = letter(true, self.mode, s);
            if self.cap {
                if up == 0 {
                    return false;
                }
                cp = up;
                self.cap = false;
            } else if self.lock && up != 0 {
                cp = up;
            }
            return sink.put_cp(cp);
        } else {
            if self.cap {
                return false;
            }
            let cp = if self.mode == NUM_MODE {
                tbl::NUMSET.get(s).copied()
            } else {
                tbl::SHARED
                    .get(s.saturating_sub(usize::from(lay.shared)))
                    .copied()
            };
            return match cp {
                Some(cp) => sink.put_cp(cp),
                None => false,
            };
        }
        true
    }
}

/// Decodes the symbols of a compact payload (at least one byte, start mode 0 to 3).
fn decode_compact(p: &[u8], sink: &mut Sink<'_>) -> bool {
    let Some(mut c) = begin_compact(p) else {
        return false;
    };
    while c.pos < c.total {
        if !c.step(sink) {
            return false;
        }
    }
    c.finished_clean()
}

/// True when the payload starts raw UTF-8 mode.
pub(super) fn is_raw(first: u8) -> bool {
    usize::from((first >> 2) & 7) == RAW_MODE
}

/// Checks a raw payload (start mode 4): prefix byte, valid UTF-8, at most 65,535 bytes. Returns
/// the text.
pub(super) fn raw_text(p: &[u8]) -> Option<&[u8]> {
    let (first, text) = p.split_first()?;
    (*first == RAW_PREFIX && text.len() <= MAX_TEXT && valid_utf8(text)).then_some(text)
}

/// Decodes one payload (at least one byte) into the sink. False: the payload is refused.
pub(crate) fn decode_payload(p: &[u8], sink: &mut Sink<'_>) -> bool {
    let Some(first) = p.first() else {
        return false;
    };
    let mode = usize::from((first >> 2) & 7);
    if mode > RAW_MODE {
        return false;
    }
    if mode == RAW_MODE {
        return match raw_text(p) {
            Some(text) => sink.put(text),
            None => false,
        };
    }
    decode_compact(p, sink)
}

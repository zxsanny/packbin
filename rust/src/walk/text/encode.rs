//! The encoder: the optimal parse over the 8 states, then the bits.
use super::{
    alpha_len, cap_symbol, esc_symbol, tables, Tables, LETTER_LIMIT, MAX_TEXT_BYTES, NONE, NUM,
    RAW_PREFIX, UPPER,
};

/// An edge that consumes one character: the symbols written (`second` is `NONE` for one), the
/// bits, and the UTF-8 bytes that follow an `ESC`.
#[derive(Clone, Copy)]
struct Edge {
    first: u8,
    second: u8,
    bits: u32,
    escape: bool,
}

const NO_EDGE: Edge = Edge {
    first: 0,
    second: NONE,
    bits: 0,
    escape: false,
};

/// The edges of `ch` in state (mode `m`, lock `k`): its letter or shared symbol when allowed, and
/// the escape. Returns how many are in `out` (the escape is always the last).
fn edges(t: &Tables, m: usize, k: usize, ch: char, out: &mut [Edge; 2]) -> usize {
    let cp = ch as usize;
    let len = &t.modes[m].len;
    let mut n = 0;
    if m == NUM {
        if cp < 128 && t.numset[cp] != NONE {
            let s = t.numset[cp];
            out[n] = Edge {
                first: s,
                second: NONE,
                bits: len[s as usize] as u32,
                escape: false,
            };
            n += 1;
        }
    } else if cp < LETTER_LIMIT && t.lower[m][cp] != NONE {
        let s = t.lower[m][cp];
        if k == 0 || UPPER[m][s as usize] == 0 {
            out[n] = Edge {
                first: s,
                second: NONE,
                bits: len[s as usize] as u32,
                escape: false,
            };
            n += 1;
        }
    } else if cp < LETTER_LIMIT && t.upper[m][cp] != NONE {
        let s = t.upper[m][cp];
        if k == 1 {
            out[n] = Edge {
                first: s,
                second: NONE,
                bits: len[s as usize] as u32,
                escape: false,
            };
        } else {
            let cap = cap_symbol(m);
            let bits = (len[cap] + len[s as usize]) as u32;
            out[n] = Edge {
                first: cap as u8,
                second: s,
                bits,
                escape: false,
            };
        }
        n += 1;
    } else if cp < 128 && t.shared[cp] != NONE {
        let s = alpha_len(m) as u8 + t.shared[cp];
        out[n] = Edge {
            first: s,
            second: NONE,
            bits: len[s as usize] as u32,
            escape: false,
        };
        n += 1;
    }
    let esc = esc_symbol(m);
    out[n] = Edge {
        first: esc as u8,
        second: NONE,
        bits: len[esc] as u32 + 8 * ch.len_utf8() as u32,
        escape: true,
    };
    n + 1
}

struct BitWriter<'a> {
    out: &'a mut Vec<u8>,
    acc: u32,
    held: u32,
}

impl BitWriter<'_> {
    /// Appends the low `len` (at most 16) bits of `value`.
    fn put(&mut self, value: u32, len: u32) {
        self.acc = (self.acc << len) | value;
        self.held += len;
        while self.held >= 8 {
            self.held -= 8;
            self.out.push((self.acc >> self.held) as u8);
        }
        self.acc &= (1 << self.held) - 1;
    }

    fn finish(&mut self) {
        if self.held > 0 {
            self.out.push((self.acc << (8 - self.held)) as u8);
        }
    }
}

fn varint(out: &mut Vec<u8>, mut n: usize) {
    loop {
        let b = (n & 0x7f) as u8;
        n >>= 7;
        if n == 0 {
            out.push(b);
            return;
        }
        out.push(b | 0x80);
    }
}

/// `emit` for every code point below `LETTER_LIMIT`: the bits of the cheapest edge per state.
pub(super) fn emission_table(t: &Tables) -> Vec<[u8; 8]> {
    let mut table = vec![[0u8; 8]; LETTER_LIMIT];
    let mut es = [NO_EDGE; 2];
    for (cp, row) in table.iter_mut().enumerate() {
        let Some(ch) = char::from_u32(cp as u32) else {
            continue;
        };
        for (s, slot) in row.iter_mut().enumerate() {
            let n = edges(t, s / 2, s % 2, ch, &mut es);
            *slot = es[..n].iter().map(|e| e.bits).min().unwrap_or(0) as u8;
        }
    }
    table
}

/// The cost of state `$s` after the control edges: the cheapest `dist` plus `base` over all states.
/// Unrolled by hand: this is the hot path and the tests run it unoptimized.
macro_rules! closed {
    ($t:expr, $base:expr, $s:literal) => {{
        let d = &$t.dist[$s];
        let mut best = d[0] + $base[0];
        let v = d[1] + $base[1];
        if v < best {
            best = v;
        }
        let v = d[2] + $base[2];
        if v < best {
            best = v;
        }
        let v = d[3] + $base[3];
        if v < best {
            best = v;
        }
        let v = d[4] + $base[4];
        if v < best {
            best = v;
        }
        let v = d[5] + $base[5];
        if v < best {
            best = v;
        }
        let v = d[6] + $base[6];
        if v < best {
            best = v;
        }
        let v = d[7] + $base[7];
        if v < best {
            best = v;
        }
        best
    }};
}

/// The cost table `f[i][state]` of finishing from character `i` in `state` (`m * 2 + k`): the
/// cheapest edge that consumes the character, then the cheapest chain of control edges.
fn costs(t: &Tables, chars: &[char]) -> Vec<[u32; 8]> {
    let mut f = vec![[0u32; 8]; chars.len() + 1];
    let mut i = chars.len();
    while i > 0 {
        i -= 1;
        let cp = chars[i] as usize;
        let next = f[i + 1];
        let mut base = [0u32; 8];
        let mut s = 0;
        if cp < LETTER_LIMIT {
            let own = &t.emit[cp];
            while s < 8 {
                base[s] = own[s] as u32 + next[s];
                s += 1;
            }
        } else {
            let escape = 8 * chars[i].len_utf8() as u32;
            while s < 8 {
                base[s] = t.esc_len[s] as u32 + escape + next[s];
                s += 1;
            }
        }
        f[i] = [
            closed!(t, base, 0),
            closed!(t, base, 1),
            closed!(t, base, 2),
            closed!(t, base, 3),
            closed!(t, base, 4),
            closed!(t, base, 5),
            closed!(t, base, 6),
            closed!(t, base, 7),
        ];
    }
    f
}

/// The wire bytes of one string (count, then payload), or `None` when it is over 65,535 UTF-8 bytes.
pub(crate) fn encode(text: &str) -> Option<Vec<u8>> {
    let raw = text.as_bytes();
    if raw.len() > MAX_TEXT_BYTES {
        return None;
    }
    if raw.is_empty() {
        return Some(vec![0]);
    }
    let t = tables();
    let chars: Vec<char> = text.chars().collect();
    let f = costs(t, &chars);
    let start = (0..4).min_by_key(|&m| (f[0][m * 2], m)).unwrap_or(0);
    let total = f[0][start * 2] as usize;
    let size = (6 + total).div_ceil(8);
    let mut out = Vec::with_capacity(3 + size.min(raw.len() + 1));
    if size >= raw.len() + 1 {
        varint(&mut out, raw.len() + 1);
        out.push(RAW_PREFIX);
        out.extend_from_slice(raw);
        return Some(out);
    }
    varint(&mut out, size);
    let at = out.len();
    let mut w = BitWriter {
        out: &mut out,
        acc: 0,
        held: 0,
    };
    w.put((8 * size - 6 - total) as u32, 3);
    w.put(start as u32, 3);
    write_parse(t, &f, &chars, start, &mut w);
    w.finish();
    debug_assert_eq!(out.len() - at, size);
    Some(out)
}

/// Walks the optimal parse from `(start, 0)`, taking at every step the edge with the smallest
/// first-symbol index whose cost plus the cost of the rest equals the optimum.
fn write_parse(t: &Tables, f: &[[u32; 8]], chars: &[char], start: usize, w: &mut BitWriter<'_>) {
    let mut s = start * 2;
    let mut i = 0;
    let mut es = [NO_EDGE; 2];
    while i < chars.len() {
        let (m, k) = (s / 2, s % 2);
        let want = f[i][s];
        // Candidate: (first symbol, state after, consumes a character, edge).
        let mut pick: Option<(u8, usize, Option<Edge>)> = None;
        for &(sym, bits, target) in &t.controls[s][..t.control_count[s]] {
            if bits as u32 + f[i][target as usize] == want && pick.map_or(true, |p| sym < p.0) {
                pick = Some((sym, target as usize, None));
            }
        }
        let n = edges(t, m, k, chars[i], &mut es);
        for e in &es[..n] {
            if e.bits + f[i + 1][s] == want && pick.map_or(true, |p| e.first < p.0) {
                pick = Some((e.first, s, Some(*e)));
            }
        }
        let Some((sym, next, edge)) = pick else {
            debug_assert!(false, "no optimal edge");
            return;
        };
        let mode = &t.modes[m];
        w.put(
            mode.code[sym as usize] as u32,
            mode.len[sym as usize] as u32,
        );
        s = next;
        if let Some(e) = edge {
            if e.second != NONE {
                w.put(
                    mode.code[e.second as usize] as u32,
                    mode.len[e.second as usize] as u32,
                );
            }
            if e.escape {
                let mut buf = [0u8; 4];
                for b in chars[i].encode_utf8(&mut buf).bytes() {
                    w.put(b as u32, 8);
                }
            }
            i += 1;
        }
    }
}

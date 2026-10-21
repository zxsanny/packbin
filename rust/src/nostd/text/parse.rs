//! The optimal parse of the compact text encoder: how each character can be written in each of the 8
//! states (mode, capital lock), the control edges between states, and the cost table the solver fills
//! in the caller's scratch words (the C++ `text_encode.hpp` port; contract `compact-text` 1.0.0).

use super::{code_len, decode_utf8, layout, tbl, NUM_MODE, SCRATCH_WORDS_PER_CHAR, TAB_C};

pub(super) const STATES: usize = 8;
pub(super) const MAX_CTRL: usize = 4;

/// How a character can be written in each text mode: the index of the letter, the capital and
/// the shared or number character it is, or -1.
pub(super) struct Cls {
    pub(super) low: [i8; 3],
    pub(super) up: [i8; 3],
    pub(super) sh: i8,
    pub(super) num: i8,
}

fn find(a: &[u32], cp: u32) -> i8 {
    a.iter()
        .position(|x| *x == cp)
        .and_then(|i| i8::try_from(i).ok())
        .unwrap_or(-1)
}

/// The capitals of a table without its trailing "no capital" entry.
fn caps(a: &[u32]) -> &[u32] {
    a.get(..a.len().saturating_sub(1)).unwrap_or(&[])
}

pub(super) fn classify(cp: u32) -> Cls {
    let mut c = Cls {
        low: [-1; 3],
        up: [-1; 3],
        sh: -1,
        num: -1,
    };
    if cp < 0x80 {
        c.low[2] = find(&tbl::EN, cp);
        c.up[2] = find(caps(&tbl::EN_UPPER), cp);
        if cp == 39 {
            c.low[0] = find(&tbl::UA, cp);
        }
        c.sh = find(&tbl::SHARED, cp);
        c.num = find(&tbl::NUMSET, cp);
    } else if (0x400..0x500).contains(&cp) {
        c.low[0] = find(&tbl::UA, cp);
        c.up[0] = find(caps(&tbl::UA_UPPER), cp);
        c.low[1] = find(&tbl::RU, cp);
        c.up[1] = find(&tbl::RU_UPPER, cp);
    }
    c
}

/// An edge that consumes the character. `kind`: 0 one symbol, 1 CAP then the letter `sym`, 2 ESC
/// then the UTF-8 bytes.
#[derive(Clone, Copy, Default)]
pub(super) struct Edge {
    pub(super) first: u8,
    pub(super) kind: u8,
    pub(super) sym: u8,
    pub(super) bits: u8,
}

/// A control edge: no character is consumed, the state changes to `to` = mode * 2 + lock.
#[derive(Clone, Copy, Default)]
pub(super) struct Ctrl {
    pub(super) first: u8,
    pub(super) bits: u8,
    pub(super) to: u8,
}

pub(super) fn sym_of(i: i8) -> u8 {
    u8::try_from(i).unwrap_or(0)
}

/// The edges that consume a character of `nbytes` bytes in `state`.
pub(super) fn edges_of(c: &Cls, state: usize, nbytes: usize) -> ([Edge; 3], usize) {
    let m = state >> 1;
    let lock = state & 1;
    let lay = layout(m);
    let ln = |s: u8| code_len(m, usize::from(s));
    let mut out = [Edge::default(); 3];
    let mut n = 0usize;
    let mut push = |e: Edge| {
        if let Some(slot) = out.get_mut(n) {
            *slot = e;
            n = n.saturating_add(1);
        }
    };
    if m < NUM_MODE {
        let low = c.low.get(m).copied().unwrap_or(-1);
        let up = c.up.get(m).copied().unwrap_or(-1);
        if low >= 0 && (lock == 0 || super::letter(true, m, usize::from(sym_of(low))) == 0) {
            let s = sym_of(low);
            push(Edge {
                first: s,
                kind: 0,
                sym: s,
                bits: ln(s),
            });
        }
        if up >= 0 {
            let s = sym_of(up);
            if lock != 0 {
                push(Edge {
                    first: s,
                    kind: 0,
                    sym: s,
                    bits: ln(s),
                });
            } else {
                push(Edge {
                    first: lay.cap,
                    kind: 1,
                    sym: s,
                    bits: ln(lay.cap).saturating_add(ln(s)),
                });
            }
        }
        if c.sh >= 0 {
            let s = lay.shared.saturating_add(sym_of(c.sh));
            push(Edge {
                first: s,
                kind: 0,
                sym: s,
                bits: ln(s),
            });
        }
    } else if c.num >= 0 {
        let s = sym_of(c.num);
        push(Edge {
            first: s,
            kind: 0,
            sym: s,
            bits: ln(s),
        });
    }
    let extra = u8::try_from(nbytes.saturating_mul(8)).unwrap_or(u8::MAX);
    push(Edge {
        first: lay.esc,
        kind: 2,
        sym: lay.esc,
        bits: ln(lay.esc).saturating_add(extra),
    });
    (out, n)
}

#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
const fn ctrl_of(state: usize) -> ([Ctrl; MAX_CTRL], usize) {
    let m = state >> 1;
    let lock = state & 1;
    let lay = super::LAYOUT[m];
    let mut out = [Ctrl {
        first: 0,
        bits: 0,
        to: 0,
    }; MAX_CTRL];
    let mut n = 0;
    let mut j = 0;
    while j < 3 {
        let target = if j < m { j } else { j + 1 };
        let s = lay.sw as usize + j;
        out[n] = Ctrl {
            first: s as u8,
            bits: TAB_C.length[m][s],
            to: (target * 2 + lock) as u8,
        };
        n += 1;
        j += 1;
    }
    if m < NUM_MODE {
        let s = lay.lock as usize;
        out[n] = Ctrl {
            first: s as u8,
            bits: TAB_C.length[m][s],
            to: (m * 2 + (lock ^ 1)) as u8,
        };
        n += 1;
    }
    (out, n)
}

struct ControlSet {
    pub(super) edge: [[Ctrl; MAX_CTRL]; STATES],
    pub(super) count: [u8; STATES],
}

#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
const fn make_controls() -> ControlSet {
    let mut set = ControlSet {
        edge: [[Ctrl {
            first: 0,
            bits: 0,
            to: 0,
        }; MAX_CTRL]; STATES],
        count: [0; STATES],
    };
    let mut st = 0;
    while st < STATES {
        let (tmp, n) = ctrl_of(st);
        set.count[st] = n as u8;
        set.edge[st] = tmp;
        st += 1;
    }
    set
}

/// Read-only: the control edges depend on the tables alone.
static CTL: ControlSet = make_controls();

pub(super) fn controls(state: usize) -> &'static [Ctrl] {
    let n = CTL.count.get(state).copied().map_or(0, usize::from);
    CTL.edge
        .get(state)
        .and_then(|row| row.get(..n))
        .unwrap_or(&[])
}

/// Where state `s` sits inside its word of deltas: 8 bits each, four to a word.
pub(super) fn shift_of(s: usize) -> u32 {
    ((s & 3) as u32).saturating_mul(8)
}

/// The cost of finishing from character `i` in each state, kept in the scratch as a minimum
/// (`base`) and 8 byte deltas: from any state another is at most three control edges away
/// (3 * 16 bits), so a delta always fits a byte. Position `n` (the end) costs 0 everywhere and is
/// not stored.
pub(super) struct Costs<'a> {
    pub(super) w: &'a mut [u32],
    pub(super) n: usize,
}

impl Costs<'_> {
    pub(super) fn cell(&self, i: usize) -> usize {
        i.saturating_mul(SCRATCH_WORDS_PER_CHAR)
    }

    pub(super) fn word(&self, at: usize) -> u32 {
        self.w.get(at).copied().unwrap_or(0)
    }

    /// The cost of the cheapest state from character `i`.
    pub(super) fn base(&self, i: usize) -> u32 {
        if i >= self.n {
            return 0;
        }
        self.word(self.cell(i))
    }

    /// How much dearer state `s` is than the cheapest one.
    pub(super) fn delta(&self, i: usize, s: usize) -> u32 {
        if i >= self.n {
            return 0;
        }
        let at = self.cell(i).saturating_add(1).saturating_add(s >> 2);
        self.word(at).checked_shr(shift_of(s)).unwrap_or(0) & 0xFF
    }

    pub(super) fn at(&self, i: usize, s: usize) -> u32 {
        self.base(i).saturating_add(self.delta(i, s))
    }

    /// `rel` holds the deltas, with a minimum of 0.
    pub(super) fn put(&mut self, i: usize, lowest: u32, rel: &[u32; STATES]) {
        let at = self.cell(i);
        let mut cell = [lowest, 0, 0];
        for (s, d) in rel.iter().enumerate() {
            if let Some(word) = cell.get_mut(1usize.saturating_add(s >> 2)) {
                *word |= (*d & 0xFF).checked_shl(shift_of(s)).unwrap_or(0);
            }
        }
        for (slot, value) in self.w.iter_mut().skip(at).zip(cell) {
            *slot = value;
        }
    }
}

/// Walks the validated UTF-8 backwards: the code point that ends at `end`, its byte length, and
/// where it starts.
pub(super) fn step_back(s: &[u8], end: usize) -> Option<(u32, usize, usize)> {
    let mut at = end;
    while at > 0 {
        at = at.saturating_sub(1);
        if s.get(at).is_some_and(|b| b & 0xC0 != 0x80) {
            break;
        }
    }
    let (cp, n) = s.get(at..end).and_then(decode_utf8)?;
    Some((cp, n, at))
}

/// Fills the scratch from the end of the text. Returns the cost of the whole text from the best
/// start mode, and that mode; `None` when the text is not the validated UTF-8 it must be.
pub(super) fn solve(s: &[u8], chars: usize, costs: &mut Costs<'_>) -> Option<(u32, usize)> {
    let mut end = s.len();
    for i in (0..chars).rev() {
        let (cp, nbytes, start) = step_back(s, end)?;
        end = start;
        let c = classify(cp);
        // Costs are kept relative to the cheapest state of the next character (the end costs 0): a
        // state's cost is its cheapest edge plus the delta of the state it leads to.
        let mut rel = [0u32; STATES];
        for (st, slot) in rel.iter_mut().enumerate() {
            let (e, ne) = edges_of(&c, st, nbytes);
            let best = e
                .iter()
                .take(ne)
                .map(|x| u32::from(x.bits))
                .min()
                .unwrap_or(0);
            *slot = best.saturating_add(costs.delta(i.saturating_add(1), st));
        }
        let mut changed = true;
        while changed {
            changed = false;
            for st in 0..STATES {
                for x in controls(st) {
                    let to = rel.get(usize::from(x.to)).copied().unwrap_or(0);
                    let v = u32::from(x.bits).saturating_add(to);
                    if let Some(slot) = rel.get_mut(st) {
                        if v < *slot {
                            *slot = v;
                            changed = true;
                        }
                    }
                }
            }
        }
        let lo = rel.iter().copied().min().unwrap_or(0);
        for slot in rel.iter_mut() {
            *slot = slot.saturating_sub(lo);
        }
        let base = costs.base(i.saturating_add(1)).saturating_add(lo);
        costs.put(i, base, &rel);
    }
    // The start mode is the one with the cheapest unlocked state; a tie goes to the smaller mode.
    let mut start = 0usize;
    for m in 1..4usize {
        if costs.at(0, m.saturating_mul(2)) < costs.at(0, start.saturating_mul(2)) {
            start = m;
        }
    }
    Some((costs.at(0, start.saturating_mul(2)), start))
}

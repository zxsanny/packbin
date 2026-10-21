//! The compact text format (contract `compact-text` 1.0.0) for the heap-free API: the tables the
//! encoder and the decoder share, built at compile time (the C++ `text.hpp` port). The decoder
//! writes into a bounded sink; the encoder keeps its parse in the caller's scratch words.
//!
//! Every table read goes through `get`, so no path here has a bounds-check panic.

mod decode;
mod encode;
mod parse;
mod raw;
mod stream;

pub(crate) use decode::{decode_payload, Sink};
pub(crate) use encode::encode_field;
pub(crate) use raw::forget_raw;
pub(crate) use stream::compare_payloads;

#[allow(dead_code)]
#[path = "../../walk/text_tables.rs"]
mod tbl;

pub(crate) const MAX_TEXT: usize = 65535;
pub(crate) const RAW_PREFIX: u8 = 0x10;
const MAX_CODE: usize = 16;
pub(crate) const HEADER_BITS: usize = 6;
/// Modes 0 ua, 1 ru, 2 en are text modes; 3 is the number mode; start mode 4 is raw UTF-8.
pub(crate) const NUM_MODE: usize = 3;
pub(crate) const RAW_MODE: usize = 4;
/// Scratch words the encoder keeps per code point of a string.
pub const SCRATCH_WORDS_PER_CHAR: usize = 3;

/// Symbol positions in the table of one mode: letters, the shared characters (the number
/// characters in mode 3), the switches to the other three modes, then CAP, LOCK and ESC.
#[derive(Clone, Copy)]
pub(crate) struct Layout {
    pub letters: u8,
    pub shared: u8,
    pub sw: u8,
    pub cap: u8,
    pub lock: u8,
    pub esc: u8,
}

#[allow(clippy::arithmetic_side_effects)]
const fn text_layout(letters: u8) -> Layout {
    Layout {
        letters,
        shared: letters,
        sw: letters + 32,
        cap: letters + 35,
        lock: letters + 36,
        esc: letters + 37,
    }
}

pub(crate) const LAYOUT: [Layout; 4] = [
    text_layout(34),
    text_layout(33),
    text_layout(27),
    Layout {
        letters: 0,
        shared: 0,
        sw: 15,
        cap: 255,
        lock: 255,
        esc: 18,
    },
];

const MAX_SYMBOLS: usize = 72;
const MAX_LETTERS: usize = 34;

const _: () = assert!(tbl::LENGTHS_UA.len() == 72 && LAYOUT[0].esc as usize + 1 == 72);
const _: () = assert!(tbl::LENGTHS_RU.len() == 71 && LAYOUT[1].esc as usize + 1 == 71);
const _: () = assert!(tbl::LENGTHS_EN.len() == 65 && LAYOUT[2].esc as usize + 1 == 65);
const _: () = assert!(tbl::LENGTHS_NUM.len() == 19 && LAYOUT[3].esc as usize + 1 == 19);
const _: () = assert!(tbl::SHARED.len() == 32 && tbl::NUMSET.len() == 15);

/// Everything the encoder and the decoder look up, in one constant object. Index 0 to 3 is the
/// mode.
pub(crate) struct Tab {
    /// Code length of each symbol.
    pub length: [[u8; MAX_SYMBOLS]; 4],
    /// Canonical code of each symbol.
    pub code: [[u16; MAX_SYMBOLS]; 4],
    /// Symbols per code length.
    pub count: [[u8; MAX_CODE + 1]; 4],
    /// Symbols sorted by (code length, index).
    pub symbol: [[u8; MAX_SYMBOLS]; 4],
    /// Letters of the text modes.
    pub lower: [[u32; MAX_LETTERS]; 3],
    /// Their capitals, 0 for none.
    pub upper: [[u32; MAX_LETTERS]; 3],
}

// Rust 1.79 has no `&mut` in a const fn, so the builders take and return the table by value.
#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
const fn fill_codes<const N: usize>(mut t: Tab, m: usize, len: &[u8; N]) -> Tab {
    let mut count = [0u32; MAX_CODE + 1];
    let mut i = 0;
    while i < N {
        t.length[m][i] = len[i];
        count[len[i] as usize] += 1;
        i += 1;
    }
    let mut next = [0u32; MAX_CODE + 2];
    let mut start = [0u32; MAX_CODE + 2];
    let mut code = 0u32;
    let mut l = 1;
    while l <= MAX_CODE {
        code = (code + count[l - 1]) << 1;
        next[l] = code;
        start[l + 1] = start[l] + count[l];
        t.count[m][l] = count[l] as u8;
        l += 1;
    }
    i = 0;
    while i < N {
        let l = len[i] as usize;
        t.code[m][i] = next[l] as u16;
        next[l] += 1;
        t.symbol[m][start[l] as usize] = i as u8;
        start[l] += 1;
        i += 1;
    }
    t
}

#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
const fn fill_letters<const N: usize>(
    mut t: Tab,
    m: usize,
    lower: &[u32; N],
    upper: &[u32; N],
) -> Tab {
    let mut i = 0;
    while i < N {
        t.lower[m][i] = lower[i];
        t.upper[m][i] = upper[i];
        i += 1;
    }
    t
}

const fn make_tab() -> Tab {
    let t = Tab {
        length: [[0; MAX_SYMBOLS]; 4],
        code: [[0; MAX_SYMBOLS]; 4],
        count: [[0; MAX_CODE + 1]; 4],
        symbol: [[0; MAX_SYMBOLS]; 4],
        lower: [[0; MAX_LETTERS]; 3],
        upper: [[0; MAX_LETTERS]; 3],
    };
    let t = fill_codes(t, 0, &tbl::LENGTHS_UA);
    let t = fill_codes(t, 1, &tbl::LENGTHS_RU);
    let t = fill_codes(t, 2, &tbl::LENGTHS_EN);
    let t = fill_codes(t, 3, &tbl::LENGTHS_NUM);
    let t = fill_letters(t, 0, &tbl::UA, &tbl::UA_UPPER);
    let t = fill_letters(t, 1, &tbl::RU, &tbl::RU_UPPER);
    fill_letters(t, 2, &tbl::EN, &tbl::EN_UPPER)
}

/// For compile-time use; run-time reads go through [`TAB`], one copy in read-only data.
pub(crate) const TAB_C: Tab = make_tab();
pub(crate) static TAB: Tab = TAB_C;

/// A table is a complete code when its Kraft sum is exactly 1.
#[allow(dead_code, clippy::indexing_slicing, clippy::arithmetic_side_effects)]
const fn complete<const N: usize>(len: &[u8; N]) -> bool {
    let mut sum = 0u64;
    let mut i = 0;
    while i < N {
        sum += 1u64 << (MAX_CODE - len[i] as usize);
        i += 1;
    }
    sum == 1u64 << MAX_CODE
}

const _: () = assert!(
    complete(&tbl::LENGTHS_UA)
        && complete(&tbl::LENGTHS_RU)
        && complete(&tbl::LENGTHS_EN)
        && complete(&tbl::LENGTHS_NUM)
);

#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
const fn min_of<const N: usize>(len: &[u8; N], mut m: usize) -> usize {
    let mut i = 0;
    while i < N {
        if (len[i] as usize) < m {
            m = len[i] as usize;
        }
        i += 1;
    }
    m
}

/// The smallest code length over the four tables.
pub(crate) const MIN_LENGTH: usize = min_of(
    &tbl::LENGTHS_NUM,
    min_of(
        &tbl::LENGTHS_EN,
        min_of(&tbl::LENGTHS_RU, min_of(&tbl::LENGTHS_UA, MAX_CODE)),
    ),
);

#[allow(clippy::indexing_slicing)]
const fn min_esc() -> usize {
    let a = tbl::LENGTHS_UA[LAYOUT[0].esc as usize] as usize;
    let b = tbl::LENGTHS_RU[LAYOUT[1].esc as usize] as usize;
    let c = tbl::LENGTHS_EN[LAYOUT[2].esc as usize] as usize;
    let d = tbl::LENGTHS_NUM[LAYOUT[3].esc as usize] as usize;
    let mut m = a;
    if b < m {
        m = b;
    }
    if c < m {
        m = c;
    }
    if d < m {
        m = d;
    }
    m
}

/// The smallest ESC code length over the four tables.
pub(crate) const MIN_ESC: usize = min_esc();

pub(crate) fn layout(mode: usize) -> Layout {
    LAYOUT.get(mode).copied().unwrap_or(LAYOUT[0])
}

pub(crate) fn code_len(mode: usize, sym: usize) -> u8 {
    TAB.length
        .get(mode)
        .and_then(|row| row.get(sym))
        .copied()
        .unwrap_or(0)
}

pub(crate) fn code_of(mode: usize, sym: usize) -> u16 {
    TAB.code
        .get(mode)
        .and_then(|row| row.get(sym))
        .copied()
        .unwrap_or(0)
}

pub(crate) fn letter(upper: bool, mode: usize, sym: usize) -> u32 {
    let rows = if upper { &TAB.upper } else { &TAB.lower };
    rows.get(mode)
        .and_then(|row| row.get(sym))
        .copied()
        .unwrap_or(0)
}

/// UTF-8 as the contract requires it: shortest form, no surrogates, nothing above U+10FFFF.
/// Returns the code point and the byte length (1 to 4) of the character at the start of `p`.
pub(crate) fn decode_utf8(p: &[u8]) -> Option<(u32, usize)> {
    let b0 = u32::from(*p.first()?);
    if b0 < 0x80 {
        return Some((b0, 1));
    }
    if !(0xC2..=0xF4).contains(&b0) {
        return None;
    }
    let need = if b0 < 0xE0 {
        2usize
    } else if b0 < 0xF0 {
        3
    } else {
        4
    };
    let tail = p.get(1..need)?;
    let lead_mask = 0xFFu32
        .checked_shr((need as u32).saturating_add(1))
        .unwrap_or(0);
    let mut v = b0 & lead_mask;
    for b in tail {
        if b & 0xC0 != 0x80 {
            return None;
        }
        v = (v << 6) | (u32::from(*b) & 0x3F);
    }
    let bad = (need == 3 && (v < 0x800 || (0xD800..=0xDFFF).contains(&v)))
        || (need == 4 && !(0x10000..=0x10FFFF).contains(&v));
    (!bad).then_some((v, need))
}

pub(crate) fn utf8_size(cp: u32) -> usize {
    if cp < 0x80 {
        1
    } else if cp < 0x800 {
        2
    } else if cp < 0x10000 {
        3
    } else {
        4
    }
}

/// True when `p` is whole, valid UTF-8 in the contract's sense.
pub(crate) fn valid_utf8(p: &[u8]) -> bool {
    let mut rest = p;
    while !rest.is_empty() {
        match decode_utf8(rest) {
            Some((_, n)) => rest = rest.get(n..).unwrap_or(&[]),
            None => return false,
        }
    }
    true
}

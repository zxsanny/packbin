//! The compact text format of every string (contract `compact-text` 1.0.0): a varint count, then a
//! payload of prefix-coded symbols in four modes, or the raw UTF-8 fallback.
//!
//! The encoder is the optimal parse of the contract: fewest bits, ties to the smallest first-symbol
//! index at every step, over the 8 states (mode, capital lock). The decoder reads any stream the
//! rules allow and does work and allocation bounded by the payload length.
use super::cursor::Cursor;
use super::pack_out::PackOut;
use super::text_tables::{
    EN, EN_UPPER, LENGTHS_EN, LENGTHS_NUM, LENGTHS_RU, LENGTHS_UA, NUMSET, RU, RU_UPPER, SHARED,
    UA, UA_UPPER,
};
use crate::value::{PackError, ShortPacket, UnpackError};
use std::sync::OnceLock;

mod decode;
mod encode;

pub(crate) use decode::decode;
pub(crate) use encode::encode;

pub(crate) const MAX_TEXT_BYTES: usize = 65535;
const RAW_PREFIX: u8 = 0x10;
const MAX_CODE_LEN: usize = 16;
const NONE: u8 = 255;
const INF: u32 = u32::MAX / 4;
/// Every letter of the three alphabets and its capital is below this code point.
const LETTER_LIMIT: usize = 1280;
const NUM: usize = 3;

const ALPHA: [&[u32]; 3] = [&UA, &RU, &EN];
const UPPER: [&[u32]; 3] = [&UA_UPPER, &RU_UPPER, &EN_UPPER];

/// A decoder refusal. `kind` is the contract's name; `needed` and `left` fill a `ShortPacket`.
#[derive(Debug, PartialEq, Eq)]
pub(crate) struct Refusal {
    pub kind: &'static str,
    pub needed: usize,
    pub left: usize,
}

struct ModeTable {
    len: Vec<u8>,
    code: Vec<u16>,
    sorted: Vec<u8>,
    first: [u32; MAX_CODE_LEN + 1],
    count: [u32; MAX_CODE_LEN + 1],
    start: [u32; MAX_CODE_LEN + 1],
}

/// One control edge of the parse: the symbol, its bits and the state it leads to.
type Control = (u8, u8, u8);

struct Tables {
    modes: [ModeTable; 4],
    lower: [[u8; LETTER_LIMIT]; 3],
    upper: [[u8; LETTER_LIMIT]; 3],
    shared: [u8; 128],
    numset: [u8; 128],
    controls: [[Control; 4]; 8],
    control_count: [usize; 8],
    /// Cheapest chain of control edges from one state to another (0 to itself).
    dist: [[u32; 8]; 8],
    /// Code length of `ESC` in the mode of each state.
    esc_len: [u8; 8],
    /// Bits of the cheapest edge for each code point below `LETTER_LIMIT`, per state.
    emit: Vec<[u8; 8]>,
}

fn alpha_len(mode: usize) -> usize {
    ALPHA[mode].len()
}

/// Index of the first symbol after the letters and shared characters (the `SW` symbols) of a mode.
fn sw_base(mode: usize) -> usize {
    if mode == NUM {
        NUMSET.len()
    } else {
        alpha_len(mode) + SHARED.len()
    }
}

fn sw_symbol(mode: usize, target: usize) -> usize {
    sw_base(mode) + target - usize::from(target > mode)
}

fn cap_symbol(mode: usize) -> usize {
    sw_base(mode) + 3
}

fn lock_symbol(mode: usize) -> usize {
    sw_base(mode) + 4
}

fn esc_symbol(mode: usize) -> usize {
    if mode == NUM {
        sw_base(mode) + 3
    } else {
        sw_base(mode) + 5
    }
}

fn build_mode(lengths: &[u8]) -> ModeTable {
    let mut sorted: Vec<u8> = (0..lengths.len() as u8).collect();
    sorted.sort_by_key(|&s| (lengths[s as usize], s));
    let mut table = ModeTable {
        len: lengths.to_vec(),
        code: vec![0; lengths.len()],
        sorted,
        first: [0; MAX_CODE_LEN + 1],
        count: [0; MAX_CODE_LEN + 1],
        start: [0; MAX_CODE_LEN + 1],
    };
    for &l in lengths {
        table.count[l as usize] += 1;
    }
    let (mut code, mut index) = (0u32, 0u32);
    for l in 1..=MAX_CODE_LEN {
        table.first[l] = code;
        table.start[l] = index;
        for k in 0..table.count[l] {
            table.code[table.sorted[(index + k) as usize] as usize] = (code + k) as u16;
        }
        code = (code + table.count[l]) << 1;
        index += table.count[l];
    }
    table
}

fn build() -> Tables {
    let modes = [
        build_mode(&LENGTHS_UA),
        build_mode(&LENGTHS_RU),
        build_mode(&LENGTHS_EN),
        build_mode(&LENGTHS_NUM),
    ];
    let mut lower = [[NONE; LETTER_LIMIT]; 3];
    let mut upper = [[NONE; LETTER_LIMIT]; 3];
    for m in 0..3 {
        for (i, &c) in ALPHA[m].iter().enumerate() {
            lower[m][c as usize] = i as u8;
            if UPPER[m][i] != 0 {
                upper[m][UPPER[m][i] as usize] = i as u8;
            }
        }
    }
    let mut shared = [NONE; 128];
    for (i, &c) in SHARED.iter().enumerate() {
        shared[c as usize] = i as u8;
    }
    let mut numset = [NONE; 128];
    for (i, &c) in NUMSET.iter().enumerate() {
        numset[c as usize] = i as u8;
    }
    let mut controls = [[(0, 0, 0); 4]; 8];
    let mut control_count = [0; 8];
    for m in 0..4 {
        for k in 0..2 {
            let s = m * 2 + k;
            for t in (0..4).filter(|&t| t != m) {
                let sym = sw_symbol(m, t);
                controls[s][control_count[s]] = (sym as u8, modes[m].len[sym], (t * 2 + k) as u8);
                control_count[s] += 1;
            }
            if m != NUM {
                let sym = lock_symbol(m);
                controls[s][control_count[s]] =
                    (sym as u8, modes[m].len[sym], (m * 2 + 1 - k) as u8);
                control_count[s] += 1;
            }
        }
    }
    let mut dist = [[INF; 8]; 8];
    for s in 0..8 {
        dist[s][s] = 0;
        for &(_, bits, target) in &controls[s][..control_count[s]] {
            dist[s][target as usize] = dist[s][target as usize].min(bits as u32);
        }
    }
    for via in 0..8 {
        for from in 0..8 {
            for to in 0..8 {
                dist[from][to] = dist[from][to].min(dist[from][via] + dist[via][to]);
            }
        }
    }
    let mut esc_len = [0; 8];
    for (s, slot) in esc_len.iter_mut().enumerate() {
        *slot = modes[s / 2].len[esc_symbol(s / 2)];
    }
    let mut t = Tables {
        modes,
        lower,
        upper,
        shared,
        numset,
        controls,
        control_count,
        dist,
        esc_len,
        emit: Vec::new(),
    };
    t.emit = encode::emission_table(&t);
    t
}

fn tables() -> &'static Tables {
    static TABLES: OnceLock<Tables> = OnceLock::new();
    TABLES.get_or_init(build)
}

// ---- the walker's two entry points

/// Texts of at least this many UTF-8 bytes are remembered by `write` for the next call.
const CACHE_MIN_BYTES: usize = 256;

/// Writes one string field, or refuses a text over 65,535 UTF-8 bytes, naming the field.
pub(super) fn write(out: &mut PackOut, name: &str, text: &str) -> Result<(), PackError> {
    let cached = match &out.text_cache {
        Some((last, field)) if last == text => Some(field.clone()),
        _ => None,
    };
    let field = match cached {
        Some(field) => field,
        None => {
            let field = encode(text).ok_or_else(|| PackError::Type(name.to_string()))?;
            if text.len() >= CACHE_MIN_BYTES {
                out.text_cache = Some((text.to_string(), field.clone()));
            }
            field
        }
    };
    out.admit(field.len(), || name.to_string())?;
    out.raw(&field);
    Ok(())
}

/// Reads one string field, naming the field in a refusal.
pub(super) fn read(cur: &mut Cursor<'_>, name: &str) -> Result<String, UnpackError> {
    match decode(cur.rest()) {
        Ok((text, used)) => {
            cur.take(used, name)?;
            Ok(text)
        }
        Err(r) => Err(UnpackError::Short(ShortPacket {
            field: name.to_string(),
            needed: r.needed,
            left: r.left,
        })),
    }
}

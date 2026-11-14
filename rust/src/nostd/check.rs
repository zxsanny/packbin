//! The scheme check: table shape, order ids and references. The rules are those of the other
//! packages (the C++ `order.hpp` port): each field takes the next order id; `flags`, `when` and
//! `u2` take the id of their first member; a flag byte and a flag bit take none.

use super::error::{Error, Fault};
use super::scheme::{Field, Kind, Scheme, MAX_FIELDS, MAX_PARITY, NO_ID};
use super::table::{
    bit_position, end, flag_byte_of, get, id_of, is_level, kind, level, members, parent_and_levels,
    source_of,
};

/// The most members of one `flags` byte and the most bits of one flag byte.
const FLAG_BITS: usize = 8;
/// A `u2` packs into 16 bytes: at most 64 members.
const MAX_U2: usize = 64;
/// The most levels a scheme may nest (`_docs/02_document/contracts/library/scheme-depth.md`).
const MAX_DEPTH: usize = 256;
/// The largest order id; a `when` or a count naming a larger one can never match.
const MAX_ID: u16 = 32767;

fn invalid(at: usize, f: &Field) -> Fault {
    Fault::new(Error::SchemeInvalid, at, id_of(f), 0)
}

/// Checks a scheme without reading or writing a byte: the table shape (spans), the order ids (a
/// duplicate, skipped or out-of-range id is refused), the members each kind allows, that every
/// `when`, count and flag bit refers to an earlier field of its scope that it can read, and that
/// no field that can write a byte follows a `repeat` (the fault names the first one that does).
/// [`pack`](super::pack) and [`unpack`](super::unpack) call it first.
pub fn validate(scheme: &Scheme<'_>) -> Result<(), Fault> {
    let t = scheme.fields;
    if t.len() > MAX_FIELDS {
        return Err(Fault::new(Error::SchemeInvalid, 0, -1, MAX_FIELDS));
    }
    depth(t)?;
    spans(t, 0, t.len())?;
    let mut next = 0u32;
    for j in level(t, 0, t.len()) {
        next = order(t, j, next)?;
    }
    shape(t, 0, t.len(), false, Round::None)?;
    refs(t, 0, t.len())?;
    repeat_last(t)?;
    parity(scheme)
}

/// A scheme nested more than 256 levels is refused first, before the passes that recurse over it.
/// Each level-opening entry counts the levels around it with one descent from the top of the table
/// (`parent_and_levels`), so nothing is stored and nothing recurses; the first entry that is the
/// 257th level is named and `needed` is the limit. A deep table is refused after about 257
/// descents of about 257 steps.
fn depth(t: &[Field]) -> Result<(), Fault> {
    for (j, f) in t.iter().enumerate() {
        if is_level(f.kind) && parent_and_levels(t, j).1 >= MAX_DEPTH {
            return Err(Fault::new(Error::SchemeInvalid, j, id_of(f), MAX_DEPTH));
        }
    }
    Ok(())
}

/// A `repeat` is the last thing a packet reads: it has no count on the wire, so unpack would read
/// a field written after it as more rounds. The table is in wire order, so no entry after the
/// first `repeat` and its members may write a byte, wherever it stands; the first that can is
/// named. A `boolean` (a bit of a byte written earlier), a zero-width `bytes` and the entries
/// that only hold members (`when`, group, flag bit, `repeat`, `times`) write none themselves.
fn repeat_last(t: &[Field]) -> Result<(), Fault> {
    // Where the entries after the first `repeat` start; a later `repeat` ends later.
    let mut after = usize::MAX;
    for (j, f) in t.iter().enumerate() {
        let silent = matches!(
            f.kind,
            Kind::Bool | Kind::When | Kind::Group | Kind::FlagBit | Kind::Times
        ) || (f.kind == Kind::Bytes && f.size == 0);
        if f.kind == Kind::Repeat {
            after = after.min(j.saturating_add(usize::from(f.span)));
        } else if j >= after && !silent {
            return Err(invalid(j, f));
        }
    }
    Ok(())
}

/// A parity count above 32, or above 0 without the `ecc` feature, is refused; so is a percentage
/// above 100 or together with a count.
fn parity(scheme: &Scheme<'_>) -> Result<(), Fault> {
    let max = if cfg!(feature = "ecc") { MAX_PARITY } else { 0 };
    if usize::from(scheme.parity) > max {
        return Err(Fault::new(Error::SchemeInvalid, 0, -1, max));
    }
    #[cfg(feature = "ecc")]
    if scheme.parity_percent > 100 || (scheme.parity_percent != 0 && scheme.parity != 0) {
        return Err(Fault::new(Error::SchemeInvalid, 0, -1, 100));
    }
    Ok(())
}

/// Every entry fits in its parent, a field without members spans itself only, and a flag bit
/// holds exactly one member.
fn spans(t: &[Field], begin: usize, stop: usize) -> Result<(), Fault> {
    for j in level(t, begin, stop) {
        let f = get(t, j).ok_or_else(|| Fault::new(Error::SchemeInvalid, j, -1, 0))?;
        let span = usize::from(f.span);
        let fits = span >= 1 && end(t, j) <= stop;
        let own = f.kind.has_members() || span == 1;
        let one_member = match f.kind {
            Kind::FlagBit | Kind::List => {
                span >= 2
                    && get(t, j.saturating_add(1)).map(|m| usize::from(m.span))
                        == span.checked_sub(1)
            }
            // The key, then one element.
            Kind::Dict => {
                span >= 3
                    && get(t, j.saturating_add(1)).map(|m| m.span) == Some(1)
                    && get(t, j.saturating_add(2)).map(|m| usize::from(m.span))
                        == span.checked_sub(2)
            }
            _ => true,
        };
        if !fits || !own || !one_member {
            return Err(invalid(j, f));
        }
        spans(t, j.saturating_add(1), end(t, j))?;
    }
    Ok(())
}

fn order(t: &[Field], j: usize, next: u32) -> Result<u32, Fault> {
    let f = get(t, j).ok_or_else(|| Fault::new(Error::SchemeInvalid, j, -1, 0))?;
    let in_order = u32::from(f.id) == next;
    match f.kind {
        Kind::FlagByte => Ok(next),
        Kind::FlagBit | Kind::U2 => members(t, j).try_fold(next, |n, m| order(t, m, n)),
        Kind::Flags | Kind::When | Kind::Group | Kind::Repeat | Kind::Times if in_order => {
            members(t, j).try_fold(next, |n, m| order(t, m, n))
        }
        Kind::List if in_order => {
            members(t, j).try_fold(0, |n, m| order(t, m, n))?;
            Ok(next.saturating_add(1))
        }
        // The key has no order id; the element starts again at 0.
        Kind::Dict if in_order => {
            members(t, j).skip(1).try_fold(0, |n, m| order(t, m, n))?;
            Ok(next.saturating_add(1))
        }
        _ if in_order => Ok(next.saturating_add(1)),
        _ => Err(invalid(j, f)),
    }
}

/// The innermost `repeat` or `times` round around a point of the table.
#[derive(Clone, Copy, PartialEq)]
enum Round {
    None,
    Repeat,
    Times,
}

/// `presence_ok`: the entries are members of `flags` or of a flag bit, the only places a
/// presence bit (`boolean`) may stand. No `repeat` inside a round and no `times` inside a `times`
/// round, at any depth (a `list` element starts outside any round); a round body holds a member.
fn shape(
    t: &[Field],
    begin: usize,
    stop: usize,
    presence_ok: bool,
    round: Round,
) -> Result<(), Fault> {
    for j in level(t, begin, stop) {
        let f = get(t, j).ok_or_else(|| Fault::new(Error::SchemeInvalid, j, -1, 0))?;
        let count = members(t, j).count();
        let body = || has_member(t, j.saturating_add(1), end(t, j));
        let ok = match f.kind {
            Kind::Bool => presence_ok && f.size == 0,
            Kind::Flags => count <= FLAG_BITS,
            Kind::FlagByte | Kind::FlagBit => usize::from(f.size) < FLAG_BITS,
            Kind::When | Kind::Sized | Kind::Bits => f.source <= MAX_ID,
            Kind::Packed => {
                f.source <= MAX_ID && matches!(f.width, 1 | 2) && matches!(f.bias, 0 | -1)
            }
            Kind::U2 => (1..=MAX_U2).contains(&count) && u2_members_ok(t, j, f),
            Kind::Group => count >= 1,
            Kind::Repeat => round == Round::None && body(),
            Kind::Times => round != Round::Times && f.source <= MAX_ID && body(),
            Kind::List => element_ok(t, j.saturating_add(1)),
            Kind::Dict => {
                TEXT && key_ok(t, j.saturating_add(1)) && element_ok(t, j.saturating_add(2))
            }
            Kind::Utf8 => TEXT && f.size == 0,
            Kind::Bytes | Kind::Utf8Wire => true,
            _ => f.size == 0,
        };
        if !ok {
            return Err(invalid(j, f));
        }
        let presence = matches!(f.kind, Kind::Flags | Kind::FlagBit);
        let inner = match f.kind {
            Kind::Repeat => Round::Repeat,
            Kind::Times => Round::Times,
            Kind::List | Kind::Dict => Round::None,
            _ => round,
        };
        shape(t, j.saturating_add(1), end(t, j), presence, inner)?;
    }
    Ok(())
}

/// True when `begin..stop` holds a member, looking through `when`, groups, flag bits and rounds:
/// only a body of empty ones holds none, and a round of it would charge no slot and read nothing.
fn has_member(t: &[Field], begin: usize, stop: usize) -> bool {
    level(t, begin, stop).any(|j| match kind(t, j) {
        Some(Kind::When | Kind::Group | Kind::FlagBit | Kind::Repeat | Kind::Times) => {
            has_member(t, j.saturating_add(1), end(t, j))
        }
        Some(_) => true,
        None => false,
    })
}

/// True when the `text` feature (the codec of `Utf8` and `Dict`) is built.
const TEXT: bool = cfg!(feature = "text");

/// A dictionary key is a decoded string with no order id.
fn key_ok(t: &[Field], at: usize) -> bool {
    get(t, at).is_some_and(|f| f.kind == Kind::Utf8 && f.id == NO_ID && f.span == 1)
}

/// A list or dictionary element is one number, `bytes`, a string, a `list`, a `dict` or a `u2` of
/// one member: an item holds one value.
fn element_ok(t: &[Field], at: usize) -> bool {
    match get(t, at) {
        Some(f)
            if f.kind.width().is_some()
                || matches!(
                    f.kind,
                    Kind::Bytes | Kind::List | Kind::Utf8 | Kind::Utf8Wire | Kind::Dict
                ) =>
        {
            f.kind != Kind::Utf8 || (TEXT && f.id != NO_ID)
        }
        Some(f) if f.kind == Kind::U2 => f.span == 2,
        _ => false,
    }
}

fn u2_members_ok(t: &[Field], j: usize, head: &Field) -> bool {
    let first = get(t, j.saturating_add(1)).map(|m| m.id);
    first == Some(head.id)
        && members(t, j).all(|m| get(t, m).is_some_and(|f| f.kind == Kind::U8 && f.span == 1))
}

/// A `when` source that is a `u2` member reads 0 to 3; otherwise the range of its integer kind.
fn eq_fits(t: &[Field], at: usize, value: i64) -> bool {
    let in_u2 = (0..at).any(|k| kind(t, k) == Some(Kind::U2) && at < end(t, k));
    if in_u2 {
        return (0..=3).contains(&value);
    }
    match kind(t, at) {
        Some(Kind::U8) => (0..=0xFF).contains(&value),
        Some(Kind::U16) => (0..=0xFFFF).contains(&value),
        Some(Kind::U32) => (0..=0xFFFF_FFFF).contains(&value),
        Some(Kind::U64) => value >= 0,
        Some(Kind::I8) => (-0x80..=0x7F).contains(&value),
        Some(Kind::I16) => (-0x8000..=0x7FFF).contains(&value),
        Some(Kind::I32) => (-0x8000_0000..=0x7FFF_FFFF).contains(&value),
        _ => true,
    }
}

/// Each flag bit has a flag byte it can see and is at most its 8th bit; each `when` and count
/// names an earlier field of its scope it can read. A `boolean` is a source of a `when` for
/// `true` only (a false one is absent on the wire); a count reads integers only; a `when` value
/// its source can never hold is refused.
fn refs(t: &[Field], begin: usize, stop: usize) -> Result<(), Fault> {
    for j in level(t, begin, stop) {
        let f = get(t, j).ok_or_else(|| Fault::new(Error::SchemeInvalid, j, -1, 0))?;
        if f.kind == Kind::FlagBit {
            let child = get(t, j.saturating_add(1)).unwrap_or(f);
            let byte = flag_byte_of(t, j).ok_or_else(|| invalid(j, child))?;
            if bit_position(t, byte, j) >= FLAG_BITS {
                return Err(invalid(j, child));
            }
        }
        if matches!(
            f.kind,
            Kind::When | Kind::Sized | Kind::Bits | Kind::Packed | Kind::Times
        ) {
            let at = source_of(t, j).ok_or_else(|| invalid(j, f))?;
            let presence = kind(t, at) == Some(Kind::Bool);
            let bool_ok = f.kind == Kind::When && f.eq == 1;
            if (presence && !bool_ok) || (f.kind == Kind::When && !eq_fits(t, at, f.eq)) {
                return Err(invalid(j, f));
            }
        }
        refs(t, j.saturating_add(1), end(t, j))?;
    }
    Ok(())
}

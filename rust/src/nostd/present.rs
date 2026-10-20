//! What a row holds for an entry: presence (flag bits and `when` bodies follow it) and the
//! integer value a `when` or a count reads.

use super::row::{Num, Row};
use super::scheme::{Field, Kind};
use super::table::{end, get, is_late, kind, level, members, source_of};

/// The value of an integer or bool entry as a `when` or a count reads it.
pub(crate) fn read_int(f: &Field, row: &dyn Row) -> Option<i64> {
    if f.kind == Kind::Bool {
        return Some(i64::from(row.flag(f.id)));
    }
    let num = row.num(f.id).filter(|n| n.kind() == f.kind)?;
    match num {
        Num::U8(v) => Some(i64::from(v)),
        Num::U16(v) => Some(i64::from(v)),
        Num::U32(v) => Some(i64::from(v)),
        Num::U64(v) => Some(v as i64),
        Num::I8(v) => Some(i64::from(v)),
        Num::I16(v) => Some(i64::from(v)),
        Num::I32(v) => Some(i64::from(v)),
        Num::I64(v) => Some(v),
        Num::F32(_) | Num::F64(_) => None,
    }
}

/// The value the `when` or counted entry at `user` reads: its source as written, so `None` when
/// the row has none or when a `when` around the source (and not around `user`) does not hold,
/// since that source is then not on the wire.
pub(crate) fn source_value(t: &[Field], user: usize, row: &dyn Row) -> Option<i64> {
    let at = source_of(t, user)?;
    let value = read_int(get(t, at)?, row)?;
    let skipped = (0..at).any(|w| {
        kind(t, w) == Some(Kind::When)
            && at < end(t, w)
            && user >= end(t, w)
            && !when_matches(t, w, row)
    });
    (!skipped).then_some(value)
}

/// True when the `when` at `i` holds: its source is written and equals its value.
pub(crate) fn when_matches(t: &[Field], i: usize, row: &dyn Row) -> bool {
    let Some(f) = get(t, i) else {
        return false;
    };
    source_value(t, i, row) == Some(f.eq)
}

/// True when the row holds a value for the entry at `i`; a member is on in `flags` and under a
/// flag bit exactly when this holds. With `skip_late`, a `when` its flag bit decides late counts
/// as absent.
pub(crate) fn present(t: &[Field], i: usize, row: &dyn Row, skip_late: bool) -> bool {
    let Some(f) = get(t, i) else {
        return false;
    };
    if f.kind.width().is_some() {
        return row.num(f.id).is_some();
    }
    match f.kind {
        Kind::Bool => row.flag(f.id),
        Kind::Flags | Kind::FlagBit | Kind::U2 => any_member(t, i, row, skip_late),
        Kind::When => {
            !(skip_late && is_late(t, i))
                && when_matches(t, i, row)
                && any_member(t, i, row, skip_late)
        }
        Kind::Bytes | Kind::Sized | Kind::Bits | Kind::Packed => row.bytes(f.id).is_some(),
        Kind::Group => any_member(t, i, row, skip_late),
        Kind::Repeat => row.count(f.id).is_some_and(|n| n != 0),
        Kind::Times => !(skip_late && is_late(t, i)) && times_present(t, i, f, row),
        Kind::List => row.count(f.id).is_some(),
        _ => false,
    }
}

/// A `times` is on when its count is above zero or the row holds rounds (a count of zero with
/// rounds is refused on pack, not dropped); with no count written, rounds make it on, so pack
/// refuses them.
fn times_present(t: &[Field], i: usize, f: &Field, row: &dyn Row) -> bool {
    let rounds = row.count(f.id).is_some_and(|n| n != 0);
    match source_value(t, i, row) {
        Some(count) => count != 0 || rounds,
        None => rounds,
    }
}

fn any_member(t: &[Field], i: usize, row: &dyn Row, skip_late: bool) -> bool {
    members(t, i).any(|j| present(t, j, row, skip_late))
}

/// Clears what the row holds for each member in `begin..stop` before an unpack, so a member the
/// packet leaves out reads as absent.
pub(crate) fn clear(t: &[Field], begin: usize, stop: usize, row: &mut dyn Row) {
    for j in level(t, begin, stop) {
        let Some(f) = get(t, j) else {
            return;
        };
        if f.kind.has_members() && !f.kind.is_container() {
            clear(t, j.saturating_add(1), end(t, j), row);
        } else if f.kind != Kind::FlagByte {
            row.clear(f.id);
        }
    }
}

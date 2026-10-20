//! Walking a scheme table: siblings by `span`, the scope of an entry, and the entries a `when`,
//! a count or a flag bit refers to. The C++ core stores these references in its table when the
//! scheme is built; here a scheme is plain `const` data, so they are found where they are used.
//! The cost is a scan of the table per lookup (a scheme is a small, trusted constant).

use super::scheme::{Field, Kind, NO_ID};

/// The entry at `i`, if the table has one.
pub(crate) fn get(t: &[Field], i: usize) -> Option<&Field> {
    t.get(i)
}

pub(crate) fn kind(t: &[Field], i: usize) -> Option<Kind> {
    get(t, i).map(|f| f.kind)
}

/// One past the last entry of the entry at `i` (its members included).
pub(crate) fn end(t: &[Field], i: usize) -> usize {
    let span = get(t, i).map_or(1, |f| usize::from(f.span).max(1));
    i.saturating_add(span)
}

/// The order id as a `Fault` names it: -1 for an entry that has none.
pub(crate) fn id_of(f: &Field) -> i32 {
    if f.id == NO_ID {
        -1
    } else {
        i32::from(f.id)
    }
}

/// The entries of one level: those starting at `begin`, each after the previous one's span,
/// before `end`.
#[derive(Clone, Copy)]
pub(crate) struct Level<'a> {
    t: &'a [Field],
    at: usize,
    end: usize,
}

impl Iterator for Level<'_> {
    type Item = usize;

    fn next(&mut self) -> Option<usize> {
        if self.at >= self.end {
            return None;
        }
        let i = self.at;
        self.at = end(self.t, i);
        Some(i)
    }
}

pub(crate) fn level(t: &[Field], begin: usize, stop: usize) -> Level<'_> {
    Level {
        t,
        at: begin,
        end: stop.min(t.len()),
    }
}

/// The direct members of the entry at `i`.
pub(crate) fn members(t: &[Field], i: usize) -> Level<'_> {
    level(t, i.saturating_add(1), end(t, i))
}

/// The entry whose members hold `i` directly, or `None` at the top level.
pub(crate) fn parent_of(t: &[Field], i: usize) -> Option<usize> {
    let mut parent = None;
    let mut cur = level(t, 0, t.len());
    while let Some(s) = cur.find(|s| *s <= i && i < end(t, *s)) {
        if s == i {
            return parent;
        }
        parent = Some(s);
        cur = members(t, s);
    }
    None
}

/// Counted kinds whose members read into an item of their own (none yet in this slice).
pub(crate) fn is_container(_kind: Kind) -> bool {
    false
}

/// Where the scope of `i` starts: the first member of the innermost container that holds it,
/// or 0.
pub(crate) fn scope_of(t: &[Field], i: usize) -> usize {
    let mut p = parent_of(t, i);
    while let Some(k) = p {
        if kind(t, k).is_some_and(is_container) {
            return k.saturating_add(1);
        }
        p = parent_of(t, k);
    }
    0
}

/// Kinds a `when` or a count can read.
fn is_source(kind: Kind) -> bool {
    kind.is_integer() || kind == Kind::Bool
}

/// The entry with order id `id` before `before` in the scope starting at `scope` that a `when`
/// or a count may read, or `None`. A container that ends before `before` is not looked into.
pub(crate) fn find_source(t: &[Field], scope: usize, before: usize, id: u16) -> Option<usize> {
    let mut j = scope;
    while j < before {
        let f = get(t, j)?;
        if is_container(f.kind) && end(t, j) <= before {
            j = end(t, j);
            continue;
        }
        if f.id == id && f.span == 1 {
            return is_source(f.kind).then_some(j);
        }
        j = j.saturating_add(1);
    }
    None
}

/// The source entry of the `when` or counted field at `i`.
pub(crate) fn source_of(t: &[Field], i: usize) -> Option<usize> {
    let f = get(t, i)?;
    find_source(t, scope_of(t, i), i, f.source)
}

/// The flag byte numbered `number` in `begin..stop` that the entry at `before` can see, or
/// `None`: the latest one, outside any part that ends before `before` and may not have run (a
/// `when`, `flags`, a flag bit); every member of `flags` (`in_flags`) is such a part.
fn find_flag_byte_in(
    t: &[Field],
    begin: usize,
    stop: usize,
    before: usize,
    number: u16,
    in_flags: bool,
) -> Option<usize> {
    let mut found = None;
    for j in level(t, begin, stop.min(before)) {
        let f = get(t, j)?;
        let closed = end(t, j) <= before;
        let skipped = matches!(f.kind, Kind::When | Kind::Flags | Kind::FlagBit);
        if closed && (in_flags || is_container(f.kind) || skipped) {
            continue;
        }
        if f.kind == Kind::FlagByte && f.size == number {
            found = Some(j);
        }
        let inner = find_flag_byte_in(
            t,
            j.saturating_add(1),
            end(t, j),
            before,
            number,
            f.kind == Kind::Flags,
        );
        if inner.is_some() {
            found = inner;
        }
    }
    found
}

/// The flag byte of the flag bit at `bit`.
pub(crate) fn flag_byte_of(t: &[Field], bit: usize) -> Option<usize> {
    let f = get(t, bit)?;
    find_flag_byte_in(t, scope_of(t, bit), bit, bit, f.size, false)
}

/// The position of the flag bit at `bit` among the bits of its flag byte `byte`.
pub(crate) fn bit_position(t: &[Field], byte: usize, bit: usize) -> usize {
    (byte.saturating_add(1)..bit)
        .filter(|j| kind(t, *j) == Some(Kind::FlagBit) && flag_byte_of(t, *j) == Some(byte))
        .count()
}

/// A `when` or a count is late when its flag bit decides it although its source is written
/// after the flag byte and before the bit: a reader decides the bit where the byte is read,
/// before that source exists. `bit` is the flag bit, `byte` its flag byte.
fn late_for(t: &[Field], bit: usize, byte: usize, i: usize) -> bool {
    source_of(t, i).is_some_and(|s| s > byte && s < bit)
}

/// The entries of the flag bit at `bit` that it decides late, in order: walked like the C++
/// `mark_late`, looking into groups, `flags` and `when`s that are not late themselves.
pub(crate) fn for_each_late(t: &[Field], bit: usize, mut each: impl FnMut(usize) -> bool) -> bool {
    let Some(byte) = flag_byte_of(t, bit) else {
        return true;
    };
    let stop = end(t, bit);
    let mut i = bit.saturating_add(1);
    while i < stop {
        let Some(k) = kind(t, i) else {
            return true;
        };
        let decided = k == Kind::When;
        let late = decided && late_for(t, bit, byte, i);
        if late && !each(i) {
            return false;
        }
        let inside = k == Kind::Flags || (k == Kind::When && !late);
        i = if inside {
            i.saturating_add(1)
        } else {
            end(t, i)
        };
    }
    true
}

/// True when the `when` at `i` is decided late by the nearest flag bit around it.
pub(crate) fn is_late(t: &[Field], i: usize) -> bool {
    if kind(t, i) != Some(Kind::When) {
        return false;
    }
    let mut p = parent_of(t, i);
    while let Some(k) = p {
        if kind(t, k) == Some(Kind::FlagBit) {
            let mut hit = false;
            for_each_late(t, k, |j| {
                hit = j == i;
                !hit
            });
            return hit;
        }
        if !matches!(kind(t, k), Some(Kind::Flags | Kind::When)) {
            return false;
        }
        p = parent_of(t, k);
    }
    false
}

/// Where value `k` of a `u2`, `bits` or `packed` field (`width` 1 or 2) sits: its byte and the
/// shift inside that byte, low bits first.
pub(crate) fn slot_of(k: usize, width: u64) -> (usize, u32) {
    if width == 2 {
        (k >> 2, ((k & 3) as u32) << 1)
    } else {
        (k >> 3, (k & 7) as u32)
    }
}

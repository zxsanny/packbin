use super::shape::label;
use super::{Field, FieldKind};

/// Refuses a `repeat` that is not the last thing its packet reads. A `repeat` has no count on the
/// wire: unpack reads rounds until the packet ends, so a field written after it would be read as
/// more rounds.
///
/// A field follows a `repeat` when it stands later in the repeat's own place, or after a `when`,
/// `flags`, flag bit or group that holds the repeat, up to the top level, and it can write a
/// byte. Every field can but a bool (an empty `group`: a bit of a byte written earlier), a
/// zero-width `bytes` and a `u2` with no name; a `when`, group, flag bit or round counts by what
/// it holds, so a second `repeat` follows the first by its first member. A `list` or `dict`
/// element is one value and never holds a `repeat` (see `integrity.rs`), and a round holds none
/// (see `shape.rs`). The check is on the scheme, not on a row: a `when` that is not taken or a
/// count of 0 does not make the scheme readable. One walk at construction; nothing per pack or
/// unpack.
pub(super) fn check_repeat_last(fields: &[Field]) {
    walk_after_repeat(fields, &mut None);
}

/// `ended`: the anchor of the first `repeat` the walk has passed.
fn walk_after_repeat(fields: &[Field], ended: &mut Option<u32>) {
    for field in fields {
        match &field.kind {
            FieldKind::Repeat {
                anchor, members, ..
            } => {
                walk_after_repeat(members, ended);
                ended.get_or_insert(*anchor);
            }
            FieldKind::When { members, .. }
            | FieldKind::Group { members, .. }
            | FieldKind::Times { members, .. } => walk_after_repeat(members, ended),
            FieldKind::FlagBit { inner, .. } => {
                walk_after_repeat(std::slice::from_ref(&**inner), ended);
            }
            FieldKind::Bytes { len: 0, .. } => {}
            FieldKind::U2 { names } if names.is_empty() => {}
            // The flags byte is written before the members.
            FieldKind::Flags { members, .. } => {
                refuse_after_repeat(field, *ended);
                walk_after_repeat(members, ended);
            }
            _ => refuse_after_repeat(field, *ended),
        }
    }
}

fn refuse_after_repeat(field: &Field, ended: Option<u32>) {
    if let Some(anchor) = ended {
        panic!(
            "repeat {anchor}: field {} follows it; a repeat reads to the end of the packet, so \
             nothing can follow it; use times",
            label(field)
        );
    }
}

/// Refuses a `repeat` or `times` whose body holds no member, wherever it stands. A round of such
/// a body charges no slot and writes no byte, so neither `max_slots` nor `max_bytes` bounds how
/// often it runs: a count of 65 535 would loop that often for no output.
///
/// A member is any field but a container that holds none: looking through `when`, groups and flag
/// bits, a body of only empty `when`s or empty groups is empty. A zero-width `bytes`, a flag
/// byte and a `flags` without members are members: they name a slot or write a byte, so the
/// budgets still bound them. One walk at construction; no per-round cost.
pub(super) fn check_round_bodies(fields: &[Field]) {
    for field in fields {
        match &field.kind {
            FieldKind::Repeat {
                anchor, members, ..
            } => check_body("repeat", *anchor, members),
            FieldKind::Times {
                anchor, members, ..
            } => check_body("times", *anchor, members),
            FieldKind::Flags { members, .. }
            | FieldKind::Group { members, .. }
            | FieldKind::When { members, .. } => check_round_bodies(members),
            FieldKind::FlagBit { inner, .. } => check_round_bodies(std::slice::from_ref(&**inner)),
            FieldKind::List { element, .. } | FieldKind::Dict { element, .. } => {
                check_round_bodies(std::slice::from_ref(&**element));
            }
            _ => {}
        }
    }
}

fn check_body(kind: &str, anchor: u32, members: &[Field]) {
    if !holds_member(members) {
        panic!(
            "{kind} {anchor}: the body holds no member; a round of it would charge no slot and \
             write nothing"
        );
    }
    check_round_bodies(members);
}

fn holds_member(fields: &[Field]) -> bool {
    fields.iter().any(|field| match &field.kind {
        FieldKind::When { members, .. }
        | FieldKind::Group { members, .. }
        | FieldKind::Repeat { members, .. }
        | FieldKind::Times { members, .. } => holds_member(members),
        FieldKind::FlagBit { inner, .. } => holds_member(std::slice::from_ref(&**inner)),
        _ => true,
    })
}

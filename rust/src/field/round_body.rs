use super::{Field, FieldKind};

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

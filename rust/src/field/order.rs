use super::{Field, FieldKind};

pub(crate) fn take_id(next: &mut u32, id: u32) {
    if id != *next {
        panic!("field id {id} is not the next order {next}");
    }
    *next = next.saturating_add(1);
}

/// Walks `fields` in order. `scope` is the first id of the enclosing container: a `when`,
/// count or flag-bit reference must name an id in `scope..next`. Which flag byte a flag bit
/// reads is checked by the shape pass (`shape.rs`).
pub(crate) fn check_order(fields: &[Field], mut next: u32, scope: u32) -> u32 {
    for field in fields {
        next = check_one(field, next, scope);
    }
    next
}

pub(crate) fn nested_element(field: &Field) -> Option<&Field> {
    match &field.kind {
        FieldKind::List { element, .. } | FieldKind::Dict { element, .. } => Some(element),
        _ => None,
    }
}

fn parse_id(name: &str) -> Option<u32> {
    name.parse::<u32>().ok().filter(|id| id.to_string() == name)
}

fn take_value_slot(next: &mut u32, name: &str) {
    if let Some(id) = parse_id(name) {
        take_id(next, id);
    } else {
        *next = next.saturating_add(1);
    }
}

fn require_walked(next: u32, scope: u32, name: &str) {
    if let Some(id) = parse_id(name) {
        if id >= next {
            panic!("field id {id} is not yet walked at order {next}");
        }
    }
    require_in_scope(scope, name);
}

// A repeat or times round reads into its own values, so an outer id is never visible there.
fn require_in_scope(scope: u32, name: &str) {
    if let Some(id) = parse_id(name) {
        if id < scope {
            panic!("field id {id} is not in the same scope (the container starts at id {scope})");
        }
    }
}

fn check_anchor(next: u32, anchor: u32) {
    if anchor != next {
        panic!("field id {anchor} is not the next order {next}");
    }
}

fn check_one(field: &Field, mut next: u32, scope: u32) -> u32 {
    match &field.kind {
        FieldKind::Int { name, .. }
        | FieldKind::Float { name, .. }
        | FieldKind::Bytes { name, .. }
        | FieldKind::Utf8 { name }
        | FieldKind::FlagByte { name, .. } => {
            take_value_slot(&mut next, name);
            next
        }
        FieldKind::Sized { name, count } | FieldKind::Bits { name, count } => {
            require_walked(next, scope, count);
            take_value_slot(&mut next, name);
            next
        }
        FieldKind::Packed { name, count, .. } => {
            require_walked(next, scope, count);
            take_value_slot(&mut next, name);
            next
        }
        FieldKind::U2 { names } => {
            for name in names {
                take_value_slot(&mut next, name);
            }
            next
        }
        FieldKind::Flags {
            anchor, members, ..
        } => {
            check_anchor(next, *anchor);
            check_order(members, next, scope)
        }
        FieldKind::When {
            anchor,
            field,
            members,
            ..
        } => {
            check_anchor(next, *anchor);
            require_walked(next, scope, field);
            check_order(members, next, scope)
        }
        FieldKind::Repeat { anchor, members } => {
            check_anchor(next, *anchor);
            check_order(members, next, *anchor)
        }
        FieldKind::Times {
            anchor,
            count,
            members,
        } => {
            check_anchor(next, *anchor);
            require_walked(next, scope, count);
            check_order(members, next, *anchor)
        }
        FieldKind::Group { anchor, name, members } => {
            check_anchor(next, *anchor);
            if members.is_empty() {
                take_value_slot(&mut next, name);
                next
            } else {
                check_order(members, next, scope)
            }
        }
        FieldKind::FlagBit { flag, inner, .. } => {
            require_in_scope(scope, flag);
            check_one(inner, next, scope)
        }
        FieldKind::List { element, .. } | FieldKind::Dict { element, .. } => {
            check_one(element, 0, 0);
            next
        }
    }
}

use super::shape::label;
use super::{Field, FieldKind};
use crate::value::{as_int, Name, Value};

/// Checks what a `when` reads and what a `list` or `dict` element may be, so a scheme the
/// walker cannot carry fails when it is built instead of losing data.
///
/// - A `when` tests an integer or bool field against an integer value; the check applies to a
///   tested name this scope has declared before the `when`.
/// - An element is one integer, float, bytes, utf8, list or dict, or a `u2` with one name. The
///   walker keeps one value per element, so a group, flags, `when`, `repeat`, `times`, flag
///   byte or bit, `sized`, `bits`, `packed` or a `u2` with several names would drop values.
pub(crate) fn check_integrity(fields: &[Field]) {
    check_seq(fields, &mut Seen::new());
}

/// The names one scope has declared so far and whether each holds an integer. A `repeat` or
/// `times` round and a `list` or `dict` element each have a scope of their own.
type Seen = Vec<(Name, bool)>;

fn check_seq(fields: &[Field], seen: &mut Seen) {
    for field in fields {
        check_one(field, seen);
    }
}

fn check_one(field: &Field, seen: &mut Seen) {
    match &field.kind {
        FieldKind::Int { name, .. } | FieldKind::FlagByte { name, .. } => {
            seen.push((name.clone(), true));
        }
        FieldKind::Float { name, .. }
        | FieldKind::Bytes { name, .. }
        | FieldKind::Utf8 { name }
        | FieldKind::Sized { name, .. }
        | FieldKind::Bits { name, .. }
        | FieldKind::Packed { name, .. } => seen.push((name.clone(), false)),
        FieldKind::U2 { names } => seen.extend(names.iter().map(|name| (name.clone(), true))),
        FieldKind::Flags { name, members, .. } => {
            seen.push((name.clone(), true));
            check_seq(members, seen);
        }
        FieldKind::Group { name, members, .. } => {
            if members.is_empty() {
                seen.push((name.clone(), true));
            } else {
                check_seq(members, seen);
            }
        }
        FieldKind::FlagBit { inner, .. } => check_one(inner, seen),
        FieldKind::When {
            anchor,
            field: tested,
            expect,
            members,
        } => {
            check_when(*anchor, tested, expect, seen);
            check_seq(members, seen);
        }
        FieldKind::Repeat { members, .. } | FieldKind::Times { members, .. } => {
            check_seq(members, &mut Seen::new());
        }
        FieldKind::List { name, element } => {
            seen.push((name.clone(), false));
            check_element("list", name, element);
        }
        FieldKind::Dict { name, element } => {
            seen.push((name.clone(), false));
            check_element("dict", name, element);
        }
    }
}

fn check_when(anchor: u32, tested: &Name, expect: &Value, seen: &Seen) {
    if let Some((_, false)) = seen.iter().rev().find(|(name, _)| name == tested) {
        panic!("when at id {anchor} tests field \"{tested}\", which is not an integer or bool");
    }
    if as_int(expect).is_none() {
        panic!(
            "when at id {anchor} compares field \"{tested}\" with a value that is not an integer"
        );
    }
}

fn check_element(owner: &str, name: &str, element: &Field) {
    match &element.kind {
        FieldKind::Int { .. }
        | FieldKind::Float { .. }
        | FieldKind::Bytes { .. }
        | FieldKind::Utf8 { .. } => {}
        FieldKind::U2 { names } if names.len() <= 1 => {}
        FieldKind::List { name, element } => check_element("list", name, element),
        FieldKind::Dict { name, element } => check_element("dict", name, element),
        _ => panic!(
            "{owner} \"{name}\" cannot carry element {}: an element is one integer, float, bytes, \
             utf8, list or dict, or a u2 with one name",
            label(element)
        ),
    }
}

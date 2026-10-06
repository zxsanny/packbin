use super::shape::label;
use super::{Field, FieldKind};
use crate::value::{as_int, Name, Value};

/// Checks what a `when` reads and what a `list` or `dict` element may be, so a scheme the
/// walker cannot carry fails when it is built instead of losing data.
///
/// - A `when` tests an integer or bool field against an integer value, and a `when` or a count
///   (`sized`, `bits`, `packed`, `times`) names a field this scope declared before it. A name
///   outside the scope (outside or inside an earlier `repeat`, `times`, `list` or `dict` body)
///   or declared nowhere is refused, whether it is an id or a name.
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
        | FieldKind::Utf8 { name } => seen.push((name.clone(), false)),
        FieldKind::Sized { name, count }
        | FieldKind::Bits { name, count }
        | FieldKind::Packed { name, count, .. } => {
            declared_integer(&format!("the count of \"{name}\""), count, seen);
            seen.push((name.clone(), false));
        }
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
        FieldKind::Repeat { members, .. } => check_seq(members, &mut Seen::new()),
        FieldKind::Times {
            anchor,
            count,
            members,
            ..
        } => {
            declared_integer(&format!("times at id {anchor}"), count, seen);
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

/// Whether the latest field `name` in this scope holds an integer; panics when this scope has
/// declared no field of that name before `owner`.
fn declared_integer(owner: &str, name: &Name, seen: &Seen) -> bool {
    match seen.iter().rev().find(|(declared, _)| declared == name) {
        Some((_, integer)) => *integer,
        None => panic!(
            "{owner} names field \"{name}\", which is not in the same scope (a field must be \
             declared earlier in the same container; a repeat, times, list or dict body is a \
             scope of its own)"
        ),
    }
}

fn check_when(anchor: u32, tested: &Name, expect: &Value, seen: &Seen) {
    if !declared_integer(&format!("when at id {anchor}"), tested, seen) {
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

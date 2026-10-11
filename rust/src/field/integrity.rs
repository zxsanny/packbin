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
/// - A `when` that tests a bool (an empty `group`) compares it with `1` (true) only: a false
///   bool is absent on the wire, so `eq(bool, 0)` could never match on unpack. A float, utf8,
///   bytes or collection source is refused. A count names an integer field only, so a bool
///   or a float count is refused.
/// - A `flags` name joins the scope after its members: a member that names the byte it sits in
///   is refused, since pack writes that byte after the members. A sibling after the container
///   may name it.
/// - An element is one integer, float, bytes, utf8, list or dict, or a `u2` with one name. The
///   walker keeps one value per element, so a group, flags, `when`, `repeat`, `times`, flag
///   byte or bit, `sized`, `bits`, `packed` or a `u2` with several names would drop values.
pub(crate) fn check_integrity(fields: &[Field]) {
    check_seq(fields, &mut Seen::new());
}

#[derive(Clone, Copy, PartialEq)]
enum Source {
    Integer,
    Bool,
    Other,
}

/// The names one scope has declared so far and what each holds. A `repeat` or `times` round
/// and a `list` or `dict` element each have a scope of their own.
type Seen = Vec<(Name, Source)>;

fn check_seq(fields: &[Field], seen: &mut Seen) {
    for field in fields {
        check_one(field, seen);
    }
}

fn check_one(field: &Field, seen: &mut Seen) {
    match &field.kind {
        FieldKind::Int { name, .. } | FieldKind::FlagByte { name, .. } => {
            seen.push((name.clone(), Source::Integer));
        }
        FieldKind::Float { name, .. }
        | FieldKind::Bytes { name, .. }
        | FieldKind::Utf8 { name } => seen.push((name.clone(), Source::Other)),
        FieldKind::Sized { name, count }
        | FieldKind::Bits { name, count }
        | FieldKind::Packed { name, count, .. } => {
            check_count(&format!("the count of \"{name}\""), count, seen);
            seen.push((name.clone(), Source::Other));
        }
        FieldKind::U2 { names } => {
            seen.extend(names.iter().map(|name| (name.clone(), Source::Integer)));
        }
        FieldKind::Flags { name, members, .. } => {
            check_seq(members, seen);
            seen.push((name.clone(), Source::Integer));
        }
        FieldKind::Group { name, members, .. } => {
            if members.is_empty() {
                seen.push((name.clone(), Source::Bool));
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
            check_count(&format!("times at id {anchor}"), count, seen);
            check_seq(members, &mut Seen::new());
        }
        FieldKind::List { name, element } => {
            seen.push((name.clone(), Source::Other));
            check_element("list", name, element);
        }
        FieldKind::Dict { name, element } => {
            seen.push((name.clone(), Source::Other));
            check_element("dict", name, element);
        }
    }
}

/// What the latest field `name` in this scope holds; panics when this scope has declared no
/// field of that name before `owner`.
fn declared(owner: &str, name: &Name, seen: &Seen) -> Source {
    match seen.iter().rev().find(|(declared, _)| declared == name) {
        Some((_, source)) => *source,
        None => panic!(
            "{owner} names field \"{name}\", which is not in the same scope (a field must be \
             declared earlier in the same container; a repeat, times, list or dict body is a \
             scope of its own)"
        ),
    }
}

fn check_count(owner: &str, name: &Name, seen: &Seen) {
    if declared(owner, name, seen) != Source::Integer {
        panic!("{owner} names field \"{name}\", which is not an integer");
    }
}

fn check_when(anchor: u32, tested: &Name, expect: &Value, seen: &Seen) {
    let source = declared(&format!("when at id {anchor}"), tested, seen);
    if source == Source::Other {
        panic!("when at id {anchor} tests field \"{tested}\", which is not an integer or bool");
    }
    let Some(number) = as_int(expect) else {
        panic!(
            "when at id {anchor} compares field \"{tested}\" with a value that is not an integer"
        );
    };
    if source == Source::Bool && number != 1 {
        panic!(
            "when at id {anchor} compares bool \"{tested}\" with a value other than true (1); a \
             false bool is absent on the wire, so the comparison could never match"
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

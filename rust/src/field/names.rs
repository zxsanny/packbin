use super::{Field, FieldKind};
use std::collections::hash_map::Entry;
use std::collections::HashMap;

/// Refuses a data member name declared twice in one scope, so no value is lost: a row holds
/// one value per name, and a later value or a `times` round list replaces the earlier one.
///
/// - The scope is the top level. A `when` body, a `flags` member, a flag bit, a non-empty
///   `group`, a `repeat` body and a `times` body belong to the scope around them, so a name
///   inside a round clashes with the same name outside it. A `list` or `dict` element holds
///   one name and is a scope of its own.
/// - A data name is the name of an integer, float, bytes, utf8, `sized`, `bits`, `packed`,
///   `list` or `dict` field, each name of a `u2` and a bool (an empty `group`). A flag byte,
///   the name of a `flags` byte and the name of a non-empty `group` are not members of a row.
/// - Alternate `when` branches may share a name: the second declaration is refused only when
///   both sit outside every `when`.
pub(crate) fn check_names(fields: &[Field]) {
    walk(fields, false, &mut HashMap::new());
}

/// Each name this scope has declared, and whether a declaration sits outside every `when`.
type Declared<'a> = HashMap<&'a str, bool>;

fn declare<'a>(name: &'a str, conditional: bool, declared: &mut Declared<'a>) {
    match declared.entry(name) {
        Entry::Vacant(first) => {
            first.insert(!conditional);
        }
        Entry::Occupied(mut first) if !conditional => {
            if *first.get() {
                panic!(
                    "member \"{name}\" is declared twice in one scope; a row holds one value per \
                     name, so one would be lost"
                );
            }
            first.insert(true);
        }
        Entry::Occupied(_) => {}
    }
}

fn walk<'a>(fields: &'a [Field], conditional: bool, declared: &mut Declared<'a>) {
    for field in fields {
        match &field.kind {
            FieldKind::Int { name, .. }
            | FieldKind::Float { name, .. }
            | FieldKind::Bytes { name, .. }
            | FieldKind::Utf8 { name }
            | FieldKind::Sized { name, .. }
            | FieldKind::Bits { name, .. }
            | FieldKind::Packed { name, .. }
            | FieldKind::List { name, .. }
            | FieldKind::Dict { name, .. } => declare(name, conditional, declared),
            FieldKind::U2 { names } => {
                for name in names {
                    declare(name, conditional, declared);
                }
            }
            FieldKind::Group { name, members, .. } if members.is_empty() => {
                declare(name, conditional, declared);
            }
            FieldKind::Group { members, .. }
            | FieldKind::Flags { members, .. }
            | FieldKind::Repeat { members, .. }
            | FieldKind::Times { members, .. } => walk(members, conditional, declared),
            FieldKind::When { members, .. } => walk(members, true, declared),
            FieldKind::FlagBit { inner, .. } => {
                walk(std::slice::from_ref(inner), conditional, declared);
            }
            FieldKind::FlagByte { .. } => {}
        }
    }
}

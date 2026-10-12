use super::pack_out::round_member;
use crate::field::{field_name, times_name, Field, FieldKind};
use crate::value::{name_of, same_values, Name, PackError, Value, Values};
use std::collections::HashMap;

/// One list per name, with an item for every round that read it.
pub(super) fn round_lists(rounds: &[Values]) -> HashMap<Name, Vec<Value>> {
    let mut lists: HashMap<Name, Vec<Value>> = HashMap::new();
    for round in rounds {
        for (key, value) in round {
            if let Some(v) = value {
                lists.entry(key.clone()).or_default().push(v.clone());
            }
        }
    }
    lists
}

/// Round `index` of a `times` given as one list per name. A list gives one item per round and
/// any other value is used in every round; a dictionary and a byte buffer are the exceptions,
/// because a lone one reads as a value for every round that was meant for one.
pub(super) fn slice_times(
    anchor: u32,
    members: &[Field],
    values: &Values,
    index: usize,
) -> Result<Values, PackError> {
    let mut slice = Values::new();
    for child in members {
        let Some(name) = field_name(child) else {
            continue;
        };
        match values.get(name) {
            Some(Some(Value::List(items))) => {
                if index < items.len() {
                    slice.insert(name_of(name), Some(items[index].clone()));
                }
            }
            Some(Some(Value::Map(_))) if holds_dict(child) => {
                return Err(PackError::Type(format!(
                    "times at id {anchor}: '{name}' is one dictionary; give a list with one \
                     dictionary per round"
                )));
            }
            Some(Some(Value::Bytes(_))) if holds_bytes(child) => {
                return Err(PackError::Type(format!(
                    "times at id {anchor}: '{name}' is one byte buffer; give a list with one \
                     buffer per round"
                )));
            }
            Some(Some(v)) => {
                slice.insert(name_of(name), Some(v.clone()));
            }
            _ => {}
        }
    }
    for below in names_below(members, false) {
        if below.when {
            continue;
        }
        match values.get(below.name) {
            Some(Some(Value::List(items))) => {
                if index < items.len() {
                    slice.insert(name_of(below.name), Some(items[index].clone()));
                }
            }
            Some(Some(v)) => {
                slice.insert(name_of(below.name), Some(v.clone()));
            }
            _ => {}
        }
    }
    Ok(slice)
}

pub(super) fn rounds_mismatch(anchor: u32, count: usize, rounds: usize) -> PackError {
    PackError::Type(format!(
        "times at id {anchor}: count {count}, {rounds} rounds"
    ))
}

/// Unpack refuses a round past `max_rounds`; pack refuses a count past it before it writes (or
/// slices) any round, so a count of billions with a lone value cannot loop for hours or fill memory.
pub(super) fn check_round_cap(
    anchor: u32,
    count_field: &str,
    members: &[Field],
    count: usize,
    max_rounds: usize,
) -> Result<(), PackError> {
    if count <= max_rounds {
        return Ok(());
    }
    let names: Vec<&str> = members.iter().filter_map(data_name).collect();
    Err(PackError::Type(format!(
        "times at id {anchor}: count {count} (from '{count_field}') is over the {max_rounds} \
         rounds a scheme allows; members '{}'",
        names.join("', '")
    )))
}

/// Unpack refuses the round after `max_rounds` of a `repeat`, so pack refuses its rounds before it
/// writes any when they pass it, naming the first member the round holds.
pub(super) fn check_repeat_cap(
    anchor: u32,
    members: &[Field],
    rounds: usize,
    max_rounds: usize,
) -> Result<(), PackError> {
    if rounds <= max_rounds {
        return Ok(());
    }
    Err(PackError::Type(format!(
        "{}: the repeat count is {rounds}, above the limit of {max_rounds} rounds",
        round_member("repeat", anchor, members)
    )))
}

/// A `times` with count 0 writes no round, and what is given for its rounds (rounds, or a list
/// with an item for a member) is refused, as it is for any other count it does not match.
pub(super) fn check_no_rounds(
    anchor: u32,
    members: &[Field],
    values: &Values,
) -> Result<(), PackError> {
    let key = times_name(anchor);
    match values.get(key.as_ref()) {
        Some(Some(Value::Groups(rounds))) if rounds.is_empty() => {
            check_lists(anchor, members, rounds, values)
        }
        Some(Some(Value::Groups(rounds))) => Err(rounds_mismatch(anchor, 0, rounds.len())),
        Some(Some(_)) => Err(PackError::Type(key.to_string())),
        _ => {
            check_aligned(anchor, members, values)?;
            check_longer(anchor, members, values, 0)
        }
    }
}

fn holds_bytes(field: &Field) -> bool {
    match &field.kind {
        FieldKind::Bytes { .. } | FieldKind::Sized { .. } => true,
        FieldKind::FlagBit { inner, .. } => holds_bytes(inner),
        _ => false,
    }
}

fn holds_dict(field: &Field) -> bool {
    match &field.kind {
        FieldKind::Dict { .. } => true,
        FieldKind::FlagBit { inner, .. } => holds_dict(inner),
        _ => false,
    }
}

/// Pack takes the rounds and ignores the values kept beside them under a name of the rounds, so
/// one that the rounds do not hold would be dropped without a word. A value that is not a list
/// counts as a list of one item, as the lists-only form reads it. Fails on the first such name.
pub(super) fn check_lists(
    anchor: u32,
    members: &[Field],
    rounds: &[Values],
    values: &Values,
) -> Result<(), PackError> {
    let mut kept: Vec<(&Name, &[Value])> = values
        .iter()
        .filter_map(|(name, value)| {
            let items = match value {
                Some(Value::List(list)) => list.as_slice(),
                Some(one) => std::slice::from_ref(one),
                None => return None,
            };
            declares(members, name).then_some((name, items))
        })
        .collect();
    if kept.is_empty() {
        return Ok(());
    }
    kept.sort_by_key(|(name, _)| *name);
    let lists = round_lists(rounds);
    for (name, list) in kept {
        let held = lists.get(name).map_or(&[][..], Vec::as_slice);
        if !same_values(list, held) {
            return Err(PackError::Type(format!(
                "times at id {anchor}: list for '{name}' disagrees with its rounds"
            )));
        }
    }
    Ok(())
}

/// Whether a field of `fields`, at any depth, is named `name`.
fn declares(fields: &[Field], name: &str) -> bool {
    fields.iter().any(|field| match &field.kind {
        FieldKind::Flags {
            name: own, members, ..
        }
        | FieldKind::Group {
            name: own, members, ..
        } => own.as_ref() == name || declares(members, name),
        FieldKind::When { members, .. } => declares(members, name),
        FieldKind::FlagBit { inner, .. } => declares(std::slice::from_ref(inner), name),
        FieldKind::U2 { names } => names.iter().any(|own| own.as_ref() == name),
        _ => field_name(field) == Some(name),
    })
}

/// A `repeat` takes its rounds only as `__repeat__` groups. With none, a value kept under a name of
/// its body (a non-list counts as a list of one item; an empty list holds nothing) would be dropped
/// without a word, so it fails on the first such name.
pub(super) fn check_repeat_lists(
    anchor: u32,
    members: &[Field],
    values: &Values,
) -> Result<(), PackError> {
    let names = names_below(members, true);
    match names.iter().find(|below| holds_items(values, below.name)) {
        Some(Below { name, .. }) => Err(PackError::Type(format!(
            "repeat at id {anchor}: '{name}' is given without '__repeat__' groups; give the rounds \
             of a repeat as '__repeat__' groups, one per round"
        ))),
        None => Ok(()),
    }
}

/// Without rounds pack gives each direct field of a `times` one item of its list per round, and a
/// name below a `flags` the same: a list shorter than the count leaves the member absent in the
/// rounds it does not reach, so its bit is clear. Below a `when` it reads nothing: a list has no
/// null to say which round holds a member that only some rounds have. A value kept under such a
/// member's name (a non-list counts as a list of one item; an empty list holds nothing) would be
/// dropped, so it fails on the first such name; the rounds hold it. A lone dictionary or byte
/// buffer below a `flags` is refused as it is for a direct member.
pub(super) fn check_aligned(
    anchor: u32,
    members: &[Field],
    values: &Values,
) -> Result<(), PackError> {
    for below in names_below(members, false) {
        if below.when {
            if holds_items(values, below.name) {
                return Err(PackError::Type(format!(
                    "times at id {anchor}: '{}' is under a flags or when; give its values per \
                     round under '{}'",
                    below.name,
                    times_name(anchor)
                )));
            }
            continue;
        }
        match values.get(below.name) {
            Some(Some(Value::Map(_))) if holds_dict(below.field) => {
                return Err(PackError::Type(format!(
                    "times at id {anchor}: '{}' is one dictionary; give a list with one \
                     dictionary per round",
                    below.name
                )));
            }
            Some(Some(Value::Bytes(_))) if holds_bytes(below.field) => {
                return Err(PackError::Type(format!(
                    "times at id {anchor}: '{}' is one byte buffer; give a list with one \
                     buffer per round",
                    below.name
                )));
            }
            _ => {}
        }
    }
    Ok(())
}

/// Without rounds pack takes item `i` of each direct field's list for round `i` of the `count`
/// rounds, so the items past the count would be dropped without a word. Fails on the first such
/// field. A list that is too short fails when its round runs out of items.
pub(super) fn check_longer(
    anchor: u32,
    members: &[Field],
    values: &Values,
    count: usize,
) -> Result<(), PackError> {
    for member in members {
        let Some(name) = data_name(member) else {
            continue;
        };
        if let Some(Some(Value::List(items))) = values.get(name) {
            if items.len() > count {
                return Err(PackError::Type(format!(
                    "times at id {anchor}: '{name}' has {} items, count is {count}",
                    items.len()
                )));
            }
        }
    }
    for below in names_below(members, false) {
        if below.when {
            continue;
        }
        if let Some(Some(Value::List(items))) = values.get(below.name) {
            if items.len() > count {
                return Err(PackError::Type(format!(
                    "times at id {anchor}: '{}' has {} items, count is {count}",
                    below.name,
                    items.len()
                )));
            }
        }
    }
    Ok(())
}

/// The name of the value pack reads for a direct member of a `times`. A `flags`, a flag byte and
/// a `group` at the top of the round are made from their members, so a list kept under their
/// name is not read (unpack publishes one under each flags and flag byte name, one item per
/// round). Under a flag bit the field is data.
fn data_name(member: &Field) -> Option<&str> {
    match &member.kind {
        FieldKind::Flags { .. } | FieldKind::FlagByte { .. } | FieldKind::Group { .. } => None,
        FieldKind::FlagBit { inner, .. } => field_name(inner),
        _ => field_name(member),
    }
}

fn holds_items(values: &Values, name: &str) -> bool {
    match values.get(name) {
        Some(Some(Value::List(items))) => !items.is_empty(),
        Some(Some(_)) => true,
        _ => false,
    }
}

/// A value name of a round body that sits below a `flags` or `when` (`when`: at any depth under a
/// `when`), with the field that holds it.
struct Below<'a> {
    name: &'a str,
    field: &'a Field,
    when: bool,
}

/// Collects, in field order, the value names of the fields below a `flags` or `when`. With `under`
/// the fields at the top count too (a `repeat` body, where none are direct).
fn names_below(fields: &[Field], under: bool) -> Vec<Below<'_>> {
    let mut out = Vec::new();
    collect_below(fields, under, false, &mut out);
    out
}

fn collect_below<'a>(fields: &'a [Field], flags: bool, when: bool, out: &mut Vec<Below<'a>>) {
    for field in fields {
        match &field.kind {
            FieldKind::Flags { members, .. } => collect_below(members, true, when, out),
            FieldKind::When { members, .. } => collect_below(members, flags, true, out),
            FieldKind::Group { name, members, .. } => {
                if flags || when {
                    out.push(Below { name, field, when });
                }
                collect_below(members, flags, when, out);
            }
            FieldKind::FlagBit { inner, .. } => {
                collect_below(std::slice::from_ref(inner), flags, when, out);
            }
            FieldKind::U2 { names } if flags || when => {
                out.extend(names.iter().map(|name| Below { name, field, when }));
            }
            _ if flags || when => {
                if let Some(name) = field_name(field) {
                    out.push(Below { name, field, when });
                }
            }
            _ => {}
        }
    }
}

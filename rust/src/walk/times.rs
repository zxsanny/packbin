use crate::field::{field_name, times_name, Field, FieldKind};
use crate::value::{same_values, Name, PackError, Value, Values};
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

/// Without rounds pack gives each direct field of a `times` one item of its list per round, and
/// reads nothing below a `flags` or `when`: a list has no null to say which round holds a member
/// that only some rounds have. A value kept under such a member's name (a non-list counts as a
/// list of one item; an empty list holds nothing) would be dropped, so it fails on the first
/// such name; the rounds hold it.
pub(super) fn check_aligned(
    anchor: u32,
    members: &[Field],
    values: &Values,
) -> Result<(), PackError> {
    let mut below = Vec::new();
    names_below(members, false, &mut below);
    match below.into_iter().find(|name| holds_items(values, name)) {
        Some(name) => Err(PackError::Type(format!(
            "times at id {anchor}: '{name}' is under a flags or when; give its values per round \
             under '{}'",
            times_name(anchor)
        ))),
        None => Ok(()),
    }
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

/// Collects, in field order, the value names of the fields below a `flags` or `when`.
fn names_below<'a>(fields: &'a [Field], under: bool, out: &mut Vec<&'a str>) {
    for field in fields {
        match &field.kind {
            FieldKind::Flags { members, .. } | FieldKind::When { members, .. } => {
                names_below(members, true, out);
            }
            FieldKind::Group { name, members, .. } => {
                if under {
                    out.push(name);
                }
                names_below(members, under, out);
            }
            FieldKind::FlagBit { inner, .. } => {
                names_below(std::slice::from_ref(inner), under, out);
            }
            FieldKind::U2 { names } if under => out.extend(names.iter().map(|n| n.as_ref())),
            _ if under => out.extend(field_name(field)),
            _ => {}
        }
    }
}

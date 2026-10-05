use crate::field::{field_name, Field, FieldKind};
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

use crate::field::{field_name, Field, FieldKind};
use crate::value::{as_bit, present, PackError, Values};
use std::collections::HashMap;

/// A bool (an empty group) is on for `1` and off for `0` or no value; any other value is a
/// type error, as for `bits`.
fn bool_on(values: &Values, name: &str) -> Result<bool, PackError> {
    match values.get(name) {
        Some(Some(v)) => as_bit(v)
            .map(|bit| bit == 1)
            .ok_or_else(|| PackError::Type(name.to_string())),
        _ => Ok(false),
    }
}

/// Sets the bits of the flag bytes read in this scope, by slot. A repeat or times round
/// collects its own.
pub(super) fn collect_flag_bits(
    fields: &[Field],
    values: &Values,
    out: &mut HashMap<usize, u8>,
) -> Result<(), PackError> {
    for field in fields {
        match &field.kind {
            FieldKind::FlagBit {
                slot, bit, inner, ..
            } => {
                if member_on(inner, values)? {
                    *out.entry(*slot).or_insert(0) |= 1 << *bit;
                }
                collect_flag_bits(std::slice::from_ref(inner), values, out)?;
            }
            FieldKind::Flags { members, .. }
            | FieldKind::Group { members, .. }
            | FieldKind::When { members, .. } => collect_flag_bits(members, values, out)?,
            _ => {}
        }
    }
    Ok(())
}

/// A group is on when it or one of its values, at any depth, is present, or one of its flag
/// bits is on. A `when`, `repeat` or `times` inside it does not count, and neither does a flag
/// byte, whose value comes from its bits.
fn group_on(name: &str, members: &[Field], values: &Values) -> Result<bool, PackError> {
    if members.is_empty() {
        return bool_on(values, name);
    }
    if present(values, name) {
        return Ok(true);
    }
    any_member_on(members, values)
}

fn any_member_on(members: &[Field], values: &Values) -> Result<bool, PackError> {
    for member in members {
        if !matches!(member.kind, FieldKind::FlagByte { .. }) && member_on(member, values)? {
            return Ok(true);
        }
    }
    Ok(false)
}

/// Whether a `flags` member or the field under a flag bit is on, so its bit is set.
pub(super) fn member_on(field: &Field, values: &Values) -> Result<bool, PackError> {
    match &field.kind {
        FieldKind::Group { name, members, .. } => group_on(name, members, values),
        FieldKind::FlagBit { inner, .. } => member_on(inner, values),
        FieldKind::Flags { name, members, .. } => {
            if present(values, name) {
                return Ok(true);
            }
            any_member_on(members, values)
        }
        FieldKind::U2 { names } => Ok(names.iter().any(|n| present(values, n))),
        _ => Ok(field_name(field).is_some_and(|n| present(values, n))),
    }
}

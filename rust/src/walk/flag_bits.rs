use super::times::check_no_rounds;
use super::written::{borrowed_count, Written};
use crate::field::{field_name, Field, FieldKind};
use crate::value::{as_bit, present, when_matches, PackError, Value, Values};
use std::collections::HashMap;

/// The fields under each flag byte read in one scope, by slot, with the bit each one owns.
pub(super) type FlagInners<'f> = HashMap<usize, Vec<(u8, &'f Field)>>;

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

/// Collects the fields under the flag bytes read in this scope, by slot. A repeat or times round
/// collects its own.
pub(super) fn collect_flag_bits<'f>(fields: &'f [Field], out: &mut FlagInners<'f>) {
    for field in fields {
        match &field.kind {
            FieldKind::FlagBit {
                slot, bit, inner, ..
            } => {
                out.entry(*slot).or_default().push((*bit, inner));
                collect_flag_bits(std::slice::from_ref(inner), out);
            }
            FieldKind::Flags { members, .. }
            | FieldKind::Group { members, .. }
            | FieldKind::When { members, .. } => collect_flag_bits(members, out),
            _ => {}
        }
    }
}

/// A group is on when it or one of its values, at any depth, is present, or one of its flag
/// bits is on. A `when`, `times` or `repeat` inside it counts as it does under `flags`. A flag
/// byte does not, since its value comes from its bits.
fn group_on(
    name: &str,
    members: &[Field],
    values: &Values,
    wrote: &Written<'_>,
) -> Result<bool, PackError> {
    if members.is_empty() {
        return bool_on(values, name);
    }
    if present(values, name) {
        return Ok(true);
    }
    any_member_on(members, values, wrote)
}

fn any_member_on(
    members: &[Field],
    values: &Values,
    wrote: &Written<'_>,
) -> Result<bool, PackError> {
    for member in members {
        if !matches!(member.kind, FieldKind::FlagByte { .. }) && member_on(member, values, wrote)? {
            return Ok(true);
        }
    }
    Ok(false)
}

/// A `when` is on when its condition holds on what pack has written so far, as unpack decides it,
/// and its body holds a value. With the condition false the body is left out and no value given
/// for it is an error.
fn when_on(
    field: &str,
    expect: &Value,
    members: &[Field],
    values: &Values,
    wrote: &Written<'_>,
) -> Result<bool, PackError> {
    if !wrote.get(field).is_some_and(|v| when_matches(v, expect)) {
        return Ok(false);
    }
    any_member_on(members, values, wrote)
}

/// A `times` is on when its count is above 0. A count pack has not written (its field was
/// skipped) is no round, as on unpack. With count 0 the values given for its rounds are refused,
/// as outside `flags`.
fn times_on(
    anchor: u32,
    count: &str,
    members: &[Field],
    values: &Values,
    wrote: &Written<'_>,
) -> Result<bool, PackError> {
    if wrote.get(count).is_none() {
        return Ok(false);
    }
    if borrowed_count(wrote, count, 0, "times")? > 0 {
        return Ok(true);
    }
    check_no_rounds(anchor, members, values)?;
    Ok(false)
}

/// A `repeat` is on when one of its rounds holds a value.
fn repeat_on(members: &[Field], values: &Values) -> Result<bool, PackError> {
    match values.get("__repeat__") {
        Some(Some(Value::Groups(rounds))) => {
            let scope = Written::unread();
            for round in rounds {
                if any_member_on(members, round, &scope)? {
                    return Ok(true);
                }
            }
            Ok(false)
        }
        Some(Some(_)) => Err(PackError::Type("__repeat__".to_string())),
        _ => Ok(false),
    }
}

/// Whether a `flags` member or the field under a flag bit is on, so its bit is set. `wrote` is
/// what pack has written in the scope so far.
pub(super) fn member_on(
    field: &Field,
    values: &Values,
    wrote: &Written<'_>,
) -> Result<bool, PackError> {
    match &field.kind {
        FieldKind::Group { name, members, .. } => group_on(name, members, values, wrote),
        FieldKind::FlagBit { inner, .. } => member_on(inner, values, wrote),
        FieldKind::Flags { name, members, .. } => {
            if present(values, name) {
                return Ok(true);
            }
            any_member_on(members, values, wrote)
        }
        FieldKind::U2 { names } => Ok(names.iter().any(|n| present(values, n))),
        FieldKind::When {
            field: tested,
            expect,
            members,
            ..
        } => when_on(tested, expect, members, values, wrote),
        FieldKind::Times {
            anchor,
            count,
            members,
            ..
        } => times_on(*anchor, count, members, values, wrote),
        FieldKind::Repeat { members, .. } => repeat_on(members, values),
        _ => Ok(field_name(field).is_some_and(|n| present(values, n))),
    }
}

use super::pack_out::round_member;
use super::times::check_no_rounds;
use super::written::{borrowed_count, Written};
use crate::field::{field_name, times_name, Field, FieldKind};
use crate::value::{as_bit, as_usize, present, when_matches, PackError, Value, Values};
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
/// skipped) is no round, as on unpack, so a value given for its rounds would be dropped without a
/// word: it is refused, naming the member (an empty list holds no value). With count 0 the values
/// given for its rounds are refused, as outside `flags`.
fn times_on(
    anchor: u32,
    count: &str,
    members: &[Field],
    values: &Values,
    wrote: &Written<'_>,
) -> Result<bool, PackError> {
    if wrote.get(count).is_none() {
        if zero_given(count, values) {
            check_no_rounds(anchor, members, values)?;
            return Ok(false);
        }
        let key = times_name(anchor);
        let given = match values.get(key.as_ref()) {
            Some(Some(Value::Groups(g))) if !g.is_empty() => {
                Some(round_member("times", anchor, members))
            }
            _ => given_name(members, values, true),
        };
        return match given {
            Some(name) => Err(PackError::Type(format!(
                "{name}: a value is given, but the count of its times is not written, so its bit \
                 is clear; write the count before the times"
            ))),
            None => Ok(false),
        };
    }
    if borrowed_count(wrote, count, 0, "times")? > 0 {
        return Ok(true);
    }
    check_no_rounds(anchor, members, values)?;
    Ok(false)
}

/// Whether the row gives the count as 0, though pack has not written it where its `times` is
/// reached (it follows the flag byte): no round starts, so nothing is dropped.
fn zero_given(count: &str, values: &Values) -> bool {
    matches!(values.get(count), Some(Some(v)) if as_usize(v) == Some(0))
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

/// The name of the first value given for `fields`, at any depth, or `None` when none is. With
/// `skip_empty` an empty list is no value.
fn given_name(fields: &[Field], values: &Values, skip_empty: bool) -> Option<String> {
    let given = |name: &str| match values.get(name) {
        Some(Some(Value::List(items))) if skip_empty && items.is_empty() => false,
        Some(Some(_)) => true,
        _ => false,
    };
    fields.iter().find_map(|field| match &field.kind {
        FieldKind::FlagByte { .. } => None,
        FieldKind::Flags { name, members, .. } | FieldKind::Group { name, members, .. } => {
            if given(name) {
                Some(name.to_string())
            } else {
                given_name(members, values, skip_empty)
            }
        }
        FieldKind::When { members, .. } => given_name(members, values, skip_empty),
        FieldKind::Times {
            anchor, members, ..
        } => {
            let key = times_name(*anchor);
            match values.get(key.as_ref()) {
                Some(Some(Value::Groups(rounds))) if !rounds.is_empty() => Some(key.to_string()),
                _ => given_name(members, values, skip_empty),
            }
        }
        FieldKind::Repeat { .. } => present(values, "__repeat__").then(|| "__repeat__".to_string()),
        FieldKind::FlagBit { inner, .. } => {
            given_name(std::slice::from_ref(inner), values, skip_empty)
        }
        FieldKind::U2 { names } => names.iter().find(|n| given(n)).map(|n| n.to_string()),
        _ => field_name(field).filter(|n| given(n)).map(str::to_string),
    })
}

/// A split flag byte decides its bits where the byte is written, from what is written so far. A
/// `when` whose condition holds (or is written after the byte and holds), or a `times` whose count
/// is not written then, would leave its bit clear and drop a value given for its body, so pack
/// refuses and names the value. A `when` whose condition is false, or whose source is never
/// written and has no value, drops its body silently, as in the combined form. Write the
/// condition or count field before the flag byte.
pub(super) fn check_split_bit(
    field: &Field,
    values: &Values,
    wrote: &Written<'_>,
) -> Result<(), PackError> {
    match &field.kind {
        FieldKind::FlagBit { inner, .. } => check_split_bit(inner, values, wrote),
        FieldKind::Flags { members, .. } | FieldKind::Group { members, .. } => members
            .iter()
            .try_for_each(|m| check_split_bit(m, values, wrote)),
        FieldKind::When {
            field: tested,
            expect,
            members,
            ..
        } => {
            if wrote.get(tested).is_some_and(|v| when_matches(v, expect)) {
                return members
                    .iter()
                    .try_for_each(|m| check_split_bit(m, values, wrote));
            }
            if wrote.get(tested).is_some() {
                return Ok(());
            }
            // The condition is written after the byte: the value given for it decides whether
            // the body would be written. A false condition drops the body silently, as in the
            // combined form; so does a source with no value at all, which is never written and
            // so never matches.
            match values.get(tested) {
                Some(Some(v)) if when_matches(v, expect) => {}
                _ => return Ok(()),
            }
            match given_name(members, values, false) {
                Some(name) => Err(PackError::Type(format!(
                    "'{name}' is given, but its when on '{tested}' holds, or is written after \
                     the flag byte, so the body would be written but the byte leaves its bit \
                     clear; write '{tested}' before the flag byte"
                ))),
                None => Ok(()),
            }
        }
        FieldKind::Times {
            anchor,
            count,
            members,
            ..
        } => {
            if wrote.get(count).is_some() {
                return Ok(());
            }
            // A count given as 0 and written after the byte starts no round: nothing is dropped, and
            // a list given for the rounds is refused as for any count 0.
            if zero_given(count, values) {
                return check_no_rounds(*anchor, members, values);
            }
            let rounds = times_name(*anchor);
            let given = match values.get(rounds.as_ref()) {
                Some(Some(Value::Groups(g))) if !g.is_empty() => Some(rounds.to_string()),
                _ => given_name(members, values, false),
            };
            match given {
                Some(name) => Err(PackError::Type(format!(
                    "'{name}' is given, but its times count '{count}' is not written where the \
                     flag byte is written (skipped or written after it); write '{count}' before \
                     the flag byte"
                ))),
                None => Ok(()),
            }
        }
        _ => Ok(()),
    }
}

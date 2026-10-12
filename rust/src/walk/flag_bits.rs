use super::pack_out::round_member;
use super::times::{check_no_rounds, check_repeat_lists};
use super::written::{borrowed_count, Written};
use crate::field::{field_name, times_name, Field, FieldKind};
use crate::value::{as_bit, as_usize, present, when_matches, PackError, Value, Values};
use std::collections::HashMap;

/// The fields under each flag byte read in one scope, by slot, with the bit each one owns.
pub(super) type FlagInners<'f> = HashMap<usize, Vec<(u8, &'f Field)>>;

/// Where a flag bit is decided: in a combined `flags` byte (which writes its own members), or at a
/// split flag byte whose fields are written elsewhere.
#[derive(Clone, Copy, PartialEq, Eq)]
pub(super) enum Form {
    Combined,
    Split,
}

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
    form: Form,
) -> Result<bool, PackError> {
    if members.is_empty() {
        return bool_on(values, name);
    }
    if present(values, name) {
        return Ok(true);
    }
    any_member_on(members, values, wrote, form)
}

fn any_member_on(
    members: &[Field],
    values: &Values,
    wrote: &Written<'_>,
    form: Form,
) -> Result<bool, PackError> {
    for member in members {
        if !matches!(member.kind, FieldKind::FlagByte { .. })
            && member_on(member, values, wrote, form)?
        {
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
    form: Form,
) -> Result<bool, PackError> {
    if !wrote.get(field).is_some_and(|v| when_matches(v, expect)) {
        return Ok(false);
    }
    any_member_on(members, values, wrote, form)
}

/// A `times` is on when its count is above 0. A count pack has not written (its field was
/// skipped) is no round, as on unpack, so a value given for its rounds would be dropped without a
/// word: it is refused, naming the member (an empty list holds no value). In the split form a
/// count given as 0 and written after the byte starts no round and is not refused. With count 0
/// the values given for its rounds are refused, as outside `flags`.
fn times_on(
    anchor: u32,
    count: &str,
    members: &[Field],
    values: &Values,
    wrote: &Written<'_>,
    form: Form,
) -> Result<bool, PackError> {
    if wrote.get(count).is_none() {
        if form == Form::Split && zero_given(count, values) {
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
/// reached (it follows the flag byte): no round starts, so nothing is dropped. Only the split
/// form has such a count; in a combined `flags` a skipped count with a stale 0 is refused like any
/// other, as the value given for the rounds would be dropped.
fn zero_given(count: &str, values: &Values) -> bool {
    matches!(values.get(count), Some(Some(v)) if as_usize(v) == Some(0))
}

/// A `repeat` is on when one of its rounds holds a value. With no rounds, a value given under a
/// name of its body would be dropped, so it is refused as outside `flags`.
fn repeat_on(
    anchor: u32,
    members: &[Field],
    values: &Values,
    form: Form,
) -> Result<bool, PackError> {
    match values.get("__repeat__") {
        Some(Some(Value::Groups(rounds))) if !rounds.is_empty() => {
            let scope = Written::unread();
            for round in rounds {
                if any_member_on(members, round, &scope, form)? {
                    return Ok(true);
                }
            }
            Ok(false)
        }
        Some(Some(Value::Groups(_))) | Some(None) | None => {
            check_repeat_lists(anchor, members, values)?;
            Ok(false)
        }
        Some(Some(_)) => Err(PackError::Type("__repeat__".to_string())),
    }
}

/// Whether a `flags` member or the field under a flag bit is on, so its bit is set. `wrote` is
/// what pack has written in the scope so far.
pub(super) fn member_on(
    field: &Field,
    values: &Values,
    wrote: &Written<'_>,
    form: Form,
) -> Result<bool, PackError> {
    match &field.kind {
        FieldKind::Group { name, members, .. } => group_on(name, members, values, wrote, form),
        FieldKind::FlagBit { inner, .. } => member_on(inner, values, wrote, form),
        FieldKind::Flags { name, members, .. } => {
            if present(values, name) {
                return Ok(true);
            }
            any_member_on(members, values, wrote, form)
        }
        FieldKind::U2 { names } => Ok(names.iter().any(|n| present(values, n))),
        FieldKind::When {
            field: tested,
            expect,
            members,
            ..
        } => when_on(tested, expect, members, values, wrote, form),
        FieldKind::Times {
            anchor,
            count,
            members,
            ..
        } => times_on(*anchor, count, members, values, wrote, form),
        FieldKind::Repeat {
            anchor, members, ..
        } => repeat_on(*anchor, members, values, form),
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
///
/// When another member of the bit holds a value that does not wait for a late source (see
/// `early_on`), the bit is set anyway and the late `when` or `times` of its body is written
/// where the walk reaches it, so nothing is dropped and nothing is refused (AZ-2385). Returns
/// whether the bit is set that way; a body held only by late members is still refused.
pub(super) fn check_split_bit(
    field: &Field,
    values: &Values,
    wrote: &Written<'_>,
) -> Result<bool, PackError> {
    let early = early_on(field, values, wrote)?;
    check_bit(field, values, wrote, early)?;
    Ok(early)
}

fn check_bit(
    field: &Field,
    values: &Values,
    wrote: &Written<'_>,
    early: bool,
) -> Result<(), PackError> {
    match &field.kind {
        FieldKind::FlagBit { inner, .. } => check_bit(inner, values, wrote, early),
        FieldKind::Flags { members, .. } | FieldKind::Group { members, .. } => members
            .iter()
            .try_for_each(|m| check_bit(m, values, wrote, early)),
        FieldKind::When {
            field: tested,
            expect,
            members,
            ..
        } => {
            if wrote.get(tested).is_some_and(|v| when_matches(v, expect)) {
                return members
                    .iter()
                    .try_for_each(|m| check_bit(m, values, wrote, early));
            }
            if early || wrote.get(tested).is_some() {
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
            // An empty list holds no value: the bit is clear and nothing is dropped.
            let given = match values.get(rounds.as_ref()) {
                Some(Some(Value::Groups(g))) if !g.is_empty() => Some(rounds.to_string()),
                _ => given_name(members, values, true),
            };
            match given.filter(|_| !early) {
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

/// Whether a member of the bit holds a value that decides the bit now, without waiting for a
/// source written after the flag byte: `member_on` with a `when` whose source is not written yet,
/// and a `times` whose count is not written yet, counted as holding nothing (they are late).
fn early_on(
    field: &Field,
    values: &Values,
    wrote: &Written<'_>,
) -> Result<bool, PackError> {
    match &field.kind {
        FieldKind::FlagBit { inner, .. } => early_on(inner, values, wrote),
        FieldKind::Group { name, members, .. } => {
            if members.is_empty() {
                return bool_on(values, name);
            }
            if present(values, name) {
                return Ok(true);
            }
            any_early(members, values, wrote)
        }
        FieldKind::Flags { name, members, .. } => {
            if present(values, name) {
                return Ok(true);
            }
            any_early(members, values, wrote)
        }
        FieldKind::When {
            field: tested,
            expect,
            members,
            ..
        } => {
            if wrote.get(tested).is_some_and(|v| when_matches(v, expect)) {
                any_early(members, values, wrote)
            } else {
                Ok(false)
            }
        }
        FieldKind::Times { count, .. } if wrote.get(count).is_none() => Ok(false),
        _ => member_on(field, values, wrote, Form::Split),
    }
}

fn any_early(members: &[Field], values: &Values, wrote: &Written<'_>) -> Result<bool, PackError> {
    for member in members {
        if !matches!(member.kind, FieldKind::FlagByte { .. }) && early_on(member, values, wrote)? {
            return Ok(true);
        }
    }
    Ok(false)
}

/// A clear flag bit (combined `flags` or split) whose field holds a `times`, `bits`, `packed` or
/// `sized` that no field wrote the count of, though the row gives it above 0 (after the `packed`
/// bias): that is what a clear `when` holding the count leaves, so the member reads nothing and the
/// count the row gives would mean nothing. Refused, naming the first member of the round for a
/// `times` and the member itself for the others. The scope is the field itself or what it reaches
/// through groups, `flags`, flag bits and a `when` whose condition holds. A count of 0, a count left
/// out and a count some field wrote are not refused. `wrote` is what pack has written so far in the
/// scope, so a count written after the flag byte but before the bit counts as written.
pub(super) fn refuse_unwritten_count(
    field: &Field,
    values: &Values,
    wrote: &Written<'_>,
) -> Result<(), PackError> {
    match &field.kind {
        FieldKind::Times {
            anchor,
            count,
            members,
            ..
        } => refuse_count(
            &round_member("times", *anchor, members),
            count,
            "its times reads no round",
            0,
            values,
            wrote,
        ),
        FieldKind::Bits { name, count } | FieldKind::Sized { name, count } => {
            refuse_count(name, count, "the member reads nothing", 0, values, wrote)
        }
        FieldKind::Packed {
            name, count, bias, ..
        } => refuse_count(name, count, "the member reads nothing", *bias, values, wrote),
        FieldKind::When {
            field: tested,
            expect,
            members,
            ..
        } => {
            if !wrote.get(tested).is_some_and(|v| when_matches(v, expect)) {
                return Ok(());
            }
            members
                .iter()
                .try_for_each(|m| refuse_unwritten_count(m, values, wrote))
        }
        FieldKind::Group { members, .. } | FieldKind::Flags { members, .. } => members
            .iter()
            .try_for_each(|m| refuse_unwritten_count(m, values, wrote)),
        FieldKind::FlagBit { inner, .. } => refuse_unwritten_count(inner, values, wrote),
        _ => Ok(()),
    }
}

fn refuse_count(
    member: &str,
    count: &str,
    reads: &str,
    bias: i8,
    values: &Values,
    wrote: &Written<'_>,
) -> Result<(), PackError> {
    if wrote.get(count).is_some() {
        return Ok(());
    }
    match values.get(count) {
        Some(Some(v)) => match as_usize(v) {
            Some(n) if i64::try_from(n).is_ok_and(|n| n + i64::from(bias) > 0) => {
                Err(PackError::Type(format!(
                    "{member}: the count {count} is {n} in the row, but no field wrote it (the \
                     when that holds it is clear), so {reads}; give the count 0, leave it out, \
                     or make the when hold"
                )))
            }
            _ => Ok(()),
        },
        _ => Ok(()),
    }
}

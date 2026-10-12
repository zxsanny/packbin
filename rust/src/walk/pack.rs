use super::flag_bits::{
    check_split_bit, collect_flag_bits, member_on, refuse_unwritten_count, FlagInners, Form,
};
use super::pack_out::{flags_byte_name, round_member, write_float, write_int, PackOut};
use super::times::{
    check_aligned, check_lists, check_longer, check_repeat_cap, check_repeat_lists,
    check_round_cap, rounds_mismatch, slice_times,
};
use super::written::{borrowed_count, written, Written};
use crate::field::{field_name, times_name, Field, FieldKind, MapScheme};
use crate::value::{
    as_bit, as_packed, as_u2, as_usize, name_of, when_matches, Name, PackError, Value, Values,
};
use std::borrow::Cow;
use std::collections::HashMap;

fn require<'a>(values: &'a Values, name: &str) -> Result<&'a Value, PackError> {
    match values.get(name) {
        Some(Some(v)) => Ok(v),
        _ => Err(PackError::Missing(name.to_string())),
    }
}

fn packed_bytes(width: u8, count: usize) -> usize {
    (count * width as usize).div_ceil(8)
}

/// Packs one round and returns what it wrote.
fn pack_round<'r>(
    members: &[Field],
    round: &'r Values,
    out: &mut PackOut,
) -> Result<Written<'r>, PackError> {
    let mut inners = FlagInners::new();
    collect_flag_bits(members, &mut inners);
    let mut wrote = Written::new();
    pack_fields(members, round, &inners, &mut wrote, out)?;
    Ok(wrote)
}

/// One list per name the rounds of a `times` wrote, with an item for every round that wrote it,
/// and the round that last added to it (counted from 1).
#[derive(Default)]
struct RoundLists(HashMap<Name, (usize, Vec<Value>)>);

impl RoundLists {
    /// A name written twice in one round keeps the later value, as in the values unpack builds.
    fn add(&mut self, round: usize, wrote: &Written<'_>) {
        for (name, value) in &wrote.items {
            let (last, items) = self.0.entry(name.clone()).or_default();
            if *last == round + 1 {
                items.pop();
            }
            items.push((**value).clone());
            *last = round + 1;
        }
    }

    /// Unpack gives the scope around a `times` these lists in place of what it held under those
    /// names, so a later `when` or count on one finds a list.
    fn leave_in(self, wrote: &mut Written<'_>) {
        for (name, (_, items)) in self.0 {
            wrote.insert(&name, Cow::Owned(Value::List(items)));
        }
    }
}

fn pack_fields<'v>(
    fields: &[Field],
    values: &'v Values,
    inners: &FlagInners<'_>,
    wrote: &mut Written<'v>,
    out: &mut PackOut,
) -> Result<(), PackError> {
    for field in fields {
        pack_one(field, values, inners, wrote, out)?;
    }
    Ok(())
}

fn pack_one<'v>(
    field: &Field,
    values: &'v Values,
    inners: &FlagInners<'_>,
    wrote: &mut Written<'v>,
    out: &mut PackOut,
) -> Result<(), PackError> {
    match &field.kind {
        FieldKind::Int {
            name,
            kind,
            big_endian,
        } => {
            let v = require(values, name)?;
            write_int(out, name, *kind, *big_endian, v)?;
            wrote.insert(name, Cow::Borrowed(v));
            Ok(())
        }
        FieldKind::Float {
            name,
            kind,
            big_endian,
        } => {
            let v = require(values, name)?;
            write_float(out, name, *kind, *big_endian, v)?;
            wrote.insert(name, Cow::Borrowed(v));
            Ok(())
        }
        FieldKind::Bytes { name, len } => {
            let v = require(values, name)?;
            match v {
                Value::Bytes(b) if b.len() == *len => {
                    out.append(name, b)?;
                    wrote.insert(name, Cow::Borrowed(v));
                    Ok(())
                }
                _ => Err(PackError::Type(name.to_string())),
            }
        }
        FieldKind::Flags { name, members, .. } => {
            let at = out.len();
            out.byte(0, || flags_byte_name(name, members))?;
            let mut bits: u8 = 0;
            for (i, member) in members.iter().enumerate() {
                if member_on(member, values, wrote, Form::Combined)? {
                    bits |= 1 << i;
                    pack_one(member, values, inners, wrote, out)?;
                } else {
                    refuse_unwritten_count(member, values, wrote)?;
                }
            }
            out.patch(at, bits);
            wrote.insert(name, Cow::Owned(Value::U8(bits)));
            Ok(())
        }
        FieldKind::FlagByte { name, slot } => {
            let mut bits: u8 = 0;
            for (bit, inner) in inners.get(slot).into_iter().flatten() {
                let early = check_split_bit(inner, values, wrote)?;
                if early || member_on(inner, values, wrote, Form::Split)? {
                    bits |= 1 << bit;
                }
            }
            wrote.set_flag_byte(*slot, bits);
            out.byte(bits, || name.to_string())?;
            wrote.insert(name, Cow::Owned(Value::U8(bits)));
            Ok(())
        }
        FieldKind::FlagBit {
            slot, bit, inner, ..
        } => {
            if wrote.flag_byte(*slot) & (1 << bit) != 0 {
                pack_one(inner, values, inners, wrote, out)
            } else {
                refuse_unwritten_count(inner, values, wrote)
            }
        }
        FieldKind::When {
            field,
            expect,
            members,
            ..
        } => {
            if wrote.get(field).is_some_and(|v| when_matches(v, expect)) {
                pack_fields(members, values, inners, wrote, out)?;
            }
            Ok(())
        }
        FieldKind::Repeat {
            anchor,
            members,
            slots,
        } => {
            let groups = match values.get("__repeat__") {
                Some(Some(Value::Groups(g))) => g.as_slice(),
                Some(Some(_)) => return Err(PackError::Type("__repeat__".to_string())),
                _ => &[],
            };
            if groups.is_empty() {
                check_repeat_lists(*anchor, members, values)?;
            }
            check_repeat_cap(*anchor, members, groups.len(), out.max_rounds)?;
            for group in groups {
                out.start_round(*slots, || round_member("repeat", *anchor, members))?;
                pack_round(members, group, out)?;
            }
            Ok(())
        }
        FieldKind::Group { name, members, .. } => {
            if members.is_empty() {
                wrote.insert(name, Cow::Owned(Value::U8(1)));
            }
            pack_fields(members, values, inners, wrote, out)
        }
        FieldKind::Sized { name, count } => {
            let n = as_usize(written(wrote, count)?)
                .ok_or_else(|| PackError::Type(count.to_string()))?;
            let v = require(values, name)?;
            match v {
                Value::Bytes(b) if b.len() == n => {
                    out.append(name, b)?;
                    wrote.insert(name, Cow::Borrowed(v));
                    Ok(())
                }
                _ => Err(PackError::Type(name.to_string())),
            }
        }
        FieldKind::U2 { names } => {
            let nbytes = names.len().div_ceil(4);
            let mut raw = vec![0u8; nbytes];
            for (i, name) in names.iter().enumerate() {
                let v = require(values, name)?;
                let n = as_u2(v).ok_or_else(|| PackError::Type(name.to_string()))?;
                raw[i / 4] |= n << ((i % 4) * 2);
                wrote.insert(name, Cow::Borrowed(v));
            }
            let first = names.first().map_or("u2", |n| n.as_ref());
            out.append(first, &raw)?;
            Ok(())
        }
        FieldKind::Bits { name, count } => {
            let n = as_usize(written(wrote, count)?)
                .ok_or_else(|| PackError::Type(count.to_string()))?;
            let v = require(values, name)?;
            match v {
                Value::List(items) if items.len() == n => {
                    let nbytes = n.div_ceil(8);
                    let mut packed = vec![0u8; nbytes];
                    for (i, item) in items.iter().enumerate() {
                        let bit = as_bit(item).ok_or_else(|| PackError::Type(name.to_string()))?;
                        packed[i / 8] |= bit << (i % 8);
                    }
                    out.append(name, &packed)?;
                    wrote.insert(name, Cow::Borrowed(v));
                    Ok(())
                }
                _ => Err(PackError::Type(name.to_string())),
            }
        }
        FieldKind::Packed {
            name,
            count,
            width,
            bias,
        } => {
            let n = borrowed_count(wrote, count, *bias, name)?;
            let v = require(values, name)?;
            match v {
                Value::List(items) if items.len() == n => {
                    let max = if *width == 2 { 3 } else { 1 };
                    let shift = if *width == 2 { 2 } else { 1 };
                    let per = if *width == 2 { 4 } else { 8 };
                    let mut packed = vec![0u8; packed_bytes(*width, n)];
                    for (i, item) in items.iter().enumerate() {
                        let slot = as_packed(item, max)
                            .ok_or_else(|| PackError::Type(name.to_string()))?;
                        packed[i / per] |= slot << ((i % per) * shift);
                    }
                    out.append(name, &packed)?;
                    wrote.insert(name, Cow::Borrowed(v));
                    Ok(())
                }
                _ => Err(PackError::Type(name.to_string())),
            }
        }
        FieldKind::Times {
            anchor,
            count,
            members,
            slots,
        } => {
            let n = borrowed_count(wrote, count, 0, "times")?;
            check_round_cap(*anchor, count, members, n, out.max_rounds)?;
            let key = times_name(*anchor);
            match values.get(key.as_ref()) {
                Some(Some(Value::Groups(rounds))) => {
                    if rounds.len() != n {
                        return Err(rounds_mismatch(*anchor, n, rounds.len()));
                    }
                    check_lists(*anchor, members, rounds, values)?;
                    let mut lists = RoundLists::default();
                    for (i, round) in rounds.iter().enumerate() {
                        out.start_round(*slots, || round_member("times", *anchor, members))?;
                        lists.add(i, &pack_round(members, round, out)?);
                    }
                    lists.leave_in(wrote);
                }
                Some(Some(_)) => return Err(PackError::Type(key.to_string())),
                _ => {
                    check_aligned(*anchor, members, values)?;
                    check_longer(*anchor, members, values, n)?;
                    let mut lists = RoundLists::default();
                    for i in 0..n {
                        out.start_round(*slots, || round_member("times", *anchor, members))?;
                        let round = slice_times(*anchor, members, values, i)?;
                        lists.add(i, &pack_round(members, &round, out)?);
                    }
                    lists.leave_in(wrote);
                }
            }
            Ok(())
        }
        FieldKind::Utf8 { name } => {
            let v = require(values, name)?;
            match v {
                Value::Str(text) => {
                    let raw = text.as_bytes();
                    if raw.len() > 65535 {
                        return Err(PackError::Type(name.to_string()));
                    }
                    out.admit(2 + raw.len(), || name.to_string())?;
                    out.raw(&(raw.len() as u16).to_le_bytes());
                    out.raw(raw);
                    wrote.insert(name, Cow::Borrowed(v));
                    Ok(())
                }
                _ => Err(PackError::Type(name.to_string())),
            }
        }
        FieldKind::List { name, element } => {
            let v = require(values, name)?;
            match v {
                Value::List(items) => {
                    if items.len() > 65535 {
                        return Err(PackError::Type(name.to_string()));
                    }
                    out.append(name, &(items.len() as u16).to_le_bytes())?;
                    let child =
                        field_name(element).ok_or_else(|| PackError::Type(name.to_string()))?;
                    for item in items {
                        let mut slice = Values::new();
                        slice.insert(name_of(child), Some(item.clone()));
                        let mut elem_wrote = Written::unread();
                        let one = std::slice::from_ref(&**element);
                        pack_fields(one, &slice, inners, &mut elem_wrote, out)?;
                    }
                    wrote.insert(name, Cow::Borrowed(v));
                    Ok(())
                }
                _ => Err(PackError::Type(name.to_string())),
            }
        }
        FieldKind::Dict { name, element } => {
            let v = require(values, name)?;
            match v {
                Value::Map(map) => {
                    if map.len() > 65535 {
                        return Err(PackError::Type(name.to_string()));
                    }
                    out.append(name, &(map.len() as u16).to_le_bytes())?;
                    let child =
                        field_name(element).ok_or_else(|| PackError::Type(name.to_string()))?;
                    for (key, item) in map {
                        let raw = key.as_bytes();
                        if raw.len() > 65535 {
                            return Err(PackError::Type(name.to_string()));
                        }
                        out.admit(2 + raw.len(), || name.to_string())?;
                        out.raw(&(raw.len() as u16).to_le_bytes());
                        out.raw(raw);
                        let mut slice = Values::new();
                        slice.insert(name_of(child), Some(item.clone()));
                        let mut elem_wrote = Written::unread();
                        let one = std::slice::from_ref(&**element);
                        pack_fields(one, &slice, inners, &mut elem_wrote, out)?;
                    }
                    wrote.insert(name, Cow::Borrowed(v));
                    Ok(())
                }
                _ => Err(PackError::Type(name.to_string())),
            }
        }
    }
}

pub fn pack(scheme: &MapScheme, values: &Values) -> Result<Vec<u8>, PackError> {
    let mut inners = FlagInners::new();
    collect_flag_bits(&scheme.fields, &mut inners);
    let mut out = PackOut::new(scheme);
    pack_fields(
        &scheme.fields,
        values,
        &inners,
        &mut Written::new(),
        &mut out,
    )?;
    Ok(out.into_bytes())
}

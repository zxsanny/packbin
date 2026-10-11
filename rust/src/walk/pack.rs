use super::flag_bits::{collect_flag_bits, member_on, FlagInners};
use super::times::{check_aligned, check_lists, check_longer, rounds_mismatch, slice_times};
use super::written::{borrowed_count, written, Written};
use crate::field::{field_name, times_name, Field, FieldKind, FloatKind, IntKind, MapScheme};
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
    out: &mut Vec<u8>,
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

fn write_bytes(out: &mut Vec<u8>, bytes: &[u8], big_endian: bool) {
    if big_endian {
        out.extend(bytes.iter().rev().copied());
    } else {
        out.extend_from_slice(bytes);
    }
}

fn write_int(out: &mut Vec<u8>, kind: IntKind, be: bool, value: &Value) -> Result<(), PackError> {
    match (kind, value) {
        (IntKind::U8, Value::U8(v)) => out.push(*v),
        (IntKind::U16, Value::U16(v)) => write_bytes(out, &v.to_le_bytes(), be),
        (IntKind::U32, Value::U32(v)) => write_bytes(out, &v.to_le_bytes(), be),
        (IntKind::U64, Value::U64(v)) => write_bytes(out, &v.to_le_bytes(), be),
        (IntKind::I8, Value::I8(v)) => out.push(*v as u8),
        (IntKind::I16, Value::I16(v)) => write_bytes(out, &v.to_le_bytes(), be),
        (IntKind::I32, Value::I32(v)) => write_bytes(out, &v.to_le_bytes(), be),
        (IntKind::I64, Value::I64(v)) => write_bytes(out, &v.to_le_bytes(), be),
        _ => return Err(PackError::Type("int".into())),
    }
    Ok(())
}

fn write_float(
    out: &mut Vec<u8>,
    kind: FloatKind,
    be: bool,
    value: &Value,
) -> Result<(), PackError> {
    match (kind, value) {
        (FloatKind::F32, Value::F32(v)) => write_bytes(out, &v.to_le_bytes(), be),
        (FloatKind::F64, Value::F64(v)) => write_bytes(out, &v.to_le_bytes(), be),
        _ => return Err(PackError::Type("float".into())),
    }
    Ok(())
}

fn pack_fields<'v>(
    fields: &[Field],
    values: &'v Values,
    inners: &FlagInners<'_>,
    wrote: &mut Written<'v>,
    out: &mut Vec<u8>,
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
    out: &mut Vec<u8>,
) -> Result<(), PackError> {
    match &field.kind {
        FieldKind::Int {
            name,
            kind,
            big_endian,
        } => {
            let v = require(values, name)?;
            write_int(out, *kind, *big_endian, v)?;
            wrote.insert(name, Cow::Borrowed(v));
            Ok(())
        }
        FieldKind::Float {
            name,
            kind,
            big_endian,
        } => {
            let v = require(values, name)?;
            write_float(out, *kind, *big_endian, v)?;
            wrote.insert(name, Cow::Borrowed(v));
            Ok(())
        }
        FieldKind::Bytes { name, len } => {
            let v = require(values, name)?;
            match v {
                Value::Bytes(b) if b.len() == *len => {
                    out.extend_from_slice(b);
                    wrote.insert(name, Cow::Borrowed(v));
                    Ok(())
                }
                _ => Err(PackError::Type(name.to_string())),
            }
        }
        FieldKind::Flags { name, members, .. } => {
            let at = out.len();
            out.push(0);
            let mut bits: u8 = 0;
            for (i, member) in members.iter().enumerate() {
                if member_on(member, values, wrote)? {
                    bits |= 1 << i;
                    pack_one(member, values, inners, wrote, out)?;
                }
            }
            out[at] = bits;
            wrote.insert(name, Cow::Owned(Value::U8(bits)));
            Ok(())
        }
        FieldKind::FlagByte { name, slot } => {
            let mut bits: u8 = 0;
            for (bit, inner) in inners.get(slot).into_iter().flatten() {
                if member_on(inner, values, wrote)? {
                    bits |= 1 << bit;
                }
            }
            wrote.set_flag_byte(*slot, bits);
            out.push(bits);
            wrote.insert(name, Cow::Owned(Value::U8(bits)));
            Ok(())
        }
        FieldKind::FlagBit {
            slot, bit, inner, ..
        } => {
            if wrote.flag_byte(*slot) & (1 << bit) != 0 {
                pack_one(inner, values, inners, wrote, out)?;
            }
            Ok(())
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
        FieldKind::Repeat { members, .. } => {
            let groups = match values.get("__repeat__") {
                Some(Some(Value::Groups(g))) => g.as_slice(),
                Some(Some(_)) => return Err(PackError::Type("__repeat__".to_string())),
                _ => &[],
            };
            for group in groups {
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
                    out.extend_from_slice(b);
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
            out.extend_from_slice(&raw);
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
                    out.extend_from_slice(&packed);
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
                    out.extend_from_slice(&packed);
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
            ..
        } => {
            let n = borrowed_count(wrote, count, 0, "times")?;
            let key = times_name(*anchor);
            match values.get(key.as_ref()) {
                Some(Some(Value::Groups(rounds))) => {
                    if rounds.len() != n {
                        return Err(rounds_mismatch(*anchor, n, rounds.len()));
                    }
                    check_lists(*anchor, members, rounds, values)?;
                    let mut lists = RoundLists::default();
                    for (i, round) in rounds.iter().enumerate() {
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
                    let n = raw.len() as u16;
                    out.extend_from_slice(&n.to_le_bytes());
                    out.extend_from_slice(raw);
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
                    let n = items.len() as u16;
                    out.extend_from_slice(&n.to_le_bytes());
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
                    let n = map.len() as u16;
                    out.extend_from_slice(&n.to_le_bytes());
                    let child =
                        field_name(element).ok_or_else(|| PackError::Type(name.to_string()))?;
                    for (key, item) in map {
                        let raw = key.as_bytes();
                        if raw.len() > 65535 {
                            return Err(PackError::Type(name.to_string()));
                        }
                        let kn = raw.len() as u16;
                        out.extend_from_slice(&kn.to_le_bytes());
                        out.extend_from_slice(raw);
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
    let mut out = Vec::with_capacity(32);
    out.push(scheme.type_number);
    pack_fields(
        &scheme.fields,
        values,
        &inners,
        &mut Written::new(),
        &mut out,
    )?;
    Ok(out)
}

use crate::field::{field_name, Field, FieldKind, FloatKind, IntKind, MapScheme};
use crate::value::{
    as_bit, as_packed, as_u2, as_usize, name_of, present, values_eq, Name, PackError, Value, Values,
};
use std::collections::HashMap;

fn require<'a>(values: &'a Values, name: &str) -> Result<&'a Value, PackError> {
    match values.get(name) {
        Some(Some(v)) => Ok(v),
        _ => Err(PackError::Missing(name.to_string())),
    }
}

fn borrowed_count(
    values: &Values,
    count: &str,
    bias: i8,
    label: &str,
) -> Result<usize, PackError> {
    let raw = as_usize(require(values, count)?)
        .ok_or_else(|| PackError::Type(count.to_string()))?;
    let item_count = raw as i64 + bias as i64;
    if item_count < 0 {
        return Err(PackError::Type(format!("{label}: item count {item_count}")));
    }
    Ok(item_count as usize)
}

fn packed_bytes(width: u8, count: usize) -> usize {
    (count * width as usize).div_ceil(8)
}

fn slice_times(members: &[Field], values: &Values, index: usize) -> Values {
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
            Some(Some(v)) if index == 0 => {
                slice.insert(name_of(name), Some(v.clone()));
            }
            _ => {}
        }
    }
    slice
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

fn collect_flag_bits(fields: &[Field], values: &Values, out: &mut HashMap<Name, u8>) {
    for field in fields {
        match &field.kind {
            FieldKind::FlagBit { flag, bit, inner } => {
                if let Some(n) = field_name(inner) {
                    if present(values, n) {
                        *out.entry(flag.clone()).or_insert(0) |= 1 << *bit;
                    }
                }
            }
            FieldKind::Flags { members, .. }
            | FieldKind::Group { members, .. }
            | FieldKind::When { members, .. }
            | FieldKind::Repeat { members }
            | FieldKind::Times { members, .. } => collect_flag_bits(members, values, out),
            _ => {}
        }
    }
}

fn group_on(name: &str, members: &[Field], values: &Values) -> bool {
    if present(values, name) {
        return true;
    }
    for child in members {
        match &child.kind {
            FieldKind::Int { name, .. }
            | FieldKind::Float { name, .. }
            | FieldKind::Bytes { name, .. }
            | FieldKind::Utf8 { name }
            | FieldKind::List { name, .. }
            | FieldKind::Dict { name, .. } => {
                if present(values, name) {
                    return true;
                }
            }
            _ => {}
        }
    }
    false
}

fn flag_member_on(member: &Field, values: &Values) -> bool {
    match &member.kind {
        FieldKind::Group { name, members } => group_on(name, members, values),
        _ => field_name(member)
            .map(|n| present(values, n))
            .unwrap_or(false),
    }
}

pub(crate) fn pack_fields(
    fields: &[Field],
    values: &Values,
    flag_bits: &HashMap<Name, u8>,
    out: &mut Vec<u8>,
) -> Result<(), PackError> {
    for field in fields {
        pack_one(field, values, flag_bits, out)?;
    }
    Ok(())
}

fn pack_one(
    field: &Field,
    values: &Values,
    flag_bits: &HashMap<Name, u8>,
    out: &mut Vec<u8>,
) -> Result<(), PackError> {
    match &field.kind {
        FieldKind::Int {
            name,
            kind,
            big_endian,
        } => write_int(out, *kind, *big_endian, require(values, name)?),
        FieldKind::Float {
            name,
            kind,
            big_endian,
        } => write_float(out, *kind, *big_endian, require(values, name)?),
        FieldKind::Bytes { name, len } => match require(values, name)? {
            Value::Bytes(b) if b.len() == *len => {
                out.extend_from_slice(b);
                Ok(())
            }
            _ => Err(PackError::Type(name.to_string())),
        },
        FieldKind::Flags { members, .. } => {
            let mut bits: u8 = 0;
            for (i, member) in members.iter().enumerate() {
                if flag_member_on(member, values) {
                    bits |= 1 << i;
                }
            }
            out.push(bits);
            for (i, member) in members.iter().enumerate() {
                if bits & (1 << i) != 0 {
                    match &member.kind {
                        FieldKind::Group { members: g, .. } => {
                            pack_fields(g, values, flag_bits, out)?;
                        }
                        _ => pack_one(member, values, flag_bits, out)?,
                    }
                }
            }
            Ok(())
        }
        FieldKind::FlagByte { name } => {
            out.push(*flag_bits.get(name.as_ref()).unwrap_or(&0));
            Ok(())
        }
        FieldKind::FlagBit { flag, bit, inner } => {
            let bits = *flag_bits.get(flag.as_ref()).unwrap_or(&0);
            if bits & (1 << bit) != 0 {
                pack_one(inner, values, flag_bits, out)?;
            }
            Ok(())
        }
        FieldKind::When {
            field,
            expect,
            members,
        } => {
            if let Ok(v) = require(values, field) {
                if values_eq(v, expect) {
                    pack_fields(members, values, flag_bits, out)?;
                }
            }
            Ok(())
        }
        FieldKind::Repeat { members } => {
            let groups = match values.get("__repeat__") {
                Some(Some(Value::Groups(g))) => g.as_slice(),
                _ => &[],
            };
            for group in groups {
                let mut bits = HashMap::new();
                collect_flag_bits(members, group, &mut bits);
                pack_fields(members, group, &bits, out)?;
            }
            Ok(())
        }
        FieldKind::Group { members, .. } => pack_fields(members, values, flag_bits, out),
        FieldKind::Sized { name, count } => {
            let n = as_usize(require(values, count)?)
                .ok_or_else(|| PackError::Type(count.to_string()))?;
            match require(values, name)? {
                Value::Bytes(b) if b.len() == n => {
                    out.extend_from_slice(b);
                    Ok(())
                }
                _ => Err(PackError::Type(name.to_string())),
            }
        }
        FieldKind::U2 { names } => {
            let nbytes = names.len().div_ceil(4);
            let mut raw = vec![0u8; nbytes];
            for (i, name) in names.iter().enumerate() {
                let n = as_u2(require(values, name)?)
                    .ok_or_else(|| PackError::Type(name.to_string()))?;
                raw[i / 4] |= n << ((i % 4) * 2);
            }
            out.extend_from_slice(&raw);
            Ok(())
        }
        FieldKind::Bits { name, count } => {
            let n = as_usize(require(values, count)?)
                .ok_or_else(|| PackError::Type(count.to_string()))?;
            match require(values, name)? {
                Value::List(items) if items.len() == n => {
                    let nbytes = n.div_ceil(8);
                    let mut packed = vec![0u8; nbytes];
                    for (i, item) in items.iter().enumerate() {
                        let bit = as_bit(item).ok_or_else(|| PackError::Type(name.to_string()))?;
                        packed[i / 8] |= bit << (i % 8);
                    }
                    out.extend_from_slice(&packed);
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
            let n = borrowed_count(values, count, *bias, name)?;
            match require(values, name)? {
                Value::List(items) if items.len() == n => {
                    let max = if *width == 2 { 3 } else { 1 };
                    let shift = if *width == 2 { 2 } else { 1 };
                    let per = if *width == 2 { 4 } else { 8 };
                    let mut packed = vec![0u8; packed_bytes(*width, n)];
                    for (i, item) in items.iter().enumerate() {
                        let v = as_packed(item, max)
                            .ok_or_else(|| PackError::Type(name.to_string()))?;
                        packed[i / per] |= v << ((i % per) * shift);
                    }
                    out.extend_from_slice(&packed);
                    Ok(())
                }
                _ => Err(PackError::Type(name.to_string())),
            }
        }
        FieldKind::Times { count, members } => {
            let n = borrowed_count(values, count, 0, "times")?;
            for i in 0..n {
                let slice = slice_times(members, values, i);
                let mut bits = HashMap::new();
                collect_flag_bits(members, &slice, &mut bits);
                pack_fields(members, &slice, &bits, out)?;
            }
            Ok(())
        }
        FieldKind::Utf8 { name } => match require(values, name)? {
            Value::Str(text) => {
                let raw = text.as_bytes();
                if raw.len() > 65535 {
                    return Err(PackError::Type(name.to_string()));
                }
                let n = raw.len() as u16;
                out.extend_from_slice(&n.to_le_bytes());
                out.extend_from_slice(raw);
                Ok(())
            }
            _ => Err(PackError::Type(name.to_string())),
        },
        FieldKind::List { name, element } => match require(values, name)? {
            Value::List(items) => {
                if items.len() > 65535 {
                    return Err(PackError::Type(name.to_string()));
                }
                let n = items.len() as u16;
                out.extend_from_slice(&n.to_le_bytes());
                let child = field_name(element).ok_or_else(|| PackError::Type(name.to_string()))?;
                for item in items {
                    let mut slice = Values::new();
                    slice.insert(crate::value::name_of(child), Some(item.clone()));
                    pack_fields(std::slice::from_ref(element), &slice, flag_bits, out)?;
                }
                Ok(())
            }
            _ => Err(PackError::Type(name.to_string())),
        },
        FieldKind::Dict { name, element } => match require(values, name)? {
            Value::Map(map) => {
                if map.len() > 65535 {
                    return Err(PackError::Type(name.to_string()));
                }
                let n = map.len() as u16;
                out.extend_from_slice(&n.to_le_bytes());
                let child = field_name(element).ok_or_else(|| PackError::Type(name.to_string()))?;
                for (key, item) in map {
                    let raw = key.as_bytes();
                    if raw.len() > 65535 {
                        return Err(PackError::Type(name.to_string()));
                    }
                    let kn = raw.len() as u16;
                    out.extend_from_slice(&kn.to_le_bytes());
                    out.extend_from_slice(raw);
                    let mut slice = Values::new();
                    slice.insert(crate::value::name_of(child), Some(item.clone()));
                    pack_fields(std::slice::from_ref(element), &slice, flag_bits, out)?;
                }
                Ok(())
            }
            _ => Err(PackError::Type(name.to_string())),
        },
    }
}

pub fn pack(scheme: &MapScheme, values: &Values) -> Result<Vec<u8>, PackError> {
    let flag_bits = if scheme.has_split_flags {
        let mut bits = HashMap::new();
        collect_flag_bits(&scheme.fields, values, &mut bits);
        bits
    } else {
        HashMap::new()
    };
    let mut out = Vec::with_capacity(32);
    out.push(scheme.type_number);
    pack_fields(&scheme.fields, values, &flag_bits, &mut out)?;
    Ok(out)
}

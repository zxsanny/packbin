use crate::field::{field_name, Field, FieldKind, FloatKind, IntKind, MapScheme};
use crate::value::{
    as_bit, as_u2, as_usize, present, values_eq, Name, PackError, Value, Values,
};
use std::collections::HashMap;

fn require<'a>(values: &'a Values, name: &str) -> Result<&'a Value, PackError> {
    match values.get(name) {
        Some(Some(v)) => Ok(v),
        _ => Err(PackError::Missing(name.to_string())),
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

fn write_float(out: &mut Vec<u8>, kind: FloatKind, be: bool, value: &Value) -> Result<(), PackError> {
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
            | FieldKind::Repeat { members } => collect_flag_bits(members, values, out),
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

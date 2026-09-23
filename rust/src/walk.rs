use crate::field::{
    field_name, float_width, int_width, Field, FieldKind, FloatKind, IntKind, Packet,
};
use crate::value::{
    as_bit, as_u2, as_usize, name_of, present, values_eq, Name, PackError, ShortPacket, UnpackError,
    Value, Values,
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

fn pack_fields(
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
            let n = as_usize(require(values, count)?).ok_or_else(|| PackError::Type(count.to_string()))?;
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
                let n = as_u2(require(values, name)?).ok_or_else(|| PackError::Type(name.to_string()))?;
                raw[i / 4] |= n << ((i % 4) * 2);
            }
            out.extend_from_slice(&raw);
            Ok(())
        }
        FieldKind::Bits { name, count } => {
            let n = as_usize(require(values, count)?).ok_or_else(|| PackError::Type(count.to_string()))?;
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
                    slice.insert(name_of(child), Some(item.clone()));
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
                    slice.insert(name_of(child), Some(item.clone()));
                    pack_fields(std::slice::from_ref(element), &slice, flag_bits, out)?;
                }
                Ok(())
            }
            _ => Err(PackError::Type(name.to_string())),
        },
    }
}

pub fn pack(packet: &Packet, values: &Values) -> Result<Vec<u8>, PackError> {
    let flag_bits = if packet.has_split_flags {
        let mut bits = HashMap::new();
        collect_flag_bits(&packet.fields, values, &mut bits);
        bits
    } else {
        HashMap::new()
    };
    let mut out = Vec::with_capacity(32);
    pack_fields(&packet.fields, values, &flag_bits, &mut out)?;
    Ok(out)
}

struct Cursor<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> Cursor<'a> {
    fn left(&self) -> usize {
        self.data.len().saturating_sub(self.pos)
    }

    fn take(&mut self, n: usize, field: &str) -> Result<&'a [u8], UnpackError> {
        let left = self.left();
        if left < n {
            return Err(UnpackError::Short(ShortPacket {
                field: field.to_string(),
                needed: n,
                left,
            }));
        }
        let start = self.pos;
        self.pos += n;
        Ok(&self.data[start..self.pos])
    }
}

fn le_buf(raw: &[u8], be: bool) -> [u8; 8] {
    let mut buf = [0u8; 8];
    if be {
        for (i, b) in raw.iter().rev().enumerate() {
            buf[i] = *b;
        }
    } else {
        buf[..raw.len()].copy_from_slice(raw);
    }
    buf
}

fn read_int(cur: &mut Cursor<'_>, name: &str, kind: IntKind, be: bool) -> Result<Value, UnpackError> {
    let n = int_width(kind);
    let raw = cur.take(n, name)?;
    let buf = le_buf(raw, be);
    Ok(match kind {
        IntKind::U8 => Value::U8(buf[0]),
        IntKind::U16 => Value::U16(u16::from_le_bytes([buf[0], buf[1]])),
        IntKind::U32 => Value::U32(u32::from_le_bytes([buf[0], buf[1], buf[2], buf[3]])),
        IntKind::U64 => Value::U64(u64::from_le_bytes(buf)),
        IntKind::I8 => Value::I8(buf[0] as i8),
        IntKind::I16 => Value::I16(i16::from_le_bytes([buf[0], buf[1]])),
        IntKind::I32 => Value::I32(i32::from_le_bytes([buf[0], buf[1], buf[2], buf[3]])),
        IntKind::I64 => Value::I64(i64::from_le_bytes(buf)),
    })
}

fn read_float(
    cur: &mut Cursor<'_>,
    name: &str,
    kind: FloatKind,
    be: bool,
) -> Result<Value, UnpackError> {
    let n = float_width(kind);
    let raw = cur.take(n, name)?;
    let buf = le_buf(raw, be);
    Ok(match kind {
        FloatKind::F32 => Value::F32(f32::from_le_bytes([buf[0], buf[1], buf[2], buf[3]])),
        FloatKind::F64 => Value::F64(f64::from_le_bytes(buf)),
    })
}

fn unpack_fields(
    fields: &[Field],
    cur: &mut Cursor<'_>,
    values: &mut Values,
    flag_bits: &mut HashMap<Name, u8>,
    groups: &mut Vec<Values>,
) -> Result<(), UnpackError> {
    for field in fields {
        unpack_one(field, cur, values, flag_bits, groups)?;
    }
    Ok(())
}

fn unpack_one(
    field: &Field,
    cur: &mut Cursor<'_>,
    values: &mut Values,
    flag_bits: &mut HashMap<Name, u8>,
    groups: &mut Vec<Values>,
) -> Result<(), UnpackError> {
    match &field.kind {
        FieldKind::Int {
            name,
            kind,
            big_endian,
        } => {
            let v = read_int(cur, name, *kind, *big_endian)?;
            values.insert(name.clone(), Some(v));
        }
        FieldKind::Float {
            name,
            kind,
            big_endian,
        } => {
            let v = read_float(cur, name, *kind, *big_endian)?;
            values.insert(name.clone(), Some(v));
        }
        FieldKind::Bytes { name, len } => {
            let raw = cur.take(*len, name)?;
            values.insert(name.clone(), Some(Value::Bytes(raw.to_vec())));
        }
        FieldKind::Flags { name, members } => {
            let bits = match read_int(cur, name, IntKind::U8, false)? {
                Value::U8(b) => b,
                _ => 0,
            };
            values.insert(name.clone(), Some(Value::U8(bits)));
            for (i, member) in members.iter().enumerate() {
                if bits & (1 << i) != 0 {
                    match &member.kind {
                        FieldKind::Group {
                            name: gname,
                            members: g,
                        } => {
                            if g.is_empty() {
                                values.insert(gname.clone(), Some(Value::U8(1)));
                            }
                            unpack_fields(g, cur, values, flag_bits, groups)?;
                        }
                        _ => unpack_one(member, cur, values, flag_bits, groups)?,
                    }
                }
            }
        }
        FieldKind::FlagByte { name } => {
            let bits = match read_int(cur, name, IntKind::U8, false)? {
                Value::U8(b) => b,
                _ => 0,
            };
            flag_bits.insert(name.clone(), bits);
            values.insert(name.clone(), Some(Value::U8(bits)));
        }
        FieldKind::FlagBit { flag, bit, inner } => {
            let bits = *flag_bits.get(flag.as_ref()).unwrap_or(&0);
            if bits & (1 << bit) != 0 {
                unpack_one(inner, cur, values, flag_bits, groups)?;
            }
        }
        FieldKind::When {
            field,
            expect,
            members,
        } => {
            if let Some(Some(v)) = values.get(field.as_ref()) {
                if values_eq(v, expect) {
                    unpack_fields(members, cur, values, flag_bits, groups)?;
                }
            }
        }
        FieldKind::Repeat { members } => {
            while cur.left() > 0 {
                let mut group = Values::with_capacity(members.len());
                let mut group_flags = HashMap::new();
                let mut nested_groups = Vec::new();
                unpack_fields(members, cur, &mut group, &mut group_flags, &mut nested_groups)?;
                groups.push(group);
            }
        }
        FieldKind::Group { members, .. } => {
            unpack_fields(members, cur, values, flag_bits, groups)?;
        }
        FieldKind::Sized { name, count } => {
            let n = match values.get(count.as_ref()) {
                Some(Some(v)) => as_usize(v).ok_or_else(|| {
                    UnpackError::Short(ShortPacket {
                        field: name.to_string(),
                        needed: 0,
                        left: cur.left(),
                    })
                })?,
                _ => {
                    return Err(UnpackError::Short(ShortPacket {
                        field: name.to_string(),
                        needed: 0,
                        left: cur.left(),
                    }))
                }
            };
            let raw = cur.take(n, name)?;
            values.insert(name.clone(), Some(Value::Bytes(raw.to_vec())));
        }
        FieldKind::U2 { names } => {
            let nbytes = names.len().div_ceil(4);
            let err_field = names.first().map(|n| n.as_ref()).unwrap_or("u2");
            let raw = cur.take(nbytes, err_field)?;
            for (i, name) in names.iter().enumerate() {
                let v = (raw[i / 4] >> ((i % 4) * 2)) & 3;
                values.insert(name.clone(), Some(Value::U8(v)));
            }
        }
        FieldKind::Bits { name, count } => {
            let n = match values.get(count.as_ref()) {
                Some(Some(v)) => as_usize(v).ok_or_else(|| {
                    UnpackError::Short(ShortPacket {
                        field: name.to_string(),
                        needed: 0,
                        left: cur.left(),
                    })
                })?,
                _ => {
                    return Err(UnpackError::Short(ShortPacket {
                        field: name.to_string(),
                        needed: 0,
                        left: cur.left(),
                    }))
                }
            };
            let nbytes = n.div_ceil(8);
            let raw = cur.take(nbytes, name)?;
            let mut items = Vec::with_capacity(n);
            for i in 0..n {
                items.push(Value::U8((raw[i / 8] >> (i % 8)) & 1));
            }
            values.insert(name.clone(), Some(Value::List(items)));
        }
        FieldKind::Utf8 { name } => {
            let count_raw = cur.take(2, name)?;
            let count = u16::from_le_bytes([count_raw[0], count_raw[1]]) as usize;
            let raw = cur.take(count, name)?;
            let text = std::str::from_utf8(raw).map_err(|_| {
                UnpackError::Short(ShortPacket {
                    field: name.to_string(),
                    needed: count,
                    left: 0,
                })
            })?;
            values.insert(name.clone(), Some(Value::Str(text.to_string())));
        }
        FieldKind::List { name, element } => {
            let count_raw = cur.take(2, name)?;
            let count = u16::from_le_bytes([count_raw[0], count_raw[1]]) as usize;
            let child = field_name(element).unwrap_or(name);
            let mut items = Vec::with_capacity(count);
            for _ in 0..count {
                let mut one = Values::new();
                unpack_fields(std::slice::from_ref(element), cur, &mut one, flag_bits, groups)?;
                items.push(match one.remove(child) {
                    Some(Some(v)) => v,
                    _ => {
                        return Err(UnpackError::Short(ShortPacket {
                            field: name.to_string(),
                            needed: 0,
                            left: cur.left(),
                        }))
                    }
                });
            }
            values.insert(name.clone(), Some(Value::List(items)));
        }
        FieldKind::Dict { name, element } => {
            let count_raw = cur.take(2, name)?;
            let count = u16::from_le_bytes([count_raw[0], count_raw[1]]) as usize;
            let child = field_name(element).unwrap_or(name);
            let mut map = std::collections::BTreeMap::new();
            for _ in 0..count {
                let key_len_raw = cur.take(2, name)?;
                let key_len = u16::from_le_bytes([key_len_raw[0], key_len_raw[1]]) as usize;
                let key_raw = cur.take(key_len, name)?;
                let key = std::str::from_utf8(key_raw)
                    .map_err(|_| {
                        UnpackError::Short(ShortPacket {
                            field: name.to_string(),
                            needed: key_len,
                            left: 0,
                        })
                    })?
                    .to_string();
                let mut one = Values::new();
                unpack_fields(std::slice::from_ref(element), cur, &mut one, flag_bits, groups)?;
                let item = match one.remove(child) {
                    Some(Some(v)) => v,
                    _ => {
                        return Err(UnpackError::Short(ShortPacket {
                            field: name.to_string(),
                            needed: 0,
                            left: cur.left(),
                        }))
                    }
                };
                if map.contains_key(&key) {
                    return Err(UnpackError::Short(ShortPacket {
                        field: name.to_string(),
                        needed: 0,
                        left: 0,
                    }));
                }
                map.insert(key, item);
            }
            values.insert(name.clone(), Some(Value::Map(map)));
        }
    }
    Ok(())
}

pub fn unpack(packet: &Packet, bytes: &[u8]) -> Result<Values, UnpackError> {
    let mut cur = Cursor { data: bytes, pos: 0 };
    let mut values = Values::with_capacity(packet.field_count);
    let mut flag_bits = HashMap::new();
    let mut groups = Vec::new();
    unpack_fields(
        &packet.fields,
        &mut cur,
        &mut values,
        &mut flag_bits,
        &mut groups,
    )?;
    if cur.left() > 0 {
        return Err(UnpackError::Trailing { left: cur.left() });
    }
    if !groups.is_empty() {
        values.insert(name_of("__repeat__"), Some(Value::Groups(groups)));
    }
    Ok(values)
}

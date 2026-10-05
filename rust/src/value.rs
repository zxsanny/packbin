use std::collections::{BTreeMap, HashMap};
use std::rc::Rc;

pub type Name = Rc<str>;
pub type Values = HashMap<Name, Option<Value>>;

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    U8(u8),
    U16(u16),
    U32(u32),
    U64(u64),
    I8(i8),
    I16(i16),
    I32(i32),
    I64(i64),
    F32(f32),
    F64(f64),
    Bytes(Vec<u8>),
    Str(String),
    List(Vec<Value>),
    Map(BTreeMap<String, Value>),
    Groups(Vec<Values>),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ShortPacket {
    pub field: String,
    pub needed: usize,
    pub left: usize,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UnpackError {
    Short(ShortPacket),
    Trailing { left: usize },
    Type { expected: u8, actual: u8 },
    DuplicateType { type_number: u8 },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PackError {
    Missing(String),
    Type(String),
}

pub fn name_of(s: impl AsRef<str>) -> Name {
    Rc::<str>::from(s.as_ref())
}

pub fn insert(values: &mut Values, name: impl AsRef<str>, value: Option<Value>) {
    values.insert(name_of(name), value);
}

pub fn present(values: &Values, name: &str) -> bool {
    matches!(values.get(name), Some(Some(_)))
}

pub fn to_hex(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        s.push(HEX[(b >> 4) as usize] as char);
        s.push(HEX[(b & 0xf) as usize] as char);
    }
    s
}

pub fn mismatched_bytes(a: &[u8], b: &[u8]) -> usize {
    let mut mism = a.len().abs_diff(b.len());
    for i in 0..a.len().min(b.len()) {
        if a[i] != b[i] {
            mism += 1;
        }
    }
    mism
}

pub fn motion_field_count(values: &Values) -> usize {
    ["heading", "speed", "altitude", "frequency"]
        .iter()
        .filter(|n| present(values, n))
        .count()
}

pub(crate) fn as_int(v: &Value) -> Option<i128> {
    match v {
        Value::U8(n) => Some(i128::from(*n)),
        Value::U16(n) => Some(i128::from(*n)),
        Value::U32(n) => Some(i128::from(*n)),
        Value::U64(n) => Some(i128::from(*n)),
        Value::I8(n) => Some(i128::from(*n)),
        Value::I16(n) => Some(i128::from(*n)),
        Value::I32(n) => Some(i128::from(*n)),
        Value::I64(n) => Some(i128::from(*n)),
        _ => None,
    }
}

/// A `when` takes its members when both values are integers of the same number, whatever their
/// width or sign.
pub(crate) fn when_matches(source: &Value, expect: &Value) -> bool {
    matches!((as_int(source), as_int(expect)), (Some(a), Some(b)) if a == b)
}

pub(crate) fn as_usize(v: &Value) -> Option<usize> {
    match v {
        Value::U8(n) => Some(*n as usize),
        Value::U16(n) => Some(*n as usize),
        Value::U32(n) => Some(*n as usize),
        Value::U64(n) => usize::try_from(*n).ok(),
        Value::I8(n) if *n >= 0 => Some(*n as usize),
        Value::I16(n) if *n >= 0 => Some(*n as usize),
        Value::I32(n) if *n >= 0 => Some(*n as usize),
        Value::I64(n) if *n >= 0 => usize::try_from(*n).ok(),
        _ => None,
    }
}

pub(crate) fn as_u2(v: &Value) -> Option<u8> {
    let n = match v {
        Value::U8(n) => *n as i64,
        Value::U16(n) => *n as i64,
        Value::U32(n) => *n as i64,
        Value::U64(n) => *n as i64,
        Value::I8(n) => *n as i64,
        Value::I16(n) => *n as i64,
        Value::I32(n) => *n as i64,
        Value::I64(n) => *n,
        _ => return None,
    };
    if (0..=3).contains(&n) {
        Some(n as u8)
    } else {
        None
    }
}

pub(crate) fn as_bit(v: &Value) -> Option<u8> {
    match v {
        Value::U8(0)
        | Value::U16(0)
        | Value::U32(0)
        | Value::U64(0)
        | Value::I8(0)
        | Value::I16(0)
        | Value::I32(0)
        | Value::I64(0) => Some(0),
        Value::U8(1)
        | Value::U16(1)
        | Value::U32(1)
        | Value::U64(1)
        | Value::I8(1)
        | Value::I16(1)
        | Value::I32(1)
        | Value::I64(1) => Some(1),
        _ => None,
    }
}

pub(crate) fn as_packed(v: &Value, max: u8) -> Option<u8> {
    let n = match v {
        Value::U8(n) => *n as i64,
        Value::U16(n) => *n as i64,
        Value::U32(n) => *n as i64,
        Value::U64(n) => *n as i64,
        Value::I8(n) => *n as i64,
        Value::I16(n) => *n as i64,
        Value::I32(n) => *n as i64,
        Value::I64(n) => *n,
        _ => return None,
    };
    if n >= 0 && n <= max as i64 {
        Some(n as u8)
    } else {
        None
    }
}

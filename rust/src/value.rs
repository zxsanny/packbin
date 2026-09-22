use std::collections::HashMap;
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

pub fn values_eq(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::U8(x), Value::U8(y)) => x == y,
        (Value::U16(x), Value::U16(y)) => x == y,
        (Value::U32(x), Value::U32(y)) => x == y,
        (Value::U64(x), Value::U64(y)) => x == y,
        (Value::I8(x), Value::I8(y)) => x == y,
        (Value::I16(x), Value::I16(y)) => x == y,
        (Value::I32(x), Value::I32(y)) => x == y,
        (Value::I64(x), Value::I64(y)) => x == y,
        (Value::F32(x), Value::F32(y)) => x.to_bits() == y.to_bits(),
        (Value::F64(x), Value::F64(y)) => x.to_bits() == y.to_bits(),
        (Value::Bytes(x), Value::Bytes(y)) => x == y,
        _ => false,
    }
}

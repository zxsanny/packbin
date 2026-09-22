use crate::value::{name_of, Name, Value};
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum IntKind {
    U8,
    U16,
    U32,
    U64,
    I8,
    I16,
    I32,
    I64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum FloatKind {
    F32,
    F64,
}

#[derive(Clone, Debug)]
pub(crate) enum FieldKind {
    Int {
        name: Name,
        kind: IntKind,
        big_endian: bool,
    },
    Float {
        name: Name,
        kind: FloatKind,
        big_endian: bool,
    },
    Bytes {
        name: Name,
        len: usize,
    },
    Flags {
        name: Name,
        members: Vec<Field>,
    },
    FlagByte {
        name: Name,
    },
    FlagBit {
        flag: Name,
        bit: u8,
        inner: Box<Field>,
    },
    When {
        field: Name,
        expect: Value,
        members: Vec<Field>,
    },
    Repeat {
        members: Vec<Field>,
    },
}

#[derive(Clone, Debug)]
pub struct Field {
    pub(crate) kind: FieldKind,
}

#[derive(Clone, Debug)]
pub struct Packet {
    pub(crate) fields: Vec<Field>,
    pub(crate) has_split_flags: bool,
    pub(crate) field_count: usize,
}

#[derive(Clone, Debug)]
pub struct FlagByte {
    name: Name,
    next_bit: Rc<RefCell<u8>>,
}

#[derive(Clone, Debug)]
pub struct Eq {
    pub(crate) field: Name,
    pub(crate) value: Value,
}

impl FlagByte {
    pub fn byte(&self) -> Field {
        Field {
            kind: FieldKind::FlagByte {
                name: self.name.clone(),
            },
        }
    }

    pub fn bit(&self, field: Field) -> Field {
        let bit = {
            let mut n = self.next_bit.borrow_mut();
            let b = *n;
            *n = n.saturating_add(1);
            b
        };
        Field {
            kind: FieldKind::FlagBit {
                flag: self.name.clone(),
                bit,
                inner: Box::new(field),
            },
        }
    }
}

pub fn flag_byte(name: impl AsRef<str>) -> FlagByte {
    FlagByte {
        name: name_of(name),
        next_bit: Rc::new(RefCell::new(0)),
    }
}

fn count_fields(fields: &[Field]) -> (usize, bool) {
    let mut n = 0;
    let mut split = false;
    for f in fields {
        match &f.kind {
            FieldKind::Int { .. }
            | FieldKind::Float { .. }
            | FieldKind::Bytes { .. }
            | FieldKind::FlagByte { .. } => n += 1,
            FieldKind::Flags { members, .. } => {
                n += 1 + count_fields(members).0;
            }
            FieldKind::FlagBit { inner, .. } => {
                split = true;
                n += count_fields(std::slice::from_ref(inner)).0;
            }
            FieldKind::When { members, .. } | FieldKind::Repeat { members } => {
                let (c, s) = count_fields(members);
                n += c;
                split |= s;
            }
        }
    }
    (n, split)
}

pub fn packet(fields: Vec<Field>) -> Packet {
    let (field_count, has_split_flags) = count_fields(&fields);
    Packet {
        fields,
        has_split_flags,
        field_count,
    }
}

pub fn eq(field: impl AsRef<str>, value: Value) -> Eq {
    Eq {
        field: name_of(field),
        value,
    }
}

pub fn when(cond: Eq, fields: Vec<Field>) -> Field {
    Field {
        kind: FieldKind::When {
            field: cond.field,
            expect: cond.value,
            members: fields,
        },
    }
}

pub fn repeat(fields: Vec<Field>) -> Field {
    Field {
        kind: FieldKind::Repeat { members: fields },
    }
}

pub fn flags(name: impl AsRef<str>, members: Vec<Field>) -> Field {
    Field {
        kind: FieldKind::Flags {
            name: name_of(name),
            members,
        },
    }
}

pub fn be(mut field: Field) -> Field {
    match &mut field.kind {
        FieldKind::Int { big_endian, .. } | FieldKind::Float { big_endian, .. } => {
            *big_endian = true;
        }
        FieldKind::FlagBit { inner, .. } => {
            *inner = Box::new(be((**inner).clone()));
        }
        _ => {}
    }
    field
}

fn int_field(name: Name, kind: IntKind) -> Field {
    Field {
        kind: FieldKind::Int {
            name,
            kind,
            big_endian: false,
        },
    }
}

pub fn u8(name: impl AsRef<str>) -> Field {
    int_field(name_of(name), IntKind::U8)
}
pub fn u16(name: impl AsRef<str>) -> Field {
    int_field(name_of(name), IntKind::U16)
}
pub fn u32(name: impl AsRef<str>) -> Field {
    int_field(name_of(name), IntKind::U32)
}
pub fn u64(name: impl AsRef<str>) -> Field {
    int_field(name_of(name), IntKind::U64)
}
pub fn i8(name: impl AsRef<str>) -> Field {
    int_field(name_of(name), IntKind::I8)
}
pub fn i16(name: impl AsRef<str>) -> Field {
    int_field(name_of(name), IntKind::I16)
}
pub fn i32(name: impl AsRef<str>) -> Field {
    int_field(name_of(name), IntKind::I32)
}
pub fn i64(name: impl AsRef<str>) -> Field {
    int_field(name_of(name), IntKind::I64)
}

pub fn f32(name: impl AsRef<str>) -> Field {
    Field {
        kind: FieldKind::Float {
            name: name_of(name),
            kind: FloatKind::F32,
            big_endian: false,
        },
    }
}

pub fn f64(name: impl AsRef<str>) -> Field {
    Field {
        kind: FieldKind::Float {
            name: name_of(name),
            kind: FloatKind::F64,
            big_endian: false,
        },
    }
}

pub fn bytes(name: impl AsRef<str>, n: usize) -> Field {
    Field {
        kind: FieldKind::Bytes {
            name: name_of(name),
            len: n,
        },
    }
}

pub(crate) fn int_width(kind: IntKind) -> usize {
    match kind {
        IntKind::U8 | IntKind::I8 => 1,
        IntKind::U16 | IntKind::I16 => 2,
        IntKind::U32 | IntKind::I32 => 4,
        IntKind::U64 | IntKind::I64 => 8,
    }
}

pub(crate) fn float_width(kind: FloatKind) -> usize {
    match kind {
        FloatKind::F32 => 4,
        FloatKind::F64 => 8,
    }
}

pub(crate) fn field_name(field: &Field) -> Option<&str> {
    match &field.kind {
        FieldKind::Int { name, .. }
        | FieldKind::Float { name, .. }
        | FieldKind::Bytes { name, .. }
        | FieldKind::Flags { name, .. }
        | FieldKind::FlagByte { name } => Some(name.as_ref()),
        FieldKind::FlagBit { inner, .. } => field_name(inner),
        FieldKind::When { .. } | FieldKind::Repeat { .. } => None,
    }
}

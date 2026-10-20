use super::error::{Error, Fault};

/// The most fields a scheme may have: ids run from 0 to 32767.
pub const MAX_FIELDS: usize = 32768;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    U8,
    U16,
    U32,
    U64,
    I8,
    I16,
    I32,
    I64,
    F32,
    F64,
    /// Fixed-length bytes; `Field::size` is the length.
    Bytes,
}

impl Kind {
    /// Bytes on the wire, or `None` for [`Kind::Bytes`] (its length is the field's).
    pub(crate) fn width(self) -> Option<usize> {
        match self {
            Kind::U8 | Kind::I8 => Some(1),
            Kind::U16 | Kind::I16 => Some(2),
            Kind::U32 | Kind::I32 | Kind::F32 => Some(4),
            Kind::U64 | Kind::I64 | Kind::F64 => Some(8),
            Kind::Bytes => None,
        }
    }
}

/// One field of a scheme. Build it with the functions of this module (`u16(0)`,
/// `be(i32(1))`, `bytes(2, 8)`); the `id` is its place in the scheme, 0 first.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Field {
    pub kind: Kind,
    pub id: u16,
    pub big_endian: bool,
    pub size: u16,
}

const fn leaf(kind: Kind, id: u16) -> Field {
    Field {
        kind,
        id,
        big_endian: false,
        size: 0,
    }
}

pub const fn u8(id: u16) -> Field {
    leaf(Kind::U8, id)
}
pub const fn u16(id: u16) -> Field {
    leaf(Kind::U16, id)
}
pub const fn u32(id: u16) -> Field {
    leaf(Kind::U32, id)
}
pub const fn u64(id: u16) -> Field {
    leaf(Kind::U64, id)
}
pub const fn i8(id: u16) -> Field {
    leaf(Kind::I8, id)
}
pub const fn i16(id: u16) -> Field {
    leaf(Kind::I16, id)
}
pub const fn i32(id: u16) -> Field {
    leaf(Kind::I32, id)
}
pub const fn i64(id: u16) -> Field {
    leaf(Kind::I64, id)
}
pub const fn f32(id: u16) -> Field {
    leaf(Kind::F32, id)
}
pub const fn f64(id: u16) -> Field {
    leaf(Kind::F64, id)
}

/// `n` bytes, held by the row as a slice of exactly `n`.
pub const fn bytes(id: u16, n: u16) -> Field {
    Field {
        kind: Kind::Bytes,
        id,
        big_endian: false,
        size: n,
    }
}

/// The field's number is written most significant byte first.
pub const fn be(field: Field) -> Field {
    Field {
        big_endian: true,
        ..field
    }
}

/// A packet layout: a type number (the first byte) and the fields in order.
#[derive(Clone, Copy, Debug)]
pub struct Scheme<'a> {
    pub type_number: u8,
    pub fields: &'a [Field],
}

impl<'a> Scheme<'a> {
    pub const fn new(type_number: u8, fields: &'a [Field]) -> Self {
        Scheme {
            type_number,
            fields,
        }
    }
}

/// Checks a scheme without reading or writing a byte: ids run 0, 1, 2, ... in field order (so a
/// duplicate or an id outside 0 to 32767 is refused) and a number field has no length.
/// [`pack`](super::pack) and [`unpack`](super::unpack) call it first.
pub fn validate(scheme: &Scheme<'_>) -> Result<(), Fault> {
    if scheme.fields.len() > MAX_FIELDS {
        return Err(Fault::new(Error::SchemeInvalid, 0, -1, MAX_FIELDS));
    }
    for (place, field) in scheme.fields.iter().enumerate() {
        let sized_ok = field.kind == Kind::Bytes || field.size == 0;
        if usize::from(field.id) != place || !sized_ok {
            return Err(Fault::new(
                Error::SchemeInvalid,
                place,
                i32::from(field.id),
                0,
            ));
        }
    }
    Ok(())
}

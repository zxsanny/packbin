use super::{Field, FieldKey, FieldKind, FloatKind, IntKind};
use crate::value::{name_of, Name};

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

pub fn sized(name: impl FieldKey, count_field: impl FieldKey) -> Field {
    Field {
        kind: FieldKind::Sized {
            name: name.to_name(),
            count: count_field.to_name(),
        },
    }
}

pub fn u2(names: &[&str]) -> Field {
    Field {
        kind: FieldKind::U2 {
            names: names.iter().map(name_of).collect(),
        },
    }
}

pub fn utf8(name: impl AsRef<str>) -> Field {
    Field {
        kind: FieldKind::Utf8 {
            name: name_of(name),
        },
    }
}

pub fn list(name: impl AsRef<str>, element: Field) -> Field {
    if matches!(element.kind, FieldKind::Repeat { .. }) {
        panic!("repeat is not a list element");
    }
    Field {
        kind: FieldKind::List {
            name: name_of(name),
            element: Box::new(element),
        },
    }
}

pub fn dict(name: impl AsRef<str>, element: Field) -> Field {
    if matches!(element.kind, FieldKind::Repeat { .. }) {
        panic!("repeat is not a dictionary element");
    }
    Field {
        kind: FieldKind::Dict {
            name: name_of(name),
            element: Box::new(element),
        },
    }
}

pub fn bits(name: impl FieldKey, count_field: impl FieldKey) -> Field {
    Field {
        kind: FieldKind::Bits {
            name: name.to_name(),
            count: count_field.to_name(),
        },
    }
}

pub fn packed(width: u8, name: impl FieldKey, count_field: impl FieldKey, bias: i8) -> Field {
    if width != 1 && width != 2 {
        panic!("packed width must be 1 or 2");
    }
    if bias != 0 && bias != -1 {
        panic!("packed bias must be 0 or -1");
    }
    Field {
        kind: FieldKind::Packed {
            name: name.to_name(),
            count: count_field.to_name(),
            width,
            bias,
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

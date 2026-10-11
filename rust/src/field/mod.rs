mod integrity;
mod leaf;
mod map_scheme;
mod names;
mod order;
mod shape;

pub use leaf::{
    bits, bytes, dict, f32, f64, i16, i32, i64, i8, list, packed, sized, u16, u2, u32, u64, u8,
    utf8,
};
pub(crate) use leaf::{float_width, int_width};
use map_scheme::count_fields;
pub use map_scheme::{MapScheme, DEFAULT_MAX_BYTES, DEFAULT_MAX_ROUNDS, DEFAULT_MAX_SLOTS};
pub(crate) use order::{check_order, nested_element, take_id};

use crate::value::{name_of, Name, Value};

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
        anchor: u32,
        name: Name,
        members: Vec<Field>,
    },
    /// `slot` and a bit's `slot` / `bit` are set by `MapScheme::new`: `slot` tells one read
    /// of a flag byte from another, `bit` is the bit's order among that read's bits.
    FlagByte {
        name: Name,
        slot: usize,
    },
    FlagBit {
        flag: Name,
        slot: usize,
        bit: u8,
        inner: Box<Field>,
    },
    When {
        anchor: u32,
        field: Name,
        expect: Value,
        members: Vec<Field>,
    },
    Repeat {
        anchor: u32,
        members: Vec<Field>,
        /// The slots one round adds to the unpacked values, counted once at construction.
        slots: usize,
    },
    Group {
        anchor: u32,
        name: Name,
        members: Vec<Field>,
    },
    Sized {
        name: Name,
        count: Name,
    },
    U2 {
        names: Vec<Name>,
    },
    Bits {
        name: Name,
        count: Name,
    },
    Packed {
        name: Name,
        count: Name,
        width: u8,
        bias: i8,
    },
    Times {
        anchor: u32,
        count: Name,
        members: Vec<Field>,
        /// The slots one round adds to the unpacked values, counted once at construction.
        slots: usize,
    },
    Utf8 {
        name: Name,
    },
    List {
        name: Name,
        element: Box<Field>,
    },
    Dict {
        name: Name,
        element: Box<Field>,
    },
}

#[derive(Clone, Debug)]
pub struct Field {
    pub(crate) kind: FieldKind,
}

/// A split-form flag byte. A bit belongs to the latest `byte()` of this name it can see in its
/// scope, and its position is its order among that byte's bits in the scheme, not the order
/// of `bit` calls, so one handle may build any number of schemes.
#[derive(Clone, Debug)]
pub struct FlagByte {
    name: Name,
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
                slot: 0,
            },
        }
    }

    /// `field` is written when its bit is set. The bit is set when the value is present (a
    /// `group`: any of its values); for a bool (an empty `group`) only when the value is `1`,
    /// and a bool value other than `0` or `1` fails pack with `PackError::Type`.
    pub fn bit(&self, field: Field) -> Field {
        Field {
            kind: FieldKind::FlagBit {
                flag: self.name.clone(),
                slot: 0,
                bit: 0,
                inner: Box::new(field),
            },
        }
    }
}

pub fn flag_byte(name: impl AsRef<str>) -> FlagByte {
    FlagByte {
        name: name_of(name),
    }
}

pub trait FieldKey {
    fn to_name(self) -> Name;
}

impl FieldKey for &str {
    fn to_name(self) -> Name {
        name_of(self)
    }
}

impl FieldKey for String {
    fn to_name(self) -> Name {
        name_of(self)
    }
}

impl FieldKey for u32 {
    fn to_name(self) -> Name {
        name_of(self.to_string())
    }
}

impl FieldKey for i32 {
    fn to_name(self) -> Name {
        name_of((self as u32).to_string())
    }
}

pub fn id_name(id: u32) -> Name {
    name_of(id.to_string())
}

/// The key a `times` keeps its rounds under in the values: a `Value::Groups` with one `Values` per
/// round. Its anchor tells one `times` of a scheme from another.
pub(crate) fn times_name(anchor: u32) -> Name {
    name_of(format!("__times_{anchor}"))
}

pub fn eq(field: impl FieldKey, value: Value) -> Eq {
    Eq {
        field: field.to_name(),
        value,
    }
}

pub fn when(anchor: u32, cond: Eq, fields: Vec<Field>) -> Field {
    Field {
        kind: FieldKind::When {
            anchor,
            field: cond.field,
            expect: cond.value,
            members: fields,
        },
    }
}

pub fn repeat(anchor: u32, fields: Vec<Field>) -> Field {
    Field {
        kind: FieldKind::Repeat {
            anchor,
            slots: count_fields(&fields),
            members: fields,
        },
    }
}

/// One byte with a bit per member (at most 8), then each member whose bit is set. A member
/// is on when its value is present; a bool member (an empty `group`) only when it is `1`, and
/// a bool value other than `0` or `1` fails pack with `PackError::Type`.
///
/// Members are decided in order, each against what pack has written so far in its scope. A
/// `when` member is on when its condition holds on that and its body holds a value (with the
/// condition false, a body value given is not written and is no error). A `times` member is on
/// when its count, as written, is above 0 (a count field pack skipped is no round); with count 0,
/// values given for its rounds fail pack. A `repeat` member is on when a round holds a value. A
/// member that is on but cannot be written in full fails pack naming the missing value. Unpack
/// reads the body of a set bit, and nothing for a clear one.
pub fn flags(anchor: u32, name: impl AsRef<str>, members: Vec<Field>) -> Field {
    Field {
        kind: FieldKind::Flags {
            anchor,
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

/// Fields gathered under one `flags` bit, on when its own value, or any value inside it at any
/// depth (an integer, float, bytes, utf8, list, dict, `sized`, `bits`, `packed`, `u2`, a nested
/// `group` or `flags`), or one of its flag bits is present; a `when`, `times` or `repeat` inside
/// it counts when it writes a value (see [`flags`]). With no fields it is a bool: allowed only
/// directly inside `flags` or under a flag bit, set by the value `1` (cleared by `0` or no
/// value), and unpacked as `1` when set.
pub fn group(anchor: u32, name: impl AsRef<str>, fields: Vec<Field>) -> Field {
    Field {
        kind: FieldKind::Group {
            anchor,
            name: name_of(name),
            members: fields,
        },
    }
}


/// `count_field` rounds. Pack reads the rounds from `Value::Groups` under `__times_<anchor>`, or
/// from one value per member name: a list gives one item per round, any other value is used in
/// every round, and a lone dictionary for a `dict` member fails pack (give one per round).
pub fn times(anchor: u32, count_field: impl FieldKey, fields: Vec<Field>) -> Field {
    Field {
        kind: FieldKind::Times {
            anchor,
            count: count_field.to_name(),
            slots: count_fields(&fields),
            members: fields,
        },
    }
}


/// Gives a bound `list` or `dict` the internal name its scheme assigned; the caller picks none.
pub(crate) fn rename_container(field: &mut Field, new_name: &str) {
    let (FieldKind::List { name, .. } | FieldKind::Dict { name, .. }) = &mut field.kind else {
        panic!("only a list or dict takes an internal name");
    };
    *name = name_of(new_name);
}

pub(crate) fn field_name(field: &Field) -> Option<&str> {
    match &field.kind {
        FieldKind::Int { name, .. }
        | FieldKind::Float { name, .. }
        | FieldKind::Bytes { name, .. }
        | FieldKind::Flags { name, .. }
        | FieldKind::FlagByte { name, .. }
        | FieldKind::Group { name, .. }
        | FieldKind::Sized { name, .. }
        | FieldKind::Bits { name, .. }
        | FieldKind::Packed { name, .. }
        | FieldKind::Utf8 { name }
        | FieldKind::List { name, .. }
        | FieldKind::Dict { name, .. } => Some(name.as_ref()),
        FieldKind::U2 { names } => names.first().map(|n| n.as_ref()),
        FieldKind::FlagBit { inner, .. } => field_name(inner),
        FieldKind::When { .. } | FieldKind::Repeat { .. } | FieldKind::Times { .. } => None,
    }
}

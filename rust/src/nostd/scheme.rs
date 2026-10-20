/// The most parity bytes a scheme may declare.
pub const MAX_PARITY: usize = 32;

/// The most fields a scheme may have: ids run from 0 to 32767.
pub const MAX_FIELDS: usize = 32768;

/// The id of an entry that has none: a flag byte and a flag bit.
pub const NO_ID: u16 = u16::MAX;

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
    /// A presence bit with no bytes, only inside `flags` or a flag bit.
    Bool,
    /// One byte of presence bits, then the members whose bit is set.
    Flags,
    /// A presence byte whose bits are the flag bits after it (`Field::size` is its number).
    FlagByte,
    /// One member, written when its bit of the flag byte numbered `Field::size` is set.
    FlagBit,
    /// Members written only when the field `Field::source` equals `Field::eq`.
    When,
    /// Bytes whose length is the value of the field `Field::source`.
    Sized,
    /// Two-bit values, four to a byte, low bits first: its members are `u8` fields.
    U2,
    /// The value of `Field::source` bits (0 or 1), eight to a byte, low bit first.
    Bits,
    /// The value of `Field::source` plus `Field::bias` numbers of `Field::width` bits.
    Packed,
    /// Members written one after another on the same row.
    Group,
    /// Rounds of the members until the packet ends, each into an item of the row.
    Repeat,
    /// (value of `Field::source`) rounds of the members, each into an item of the row.
    Times,
    /// A u16 item count, then the items: its one member is the element, ids from 0.
    List,
    /// A string: a varint count, then the compact payload. The row holds the UTF-8 text (needs
    /// the `text` feature). With id [`NO_ID`] it is the key of a `dict`.
    Utf8,
    /// A string kept as it is on the wire: the row holds the payload after the count, never
    /// decoded or checked, so it needs no codec.
    Utf8Wire,
    /// A u16 entry count, then per entry a string key and the element, in strictly ascending key
    /// order (needs the `text` feature). Its two members are the key (`key()`) and the element;
    /// the element's ids start from 0.
    Dict,
}

impl Kind {
    /// Bytes on the wire of a number, or `None` for another kind.
    pub(crate) fn width(self) -> Option<usize> {
        match self {
            Kind::U8 | Kind::I8 => Some(1),
            Kind::U16 | Kind::I16 => Some(2),
            Kind::U32 | Kind::I32 | Kind::F32 => Some(4),
            Kind::U64 | Kind::I64 | Kind::F64 => Some(8),
            _ => None,
        }
    }

    pub(crate) fn is_integer(self) -> bool {
        matches!(
            self,
            Kind::U8
                | Kind::U16
                | Kind::U32
                | Kind::U64
                | Kind::I8
                | Kind::I16
                | Kind::I32
                | Kind::I64
        )
    }

    /// Kinds whose entry is followed by member entries (`Field::span` above 1 is allowed).
    pub(crate) fn has_members(self) -> bool {
        matches!(
            self,
            Kind::Flags
                | Kind::FlagBit
                | Kind::When
                | Kind::U2
                | Kind::Group
                | Kind::Repeat
                | Kind::Times
                | Kind::List
                | Kind::Dict
        )
    }

    /// Kinds whose members read into items of their own (`Row::item`): a scope of their own.
    pub(crate) fn is_container(self) -> bool {
        matches!(self, Kind::Repeat | Kind::Times | Kind::List | Kind::Dict)
    }

    /// Kinds that start with a u16 item count (and charge no round).
    pub(crate) fn is_counted(self) -> bool {
        matches!(self, Kind::List | Kind::Dict)
    }
}

/// One entry of a scheme table. Members follow their parent in order; `span` counts the entry
/// and all entries below it, so the next sibling is at `index + span`. Build entries with the
/// functions of this module (`u16(0)`, `be(i32(1))`, `flags(2, 3)`); the `id` is the field's
/// order id: each field takes the next one, 0 first, and `flags`, `when`, `u2`, `group`,
/// `repeat` and `times` take the id of their first member. A flag byte and a flag bit take none
/// ([`NO_ID`]). A `list` takes the next id like a field (the row finds its items by it; the
/// other packages give a list a name only), and its element's ids start again at 0.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Field {
    pub kind: Kind,
    pub id: u16,
    pub big_endian: bool,
    /// `bytes` length; a flag byte or flag bit number (0 to 7).
    pub size: u16,
    /// This entry and the entries of its members.
    pub span: u16,
    /// The order id a `when` tests or a count (`sized`, `bits`, `packed`) reads.
    pub source: u16,
    /// The value a `when` matches.
    pub eq: i64,
    /// `packed` bit width (1 or 2).
    pub width: u8,
    /// `packed` count bias (0 or -1).
    pub bias: i8,
}

const fn entry(kind: Kind, id: u16) -> Field {
    Field {
        kind,
        id,
        big_endian: false,
        size: 0,
        span: 1,
        source: NO_ID,
        eq: 0,
        width: 0,
        bias: 0,
    }
}

const fn parent(kind: Kind, id: u16, members: u16) -> Field {
    Field {
        span: members.saturating_add(1),
        ..entry(kind, id)
    }
}

pub const fn u8(id: u16) -> Field {
    entry(Kind::U8, id)
}
pub const fn u16(id: u16) -> Field {
    entry(Kind::U16, id)
}
pub const fn u32(id: u16) -> Field {
    entry(Kind::U32, id)
}
pub const fn u64(id: u16) -> Field {
    entry(Kind::U64, id)
}
pub const fn i8(id: u16) -> Field {
    entry(Kind::I8, id)
}
pub const fn i16(id: u16) -> Field {
    entry(Kind::I16, id)
}
pub const fn i32(id: u16) -> Field {
    entry(Kind::I32, id)
}
pub const fn i64(id: u16) -> Field {
    entry(Kind::I64, id)
}
pub const fn f32(id: u16) -> Field {
    entry(Kind::F32, id)
}
pub const fn f64(id: u16) -> Field {
    entry(Kind::F64, id)
}

/// `n` bytes, held by the row as a slice of exactly `n`.
pub const fn bytes(id: u16, n: u16) -> Field {
    Field {
        size: n,
        ..entry(Kind::Bytes, id)
    }
}

/// The field's number is written most significant byte first.
pub const fn be(field: Field) -> Field {
    Field {
        big_endian: true,
        ..field
    }
}

/// A presence bit: set when [`Row::flag`](super::Row::flag) is true. Allowed only as a member of
/// `flags` or under a flag bit.
pub const fn boolean(id: u16) -> Field {
    entry(Kind::Bool, id)
}

/// One byte with a bit per member (at most 8), then each member whose bit is set: a member is on
/// when the row holds its value (a `when`: its condition holds and its body holds a value).
/// `entries` is the number of table entries after this one that belong to it.
pub const fn flags(id: u16, entries: u16) -> Field {
    parent(Kind::Flags, id, entries)
}

/// A presence byte numbered `number` (0 to 7) whose bits are the `flag_bit`s of that number after
/// it in its scope.
pub const fn flag_byte(number: u16) -> Field {
    Field {
        size: number,
        ..entry(Kind::FlagByte, NO_ID)
    }
}

/// The member that follows (`entries` table entries: 1 for a single field) is written when it
/// holds a value, and its bit is set in the latest flag byte `number` its scope can see.
pub const fn flag_bit(number: u16, entries: u16) -> Field {
    Field {
        size: number,
        ..parent(Kind::FlagBit, NO_ID, entries)
    }
}

/// The `entries` table entries after this one are on the wire only when the earlier field
/// `source` equals `value`. The id is the id of its first member.
pub const fn when(id: u16, source: u16, value: i64, entries: u16) -> Field {
    Field {
        source,
        eq: value,
        ..parent(Kind::When, id, entries)
    }
}

/// Bytes whose length is the value of the earlier integer field `count`.
pub const fn sized(id: u16, count: u16) -> Field {
    Field {
        source: count,
        ..entry(Kind::Sized, id)
    }
}

/// `count` values of one bit (0 or 1), eight to a byte, low bit first.
pub const fn bits(id: u16, count: u16) -> Field {
    Field {
        source: count,
        ..entry(Kind::Bits, id)
    }
}

/// (value of `count` + `bias`) numbers of `width` bits (1 or 2), low bits first; `bias` is 0
/// or -1.
pub const fn packed(width: u8, id: u16, count: u16, bias: i8) -> Field {
    Field {
        source: count,
        width,
        bias,
        ..entry(Kind::Packed, id)
    }
}

/// Two-bit values (0 to 3), four to a byte, low bits first: the `n` entries after this one are
/// `u8` fields, the first with id `id`.
pub const fn u2(id: u16, n: u16) -> Field {
    parent(Kind::U2, id, n)
}

/// Members written one after another (at least one; a presence bit with no members is a
/// [`boolean`]). Under `flags` the group is on when any member is.
pub const fn group(id: u16, entries: u16) -> Field {
    parent(Kind::Group, id, entries)
}

/// Rounds of the members until the packet ends; round `k` is item `k` of the row
/// ([`Row::item`](super::Row::item)). Not inside another `repeat` or `times` round.
pub const fn repeat(id: u16, entries: u16) -> Field {
    parent(Kind::Repeat, id, entries)
}

/// (value of the earlier integer field `count`) rounds of the members; round `k` is item `k`.
/// Not inside another `times` round.
pub const fn times(id: u16, count: u16, entries: u16) -> Field {
    Field {
        source: count,
        ..parent(Kind::Times, id, entries)
    }
}

/// A u16 item count, then the items. The element (the `entries` table entries that follow: a
/// number, `bytes`, a `list` or a `u2` of one member) has ids from 0 in each item.
pub const fn list(id: u16, entries: u16) -> Field {
    parent(Kind::List, id, entries)
}

/// A string; the row holds the UTF-8 text through [`Row::bytes`](super::Row::bytes) on pack and
/// [`Row::slots`](super::Row::slots) on unpack (needs the `text` feature).
pub const fn utf8(id: u16) -> Field {
    entry(Kind::Utf8, id)
}

/// A string whose payload the row holds as it is on the wire (the bytes after the count).
pub const fn utf8_wire(id: u16) -> Field {
    entry(Kind::Utf8Wire, id)
}

/// The key of a `dict`: the first of its two members. A row holds it under [`DICT_KEY`].
pub const fn key() -> Field {
    entry(Kind::Utf8, NO_ID)
}

/// A u16 entry count, then entries of a string key and an element, keys strictly ascending by
/// their UTF-8 bytes. The `entries` table entries that follow are the key (`key()`) and the
/// element (a number, `bytes`, a string, a `list`, a `dict` or a `u2` of one member), whose ids
/// start from 0 in each item.
pub const fn dict(id: u16, entries: u16) -> Field {
    parent(Kind::Dict, id, entries)
}

/// The id under which a `dict` item row holds its key.
pub const DICT_KEY: u16 = NO_ID;

/// The most rounds one `repeat` or `times` may start (the std default).
pub const DEFAULT_MAX_ROUNDS: usize = 65_535;
/// The most slots (members a round can hold, summed over every round started) one call may
/// charge (the std default).
pub const DEFAULT_MAX_SLOTS: usize = 1_048_576;

/// A packet layout: a type number (the first byte), the table of fields in order, and the round
/// limits (a round past either is [`Error::TooMany`](super::Error::TooMany)).
#[derive(Clone, Copy, Debug)]
pub struct Scheme<'a> {
    pub type_number: u8,
    pub fields: &'a [Field],
    /// The most rounds one `repeat` or `times` may start where it stands (each time it is read).
    pub max_rounds: usize,
    /// The most slots all rounds of one call may charge together; a round charges one slot per
    /// member its body can hold.
    pub max_slots: usize,
    /// Parity bytes after every packet (0 to 32; needs the `ecc` feature when above 0).
    pub parity: u8,
}

impl<'a> Scheme<'a> {
    pub const fn new(type_number: u8, fields: &'a [Field]) -> Self {
        Scheme {
            type_number,
            fields,
            max_rounds: DEFAULT_MAX_ROUNDS,
            max_slots: DEFAULT_MAX_SLOTS,
            parity: 0,
        }
    }

    /// The scheme with `n` parity bytes after every packet (message error correction): `pack`
    /// appends them, `unpack` detects wrong bytes and `unpack_repair` fixes them. A count above
    /// 32, or above 0 without the `ecc` feature, is refused by [`validate`](super::validate).
    pub const fn with_parity(self, n: u8) -> Self {
        Scheme { parity: n, ..self }
    }

    pub const fn with_limits(self, max_rounds: usize, max_slots: usize) -> Self {
        Scheme {
            max_rounds,
            max_slots,
            ..self
        }
    }
}

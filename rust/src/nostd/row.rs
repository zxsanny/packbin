use super::scheme::Kind;

/// A number as a field holds it. Nothing here allocates.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Num {
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
}

impl Num {
    pub(crate) fn kind(self) -> Kind {
        match self {
            Num::U8(_) => Kind::U8,
            Num::U16(_) => Kind::U16,
            Num::U32(_) => Kind::U32,
            Num::U64(_) => Kind::U64,
            Num::I8(_) => Kind::I8,
            Num::I16(_) => Kind::I16,
            Num::I32(_) => Kind::I32,
            Num::I64(_) => Kind::I64,
            Num::F32(_) => Kind::F32,
            Num::F64(_) => Kind::F64,
        }
    }

    /// The value as the unsigned bits of its width (floats by their IEEE bits, so NaN keeps its
    /// payload).
    pub(crate) fn bits(self) -> u64 {
        match self {
            Num::U8(v) => u64::from(v),
            Num::U16(v) => u64::from(v),
            Num::U32(v) => u64::from(v),
            Num::U64(v) => v,
            Num::I8(v) => u64::from(v as u8),
            Num::I16(v) => u64::from(v as u16),
            Num::I32(v) => u64::from(v as u32),
            Num::I64(v) => v as u64,
            Num::F32(v) => u64::from(v.to_bits()),
            Num::F64(v) => v.to_bits(),
        }
    }

    pub(crate) fn from_bits(kind: Kind, bits: u64) -> Option<Num> {
        Some(match kind {
            Kind::U8 => Num::U8(bits as u8),
            Kind::U16 => Num::U16(bits as u16),
            Kind::U32 => Num::U32(bits as u32),
            Kind::U64 => Num::U64(bits),
            Kind::I8 => Num::I8(bits as u8 as i8),
            Kind::I16 => Num::I16(bits as u16 as i16),
            Kind::I32 => Num::I32(bits as u32 as i32),
            Kind::I64 => Num::I64(bits as i64),
            Kind::F32 => Num::F32(f32::from_bits(bits as u32)),
            Kind::F64 => Num::F64(f64::from_bits(bits)),
            _ => return None,
        })
    }
}

/// The caller's data, read and written by field id. A scheme field `u16(0)` asks `num(0)` on
/// pack and calls `set_num(0, ..)` on unpack. `num` and `bytes` return `None` for an id the row
/// has no value for; `set_num` and `set_bytes` return `false` to refuse a value. Either becomes
/// [`Error::BadValue`](super::Error::BadValue) naming the field, except where a member may be
/// absent: in `flags`, under a flag bit and in a `when` body, `None` (or a `false` flag) leaves
/// the member off the wire.
///
/// The methods with a default body serve the other field kinds; a row implements those its
/// schemes use.
pub trait Row {
    fn num(&self, id: u16) -> Option<Num>;
    fn bytes(&self, id: u16) -> Option<&[u8]>;
    fn set_num(&mut self, id: u16, value: Num) -> bool;
    fn set_bytes(&mut self, id: u16, value: &[u8]) -> bool;

    /// A `boolean`: true sets its presence bit.
    fn flag(&self, _id: u16) -> bool {
        false
    }

    /// Unpack sets a `boolean` whose bit is set; `false` refuses it.
    fn set_flag(&mut self, _id: u16, _on: bool) -> bool {
        false
    }

    /// Unpack calls this for every member before it reads a packet, so a member the packet leaves
    /// out reads as absent afterwards: `num` and `bytes` return `None`, `flag` returns false.
    fn clear(&mut self, _id: u16) {}

    /// Storage for the values of a `sized`, `bits` or `packed` field on unpack: the slice is the
    /// capacity (a longer value is [`Error::TooMany`](super::Error::TooMany), nothing written).
    /// Unpack fills the first values, then calls `set_count`; pack reads them from `bytes`.
    fn slots(&mut self, _id: u16) -> Option<&mut [u8]> {
        None
    }

    /// The number of values unpack wrote into `slots`, or of items it filled for a `repeat`,
    /// `times` or `list`; `false` refuses it.
    fn set_count(&mut self, _id: u16, _n: usize) -> bool {
        false
    }

    /// The items a `repeat`, `times` or `list` holds on pack (`None`: the row holds none).
    fn count(&self, _id: u16) -> Option<usize> {
        None
    }

    /// Item `k` of a `repeat`, `times` or `list` on pack: a row of its own, whose ids are those of
    /// the round's members (a list element: id 0).
    fn item(&self, _id: u16, _k: usize) -> Option<&dyn Row> {
        None
    }

    /// Storage for item `k` on unpack (`None` when the row has no room for it: that is
    /// [`Error::TooMany`](super::Error::TooMany)). Unpack clears the item's members, reads them
    /// into it, and calls `set_count` with the items filled when the container ends.
    fn item_mut(&mut self, _id: u16, _k: usize) -> Option<&mut dyn Row> {
        None
    }
}

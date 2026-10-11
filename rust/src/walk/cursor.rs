use crate::field::{float_width, int_width, FloatKind, IntKind, MapScheme};
use crate::value::{ShortPacket, UnpackError, Value};

/// The state of one unpack call: the read position, and the slots its rounds have started so
/// far, shared by every field of the call and checked against the limits of its scheme.
pub(crate) struct Cursor<'a> {
    data: &'a [u8],
    pos: usize,
    max_rounds: usize,
    max_slots: usize,
    slots: usize,
}

impl<'a> Cursor<'a> {
    pub(super) fn new(data: &'a [u8], scheme: &MapScheme) -> Self {
        Cursor {
            data,
            pos: 0,
            max_rounds: scheme.max_rounds,
            max_slots: scheme.max_slots,
            slots: 0,
        }
    }

    /// Admits a round of `field` that is about to start, taking its `round_slots`; `started` is
    /// the rounds the same field has already started in this walk. Refuses, as a bad value,
    /// the round that would pass either limit, before it allocates anything.
    pub(super) fn start_round(
        &mut self,
        field: &str,
        started: usize,
        round_slots: usize,
    ) -> Result<(), UnpackError> {
        if started >= self.max_rounds || round_slots > self.max_slots - self.slots {
            return Err(UnpackError::Short(ShortPacket {
                field: field.to_string(),
                needed: 0,
                left: self.left(),
            }));
        }
        self.slots += round_slots;
        Ok(())
    }

    pub(crate) fn left(&self) -> usize {
        self.data.len().saturating_sub(self.pos)
    }

    pub(crate) fn take(&mut self, n: usize, field: &str) -> Result<&'a [u8], UnpackError> {
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

pub(super) fn read_int(
    cur: &mut Cursor<'_>,
    name: &str,
    kind: IntKind,
    be: bool,
) -> Result<Value, UnpackError> {
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

pub(super) fn read_float(
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

/// Item count and byte length of a packed field, or `None` when the count is negative or
/// does not fit the target's integer sizes (32-bit targets included).
pub(crate) fn packed_layout(raw_count: usize, bias: i8, width: usize) -> Option<(usize, usize)> {
    let items = i64::try_from(raw_count)
        .ok()?
        .checked_add(i64::from(bias))?;
    let n = usize::try_from(items).ok()?;
    let bits = n.checked_mul(width)?;
    Some((n, bits.div_ceil(8)))
}

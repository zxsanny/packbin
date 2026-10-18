use crate::field::{field_name, Field, FieldKind, FloatKind, IntKind, MapScheme};
use crate::value::{PackError, Value};

/// The state of one pack call: the packet written so far (type byte included) and the limits of its
/// scheme. Pack refuses, naming the member, an append that would make the packet longer than
/// `max_bytes` before it writes or allocates anything for it, and a round that would pass
/// `max_slots` before its first byte, as unpack charges the same rounds.
pub(super) struct PackOut {
    buf: Vec<u8>,
    max_bytes: usize,
    pub(super) max_rounds: usize,
    max_slots: usize,
    slots: usize,
    /// The last long text written and its field: a lone string under a `times` is packed once per
    /// round, and encoding 64 KiB costs far more than comparing it.
    pub(super) text_cache: Option<(String, Vec<u8>)>,
}

impl PackOut {
    pub(super) fn new(scheme: &MapScheme) -> Self {
        let mut buf = Vec::with_capacity(32.min(scheme.max_bytes));
        buf.push(scheme.type_number);
        PackOut {
            buf,
            max_bytes: scheme.max_bytes,
            max_rounds: scheme.max_rounds,
            max_slots: scheme.max_slots,
            slots: 0,
            text_cache: None,
        }
    }

    pub(super) fn len(&self) -> usize {
        self.buf.len()
    }

    pub(super) fn into_bytes(self) -> Vec<u8> {
        self.buf
    }

    /// Makes room for `n` more bytes, or refuses naming the member (`name` is built only then).
    /// The buffer grows by doubling but never past `max_bytes`.
    pub(super) fn admit(
        &mut self,
        n: usize,
        name: impl FnOnce() -> String,
    ) -> Result<(), PackError> {
        let need = self.buf.len().saturating_add(n);
        if need > self.max_bytes {
            return Err(PackError::Type(format!(
                "{}: the packet would be {need} bytes, above the limit of {} bytes",
                name(),
                self.max_bytes
            )));
        }
        if need > self.buf.capacity() {
            let target = need.max(self.buf.capacity() * 2).min(self.max_bytes);
            self.buf.reserve_exact(target - self.buf.len());
        }
        Ok(())
    }

    /// Writes bytes that `admit` has made room for.
    pub(super) fn raw(&mut self, bytes: &[u8]) {
        self.buf.extend_from_slice(bytes);
    }

    pub(super) fn append(&mut self, name: &str, bytes: &[u8]) -> Result<(), PackError> {
        self.admit(bytes.len(), || name.to_string())?;
        self.raw(bytes);
        Ok(())
    }

    /// A flag byte or a combined `flags` byte; `patch` sets its bits later.
    pub(super) fn byte(
        &mut self,
        byte: u8,
        name: impl FnOnce() -> String,
    ) -> Result<(), PackError> {
        self.admit(1, name)?;
        self.buf.push(byte);
        Ok(())
    }

    pub(super) fn patch(&mut self, at: usize, byte: u8) {
        self.buf[at] = byte;
    }

    /// Charges a round of `width` slots before its first byte; refuses the round that would pass
    /// `max_slots`, naming the first member the round holds.
    pub(super) fn start_round(
        &mut self,
        width: usize,
        name: impl FnOnce() -> String,
    ) -> Result<(), PackError> {
        let total = self.slots.saturating_add(width);
        if total > self.max_slots {
            return Err(PackError::Type(format!(
                "{}: the rounds would hold {total} slots, above the limit of {} slots",
                name(),
                self.max_slots
            )));
        }
        self.slots = total;
        Ok(())
    }
}

fn write_ordered(
    out: &mut PackOut,
    name: &str,
    raw: &[u8],
    big_endian: bool,
) -> Result<(), PackError> {
    if !big_endian {
        return out.append(name, raw);
    }
    out.admit(raw.len(), || name.to_string())?;
    let mut be = [0u8; 8];
    for (to, from) in be.iter_mut().zip(raw.iter().rev()) {
        *to = *from;
    }
    out.raw(&be[..raw.len()]);
    Ok(())
}

pub(super) fn write_int(
    out: &mut PackOut,
    name: &str,
    kind: IntKind,
    be: bool,
    value: &Value,
) -> Result<(), PackError> {
    match (kind, value) {
        (IntKind::U8, Value::U8(v)) => out.append(name, &[*v]),
        (IntKind::U16, Value::U16(v)) => write_ordered(out, name, &v.to_le_bytes(), be),
        (IntKind::U32, Value::U32(v)) => write_ordered(out, name, &v.to_le_bytes(), be),
        (IntKind::U64, Value::U64(v)) => write_ordered(out, name, &v.to_le_bytes(), be),
        (IntKind::I8, Value::I8(v)) => out.append(name, &[*v as u8]),
        (IntKind::I16, Value::I16(v)) => write_ordered(out, name, &v.to_le_bytes(), be),
        (IntKind::I32, Value::I32(v)) => write_ordered(out, name, &v.to_le_bytes(), be),
        (IntKind::I64, Value::I64(v)) => write_ordered(out, name, &v.to_le_bytes(), be),
        _ => Err(PackError::Type("int".into())),
    }
}

pub(super) fn write_float(
    out: &mut PackOut,
    name: &str,
    kind: FloatKind,
    be: bool,
    value: &Value,
) -> Result<(), PackError> {
    match (kind, value) {
        (FloatKind::F32, Value::F32(v)) => write_ordered(out, name, &v.to_le_bytes(), be),
        (FloatKind::F64, Value::F64(v)) => write_ordered(out, name, &v.to_le_bytes(), be),
        _ => Err(PackError::Type("float".into())),
    }
}

/// The first name a combined `flags` declares, depth-first through its `when`, `repeat`, `times`
/// and nested `flags` members: the member its byte is named by when the byte would pass the
/// budget. A `flags` that declares none is named by its own name.
pub(super) fn flags_byte_name(name: &str, members: &[Field]) -> String {
    members
        .iter()
        .find_map(declared_name)
        .unwrap_or(name)
        .to_string()
}

fn declared_name(field: &Field) -> Option<&str> {
    match &field.kind {
        FieldKind::FlagBit { inner, .. } => declared_name(inner),
        FieldKind::Flags { name, members, .. } => {
            Some(members.iter().find_map(declared_name).unwrap_or(name))
        }
        FieldKind::When { members, .. }
        | FieldKind::Repeat { members, .. }
        | FieldKind::Times { members, .. } => members.iter().find_map(declared_name),
        _ => field_name(field),
    }
}

/// The member a refused round is named by: the first name the round holds, depth-first, a
/// group's own name before its members, flag bytes not counted; `<kind> <anchor>` if none.
pub(super) fn round_member(kind: &str, anchor: u32, members: &[Field]) -> String {
    match members.iter().find_map(held_name) {
        Some(name) => name.to_string(),
        None => format!("{kind} {anchor}"),
    }
}

fn held_name(field: &Field) -> Option<&str> {
    match &field.kind {
        FieldKind::FlagByte { .. } => None,
        FieldKind::FlagBit { inner, .. } => held_name(inner),
        FieldKind::Flags { members, .. }
        | FieldKind::When { members, .. }
        | FieldKind::Repeat { members, .. }
        | FieldKind::Times { members, .. } => members.iter().find_map(held_name),
        _ => field_name(field),
    }
}

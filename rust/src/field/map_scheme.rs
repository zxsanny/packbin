use super::{check_order, integrity, shape, Field, FieldKind};

/// The most rounds one `repeat` or `times` field may start in one unpack call.
pub const DEFAULT_MAX_ROUNDS: usize = 65_535;
/// The most slots (names a round can hold, summed over every round started) one unpack call
/// may create.
pub const DEFAULT_MAX_SLOTS: usize = 4_194_304;

#[derive(Clone, Debug)]
pub struct MapScheme {
    pub(crate) type_number: u8,
    pub(crate) fields: Vec<Field>,
    /// The scheme reads at least one split-form flag byte.
    pub(crate) has_split_flags: bool,
    pub(crate) field_count: usize,
    pub(crate) max_rounds: usize,
    pub(crate) max_slots: usize,
}

pub(super) fn count_fields(fields: &[Field]) -> usize {
    let mut n = 0;
    for f in fields {
        match &f.kind {
            FieldKind::Int { .. }
            | FieldKind::Float { .. }
            | FieldKind::Bytes { .. }
            | FieldKind::FlagByte { .. }
            | FieldKind::Sized { .. }
            | FieldKind::Bits { .. }
            | FieldKind::Packed { .. }
            | FieldKind::Utf8 { .. }
            | FieldKind::List { .. }
            | FieldKind::Dict { .. } => n += 1,
            FieldKind::U2 { names } => n += names.len(),
            FieldKind::Flags { members, .. } | FieldKind::Group { members, .. } => {
                n += 1 + count_fields(members);
            }
            FieldKind::FlagBit { inner, .. } => n += count_fields(std::slice::from_ref(inner)),
            FieldKind::When { members, .. }
            | FieldKind::Repeat { members, .. }
            | FieldKind::Times { members, .. } => n += count_fields(members),
        }
    }
    n
}

impl MapScheme {
    /// Panics, naming the field, on a scheme that cannot round-trip: a field out of order or
    /// scope, a flag bit with no flag byte before it in its scope, a 9th member or bit in one
    /// flags byte or flag byte, a bool (an empty `group`) not directly inside `flags` or
    /// under a flag bit, a `when` that tests a field or value that is not an integer, or a `list`
    /// or `dict` element that is not one integer, float, bytes, utf8, list or dict (a `u2` with
    /// one name). Binds each flag bit to its flag byte and numbers it by field order.
    pub fn new(type_number: i32, mut fields: Vec<Field>) -> Self {
        if !(0..=255).contains(&type_number) {
            panic!("type number must be 0..=255");
        }
        let field_count = count_fields(&fields);
        check_order(&fields, 0, 0);
        let flag_bytes = shape::check_shape(&mut fields);
        integrity::check_integrity(&fields);
        MapScheme {
            type_number: type_number as u8,
            fields,
            has_split_flags: flag_bytes > 0,
            field_count,
            max_rounds: DEFAULT_MAX_ROUNDS,
            max_slots: DEFAULT_MAX_SLOTS,
        }
    }

    /// Returns the scheme with other unpack limits (clone first to keep the original): the
    /// most rounds one `repeat` or `times` field may start, and the most slots all rounds of
    /// one unpack call may create together. `unpack` refuses a packet that would pass either
    /// when the round that crosses it would start. Panics when either is 0; `usize::MAX` is
    /// valid.
    pub fn with_limits(mut self, max_rounds: usize, max_slots: usize) -> Self {
        if max_rounds == 0 {
            panic!("max_rounds must be at least 1");
        }
        if max_slots == 0 {
            panic!("max_slots must be at least 1");
        }
        self.max_rounds = max_rounds;
        self.max_slots = max_slots;
        self
    }

    pub fn max_rounds(&self) -> usize {
        self.max_rounds
    }

    pub fn max_slots(&self) -> usize {
        self.max_slots
    }

    pub fn type_number(&self) -> u8 {
        self.type_number
    }
}

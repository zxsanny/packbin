use super::{check_order, shape, Field, FieldKind};

#[derive(Clone, Debug)]
pub struct MapScheme {
    pub(crate) type_number: u8,
    pub(crate) fields: Vec<Field>,
    /// The scheme reads at least one split-form flag byte.
    pub(crate) has_split_flags: bool,
    pub(crate) field_count: usize,
}

fn count_fields(fields: &[Field]) -> usize {
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
    /// flags byte or flag byte, or a bool (an empty `group`) not directly inside `flags` or
    /// under a flag bit. Binds each flag bit to its flag byte and numbers it by field order.
    pub fn new(type_number: i32, mut fields: Vec<Field>) -> Self {
        if !(0..=255).contains(&type_number) {
            panic!("type number must be 0..=255");
        }
        let field_count = count_fields(&fields);
        check_order(&fields, 0, 0);
        let flag_bytes = shape::check_shape(&mut fields);
        MapScheme {
            type_number: type_number as u8,
            fields,
            has_split_flags: flag_bytes > 0,
            field_count,
        }
    }

    pub fn type_number(&self) -> u8 {
        self.type_number
    }
}

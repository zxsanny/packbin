use super::unpack::{unpack_fields, Cursor};
use crate::field::Field;
use crate::value::{Name, ShortPacket, UnpackError, Value, Values};
use std::collections::HashMap;

/// Reads one `list` or `dict` element and returns its value.
///
/// An element that reads nothing is an error: a huge count of such elements would otherwise
/// be stored one by one from a few bytes of input.
pub(super) fn unpack_element(
    element: &Field,
    owner: &str,
    child: &str,
    cur: &mut Cursor<'_>,
    flag_bits: &mut HashMap<Name, u8>,
    groups: &mut Vec<Values>,
) -> Result<Value, UnpackError> {
    let before = cur.left();
    let mut one = Values::new();
    unpack_fields(
        std::slice::from_ref(element),
        cur,
        &mut one,
        flag_bits,
        groups,
    )?;
    if cur.left() == before {
        return Err(UnpackError::Short(ShortPacket {
            field: owner.to_string(),
            needed: 0,
            left: before,
        }));
    }
    match one.remove(child) {
        Some(Some(v)) => Ok(v),
        _ => Err(UnpackError::Short(ShortPacket {
            field: owner.to_string(),
            needed: 0,
            left: cur.left(),
        })),
    }
}

/// Capacity to reserve for `count` decoded elements. Every element reads at least one byte,
/// so more than the bytes left can never be filled; the packet's own count is not trusted.
pub(crate) fn capacity_hint(count: usize, left: usize) -> usize {
    count.min(left)
}

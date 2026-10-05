mod element;
mod pack;
mod unpack;

#[cfg(test)]
pub(crate) use element::capacity_hint;
#[cfg(test)]
pub(crate) use unpack::packed_layout;

use crate::field::MapScheme;
use crate::value::{PackError, UnpackError, Values};

/// Packs `values`, keyed by field name, with a map scheme: the type number, then each field.
///
/// - The bits of a `flags` byte or flag byte come from its fields; a value under its own name
///   is not read. A bool (an empty `group`) sets its bit for `1` and leaves it clear for `0` or
///   no value.
/// - Each field inside a `times` takes a [`Value::List`] with one item per round.
/// - A `repeat` takes its rounds as [`Value::Groups`] (one [`Values`] per round) under the name
///   `"__repeat__"`; no value there packs no rounds.
///
/// Returns the packet bytes, or a [`PackError`]: [`PackError::Missing`] when a field that is
/// written has no value; [`PackError::Type`] when a value does not fit its field, a bool value
/// is not `0` or `1`, or `"__repeat__"` holds anything but [`Value::Groups`].
///
/// [`Value::List`]: crate::Value::List
/// [`Value::Groups`]: crate::Value::Groups
pub fn pack(scheme: &MapScheme, values: &Values) -> Result<Vec<u8>, PackError> {
    pack::pack(scheme, values)
}

/// Unpacks a packet built with `scheme` into values keyed by field name.
///
/// - Each `flags` byte and flag byte is returned under its own name as `Value::U8` holding the
///   byte read (for example `m = U8(1)`).
/// - A field behind a clear bit or an untaken `when` is absent; a set bool is `Value::U8(1)`.
/// - Each field inside a `times` is one [`Value::List`] with an item for every round that read
///   it; a field no round read is absent.
/// - `repeat` rounds are [`Value::Groups`] under `"__repeat__"`, absent when there are none.
///
/// Returns an [`UnpackError`] instead: [`UnpackError::Type`] for another type number;
/// [`UnpackError::Short`] for a packet that ends early or holds a value that cannot be read
/// (a count that does not fit, invalid UTF-8, an element that reads nothing);
/// [`UnpackError::Trailing`] for bytes left over, including after a `repeat` round that reads
/// nothing.
///
/// [`Value::List`]: crate::Value::List
/// [`Value::Groups`]: crate::Value::Groups
pub fn unpack(scheme: &MapScheme, bytes: &[u8]) -> Result<Values, UnpackError> {
    unpack::unpack(scheme, bytes)
}

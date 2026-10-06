mod element;
mod pack;
mod times;
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
/// - A `times` takes its rounds as [`Value::Groups`] (one [`Values`] per round) under the name
///   `"__times_<anchor>"`, as many as its count; a member under a `flags` or `when` stays in its
///   round. Without that value each direct field of the `times` takes a [`Value::List`] with one
///   item per round; a list cannot say which round holds a field under a `flags` or `when`, so a
///   value kept under the name of such a field (at any depth below them; a non-list counts as a
///   list of one item) is a [`PackError::Type`] naming it, and the field goes in the rounds.
///   With both, a value kept for a name of the rounds must be what the rounds hold. To change a
///   value after `unpack`, edit the rounds and drop or rewrite the per-name lists, or edit the
///   lists and drop the `"__times_<anchor>"` key (not for a field under a `flags` or `when`:
///   edit its rounds); leaving both and changing one is an error.
/// - A `repeat` takes its rounds as [`Value::Groups`] (one [`Values`] per round) under the name
///   `"__repeat__"`; no value there packs no rounds.
///
/// Returns the packet bytes, or a [`PackError`]: [`PackError::Missing`] when a field that is
/// written has no value; [`PackError::Type`] when a value does not fit its field, a bool value
/// is not `0` or `1`, `"__repeat__"` or a `times` holds anything but [`Value::Groups`], the
/// rounds of a `times` are not as many as its count, a value kept beside them differs from
/// them, or a `times` without rounds has a value kept under a field below a `flags` or `when`.
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
///   it; a field no round read is absent. The rounds also come as [`Value::Groups`] under
///   `"__times_<anchor>"`, empty for count 0; pack takes them back in place of the lists.
/// - `repeat` rounds are [`Value::Groups`] under `"__repeat__"`, absent when there are none.
///
/// - A packet that would start more than `max_rounds` rounds of one `repeat` or `times` field
///   (default [`DEFAULT_MAX_ROUNDS`](crate::DEFAULT_MAX_ROUNDS)), or whose rounds together would hold more than
///   `max_slots` slots (default [`DEFAULT_MAX_SLOTS`](crate::DEFAULT_MAX_SLOTS); a round holds one slot per name it can
///   read, counted from every round of a `times` inside a `repeat` too), is refused when the
///   round that crosses the limit would start, before anything is built for it. A `times`
///   count is not refused up front: a huge count whose packet ends early is a short read.
///   `MapScheme::with_limits` and `Scheme::with_limits` change the limits of one scheme.
///
/// Returns an [`UnpackError`] instead: [`UnpackError::Type`] for another type number;
/// [`UnpackError::Short`] for a packet that ends early or holds a value that cannot be read
/// (a count that does not fit, invalid UTF-8, an element that reads nothing, a round past a
/// limit, with `needed` 0 and the field `"repeat"` or `"times"`);
/// [`UnpackError::Trailing`] for bytes left over, including after a `repeat` round that reads
/// nothing.
///
/// [`Value::List`]: crate::Value::List
/// [`Value::Groups`]: crate::Value::Groups
pub fn unpack(scheme: &MapScheme, bytes: &[u8]) -> Result<Values, UnpackError> {
    unpack::unpack(scheme, bytes)
}

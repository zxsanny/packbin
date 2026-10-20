//! The count header of a string field: a varint of 1 to 3 bytes (LEB128, minimal), then that many
//! payload bytes (the C++ `text_count.hpp` port). Shared by the codec and by `Utf8Wire`, so a
//! build without `text` can skip, read and forward a string.

use super::error::{Error, Fault};
use super::io::{Reader, Writer};

/// The largest count a 3-byte varint holds.
pub(crate) const MAX_COUNT: usize = 2_097_151;

pub(crate) fn varint_size(n: usize) -> usize {
    if n < 128 {
        1
    } else if n < 16384 {
        2
    } else {
        3
    }
}

/// Writes the varint of `n` at the start of `dst` (`varint_size(n)` bytes; a shorter `dst` takes
/// what fits).
pub(crate) fn put_varint(dst: &mut [u8], mut n: usize) {
    for slot in dst.iter_mut() {
        if n >= 128 {
            *slot = (n as u8) | 0x80;
            n >>= 7;
        } else {
            *slot = n as u8;
            n = 0;
        }
    }
}

/// Reserves a string field (the count header, then `size` payload bytes) and returns the payload.
/// Written without `split_at_mut`, which links a panic path.
pub(crate) fn put_field<'w>(
    w: &'w mut Writer<'_>,
    size: usize,
    id: i32,
) -> Result<&'w mut [u8], Fault> {
    let head = varint_size(size);
    let all = w.take(head.saturating_add(size), id)?;
    if let Some(count) = all.get_mut(..head) {
        put_varint(count, size);
    }
    all.get_mut(head..)
        .ok_or_else(|| Fault::new(Error::BufferFull, 0, id, 0))
}

/// Reads the count of a string: `BadValue` for a fourth byte or a non-minimal form.
pub(crate) fn get_count(r: &mut Reader<'_>, id: i32) -> Result<usize, Fault> {
    let at = r.pos();
    let mut n = 0usize;
    for k in 0..3u32 {
        let b = *r.take(1, id)?.first().unwrap_or(&0);
        n |= usize::from(b & 0x7F)
            .checked_shl(k.saturating_mul(7))
            .unwrap_or(0);
        if b & 0x80 == 0 {
            if k > 0 && b == 0 {
                return Err(Fault::new(Error::BadValue, at, id, 0));
            }
            return Ok(n);
        }
    }
    Err(Fault::new(Error::BadValue, at, id, 0))
}

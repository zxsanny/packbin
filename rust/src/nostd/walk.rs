use super::check::validate;
use super::error::{Error, Fault};
use super::io::{Reader, Writer};
use super::pack::{Budget, Pack};
use super::present::clear;
use super::row::Row;
use super::scheme::Scheme;
use super::unpack::Unpack;

fn budget_of(scheme: &Scheme<'_>) -> Budget {
    Budget {
        max_rounds: scheme.max_rounds,
        max_slots: scheme.max_slots,
        slots: 0,
    }
}

/// Packs `row` into `out` and returns the bytes written: the type number, then each field.
/// A scheme that is not valid, a row without a value for a field (or with one of another kind or
/// length) and an `out` that is too small are errors; the failure names the field.
pub fn pack(scheme: &Scheme<'_>, row: &dyn Row, out: &mut [u8]) -> Result<usize, Fault> {
    pack_with(scheme, row, out, &mut [])
}

/// Like [`pack`], with working words for the compact text encoder (`text`): a string whose
/// compact form may be shorter than its raw form needs 3 words per code point
/// ([`SCRATCH_WORDS_PER_CHAR`](super::SCRATCH_WORDS_PER_CHAR)) of the longest such string. The
/// words need no initial value. A string that needs more is
/// [`Error::ScratchTooSmall`](super::Error::ScratchTooSmall) naming the field and the words
/// needed; the encoder never writes a different encoding instead.
pub fn pack_with(
    scheme: &Scheme<'_>,
    row: &dyn Row,
    out: &mut [u8],
    scratch: &mut [u32],
) -> Result<usize, Fault> {
    validate(scheme)?;
    let mut writer = Writer::new(out);
    writer.put(&[scheme.type_number], -1)?;
    let mut budget = budget_of(scheme);
    Pack {
        t: scheme.fields,
        w: &mut writer,
        row,
        budget: &mut budget,
        scratch,
    }
    .top()?;
    Ok(writer.len())
}

/// Like [`pack`], into a new `Vec` of at most `limit` bytes (needs the `alloc` feature). The `Vec` is
/// allocated at `limit` before the pack runs: `limit` is the caller's budget, never a length read
/// from a packet.
#[cfg(feature = "alloc")]
pub fn pack_vec(
    scheme: &Scheme<'_>,
    row: &dyn Row,
    limit: usize,
) -> Result<alloc::vec::Vec<u8>, Fault> {
    let mut out = alloc::vec![0u8; limit];
    let n = pack(scheme, row, &mut out)?;
    out.truncate(n);
    Ok(out)
}

/// Unpacks `bytes` into `row` and returns the bytes read, all of them. Every member is first
/// cleared ([`Row::clear`]), so one the packet leaves out reads as absent. A failure may leave the
/// fields read before it in `row`. Nothing is read from a packet of another type number
/// ([`Error::TypeMismatch`], `needed` the expected one).
pub fn unpack(scheme: &Scheme<'_>, bytes: &[u8], row: &mut dyn Row) -> Result<usize, Fault> {
    validate(scheme)?;
    let mut reader = Reader::new(bytes);
    let first = reader.take(1, -1)?;
    if first.first() != Some(&scheme.type_number) {
        return Err(Fault::new(
            Error::TypeMismatch,
            0,
            -1,
            usize::from(scheme.type_number),
        ));
    }
    clear(scheme.fields, 0, scheme.fields.len(), row);
    let mut budget = budget_of(scheme);
    Unpack {
        t: scheme.fields,
        r: &mut reader,
        row,
        flag_bytes: [0; 8],
        budget: &mut budget,
    }
    .top()?;
    reader.finish()?;
    Ok(reader.pos())
}

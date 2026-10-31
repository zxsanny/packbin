//! Message error correction around the plain walk (the C++ `codec.hpp` glue). The codec itself,
//! `protect`, `check` and `repair`, is the one the `std` walker uses (`ecc_core`), public here
//! for a caller that protects bytes of its own.

use super::error::{Error, Fault};
use super::io::Writer;
use crate::ecc_core::{self, Kind, MAX_SENT};

pub use crate::ecc_core::{check, protect, repair, Kind as EccKind, Outcome};

/// The error a refusal of the codec is, for a message of `len` bytes under `n` parity bytes.
fn fault(kind: Kind, len: usize, n: usize) -> Fault {
    match kind {
        Kind::Ok | Kind::Uncorrectable => Fault::new(Error::Uncorrectable, 0, -1, 0),
        Kind::Short => Fault::new(Error::ShortPacket, len, -1, n),
        Kind::TooLong => Fault::new(Error::TooLong, len, -1, MAX_SENT),
        Kind::BadLimit => Fault::new(Error::BadValue, 0, -1, n / 2),
        Kind::BadParity => Fault::new(Error::SchemeInvalid, 0, -1, ecc_core::MAX_PARITY),
    }
}

/// The parity count of a packet of `len` bytes under percentage `p`; a packet above the largest
/// clear length of `p` is `TooLong` naming it (the written bytes are zeroed).
pub(crate) fn percent_count(w: &mut Writer<'_>, p: usize) -> Result<usize, Fault> {
    let len = w.len();
    let limit = ecc_core::largest_clear(p);
    if len > limit {
        w.zero();
        return Err(Fault::new(Error::TooLong, len, -1, limit));
    }
    Ok(ecc_core::parity_count(p, len))
}

/// The parity count of a received message of `len` bytes: `n` under a count, found from the length
/// under a percentage `p` above 0 (`TooLong` above 254 bytes, `Uncorrectable` when no clear length
/// gives `len`).
pub(crate) fn received_count(len: usize, n: usize, p: usize) -> Result<usize, Fault> {
    if p == 0 {
        return Ok(n);
    }
    if len > MAX_SENT {
        return Err(Fault::new(Error::TooLong, len, -1, MAX_SENT));
    }
    match ecc_core::clear_length(p, len) {
        Some(clear) => Ok(len.saturating_sub(clear)),
        None => Err(Fault::new(Error::Uncorrectable, 0, -1, 0)),
    }
}

/// The checks of [`seal`] that need no work: fields above `254 - n` bytes are `TooLong` (`offset`
/// the field bytes, `needed` the limit; the written bytes are zeroed) and `n` bytes must fit.
pub(crate) fn room(w: &mut Writer<'_>, n: usize) -> Result<(), Fault> {
    let len = w.len();
    let limit = MAX_SENT.saturating_sub(n);
    if len > limit {
        w.zero();
        return Err(Fault::new(Error::TooLong, len, -1, limit));
    }
    if w.room() < n {
        return Err(Fault::new(Error::BufferFull, len, -1, n));
    }
    Ok(())
}

/// Appends the `n` parity bytes of the bytes written so far (after [`room`]'s checks).
pub(crate) fn seal(w: &mut Writer<'_>, n: usize) -> Result<(), Fault> {
    room(w, n)?;
    let len = w.len();
    let mut parity = [0u8; ecc_core::MAX_PARITY];
    let kind = protect(w.written(), n, &mut parity);
    if kind != Kind::Ok {
        return Err(fault(kind, len, n));
    }
    w.put(parity.get(..n).unwrap_or(&[]), -1)
}

/// Detect only: the syndromes of a protected message are all zero.
pub(crate) fn detect(message: &[u8], n: usize) -> Result<(), Fault> {
    let outcome = check(message, n);
    if outcome.kind == Kind::Ok {
        return Ok(());
    }
    Err(fault(outcome.kind, message.len(), n))
}

/// Repairs up to `limit` wrong bytes in place; the number fixed. On a refusal the buffer is as it
/// was.
pub(crate) fn fix(message: &mut [u8], n: usize, limit: usize) -> Result<usize, Fault> {
    let len = message.len();
    let outcome = repair(message, n, limit);
    finish(outcome, len, n)
}

/// [`fix`] under a percentage `p` above 0: the limit is 0 to 16 (else `BadValue` before any byte is
/// read), the count comes from the length, and a limit above `n / 2` is lowered to it.
pub(crate) fn fix_percent(
    message: &mut [u8],
    p: usize,
    limit: usize,
) -> Result<(usize, usize), Fault> {
    if limit > ecc_core::MAX_PERCENT_LIMIT {
        return Err(Fault::new(
            Error::BadValue,
            0,
            -1,
            ecc_core::MAX_PERCENT_LIMIT,
        ));
    }
    let len = message.len();
    let n = received_count(len, 0, p)?;
    fix(message, n, limit.min(n / 2)).map(|repaired| (n, repaired))
}

fn finish(outcome: Outcome, len: usize, n: usize) -> Result<usize, Fault> {
    if outcome.kind == Kind::Ok {
        return Ok(outcome.repaired);
    }
    Err(fault(outcome.kind, len, n))
}

//! Message error correction (contract `_docs/02_document/contracts/library/message-ecc.md`).
//!
//! A protected message is the clear message followed by `n` parity bytes of a Reed-Solomon code
//! over GF(256) (field polynomial 0x11D, alpha = 2, generator roots alpha^0 .. alpha^(n-1)). The
//! code word is one byte longer than what is sent: its first byte is the clear length, covered
//! by the code and not sent, so a message with one byte more or less fails the check.
use crate::ecc_core;
use crate::value::{PackError, ShortPacket, UnpackError};
use std::borrow::Cow;

/// The most parity bytes a scheme may declare.
pub const MAX_PARITY: usize = ecc_core::MAX_PARITY;
/// The most bytes a protected message may have: the code word is 255, one byte is not sent.
pub(crate) const MAX_BLOCK: usize = ecc_core::MAX_SENT;

/// Refuses a clear message above `254 - n` bytes (nothing is checked for `n` = 0).
pub(crate) fn check_len(len: usize, n: usize) -> Result<(), PackError> {
    if n > 0 && len > MAX_BLOCK - n {
        return Err(PackError::Type(format!(
            "the clear message is {len} bytes, above the limit of {} bytes ({MAX_BLOCK} minus {n} parity bytes)",
            MAX_BLOCK - n
        )));
    }
    Ok(())
}

/// Appends the parity of `bytes` (a clear message `check_len` accepted).
pub(crate) fn push_parity(bytes: &mut Vec<u8>, n: usize) {
    if n > 0 {
        let mut parity = [0u8; MAX_PARITY];
        ecc_core::protect(bytes, n, &mut parity);
        bytes.extend_from_slice(&parity[..n]);
    }
}

pub(crate) fn append(bytes: &mut Vec<u8>, n: usize) -> Result<(), PackError> {
    check_len(bytes.len(), n)?;
    push_parity(bytes, n);
    Ok(())
}

/// A parity count above 32 (a hand-written handler declares its own) and a correction limit above
/// `n / 2` are refused before any byte is read.
pub(crate) fn check_limit(n: usize, t: usize) -> Result<(), UnpackError> {
    if n > MAX_PARITY {
        return Err(UnpackError::BadParity {
            parity: n,
            max: MAX_PARITY,
        });
    }
    if t > n / 2 {
        return Err(UnpackError::BadLimit {
            limit: t,
            max: n / 2,
        });
    }
    Ok(())
}

/// The clear bytes of a received message and the number of bytes repaired. With `n` = 0 the
/// bytes are returned as they are.
pub(crate) fn unprotect(
    bytes: &[u8],
    n: usize,
    t: usize,
) -> Result<(Cow<'_, [u8]>, usize), UnpackError> {
    check_limit(n, t)?;
    if n == 0 {
        return Ok((Cow::Borrowed(bytes), 0));
    }
    if bytes.len() > MAX_BLOCK {
        return Err(UnpackError::TooLong {
            len: bytes.len(),
            limit: MAX_BLOCK,
        });
    }
    if bytes.len() < n {
        return Err(UnpackError::Short(ShortPacket {
            field: "parity".to_string(),
            needed: n,
            left: bytes.len(),
        }));
    }
    let clear_len = bytes.len() - n;
    if ecc_core::check(bytes, n).kind == ecc_core::Kind::Ok {
        return Ok((Cow::Borrowed(&bytes[..clear_len]), 0));
    }
    let mut word = bytes.to_vec();
    let outcome = ecc_core::repair(&mut word, n, t);
    if outcome.kind != ecc_core::Kind::Ok {
        return Err(UnpackError::Uncorrectable);
    }
    word.truncate(clear_len);
    Ok((Cow::Owned(word), outcome.repaired))
}

/// The parity count all handlers of one dispatch declare, or a refusal naming two that differ.
pub(crate) fn shared_parity(counts: impl IntoIterator<Item = usize>) -> Result<usize, UnpackError> {
    let mut counts = counts.into_iter();
    let first = counts.next().unwrap_or(0);
    match counts.find(|&other| other != first) {
        Some(other) => Err(UnpackError::MixedParity { first, other }),
        None => Ok(first),
    }
}

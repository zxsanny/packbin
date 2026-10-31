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
/// The most a parity percentage may be.
pub(crate) const MAX_PERCENT: usize = 100;
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

/// [`append`] under a fixed count `n`, or under a percentage `p` above 0: the count is then
/// derived from the length, and a clear message above the largest clear length of `p` is refused.
pub(crate) fn append_for(bytes: &mut Vec<u8>, n: usize, p: usize) -> Result<(), PackError> {
    if p == 0 {
        return append(bytes, n);
    }
    let len = bytes.len();
    let limit = ecc_core::largest_clear(p);
    if len > limit {
        return Err(PackError::Type(format!(
            "the clear message is {len} bytes, above the limit of {limit} bytes ({MAX_BLOCK} minus its parity bytes at {p} percent)"
        )));
    }
    push_parity(bytes, ecc_core::parity_count(p, len));
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

/// Like [`unprotect`] for a scheme that declares a percentage `p` above 0 instead of a count: a
/// limit above 16 is refused, the count is found from the received length, and a limit above
/// `n / 2` of this message is lowered to it.
pub(crate) fn unprotect_percent(
    bytes: &[u8],
    p: usize,
    t: usize,
) -> Result<(Cow<'_, [u8]>, usize), UnpackError> {
    check_percent_limit(t)?;
    if bytes.len() > MAX_BLOCK {
        return Err(UnpackError::TooLong {
            len: bytes.len(),
            limit: MAX_BLOCK,
        });
    }
    let Some(clear_len) = ecc_core::clear_length(p, bytes.len()) else {
        return Err(UnpackError::Uncorrectable);
    };
    let n = bytes.len() - clear_len;
    unprotect(bytes, n, t.min(n / 2))
}

/// A correction limit under a percentage is 0 to 16, before any byte is read.
pub(crate) fn check_percent_limit(t: usize) -> Result<(), UnpackError> {
    if t > ecc_core::MAX_PERCENT_LIMIT {
        return Err(UnpackError::BadLimit {
            limit: t,
            max: ecc_core::MAX_PERCENT_LIMIT,
        });
    }
    Ok(())
}

/// [`unprotect`] under a fixed count `n`, or [`unprotect_percent`] when `p` is above 0.
pub(crate) fn unprotect_for(
    bytes: &[u8],
    n: usize,
    p: usize,
    t: usize,
) -> Result<(Cow<'_, [u8]>, usize), UnpackError> {
    if p > 0 {
        unprotect_percent(bytes, p, t)
    } else {
        unprotect(bytes, n, t)
    }
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

/// The setting all handlers of one dispatch declare, a fixed count or a percentage, or a refusal
/// naming two that differ (the count, or the percentage when the handler has one).
pub(crate) fn shared_setting(
    settings: impl IntoIterator<Item = (usize, usize)>,
) -> Result<(usize, usize), UnpackError> {
    let mut settings = settings.into_iter();
    let first = settings.next().unwrap_or((0, 0));
    let shown = |(n, p): (usize, usize)| if p > 0 { p } else { n };
    match settings.find(|&other| other != first) {
        Some(other) => Err(UnpackError::MixedParity {
            first: shown(first),
            other: shown(other),
        }),
        None => Ok(first),
    }
}

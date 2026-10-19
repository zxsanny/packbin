//! Message error correction (contract `_docs/02_document/contracts/library/message-ecc.md`).
//!
//! A protected message is the clear message followed by `n` parity bytes of a Reed-Solomon code
//! over GF(256) (field polynomial 0x11D, alpha = 2, generator roots alpha^0 .. alpha^(n-1)). The
//! code word is one byte longer than what is sent: its first byte is the clear length, covered
//! by the code and not sent, so a message with one byte more or less fails the check.
use crate::value::{PackError, ShortPacket, UnpackError};
use std::borrow::Cow;

/// The most parity bytes a scheme may declare.
pub const MAX_PARITY: usize = 32;
/// The most bytes a protected message may have: the code word is 255, one byte is not sent.
pub(crate) const MAX_BLOCK: usize = 254;

const POLY: u16 = 0x11D;
/// A generator or locator has at most `MAX_PARITY + 1` coefficients.
const WIDTH: usize = MAX_PARITY + 1;

const fn tables() -> ([u8; 512], [u8; 256]) {
    let mut exp = [0u8; 512];
    let mut log = [0u8; 256];
    let mut x: u16 = 1;
    let mut i = 0;
    while i < 255 {
        exp[i] = x as u8;
        log[x as usize] = i as u8;
        x <<= 1;
        if x & 0x100 != 0 {
            x ^= POLY;
        }
        i += 1;
    }
    while i < 512 {
        exp[i] = exp[i - 255];
        i += 1;
    }
    (exp, log)
}

const TABLES: ([u8; 512], [u8; 256]) = tables();
static EXP: [u8; 512] = TABLES.0;
static LOG: [u8; 256] = TABLES.1;

fn mul(a: u8, b: u8) -> u8 {
    if a == 0 || b == 0 {
        0
    } else {
        EXP[LOG[a as usize] as usize + LOG[b as usize] as usize]
    }
}

/// `a` is not 0.
fn inv(a: u8) -> u8 {
    EXP[255 - LOG[a as usize] as usize]
}

/// The monic generator, highest degree first; `n + 1` coefficients.
fn generator(n: usize) -> [u8; WIDTH] {
    let mut g = [0u8; WIDTH];
    g[0] = 1;
    for (len, root) in EXP[..n].iter().enumerate() {
        for j in (0..=len).rev() {
            g[j + 1] ^= mul(g[j], *root);
        }
    }
    g
}

/// The parity of `clear`, in the first `n` bytes of the result: the remainder of
/// `[len(clear)] + clear + n zeros` divided by the generator.
fn parity(clear: &[u8], n: usize) -> [u8; MAX_PARITY] {
    let g = generator(n);
    let mut reg = [0u8; MAX_PARITY];
    for b in std::iter::once(clear.len() as u8).chain(clear.iter().copied()) {
        let feedback = b ^ reg[0];
        reg.copy_within(1..n, 0);
        reg[n - 1] = 0;
        if feedback != 0 {
            for j in 0..n {
                reg[j] ^= mul(g[j + 1], feedback);
            }
        }
    }
    reg
}

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
        let parity = parity(bytes, n);
        bytes.extend_from_slice(&parity[..n]);
    }
}

pub(crate) fn append(bytes: &mut Vec<u8>, n: usize) -> Result<(), PackError> {
    check_len(bytes.len(), n)?;
    push_parity(bytes, n);
    Ok(())
}

/// The syndromes of `word`: the code word is the clear length (word length minus `n`), then
/// the word. All zero means the message is intact.
fn syndromes(word: &[u8], n: usize) -> [u8; MAX_PARITY] {
    let len = (word.len() - n) as u8;
    let mut out = [0u8; MAX_PARITY];
    for (i, slot) in out[..n].iter_mut().enumerate() {
        let alpha = EXP[i];
        let mut s = len;
        for &b in word {
            s = mul(s, alpha) ^ b;
        }
        *slot = s;
    }
    out
}

/// `p`, lowest degree first, at `x`.
fn eval(p: &[u8], x: u8) -> u8 {
    p.iter().rev().fold(0, |y, &c| mul(y, x) ^ c)
}

/// Berlekamp-Massey: the error locator, lowest degree first, without trailing zeros.
fn locator(synd: &[u8], n: usize) -> ([u8; WIDTH], usize) {
    let mut lam = [0u8; WIDTH];
    lam[0] = 1;
    let mut lam_len = 1;
    let mut prev = lam;
    let mut prev_len = 1;
    let (mut l, mut m, mut b) = (0usize, 1usize, 1u8);
    for r in 0..n {
        let mut d = synd[r];
        for i in 1..=l.min(r) {
            if i < lam_len {
                d ^= mul(lam[i], synd[r - i]);
            }
        }
        if d == 0 {
            m += 1;
            continue;
        }
        let before = lam;
        let before_len = lam_len;
        let coef = mul(d, inv(b));
        // The length never passes r + 1 <= n, so every index below is inside WIDTH.
        lam_len = lam_len.max(prev_len + m);
        for i in 0..prev_len {
            lam[i + m] ^= mul(coef, prev[i]);
        }
        if 2 * l <= r {
            l = r + 1 - l;
            prev = before;
            prev_len = before_len;
            b = d;
            m = 1;
        } else {
            m += 1;
        }
    }
    while lam_len > 1 && lam[lam_len - 1] == 0 {
        lam_len -= 1;
    }
    (lam, lam_len)
}

/// Repairs `word` (N sent bytes, `n` parity) in place: at most `t` wrong bytes. Returns how
/// many it repaired, or `Uncorrectable` when the word is not within `t` bytes of a code word.
fn repair(word: &mut [u8], n: usize, t: usize, synd: &[u8]) -> Result<usize, UnpackError> {
    if t == 0 {
        return Err(UnpackError::Uncorrectable);
    }
    let (lam, lam_len) = locator(synd, n);
    let degree = lam_len - 1;
    if degree == 0 || degree > t {
        return Err(UnpackError::Uncorrectable);
    }
    let size = word.len();
    // Position p (0 is the first sent byte) has the locator alpha^(size - 1 - p); it is wrong
    // when the locator polynomial is 0 at the inverse of that.
    let mut roots = [0usize; MAX_PARITY / 2];
    let mut found = 0;
    for p in 0..size {
        let inverse = EXP[(255 - (size - 1 - p)) % 255];
        if eval(&lam[..lam_len], inverse) == 0 {
            if found == degree {
                return Err(UnpackError::Uncorrectable);
            }
            roots[found] = p;
            found += 1;
        }
    }
    if found != degree {
        return Err(UnpackError::Uncorrectable);
    }
    let mut omega = [0u8; MAX_PARITY];
    for i in 0..n {
        for (j, &c) in lam[..lam_len].iter().enumerate() {
            if i + j < n {
                omega[i + j] ^= mul(synd[i], c);
            }
        }
    }
    // The formal derivative in characteristic 2 keeps the odd-degree terms.
    let mut derivative = [0u8; WIDTH];
    for i in (1..lam_len).step_by(2) {
        derivative[i - 1] = lam[i];
    }
    for &p in &roots[..degree] {
        let x = EXP[(size - 1 - p) % 255];
        let inverse = inv(x);
        let denominator = eval(&derivative[..lam_len - 1], inverse);
        if denominator == 0 {
            return Err(UnpackError::Uncorrectable);
        }
        word[p] ^= mul(x, mul(eval(&omega[..n], inverse), inv(denominator)));
    }
    if syndromes(word, n).iter().any(|&s| s != 0) {
        return Err(UnpackError::Uncorrectable);
    }
    Ok(degree)
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
    let synd = syndromes(bytes, n);
    if synd[..n].iter().all(|&s| s == 0) {
        return Ok((Cow::Borrowed(&bytes[..clear_len]), 0));
    }
    let mut word = bytes.to_vec();
    let repaired = repair(&mut word, n, t, &synd)?;
    word.truncate(clear_len);
    Ok((Cow::Owned(word), repaired))
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

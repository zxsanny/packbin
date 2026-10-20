//! The Reed-Solomon core of the message error correction (contract
//! `_docs/02_document/contracts/library/message-ecc.md`), shared by the `std` walker and the
//! heap-free API (the C++ `ecc.hpp` port).
//!
//! A protected message is the clear message followed by `n` parity bytes of a code over GF(256)
//! (field polynomial 0x11D, alpha = 2, generator roots alpha^0 .. alpha^(n-1)). The code word is
//! one byte longer than what is sent: its first byte is the clear length, covered by the code and
//! not sent, so a message with one byte more or less fails the check.
//!
//! Fixed buffers on the stack, tables in read-only data, no allocation and no panic path: every
//! read goes through `get` and every sum is checked or saturating.
#![deny(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

/// The most parity bytes a scheme may declare.
pub const MAX_PARITY: usize = 32;
/// The most bytes a protected message may have: the code word is 255, one byte is not sent.
pub const MAX_SENT: usize = 254;

const POLY: u16 = 0x11D;
/// A generator or locator has at most `MAX_PARITY + 1` coefficients.
const WIDTH: usize = MAX_PARITY + 1;

/// Why a call was refused.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Ok,
    /// More wrong bytes than the limit allows (or the syndromes are not zero and the limit is 0).
    Uncorrectable,
    /// Fewer than `n` bytes received.
    Short,
    /// A clear message above `254 - n`, or a received buffer above 254.
    TooLong,
    /// `n` outside 0 to 32.
    BadParity,
    /// A limit outside 0 to `n / 2`.
    BadLimit,
}

/// The kind and, for a repair, the wrong bytes found and fixed (0 for an intact buffer).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Outcome {
    pub kind: Kind,
    pub repaired: usize,
}

const fn refused(kind: Kind) -> Outcome {
    Outcome { kind, repaired: 0 }
}

const OK: Outcome = refused(Kind::Ok);

#[allow(clippy::indexing_slicing, clippy::arithmetic_side_effects)]
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

fn log_of(a: u8) -> usize {
    LOG.get(usize::from(a)).copied().map_or(0, usize::from)
}

/// alpha^e for any `e`.
fn alpha(e: usize) -> u8 {
    EXP.get(e % 255).copied().unwrap_or(0)
}

fn mul(a: u8, b: u8) -> u8 {
    if a == 0 || b == 0 {
        return 0;
    }
    EXP.get(log_of(a).saturating_add(log_of(b)))
        .copied()
        .unwrap_or(0)
}

/// `a` is not 0.
fn inv(a: u8) -> u8 {
    alpha(255usize.saturating_sub(log_of(a)))
}

fn at(a: &[u8], i: usize) -> u8 {
    a.get(i).copied().unwrap_or(0)
}

fn xor_at(a: &mut [u8], i: usize, v: u8) {
    if let Some(slot) = a.get_mut(i) {
        *slot ^= v;
    }
}

/// The monic generator, highest degree first; `n + 1` coefficients.
fn generator(n: usize) -> [u8; WIDTH] {
    let mut g = [0u8; WIDTH];
    if let Some(first) = g.first_mut() {
        *first = 1;
    }
    for i in 0..n {
        let root = alpha(i);
        for j in (1..=i.saturating_add(1)).rev() {
            let term = mul(at(&g, j.saturating_sub(1)), root);
            xor_at(&mut g, j, term);
        }
    }
    g
}

/// Writes the `n` parity bytes of `clear` to the start of `parity_out` (nothing for `n` = 0 or on
/// a refusal). A protected message is the clear bytes followed by these.
pub fn protect(clear: &[u8], n: usize, parity_out: &mut [u8]) -> Kind {
    if n > MAX_PARITY {
        return Kind::BadParity;
    }
    if n == 0 {
        return Kind::Ok;
    }
    if clear.len() > MAX_SENT.saturating_sub(n) {
        return Kind::TooLong;
    }
    let Some(reg) = parity_out.get_mut(..n) else {
        return Kind::BadParity;
    };
    for slot in reg.iter_mut() {
        *slot = 0;
    }
    let g = generator(n);
    // Division by g, one byte at a time: the first byte is the clear length, then the clear bytes.
    let head = u8::try_from(clear.len()).unwrap_or(0);
    for input in core::iter::once(head).chain(clear.iter().copied()) {
        let feedback = input ^ at(reg, 0);
        for j in 0..n {
            let next = at(reg, j.saturating_add(1));
            let tap = mul(at(&g, j.saturating_add(1)), feedback);
            if let Some(slot) = reg.get_mut(j) {
                *slot = next ^ tap;
            }
        }
    }
    Kind::Ok
}

/// The syndromes of `word` (clear then parity), `n` of them; the code word is the clear length
/// (word length minus `n`), then the word. True when any is not 0.
fn syndromes(word: &[u8], n: usize, s: &mut [u8; MAX_PARITY]) -> bool {
    let sent_clear = u8::try_from(word.len().saturating_sub(n)).unwrap_or(0);
    let mut any = 0u8;
    for (i, slot) in s.iter_mut().enumerate().take(n) {
        let mut acc = sent_clear;
        for byte in word {
            let step = if acc == 0 {
                0
            } else {
                alpha(log_of(acc).saturating_add(i))
            };
            acc = step ^ byte;
        }
        *slot = acc;
        any |= acc;
    }
    any != 0
}

/// Berlekamp-Massey: the error locator, lowest degree first, in `lam[0..=n]`; returns its degree.
fn locator(s: &[u8; MAX_PARITY], n: usize, lam: &mut [u8; WIDTH]) -> usize {
    let mut prev = [0u8; WIDTH];
    let mut keep = [0u8; WIDTH];
    *lam = [0u8; WIDTH];
    if let Some(first) = lam.first_mut() {
        *first = 1;
    }
    if let Some(first) = prev.first_mut() {
        *first = 1;
    }
    let (mut l, mut m, mut b) = (0usize, 1usize, 1u8);
    for r in 0..n {
        let mut d = at(s, r);
        for i in 1..=l {
            d ^= mul(at(lam, i), at(s, r.saturating_sub(i)));
        }
        if d == 0 {
            m = m.saturating_add(1);
            continue;
        }
        let grows = l.saturating_mul(2) <= r;
        if grows {
            keep = *lam;
        }
        let coef = mul(d, inv(b));
        // x^m * prev has degree at most r + 1 - l <= n, so the loop bound loses no term.
        let mut i = 0usize;
        while i.saturating_add(m) <= n {
            xor_at(lam, i.saturating_add(m), mul(coef, at(&prev, i)));
            i = i.saturating_add(1);
        }
        if grows {
            prev = keep;
            l = r.saturating_add(1).saturating_sub(l);
            b = d;
            m = 1;
        } else {
            m = m.saturating_add(1);
        }
    }
    let mut deg = n;
    while deg > 0 && at(lam, deg) == 0 {
        deg = deg.saturating_sub(1);
    }
    deg
}

/// The polynomial `p` (lowest degree first) at `x`.
fn poly_at(p: &[u8], x: u8) -> u8 {
    p.iter().rev().fold(0, |y, c| mul(y, x) ^ c)
}

/// The refusals every entry point shares once `n` is known to be 1 to 32.
fn size_kind(size: usize, n: usize) -> Kind {
    if size > MAX_SENT {
        Kind::TooLong
    } else if size < n {
        Kind::Short
    } else {
        Kind::Ok
    }
}

/// Whether the `n` syndromes of a received buffer (clear then parity) are all zero. `Ok`: intact.
/// `Uncorrectable`: not intact (detection only; it does not look for the wrong bytes).
pub fn check(word: &[u8], n: usize) -> Outcome {
    if n > MAX_PARITY {
        return refused(Kind::BadParity);
    }
    if n == 0 {
        return OK;
    }
    let size = size_kind(word.len(), n);
    if size != Kind::Ok {
        return refused(size);
    }
    let mut s = [0u8; MAX_PARITY];
    if syndromes(word, n, &mut s) {
        return refused(Kind::Uncorrectable);
    }
    OK
}

/// Repairs up to `t` wrong bytes of `word` in place (`t` from 0 to `n / 2`). `Ok` with the number
/// of bytes fixed (0 when intact). On any refusal the buffer is left exactly as it was: the repair
/// is verified on the syndromes before a byte is written. Refusals are decided in the order of
/// the reference: `n`, `t`, then `n` = 0 (nothing to do), length, syndromes.
pub fn repair(word: &mut [u8], n: usize, t: usize) -> Outcome {
    if n > MAX_PARITY {
        return refused(Kind::BadParity);
    }
    if t > n / 2 {
        return refused(Kind::BadLimit);
    }
    if n == 0 {
        return OK;
    }
    let size = word.len();
    let kind = size_kind(size, n);
    if kind != Kind::Ok {
        return refused(kind);
    }
    let mut s = [0u8; MAX_PARITY];
    if !syndromes(word, n, &mut s) {
        return OK;
    }
    if t == 0 {
        return refused(Kind::Uncorrectable);
    }
    let uncorrectable = refused(Kind::Uncorrectable);

    let mut lam = [0u8; WIDTH];
    let deg = locator(&s, n, &mut lam);
    if deg == 0 || deg > t {
        return uncorrectable;
    }

    // Position p (0 = first sent byte) has locator X = alpha^(size - 1 - p); it is wrong when
    // lam(X^-1) = 0. The unsent length byte cannot be wrong: a root there makes the count differ.
    let mut pos = [0usize; MAX_PARITY / 2];
    let mut found = 0usize;
    for p in 0..size {
        let back = size.saturating_sub(1).saturating_sub(p);
        let coefficients = lam.get(..deg.saturating_add(1)).unwrap_or(&[]);
        if poly_at(coefficients, alpha(255usize.saturating_sub(back))) != 0 {
            continue;
        }
        if found == deg {
            return uncorrectable;
        }
        if let Some(slot) = pos.get_mut(found) {
            *slot = p;
        }
        found = found.saturating_add(1);
    }
    if found != deg {
        return uncorrectable;
    }

    // omega = (S * lam) mod x^n.
    let mut omega = [0u8; MAX_PARITY];
    for i in 0..n {
        for j in 0..=deg {
            if i.saturating_add(j) < n {
                xor_at(&mut omega, i.saturating_add(j), mul(at(&s, i), at(&lam, j)));
            }
        }
    }

    // Error value at p: X * omega(X^-1) / lam'(X^-1); lam' keeps the odd-degree terms.
    let mut value = [0u8; MAX_PARITY / 2];
    for k in 0..deg {
        let back = size.saturating_sub(1).saturating_sub(at_usize(&pos, k));
        let xi = alpha(255usize.saturating_sub(back));
        let mut den = 0u8;
        for i in (1..=deg).rev() {
            let term = if i & 1 != 0 { at(&lam, i) } else { 0 };
            den = mul(den, xi) ^ term;
        }
        if den == 0 {
            return uncorrectable;
        }
        let num = poly_at(omega.get(..n).unwrap_or(&[]), xi);
        if let Some(slot) = value.get_mut(k) {
            *slot = mul(alpha(back), mul(num, inv(den)));
        }
    }

    // The syndromes of the repaired word, without writing it: byte p weighs alpha^(i * back).
    for i in 0..n {
        let mut after = at(&s, i);
        for k in 0..deg {
            let back = size.saturating_sub(1).saturating_sub(at_usize(&pos, k));
            after ^= mul(at(&value, k), alpha(i.saturating_mul(back)));
        }
        if after != 0 {
            return uncorrectable;
        }
    }
    for k in 0..deg {
        xor_at(word, at_usize(&pos, k), at(&value, k));
    }
    Outcome {
        kind: Kind::Ok,
        repaired: deg,
    }
}

fn at_usize(a: &[usize], i: usize) -> usize {
    a.get(i).copied().unwrap_or(0)
}

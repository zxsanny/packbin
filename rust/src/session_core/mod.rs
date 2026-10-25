//! The pad, hash and key derivation of the session, shared by the `std` `PackSession` and the heap-free
//! `nostd::Session`: fixed buffers on the stack, no allocation, no panic path.

#[cfg(all(test, feature = "std"))]
pub(crate) mod counters;
pub(crate) mod hkdf;
#[cfg(feature = "frame")]
pub(crate) mod hmac;
pub(crate) mod pad;
pub(crate) mod sha256;

#[cfg(any(feature = "std", feature = "session"))]
pub(crate) const SEED_SIZE: usize = 32;
#[cfg(any(feature = "std", feature = "session"))]
pub(crate) const NONCE_SIZE: usize = 16;

#[cfg(any(feature = "std", feature = "session"))]
/// The send and receive keys of a session opened with `nonce` (any other length is the caller's
/// check): the first 32 bytes of HKDF-SHA-256 output belong to the initiator's send side.
pub(crate) fn split_keys(
    seed: &[u8; SEED_SIZE],
    nonce: &[u8],
    initiator: bool,
) -> ([u8; SEED_SIZE], [u8; SEED_SIZE]) {
    let mut both = [0u8; SEED_SIZE * 2];
    hkdf::derive(seed, nonce, b"packbin", &mut both);
    let mut first = [0u8; SEED_SIZE];
    let mut second = [0u8; SEED_SIZE];
    for (slot, byte) in first.iter_mut().zip(both.iter()) {
        *slot = *byte;
    }
    for (slot, byte) in second.iter_mut().zip(both.iter().skip(SEED_SIZE)) {
        *slot = *byte;
    }
    for byte in both.iter_mut() {
        *byte = 0;
    }
    if initiator {
        (first, second)
    } else {
        (second, first)
    }
}

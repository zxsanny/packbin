//! The hash, MAC, key derivation and cipher of frame mode (`nostd::FrameSession`): fixed buffers on
//! the stack, no allocation, no panic path.

#[cfg(all(test, feature = "std"))]
pub(crate) mod counters;
pub(crate) mod hkdf;
#[cfg(feature = "frame")]
pub(crate) mod hmac;
pub(crate) mod pad;
pub(crate) mod sha256;
pub(crate) mod wipe;

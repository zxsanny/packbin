//! HMAC-SHA-256 with the key blocks compressed once: a key is two 8-word chaining states (64 bytes), so a
//! call costs the message's own compressions plus one for the outer hash. Fixed buffers, no heap, no panic path.
use super::sha256::{midstate, Sha256};
use super::wipe::wipe;

const BLOCK: usize = 64;

/// The inner and outer pad states of one 32-byte HMAC key.
pub(crate) struct Pads {
    inner: [u32; 8],
    outer: [u32; 8],
}

fn pad_block(key: &[u8; 32], pad: u8) -> [u8; BLOCK] {
    let mut block = [pad; BLOCK];
    for (slot, byte) in block.iter_mut().zip(key) {
        *slot = *byte ^ pad;
    }
    block
}

impl Pads {
    /// Zero states: a slot for a direction that was not loaded.
    pub(crate) const fn empty() -> Self {
        Pads {
            inner: [0u32; 8],
            outer: [0u32; 8],
        }
    }

    pub(crate) fn new(key: &[u8; 32]) -> Self {
        let mut ipad = pad_block(key, 0x36);
        let mut opad = pad_block(key, 0x5c);
        let pads = Pads {
            inner: midstate(&ipad),
            outer: midstate(&opad),
        };
        wipe(&mut ipad);
        wipe(&mut opad);
        pads
    }

    /// HMAC-SHA-256 of the pieces of a message joined, with no buffer for the joined message.
    pub(crate) fn mac(&self, parts: &[&[u8]]) -> [u8; 32] {
        let mut inner = Sha256::resume(self.inner, BLOCK as u64);
        for part in parts {
            inner.update(part);
        }
        let digest = inner.finish();
        let mut outer = Sha256::resume(self.outer, BLOCK as u64);
        outer.update(&digest);
        outer.finish()
    }

    /// Overwrites both states through the volatile wipe.
    pub(crate) fn wipe(&mut self) {
        wipe(&mut self.inner);
        wipe(&mut self.outer);
    }
}

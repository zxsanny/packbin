//! The MAC-only call: a tag without encryption, for a per-hop network check and for key fingerprints.

use super::{ct_eq, refuse, salt, MAX_EPOCH};
use crate::nostd::error::{Error, Fault};
use crate::session_core::{hkdf, hmac::Pads, wipe::wipe};

/// An HMAC-SHA-256 key derived from a 32-byte key, an epoch and a label, with its pad states
/// computed once. 68 bytes, no heap. Debug prints the epoch only.
pub struct MacKey {
    pads: Pads,
    epoch: u32,
}

impl MacKey {
    /// `K_label = HKDF(key, "packbin-frame" ‖ epoch, 0x00 ‖ label)`. An epoch above 0xFFFFFF, or a label
    /// that is not 1 to 32 bytes, is `BadValue`.
    pub fn derive(key: &[u8; 32], epoch: u32, label: &[u8]) -> Result<MacKey, Fault> {
        if epoch > MAX_EPOCH || label.is_empty() || label.len() > 32 {
            return Err(refuse(Error::BadValue, 0));
        }
        let mut info = [0u8; 33];
        for (slot, byte) in info.iter_mut().skip(1).zip(label) {
            *slot = *byte;
        }
        let used = label.len().saturating_add(1);
        let mut derived = [0u8; 32];
        hkdf::derive(
            key,
            &salt(epoch),
            info.get(..used).unwrap_or(&[]),
            &mut derived,
        );
        let pads = Pads::new(&derived);
        wipe(&mut derived);
        Ok(MacKey { pads, epoch })
    }

    /// The epoch the key was derived for.
    pub fn epoch(&self) -> u32 {
        self.epoch
    }

    /// Writes the first `out.len()` bytes of the HMAC of the pieces of a message joined; `out.len()` is 4,
    /// 8, 16 or 32, any other length is `BadValue` and nothing is written.
    pub fn tag(&self, parts: &[&[u8]], out: &mut [u8]) -> Result<(), Fault> {
        if !matches!(out.len(), 4 | 8 | 16 | 32) {
            return Err(refuse(Error::BadValue, 4));
        }
        let full = self.pads.mac(parts);
        for (slot, byte) in out.iter_mut().zip(full.iter()) {
            *slot = *byte;
        }
        Ok(())
    }

    /// True when `tag` (4, 8, 16 or 32 bytes) is the tag of the message; compares every byte without an
    /// early exit.
    pub fn verify(&self, parts: &[&[u8]], tag: &[u8]) -> bool {
        if !matches!(tag.len(), 4 | 8 | 16 | 32) {
            return false;
        }
        let full = self.pads.mac(parts);
        ct_eq(full.get(..tag.len()).unwrap_or(&[]), tag)
    }
}

impl Drop for MacKey {
    fn drop(&mut self) {
        self.pads.wipe();
    }
}

impl core::fmt::Debug for MacKey {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("MacKey")
            .field("epoch", &self.epoch)
            .finish_non_exhaustive()
    }
}

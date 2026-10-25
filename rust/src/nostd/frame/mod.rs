//! Frame mode of the session (`pack-session.md` 2.0.0): sealed, authenticated frames for links that lose,
//! reorder and duplicate messages. A frame is `clear part ‖ ciphertext ‖ tag`: ChaCha20 under a key per
//! (key, epoch, direction) from HKDF-SHA-256, a nonce built from the caller's 8-byte `msg_id`, the
//! `kind` nibble, the direction and the epoch, and a tag that is the first 4, 8 or 16 bytes of
//! HMAC-SHA-256 over the nonce, the associated data, the clear part and the ciphertext (encrypt, then MAC).
//! [`Session::open_frame`] checks the caller's replay window first (no hashing for a duplicate or an old
//! counter), then the tag in constant time, then decrypts into the caller's buffer, which is untouched
//! unless the frame opened; a previous (key, epoch) can open frames sealed just before a key change.
//! [`MacKey`] is the MAC-only call. No heap, no panic path, no `unsafe`.
//!
//! **For one key, epoch and direction, never seal two different messages with the same `msg_id`.** Reuse
//! breaks the confidentiality of both messages and the library cannot check it (meshbell builds `msg_id`
//! from the source, the id field and the creation wave, so it is unique by construction). A new epoch
//! derives new keys and nonces.
#![forbid(unsafe_code)]

mod mac;
mod seal;
mod window;

use super::error::{Error, Fault};
use super::session::Session;
use crate::session_core::{hkdf, hmac::Pads};

pub use mac::MacKey;
pub use window::{Freshness, ReplayWindow};

/// The longest frame body: clear part, ciphertext and tag together.
pub const MAX_BODY: usize = 255;
pub(super) const MAX_EPOCH: u32 = 0x00FF_FFFF;
const LABEL: &[u8; 13] = b"packbin-frame";

pub(super) fn refuse(error: Error, needed: usize) -> Fault {
    Fault::new(error, 0, -1, needed)
}

/// `"packbin-frame" ‖ epoch` as a 32-bit little-endian integer.
pub(super) fn salt(epoch: u32) -> [u8; 17] {
    let mut out = [0u8; 17];
    for (slot, byte) in out
        .iter_mut()
        .zip(LABEL.iter().chain(epoch.to_le_bytes().iter()))
    {
        *slot = *byte;
    }
    out
}

/// True when the slices are equal; folds every byte, so the time does not depend on where they differ.
pub(super) fn ct_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut diff = 0u8;
    for (x, y) in a.iter().zip(b) {
        diff |= *x ^ *y;
    }
    core::hint::black_box(diff) == 0
}

/// The direction of a frame.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Direction {
    Up = 1,
    Down = 2,
    Group = 3,
}

impl Direction {
    pub(super) const fn index(self) -> usize {
        match self {
            Direction::Up => 0,
            Direction::Down => 1,
            Direction::Group => 2,
        }
    }

    const fn bit(self) -> u8 {
        match self {
            Direction::Up => 1,
            Direction::Down => 2,
            Direction::Group => 4,
        }
    }
}

/// The directions a session loaded.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Directions(u8);

impl Directions {
    pub const NONE: Directions = Directions(0);
    pub const ALL: Directions = Directions(7);

    /// The set with `direction` added.
    pub const fn with(self, direction: Direction) -> Directions {
        Directions(self.0 | direction.bit())
    }

    pub const fn contains(self, direction: Direction) -> bool {
        self.0 & direction.bit() != 0
    }
}

/// What a frame-mode session is loaded with besides the key.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct FrameConfig {
    /// The tag bytes: 4, 8 or 16, fixed for the lifetime of the loaded key.
    pub tag_len: u8,
    pub directions: Directions,
}

/// What the caller supplies per message. `msg_id` must be unique per (key, epoch, direction) for every
/// message ever sealed (see the module note); `kind` is 0 to 15.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MsgCtx {
    pub msg_id: [u8; 8],
    pub kind: u8,
}

/// Which loaded key opened a frame.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Slot {
    Current,
    Previous,
}

/// What an opened frame reports.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Opened {
    pub slot: Slot,
    pub clear_len: usize,
    pub plain_len: usize,
}

/// The encryption key and the MAC pad states of one direction.
pub(super) struct DirKeys {
    enc: [u8; 32],
    pads: Pads,
}

impl DirKeys {
    const fn empty() -> Self {
        DirKeys {
            enc: [0u8; 32],
            pads: Pads::empty(),
        }
    }

    fn derive(key: &[u8; 32], epoch: u32, direction: Direction) -> Self {
        let salt = salt(epoch);
        let d = direction as u8;
        let mut enc = [0u8; 32];
        hkdf::derive(key, &salt, &[d, b'e', b'n', b'c'], &mut enc);
        let mut mac = [0u8; 32];
        hkdf::derive(key, &salt, &[d, b'm', b'a', b'c'], &mut mac);
        let pads = Pads::new(&mac);
        for byte in mac.iter_mut() {
            *byte = 0;
        }
        DirKeys { enc, pads }
    }
}

/// The keys of one (key, epoch) for the loaded directions.
pub(super) struct SlotKeys {
    epoch: u32,
    dirs: [DirKeys; 3],
}

impl SlotKeys {
    fn derive(key: &[u8; 32], epoch: u32, directions: Directions) -> Self {
        let one = |direction: Direction| {
            if directions.contains(direction) {
                DirKeys::derive(key, epoch, direction)
            } else {
                DirKeys::empty()
            }
        };
        SlotKeys {
            epoch,
            dirs: [
                one(Direction::Up),
                one(Direction::Down),
                one(Direction::Group),
            ],
        }
    }

    fn dir(&self, direction: Direction) -> Option<&DirKeys> {
        self.dirs.get(direction.index())
    }
}

impl Drop for SlotKeys {
    /// Overwrites the keys and pad states (best effort: the compiler is asked to keep the writes).
    fn drop(&mut self) {
        for keys in self.dirs.iter_mut() {
            for byte in keys.enc.iter_mut() {
                *byte = 0;
            }
            keys.pads.wipe();
        }
        core::hint::black_box(&mut self.dirs);
    }
}

/// The frame half of a [`Session`].
pub(super) struct FrameState {
    tag_len: u8,
    directions: Directions,
    current: SlotKeys,
    previous: Option<SlotKeys>,
}

fn check_load(epoch: u32) -> Result<(), Fault> {
    if epoch > MAX_EPOCH {
        return Err(refuse(Error::BadValue, 0));
    }
    Ok(())
}

impl Session {
    /// A frame-mode session: keys for each loaded direction are derived once, here. A `tag_len` that is
    /// not 4, 8 or 16, or an `epoch` above 0xFFFFFF, is [`Error::BadValue`]. A stream call on this
    /// session is `BadValue`, and a frame call on a stream session is `BadValue`.
    pub fn load_frame(key: &[u8; 32], epoch: u32, config: FrameConfig) -> Result<Session, Fault> {
        check_load(epoch)?;
        if !matches!(config.tag_len, 4 | 8 | 16) {
            return Err(refuse(Error::BadValue, 4));
        }
        Ok(Session::with_frame(FrameState {
            tag_len: config.tag_len,
            directions: config.directions,
            current: SlotKeys::derive(key, epoch, config.directions),
            previous: None,
        }))
    }

    /// Keeps a previous (key, epoch) that [`Session::open_frame`] tries when the current key's tag does not
    /// match (the key just replaced, for frames sealed before the change). Seal never uses it.
    pub fn set_previous(&mut self, key: &[u8; 32], epoch: u32) -> Result<(), Fault> {
        check_load(epoch)?;
        let state = self
            .frame
            .as_mut()
            .ok_or_else(|| refuse(Error::BadValue, 0))?;
        state.previous = Some(SlotKeys::derive(key, epoch, state.directions));
        Ok(())
    }

    /// Drops the previous (key, epoch) and overwrites its keys.
    pub fn clear_previous(&mut self) {
        if let Some(state) = self.frame.as_mut() {
            state.previous = None;
        }
    }
}

#[cfg(test)]
impl Session {
    /// The encryption key of `direction` and the HMAC of the probe message `probe` under its MAC key.
    pub(crate) fn test_material(
        &self,
        direction: Direction,
        probe: &[u8],
    ) -> Option<([u8; 32], [u8; 32])> {
        let keys = self.frame.as_ref()?.current.dir(direction)?;
        Some((keys.enc, keys.pads.mac(&[probe])))
    }
}

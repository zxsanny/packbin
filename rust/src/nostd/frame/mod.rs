//! Frame mode of the session (`pack-session.md` 2.0.0): sealed, authenticated frames for links that lose,
//! reorder and duplicate messages. A frame is `clear part ‖ ciphertext ‖ tag`: ChaCha20 under a key per
//! (key, epoch, direction) from HKDF-SHA-256, a nonce built from the caller's 8-byte `msg_id`, the
//! `kind` nibble, the direction and the epoch, and a tag that is the first 4, 8 or 16 bytes of
//! HMAC-SHA-256 over the nonce, the associated data, the clear part and the ciphertext (encrypt, then MAC).
//! [`FrameSession::open_frame`] checks the caller's replay window first (no hashing for a duplicate or an
//! old counter), then the tag in constant time, then decrypts into the caller's buffer, which is untouched
//! unless the frame opened; a previous (key, epoch) can open frames sealed just before a key change.
//! [`MacKey`] is the MAC-only call. No heap, no panic path, no `unsafe`.
//!
//! **For one key, epoch and direction, never seal two different messages with the same `msg_id`.** Reuse
//! breaks the confidentiality of both messages and the library cannot check it (meshbell builds `msg_id`
//! from the source, the id field and the creation wave, so it is unique by construction). A new epoch
//! derives new keys and nonces.
//!
//! ```
//! use packbin::nostd::{Fault, FrameConfig, FrameDirection, FrameDirections, FrameSession, MacKey, MsgContext, ReplayWindow};
//!
//! fn main() -> Result<(), Fault> {
//!     let key = [0x11u8; 32];
//!     let config = FrameConfig { tag_len: 4, directions: FrameDirections::NONE.with(FrameDirection::Up) };
//!     let node = FrameSession::load_frame(&key, 1, config)?;
//!     let ctx = MsgContext { msg_id: [0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0], kind: 4 };
//!     let ad = [0u8, 1, 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0, 4]; // the header: authenticated, not sent
//!
//!     let mut body = [0u8; 255];
//!     let n = node.seal_frame(FrameDirection::Up, &ctx, &ad, &[], b"hello, relay", &mut body)?;
//!     assert_eq!(n, 12 + 4); // the plaintext and a 4-byte tag
//!
//!     let mut window = ReplayWindow::new();
//!     let mut plain = [0u8; 255];
//!     let opened = node.open_frame(FrameDirection::Up, &ctx, &ad, &body[..n], 0, Some((&mut window, 7)), &mut plain)?;
//!     assert_eq!(&plain[..opened.plain_len], b"hello, relay");
//!     // the same frame again is a duplicate: refused before any hashing
//!     assert!(node.open_frame(FrameDirection::Up, &ctx, &ad, &body[..n], 0, Some((&mut window, 7)), &mut plain).is_err());
//!
//!     // the MAC-only call: a 4-byte tag over a message in parts
//!     let mac = MacKey::derive(&[0x22; 32], 7, b"net")?;
//!     let mut tag = [0u8; 4];
//!     mac.tag(&[b"wave", b"frame bytes"], &mut tag)?;
//!     assert!(mac.verify(&[b"wave", b"frame bytes"], &tag));
//!     Ok(())
//! }
//! ```
#![forbid(unsafe_code)]

mod mac;
mod seal;
mod window;

use super::error::{Error, Fault};
use crate::session_core::{hkdf, hmac::Pads, wipe::wipe};

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
pub enum FrameDirection {
    Up = 1,
    Down = 2,
    Group = 3,
}

impl FrameDirection {
    pub(super) const fn index(self) -> usize {
        match self {
            FrameDirection::Up => 0,
            FrameDirection::Down => 1,
            FrameDirection::Group => 2,
        }
    }

    const fn bit(self) -> u8 {
        match self {
            FrameDirection::Up => 1,
            FrameDirection::Down => 2,
            FrameDirection::Group => 4,
        }
    }
}

/// The directions a session loaded.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FrameDirections(u8);

impl FrameDirections {
    pub const NONE: FrameDirections = FrameDirections(0);
    pub const ALL: FrameDirections = FrameDirections(7);

    /// The set with `direction` added.
    pub const fn with(self, direction: FrameDirection) -> FrameDirections {
        FrameDirections(self.0 | direction.bit())
    }

    pub const fn contains(self, direction: FrameDirection) -> bool {
        self.0 & direction.bit() != 0
    }
}

/// What a frame-mode session is loaded with besides the key.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct FrameConfig {
    /// The tag bytes: 4, 8 or 16, fixed for the lifetime of the loaded key.
    pub tag_len: u8,
    pub directions: FrameDirections,
}

/// What the caller supplies per message. `msg_id` must be unique per (key, epoch, direction) for every
/// message ever sealed (see the module note); `kind` is 0 to 15.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MsgContext {
    pub msg_id: [u8; 8],
    pub kind: u8,
}

/// Which loaded key opened a frame.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FrameSlot {
    Current,
    Previous,
}

/// What an opened frame reports.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct FrameOpened {
    pub slot: FrameSlot,
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

    /// Fills `self` in place (a 96-byte slot is written where it lives, not built and copied).
    fn fill(&mut self, key: &[u8; 32], epoch: u32, direction: FrameDirection) {
        let salt = salt(epoch);
        let d = direction as u8;
        hkdf::derive(key, &salt, &[d, b'e', b'n', b'c'], &mut self.enc);
        let mut mac = [0u8; 32];
        hkdf::derive(key, &salt, &[d, b'm', b'a', b'c'], &mut mac);
        self.pads = Pads::new(&mac);
        wipe(&mut mac);
    }

    fn wipe(&mut self) {
        wipe(&mut self.enc);
        self.pads.wipe();
    }
}

/// The keys of one (key, epoch) for the loaded directions.
pub(super) struct SlotKeys {
    epoch: u32,
    dirs: [DirKeys; 3],
}

impl SlotKeys {
    #[inline(always)]
    const fn empty() -> Self {
        SlotKeys {
            epoch: 0,
            dirs: [DirKeys::empty(), DirKeys::empty(), DirKeys::empty()],
        }
    }

    /// Derives the keys of each loaded direction into `self`.
    fn fill(&mut self, key: &[u8; 32], epoch: u32, directions: FrameDirections) {
        self.epoch = epoch;
        for direction in [
            FrameDirection::Up,
            FrameDirection::Down,
            FrameDirection::Group,
        ] {
            if let Some(keys) = self.dirs.get_mut(direction.index()) {
                if directions.contains(direction) {
                    keys.fill(key, epoch, direction);
                } else {
                    keys.wipe();
                }
            }
        }
    }

    fn dir(&self, direction: FrameDirection) -> Option<&DirKeys> {
        self.dirs.get(direction.index())
    }
}

impl SlotKeys {
    /// Overwrites the keys and pad states in place through the volatile wipe.
    fn wipe(&mut self) {
        self.epoch = 0;
        for keys in self.dirs.iter_mut() {
            keys.wipe();
        }
    }
}

impl Drop for SlotKeys {
    fn drop(&mut self) {
        self.wipe();
    }
}

/// A frame-mode session: the keys derived from a shared 32-byte key and epoch
/// ([`FrameSession::load_frame`]). Not `Clone`, so the keys live in one place; its frame state wipes them
/// when the session is dropped.
pub struct FrameSession {
    frame: FrameState,
}

/// The keys and settings of a [`FrameSession`]; `loaded` is false until the keys are derived into it.
pub(super) struct FrameState {
    loaded: bool,
    tag_len: u8,
    directions: FrameDirections,
    current: SlotKeys,
    previous: SlotKeys,
    has_previous: bool,
}

impl FrameState {
    pub(super) const fn empty() -> Self {
        FrameState {
            loaded: false,
            tag_len: 0,
            directions: FrameDirections::NONE,
            current: SlotKeys::empty(),
            previous: SlotKeys::empty(),
            has_previous: false,
        }
    }

    pub(super) fn previous(&self) -> Option<&SlotKeys> {
        self.has_previous.then_some(&self.previous)
    }
}

fn check_load(epoch: u32) -> Result<(), Fault> {
    if epoch > MAX_EPOCH {
        return Err(refuse(Error::BadValue, 0));
    }
    Ok(())
}

impl FrameSession {
    /// A session with no keys: every call on it is refused. A constant, so a caller that is short of stack
    /// declares it where it lives and loads into it with [`FrameSession::load_frame_in_place`].
    pub const fn frame_unloaded() -> FrameSession {
        FrameSession {
            frame: FrameState::empty(),
        }
    }

    /// Derives the keys of each loaded direction into this session, in place (nothing of the 600-byte
    /// session is built elsewhere and copied). A `tag_len` that is not 4, 8 or 16 or an `epoch` above
    /// 0xFFFFFF is [`Error::BadValue`]. Loading again replaces the keys and drops the previous slot.
    pub fn load_frame_in_place(
        &mut self,
        key: &[u8; 32],
        epoch: u32,
        config: FrameConfig,
    ) -> Result<(), Fault> {
        check_load(epoch)?;
        if !matches!(config.tag_len, 4 | 8 | 16) {
            return Err(refuse(Error::BadValue, 4));
        }
        let state = &mut self.frame;
        state.loaded = false;
        state.tag_len = config.tag_len;
        state.directions = config.directions;
        state.previous.wipe();
        state.has_previous = false;
        state.current.fill(key, epoch, config.directions);
        state.loaded = true;
        Ok(())
    }

    /// A frame-mode session: keys for each loaded direction are derived once, here (see
    /// [`FrameSession::load_frame_in_place`], which does the same without moving the session).
    pub fn load_frame(
        key: &[u8; 32],
        epoch: u32,
        config: FrameConfig,
    ) -> Result<FrameSession, Fault> {
        let mut session = FrameSession::frame_unloaded();
        session.load_frame_in_place(key, epoch, config)?;
        Ok(session)
    }

    pub(super) fn frame_state(&self) -> Option<&FrameState> {
        self.frame.loaded.then_some(&self.frame)
    }

    /// Keeps a previous (key, epoch) that [`FrameSession::open_frame`] tries when the current key's tag does
    /// not match (the key just replaced, for frames sealed before the change). Seal never uses it.
    pub fn set_previous(&mut self, key: &[u8; 32], epoch: u32) -> Result<(), Fault> {
        check_load(epoch)?;
        if !self.frame.loaded {
            return Err(refuse(Error::BadValue, 0));
        }
        let directions = self.frame.directions;
        self.frame.previous.fill(key, epoch, directions);
        self.frame.has_previous = true;
        Ok(())
    }

    /// Drops the previous (key, epoch) and overwrites its keys.
    pub fn clear_previous(&mut self) {
        self.frame.previous.wipe();
        self.frame.has_previous = false;
    }
}

// The cfg of the callers, frame_hostile_tests and frame_core_tests (lib.rs).
#[cfg(all(test, feature = "std", feature = "frame"))]
impl FrameSession {
    /// True when no byte of the previous slot's keys is set.
    pub(crate) fn test_previous_is_zero(&self) -> bool {
        let slot = &self.frame.previous;
        slot.epoch == 0
            && slot
                .dirs
                .iter()
                .all(|k| k.enc.iter().all(|b| *b == 0) && k.pads.mac(&[]) == Pads::empty().mac(&[]))
    }

    /// The encryption key of `direction` and the HMAC of the probe message `probe` under its MAC key.
    pub(crate) fn test_material(
        &self,
        direction: FrameDirection,
        probe: &[u8],
    ) -> Option<([u8; 32], [u8; 32])> {
        let keys = self.frame_state()?.current.dir(direction)?;
        Some((keys.enc, keys.pads.mac(&[probe])))
    }
}

//! The session of the heap-free API: frame mode (`pack-session.md` 2.0.0, the `frame` module) is its only
//! mode. The derived keys live in the frame state, which wipes them when the session is dropped.

/// A frame-mode session: the keys derived from a shared 32-byte key and epoch ([`Session::load_frame`]).
/// Not `Clone`, so the keys live in one place.
pub struct Session {
    /// The frame-mode keys, set by `load_frame` (`frame` module).
    pub(super) frame: super::frame::FrameState,
}

impl Session {
    /// A session with no keys at all and zeroed frame slots: a constant, so it is written where it is declared.
    pub(super) const fn unloaded() -> Session {
        Session {
            frame: super::frame::FrameState::empty(),
        }
    }
}

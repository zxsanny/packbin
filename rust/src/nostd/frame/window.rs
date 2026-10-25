//! The replay window of frame mode: the highest counter a sender's frames reached and which of the 64
//! counters up to it were seen. The caller owns one per sender and passes the counter with each open.

/// What the window says about a counter.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Freshness {
    /// Not seen, and not older than the window.
    Fresh,
    /// Already committed.
    Duplicate,
    /// 64 or more behind the highest committed counter.
    TooOld,
}

/// Highest committed counter (`top`) and a bit per counter below it (`bits`: bit i set means `top - i`
/// was committed); `bits == 0` is an empty window. 16 bytes.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct ReplayWindow {
    top: u64,
    bits: u64,
}

impl ReplayWindow {
    /// An empty window: every counter is fresh.
    pub const fn new() -> Self {
        ReplayWindow { top: 0, bits: 0 }
    }

    /// A window restored from `parts` (for example saved before a restart). `bits == 0` is empty.
    pub const fn from_parts(top: u64, bits: u64) -> Self {
        ReplayWindow { top, bits }
    }

    /// `(top, bits)`.
    pub const fn parts(&self) -> (u64, u64) {
        (self.top, self.bits)
    }

    /// What the window says about `counter`. Never changes the state.
    pub fn check(&self, counter: u64) -> Freshness {
        if self.bits == 0 || counter > self.top {
            return Freshness::Fresh;
        }
        let behind = self.top.saturating_sub(counter);
        if behind >= 64 {
            return Freshness::TooOld;
        }
        let seen = self
            .bits
            .checked_shr(u32::try_from(behind).unwrap_or(64))
            .unwrap_or(0)
            & 1;
        if seen == 1 {
            Freshness::Duplicate
        } else {
            Freshness::Fresh
        }
    }

    /// Records `counter`. `open_frame` calls this only after a frame opened; a counter 64 or more behind
    /// the highest is ignored.
    pub fn commit(&mut self, counter: u64) {
        if self.bits == 0 {
            self.top = counter;
            self.bits = 1;
        } else if counter > self.top {
            let shift = counter.saturating_sub(self.top);
            let moved = self
                .bits
                .checked_shl(u32::try_from(shift).unwrap_or(64))
                .unwrap_or(0);
            self.bits = moved | 1;
            self.top = counter;
        } else {
            let behind = self.top.saturating_sub(counter);
            let bit = 1u64
                .checked_shl(u32::try_from(behind).unwrap_or(64))
                .unwrap_or(0);
            self.bits |= bit;
        }
    }
}

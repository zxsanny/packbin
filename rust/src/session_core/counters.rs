//! Test-only counters of the work a call did, per thread: SHA-256 compressions and ChaCha20 blocks.
use std::cell::Cell;

thread_local! {
    static SHA: Cell<usize> = const { Cell::new(0) };
    static CHACHA: Cell<usize> = const { Cell::new(0) };
}

pub(crate) fn sha_compression() {
    SHA.with(|c| c.set(c.get() + 1));
}

pub(crate) fn chacha_block() {
    CHACHA.with(|c| c.set(c.get() + 1));
}

/// (compressions, blocks) since the last call to `take` on this thread.
#[cfg(feature = "frame")]
pub(crate) fn take() -> (usize, usize) {
    (SHA.with(|c| c.replace(0)), CHACHA.with(|c| c.replace(0)))
}

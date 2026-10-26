---
loop: 73
branch: dev
---

# Loop 73: wipe the Rust HKDF temporaries (AZ-3199 follow-up)

Phase 1 grasp confirmed (owner, 2026-10-26, AskQuestion at loop start, recommended option "Rust HKDF wipes").

## What

`rust/src/session_core/hkdf.rs` derives the frame-mode keys (`nostd/frame/mod.rs`, `nostd/frame/mac.rs`) and the stream session keys (`session_core/mod.rs` `split_keys`). Its callers already clear what they receive. Its own temporaries (the key-and-pad `block`, the inner `digest`, `prk`, `previous` and the SHA-256 states that hold the key's midstate) are left on the stack. Loop 72 cleared the same temporaries in C#, Java and Swift; this loop does it in Rust. Wire bytes do not change.

## Code sections / UI locations for this loop

Owner words: the chosen option named `rust/src/session_core/hkdf.rs` and "clear block, digest, prk, previous and the SHA-256 key states before return, as loop 72 did in C#, Java, Swift. Wire bytes unchanged; re-measure the Rust M4F/M33F pins."

## Flagged concerns

Filled in Phase 2.

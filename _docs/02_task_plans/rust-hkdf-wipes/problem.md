---
loop: 73
branch: dev
---

# Loop 73: wipe Rust key material with one volatile helper (AZ-3199 follow-up)

Phase 1 grasp confirmed (owner, 2026-10-26, AskQuestion at loop start, recommended option "Rust HKDF wipes"). Wipe method decided (owner, 2026-10-26, AskQuestion "Wipe method", recommended option "Accept recommended").

## What

Loop 72 made C#, Java and Swift overwrite every temporary that held key-derived bytes (review items 5 to 8 and 10 of loop 71). The Rust package is the reference for those three, and it has two gaps of the same kind:

1. **Temporaries left on the stack.** `rust/src/session_core/hkdf.rs` derives the frame-mode keys (`nostd/frame/mod.rs`, `nostd/frame/mac.rs`) and the stream session keys (`session_core/mod.rs` `split_keys`). Its callers clear what they receive. Its own temporaries are never cleared: the key-and-pad `block`, the inner `digest`, `prk`, `previous`, and the two SHA-256 hashers whose `state` holds the key's midstate. `rust/src/session_core/pad.rs` (the ChaCha20 stream pad of both sessions and the frame cipher) never clears `state` (which holds the key words), `work` or the keystream `pad`. C# and Java clear both since loop 72 (`SessionPad`, item 6).
2. **The wipe method is a hint.** The Rust wipes that exist write zeros and then call `core::hint::black_box`. The Rust documentation says `black_box` is best effort and programs cannot rely on it for correctness, so the compiler may still drop the zero writes as dead stores. `split_keys` and `PackSession::open` (std) clear with a plain loop or `fill(0)` and no hint at all.

The owner chose one wipe helper in `session_core`: a volatile write per element (`core::ptr::write_volatile`, which the compiler must not remove) followed by `core::sync::atomic::compiler_fence`, in one documented `unsafe` block. Every Rust wipe calls it: the new ones of item 1 and the existing ones of item 2. This is how the RustCrypto `zeroize` crate works inside; the crate has no dependency today and keeps none. The SHA-256 round schedule window (`w` in `compress`, 16 words) is wiped at the end of every compression: owner, 2026-10-26, after the security review showed that the window gives back the whole block hashed (at key load, the key XOR a pad). This replaced the first answer (leave it), which rested on the agent's wrong description of the window ("256 B", "key-derived words").

Wire bytes do not change: the 27 rows of `fixtures/crypto/vectors.txt`, the 157 rows of `fixtures/frame/vectors.txt` and the stream session vectors stay byte for byte as they are.

Who: meshbell's Rust side and the nRF54L15 firmware run this code (`target-chip`: Cortex-M33F), through the `session` and `frame` features of the heap-free API and the std `PackSession`.

## Code sections / UI locations for this loop

Owner words: the chosen option named `rust/src/session_core/hkdf.rs` and "clear block, digest, prk, previous and the SHA-256 key states before return, as loop 72 did in C#, Java, Swift. Wire bytes unchanged; re-measure the Rust M4F/M33F pins." The second answer: "One wipe helper in session_core (write_volatile + compiler_fence, one documented unsafe block) used by the new HKDF wipes and the ~6 existing black_box wipes. SHA-256 round schedule left, documented as in the managed packages."

Sites (agent's read of the named code; every one is a wipe the owner's answer covers):

| File | Temporaries | Today |
|------|-------------|-------|
| `rust/src/session_core/hkdf.rs` | `hmac_sha256`: `block`, `digest`, the `inner` and `outer` hashers; `derive`: `prk`, `previous` (also on the two early returns) | not wiped |
| `rust/src/session_core/sha256.rs` | hasher `state` and `block` (a wipe the HKDF hashers can call; `compress` round schedule `w` excluded) | not wiped |
| `rust/src/session_core/pad.rs` | `block`: `state`, `work`; `xor`, `xor_with_nonce`: keystream `pad` | not wiped |
| `rust/src/session_core/hmac.rs` | `Pads::new` `ipad`, `opad`; `Pads::wipe` | `black_box` |
| `rust/src/session_core/mod.rs` | `split_keys` `both` | plain loop |
| `rust/src/session/mod.rs` | `PackSession::open` `seed` | `fill(0)` |
| `rust/src/nostd/session.rs` | `wipe` (seed, send and receive keys at drop) | `black_box` |
| `rust/src/nostd/frame/mod.rs` | `fill` `mac`; key slot `wipe` (`enc`, pads); `SlotKeys::wipe` (`dirs`) | `black_box` |
| `rust/src/nostd/frame/mac.rs` | `MacKey::derive` `derived`; drop | `black_box` |

Read only: `fixtures/crypto/vectors.txt`, `fixtures/frame/vectors.txt`, `_docs/02_document/contracts/library/pack-session.md` (2.0.0), `rust/embedded/limits.txt`, `rust/embedded/limits-m33f.txt` (re-pinned by this loop). `nostd/frame/mod.rs:89` (`black_box` in the constant-time compare) is not a wipe and stays.

## Figures on HEAD (96a2cd3 + intake 72beacb), this loop

`rust/embedded/run.sh host`, 2026-10-26, Rust 1.98.1 libraries, exit 0 (log in the session scratchpad, `rust-embedded-head.log`):

```
rust-m4f   SIZE base    flash=15060 B (limit 16384) stack=456 B (limit 512)
rust-m4f   SIZE text    flash=27156 B (limit 27964) stack=2736 B (limit 2898)
rust-m4f   SIZE ecc     flash=18692 B (limit 18879) stack=744 B (limit 798)
rust-m4f   SIZE session flash=18812 B (limit 19325) stack=1528 B (limit 1924)
rust-m4f   SIZE frame   flash=20164 B (limit 20480) stack=1752 B (limit 1991)
rust-m33f  SIZE base    flash=15132 B (limit 15132) stack=456 B (limit 456)
rust-m33f  SIZE text    flash=27268 B (limit 27268) stack=2736 B (limit 2736)
rust-m33f  SIZE ecc     flash=18764 B (limit 18764) stack=744 B (limit 744)
rust-m33f  SIZE session flash=18884 B (limit 18884) stack=1528 B (limit 1528)
rust-m33f  SIZE frame   flash=20236 B (limit 20236) stack=1752 B (limit 1752)
```

The M4F frame set has 316 B of flash left under the owner's bound of 20,480 B. The M33F pins equal the measured figures, so every byte this loop adds to `session` or `frame` re-pins that row.

## Flagged concerns

| concern | policy / owner | status | severity |
| --- | --- | --- | --- |
| `black_box` is a hint; wipes need a write the compiler keeps | owner, 2026-10-26: one volatile helper for every Rust wipe | resolved | Medium |
| One `unsafe` block in a crate whose `frame` module forbids `unsafe` | owner, 2026-10-26 (same answer): the helper lives in `session_core`; `frame` keeps `#![forbid(unsafe_code)]` | resolved | Low |
| The SHA-256 round schedule window equals the last block hashed (key XOR pad at key load) | owner, 2026-10-26, after the security review: wipe it at the end of every compression (the first answer, leave it, is replaced); the working words stay in registers or spills (L73-1) | resolved | Low |
| Moves and by-value returns (`hmac_sha256` and `split_keys` results, `Pads` from `Pads::new`) can leave copies no code can reach; Rust guarantees nothing about them (the `zeroize` docs say the same) | the contract keeps "best effort"; the Rust description names the limit (L73-1) | open | Low |
| Three more clears per ChaCha20 block slow the stream pad and the frame cipher; no Rust timing check covers the pad | AC-6 (ratio measured beside a HEAD copy in this loop) | open | Low |
| The M4F frame set has 316 B of flash under its owner bound of 20,480 B | AC-5.2: a figure above the bound stops the loop for the owner | open | Low |
| The std `PackSession` keeps its send and receive keys until the memory is reused (no `Drop`), as the managed stream sessions do | out of scope, candidate for a later loop | open | Low |

Acceptance criteria: `acceptance_criteria.md`. Expected results: `input_data/expected_results/results_report.md`.

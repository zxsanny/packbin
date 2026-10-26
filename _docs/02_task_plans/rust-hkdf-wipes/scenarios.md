# Scenarios — loop 73, Rust wipes

Source: `new-task` Step 4.7 (3 points: up to 8 rows). Fit analysis found no collision that needs an owner choice: the M33F pins move by design (owner: "re-measure the Rust M4F/M33F pins"), and the M4F frame bound is a stop condition in AC-5.2, not a card.

## Fit (Part A)

| Component / flow | Today | After | Who depends on today | Collision |
|------------------|-------|-------|----------------------|-----------|
| Rust key derivation (`hkdf.rs`) | temporaries left on the stack | cleared by volatile writes before every return | frame keys, MAC keys, stream session keys | none: output bytes unchanged |
| Rust stream pad (`pad.rs`) | ChaCha20 state, work and keystream left on the stack | cleared per block and per call | std and heap-free stream sessions, frame cipher | none: bytes unchanged; a little slower (AC-6) |
| Existing Rust wipes | zero writes plus `black_box`, or plain loops | one volatile helper | session and frame drop, key load | none |
| Embedded rows | M33F pins equal HEAD; M4F frame 316 B under its bound | `session` and `frame` re-pinned on M33F; M4F within its limits | `rust-embedded` CI job | none beyond AC-5 |

## Matrix (Part B)

| # | Actor | Trigger | State | Proposed behavior | Status | AC |
|---|-------|---------|-------|-------------------|--------|----|
| 1 | Rust app | opens a stream session (`split_keys`) | first use | send and receive keys as at HEAD; `both`, `prk`, `previous`, `block`, `digest` and both hashers cleared | confirmed | AC-2, AC-4, AC-7 |
| 2 | Rust app | loads a frame session, then rotates to a new epoch | repeat | each key slot fill derives as at HEAD and clears its temporaries every time | confirmed | AC-2, AC-4, AC-7 |
| 3 | Rust app | asks `derive` for more than 255 blocks, or the output slice ends early | partial failure | the early return clears `prk` and `previous` as the normal end does | confirmed | AC-2.2 |
| 4 | Rust app | `MacKey::derive` with an epoch above 0xFFFFFF or a bad label | invalid input | `BadValue` before any key is derived; nothing to clear | confirmed | inherited (loop 69) |
| 5 | Rust app | HMAC with a key longer than 64 bytes (hashed key path) | boundary | `block` cleared as for a short key; the hash result moved into the block is a by-value copy (L73-1) | confirmed | AC-2.1, AC-4.2 |
| 6 | Two threads, std | each runs its own `PackSession` | concurrent | no shared state; each call clears its own stack | confirmed | AC-7 |
| 7 | Rust app | drops a heap-free `Session`, a frame session or a `MacKey` | existing data | seed, keys and pads cleared through the helper | confirmed | AC-4.1 |
| 8 | Firmware build | `session` or `frame` embedded set | existing-feature overlap | links with no heap and no panic path; figures within AC-5.2 | confirmed | AC-5 |

No `unknown` row. No problem card.

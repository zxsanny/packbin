# Scenarios — remove-stream-session

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A v0.3.0 user calls `PackSession` after upgrading | confirmed | The type is gone (compile or import error); the README change history names frame mode as the session | AZ-3281..AZ-3288 AC-1; AZ-3291 AC-1 | intake |
| S2 | meshbell's Rust code uses the heap-free frame `Session` | confirmed | It is `FrameSession` with the D1 names; the bytes are the same; the rename is documented for meshbell, not made there | AZ-3289 AC-1, AC-2 | intake D1 |
| S3 | A Rust user enables the `session` Cargo feature | confirmed | Cargo refuses the unknown feature; `frame` builds alone and with `text,ecc` | AZ-3284 AC-1, AC-2 | inventory |
| S4 | A frame user seals and opens after the renames | confirmed | The 157 frame rows give the same bytes and results in Rust, C#, Java, Swift | AZ-3281, AZ-3282, AZ-3285 AC-2; AZ-3289 AC-2; AZ-3290 AC-2 | intake |
| S5 | A scheme with parity bytes is packed and unpacked in the clear | confirmed | Unchanged; the ECC fixtures and every package's ECC tests pass | AZ-3281 AC-3, AZ-3282 AC-3, AZ-3283 AC-3, AZ-3284 AC-5, AZ-3285 AC-4, AZ-3286 AC-4, AZ-3287 AC-3, AZ-3288 AC-3 | inventory §3 |
| S6 | The ring runs every driver pair | confirmed | Clear and ECC stages pass 8 x 8; the `pack-session` and `pack-session-ecc` stages and commands are gone | AZ-3280 AC-1, AC-2 | inventory §4 |
| S7 | The Rust embedded stage builds every set on M4F and M33F | confirmed | No `session` set; `frame` within its pins (re-pinned if it moves, reported); `base`, `text`, `ecc` move by 0 B | AZ-3284 AC-4; AZ-3289 AC-2 | measured on HEAD |
| S8 | The C++ embedded stage and the ESP-IDF example build | confirmed | The pinned images keep their pins; the vector runners pass without session tests; the ESP-IDF example builds with no session | AZ-3286 AC-3, AC-4 | inventory §6 |
| S9 | A Java caller passes an int direction (`FrameSession.UP`) | confirmed | Compile error; the caller passes a `FrameDirection`; frame bytes unchanged | AZ-3290 AC-1, AC-3 | intake D1 |
| S10 | The crypto vectors run in each package | confirmed | 27 of 27 rows in all 8 packages; C++, Go, Python, TypeScript through an internal module | AZ-3283, AZ-3286, AZ-3287, AZ-3288 AC-2; AZ-3281, AZ-3282, AZ-3285 AC-2; AZ-3284 AC-3 | intake D2 |
| S11 | The hostile corpus is loaded (its `ring_session` line) | confirmed | Kept as plain hostile input; loaders count lines dynamically | AZ-3284 AC-5; AZ-3283 AC-3; AZ-3285 AC-4 | inventory §4 |
| S12 | A Go or npm consumer installs the next release | confirmed | No new dependency; `golang.org/x/crypto` and `@noble/hashes` stay (the internal ChaCha20, HKDF) | AZ-3287 AC-3; AZ-3288 AC-3 | intake D2 |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | Removing `PackSession` breaks its users (v0.1.x to v0.3.0) | Remove now; 0.x minor step; release notes (owner, "Stream mode": Remove it) | yes (problem.md flagged concerns; ADR-009) |
| 2 | Frame type names differ between Rust, C#, Java, Swift; four ports would copy them | One set, the C# names; Java gets a `FrameDirection` enum (D1) | yes (AC-4; ADR-009) |
| 3 | The HKDF and ChaCha20 of C++, Go, Python, TypeScript lose their only caller | Move to an internal module tested on the 27 crypto rows (D2) | yes (AC-5) |

## Not walked

- Permission denied, undo, concurrent: a library removal has no actor roles; concurrency of frame mode is unchanged (its rules are in the contract).

## Assessment round 1

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| D6 | A Java caller loads a frame session | confirmed | `FrameSession.load(key, epoch, FrameConfig)` with `FrameConfig(tagLength, FrameDirections)`, the shape of Rust, C# and Swift; the varargs load is gone (owner, 2026-10-27, option A) | AZ-3322 AC-1..AC-4 | assess-round-1 |

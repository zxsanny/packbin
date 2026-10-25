# Handoff to loop 72

From the loop 71 record (`record71.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 71

Frame mode (contract `pack-session.md` 2.0.0, ADR 008) in the C#, Java and Swift packages (AZ-3232, AZ-3233, AZ-3234, docs AZ-3235; epic AZ-3199): `FrameSession`, `ReplayWindow` and `MacKey` beside the stream `PackSession`, equal to the Rust bytes on the 157 rows of `fixtures/frame/vectors.txt` and the 27 rows of `fixtures/crypto/vectors.txt`; README examples checked by `scripts/frame/readme-examples.sh` (a `test.yml` step); independent security review with the Java Medium fixed by documentation, the body read once, the platform fixed-time compare.

## First actions of loop 72

0. CI of the loop 71 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`; read the `csharp`, `java`, `swift` jobs (Swift on Linux uses swift-crypto, which the worker could not run; the Docker swift stage did pass here) and the `README examples` step.
1. Check `uptime` before any total run: loop 71's first step 11 took over two hours at host load 112 (an unrelated `tippecanoe` job) and three publish-gate shares failed on environment errors; stop and rerun alone at load below 30.
2. Retro: not due (last loop 69; next after loop 73 or an incident).

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row.
- Frame mode: the order of the other four packages (Python, TypeScript, C++, Go); PB-02 vector tests there; a cross-language frame ring; a replay window per key slot (F69-2); whether `frame` is on with `std`; hardening of the `hkdf.rs` temporaries.
- Story points of AZ-3232..3235 (sent as "Story point estimate", not echoed).

## Candidates (not specs yet)

- Frame mode in Python and TypeScript (the Go and C++ packages after), with the same fixtures and README check.
- A cross-language frame ring (`fixtures/frame/ring-cases.txt` is optional and absent).
- The carried security Lows: compile the key-reading test hooks out of release builds; wipe the ChaCha state in C# and Java `SessionPad` (shared stream code); per-instance Java MAC counter; align C# `Load` for an empty direction set; C# `Seal` with overlapping buffers.
- Unchanged: Go window floor of 10 s; `item` pointer removal; `session_core` clippy; ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

- **L71-1**: constant-time compare and key wipe are best effort in managed runtimes (documented in the API docs and the README); do not describe them as guarantees.
- **L71-2**: `setPrevious`, `clearPrevious` and `close` must not run beside `seal` or `open` in C#, Java and Swift (documented); a caller that rotates keys under load needs its own lock.
- **L71-3**: `scripts/loop-tests.sh` runs everything in the publish gate when `README.md` or `test.yml` changes; the gate fails if the tree changes while it runs (about 6 minutes on a quiet host).

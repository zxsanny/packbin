# Handoff to loop 73

From the loop 72 record (`record72.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 72

Frame hardening in C#, Java and Swift (AZ-3254, AZ-3255, AZ-3256; epic AZ-3199). This closes loop 71 review items 5 to 8 and 10:
- Pad and HMAC temporaries are wiped, including Java HKDF T(i) and the Swift stream keys.
- Java counts MACs per instance and has no static mutable state.
- C# `Load` with no direction builds a refusing session.
- C# `Seal` gives the same bytes when its buffers overlap.
- Test hooks use each language's official own-tests visibility (owner decision B): Swift `package` in place of `@_spi(Vectors)`, C# `internal`, Java package-private.

Wire bytes are unchanged. The security review passed with no finding.

## First actions of loop 73

0. CI of the loop 72 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`. Read the Swift jobs: `package` access on Linux CI, and the `speed` part's release test build, which now needs no extra flag. Read any red job's log before calling it a flake (`gh api .../jobs/<id>/logs`).
1. Check `uptime` and `ps -Ao pcpu,command -r | head` before any total run.
2. Retro: due after loop 73 (the last one covered loop 69).

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row.
- Frame mode: the order for the other four packages (Python, TypeScript, C++, Go); PB-02 vector tests there; a cross-language frame ring; a replay window per key slot (F69-2, a contract change); whether `frame` is on with `std`; hardening of the Rust `hkdf.rs` temporaries.

## Candidates (not specs yet)

- Frame mode in Python and TypeScript, then Go and C++, with the same fixtures and README check. No named consumer yet (meshbell's are Rust, C#, Java and Swift).
- A cross-language frame ring (`fixtures/frame/ring-cases.txt`, which is optional and absent).
- The Rust `hkdf.rs` temporaries (`prk`, `previous` and pad blocks; this moves the embedded figures, so run the M4F and M33F rows).
- Unchanged: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

- **L72-1**: a Swift test hook must be `package`, never `@_spi` or `@testable`. `@testable` breaks the release test build (`run-suite.sh` `swift_speed`), because SwiftPM compiles every test file into one bundle.
- **L71-1** (unchanged): constant-time compare and key wipe are best effort in managed runtimes.
- **L71-2** (unchanged): `setPrevious`, `clearPrevious` and `close` must not run beside `seal` or `open`.

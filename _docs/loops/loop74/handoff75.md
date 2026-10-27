# Handoff to loop 75

From the loop 74 record (`record74.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close; the four frame ports wait in `_docs/02_tasks/backlog/`.

## Shipped in loop 74

The stream session is removed from all eight packages (ADR-009, contract `pack-session.md` 3.0.0); frame mode is the one session:
- Tasks AZ-3280..AZ-3291 and AZ-3322 (13 tasks, 38 points): ring and CI first, then C#, Java, Python, Rust, Swift, C++, Go, TypeScript, the frame type names (D1), docs, and Java `FrameConfig` / `FrameDirections`.
- One set of frame names in Rust, C#, Java and Swift: `FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey` (Java adds `FrameSealed`). Rust and Swift renamed, Java moved its nested types out and replaced int directions with an enum.
- C++, Go, Python and TypeScript keep SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 in an internal module checked on the 27 rows of `fixtures/crypto/vectors.txt` (D2). C++ also has `crypto_tests.cpp`, which runs on the Cortex-M3, Cortex-M33F and big-endian s390x vector runners (security review F1).
- Frame bytes, the frame and crypto fixtures and every Rust embedded figure are unchanged (M4F frame 20,332 B of 20,480; M33F pins 20,404 B / 1,728 B).

## First actions of loop 75

0. CI of the loop 74 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`; read any red job's log before calling it a flake.
1. Check `uptime`, `ps -Ao pcpu,command -r | head` and that the Mac stays awake (a laptop sleep put 2.5 hours into the loop 74 step 11 timings; ask the app to keep it awake before a total run).
2. Loop 75 is the four frame-mode ports, already specified in `_docs/02_tasks/backlog/` (move them to `todo/` at intake): AZ-3292 C++, AZ-3293 Go, AZ-3294 Python, AZ-3295 TypeScript, 5 points each. Each ports the `FrameSession`, `ReplayWindow` and `MacKey` of the contract (3.0.0), under the D1 names, to 157 of 157 `fixtures/frame/vectors.txt` rows, on top of its internal crypto module. Disjoint packages: one wave of four workers, the parent applies README hunks (one writer) and the contract consumer list.
3. Retro: the last one covers loop 74 (this loop only); next due after loop 79.

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the order and scope of any later frame work.
- The next 0.x release notes the removal of `PackSession` and the frame renames (README upgrade note is written); meshbell (another repository) renames its Rust `Session` to `FrameSession`.
- Whether to add a cross-language frame ring (`fixtures/frame/ring-cases.txt`) once the ports land.
- A public-key pairing step (each device derives its frame key by X25519 against a pinned gateway key): a candidate from the loop 74 intake, not decided.

## Candidates (not specs yet)

- Pre-existing issues found on the way (each exists at 10cc0be): the C# and Java `edges` hostile probes print "FAIL dict: NFC and NFD forms of é are two keys" (probably against the loop 42 ascending dict-key rule); `fixtures/hostile/fuzz/csharp/PackbinProbe.csproj` also compiles `ns20/Program.cs` (fix: `<Compile Remove="ns20/**" />`); `cargo test --no-default-features --features frame` over all targets fails to compile (std-only test files lack `#![cfg(feature = "std")]`).
- The Swift DocC catalog's "whole API" list names no frame types; the vcpkg `supports: linux | osx` line was justified by `os_random`, which is gone (`publish-embedded.sh`, ADR-003 line 48).
- A runtime check of the C++ `chacha20_xor` count-down loop on a 16-bit `size_t` (AVR runs no tests; an emulator is needed).
- Test and probe names that still say "Session" (`EccSessionTextTests`, `TopRangeAndSessionTests`, `fuzz_ecc_session.py` / `.ts`): names only.
- Review notes accepted under D2 (F2, F3): the internal crypto ships in the Arduino library, the npm tarball (`dist/crypto.js`, unreachable through `exports`), the Python wheel and the C++ static library; `@noble/hashes` and `golang.org/x/crypto` install with no caller until loop 75.
- **Go intermittent failure (open, L74-3)**: in the last-but-one loop 74 smoke run the Go step (`go test -race` in `golang:1.27`) failed once with `FAIL github.com/zxsanny/packbin/go 87.215s` and the failing test is unknown (the script then discarded its logs); the same code passed 7 other times (step 11, a standalone run, 3 repeats of the step, the earlier smoke run, the final smoke run). `smoke74.sh` now keeps all step logs in `$TMPDIR/smoke74-failed-logs` and names failing Go tests; if it fails again, read the name first. Timing tests with a load factor are the usual suspects (`speed_test.go`, `dict_order_test.go`, `ecc_repair_test.go`, `hostile_loader_test.go`, `text_concurrency_test.go`).
- Unchanged: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part; a `Drop` wipe for std Rust sessions is moot (the std `PackSession` is gone).

## Risks

- **L74-1**: while C++, Go, Python and TypeScript have no session, a caller there has no encryption in packbin at all; frame mode comes with loop 75.
- **L74-2**: a total step 11 across a laptop sleep reports wall time (Swift 7,489 s, ring 3,525 s in loop 74); the pass/fail result is valid, the durations are not.
- **L74-3**: see the Go intermittent failure above; one failing run in eight is not yet a diagnosis.
- **L73-1** (unchanged): a volatile wipe reaches only the memory it is given; Rust moves and by-value returns can leave copies (`load_frame` returns by value; use `load_frame_in_place` on a device); the M4F `frame` set has 148 B of flash left.
- **L72-1** (unchanged): a Swift test hook must be `package`.
- **L71-1, L71-2** (unchanged): constant-time compare and wipe are best effort in managed runtimes; `setPrevious`, `clearPrevious`, `close` must not run beside `seal` or `open`.

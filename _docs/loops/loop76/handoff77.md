# Handoff to loop 77

From the loop 76 record (`record76.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 76

The hygiene items of `handoff75.md` and `handoff76.md` (tasks AZ-3329..AZ-3334, 12 points, epic AZ-2645): the C# hostile probe runs and the four `edges` probes (C#, Java, Python, TypeScript) pass the NFC/NFD case in ascending key order; the timing selftest reads its checks without pipes from `printf` and prints the matched text on a failure; every Rust feature set compiles its tests; the Swift DocC lists the 10 frame types; ADR-003 and the C++ description carry the live Windows reason; two C# test classes and two fuzz probes lost the "Session" name. Frame bytes, fixtures, the contract and every embedded pin are unchanged.

## First actions of loop 77

0. CI of the loop 76 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`; read any red job's log before calling it a flake.
1. Check `uptime` and `ps -Ao pcpu,command -r | head`; a total run is not a result above load 60.
2. Pick the work: the owner input below, or the candidates. No spec is ready.

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`.
- Whether the vcpkg port drops `supports: linux | osx` and claims Windows (needs a Windows build and test first).
- Whether to add a cross-language frame ring (`fixtures/frame/ring-cases.txt`); a public-key pairing step (loop 74 intake, not decided).

## Candidates (not specs yet)

- Four dead-code warnings print in the `frame` and `text,ecc,frame` Rust test builds, all in `cfg(test)` items (`nostd/frame/mod.rs` `test_previous_is_zero` and `test_material`, `session_core/hkdf.rs` `hmac_sha256_of`, `session_core/pad.rs` `block_of`), and one in the default build (`session_core/counters.rs` `take`): a cfg-only cleanup with `cfg(all(test, feature = "std"))`; it cannot move an embedded pin.
- `swift/Sources/Packbin/PackbinError.swift:4-5` says every raw value is a shared hostile-vector outcome term; false for the four frame kinds.
- DocC link resolution (`swift package generate-documentation`) was not run; `cargo test --all-features --no-run` is not in the matrix.
- The AVR runtime check of the C++ `chacha20_xor` count-down loop on a 16-bit `size_t` (needs an emulator).
- Unchanged from `handoff75.md`: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.
- Review Infos of loop 75 not acted on: C++ `MsgContext` default is a valid all-zero id; a `close` racing an `open` (C++, Python, TypeScript); the README examples use an all-zero key with the comment "use a random key".
- Go intermittent failure L74-3: did not show in loop 76; keep `smoke` logs on a failure.

## Risks

- **L76-1**: the cause of the timing-selftest flake (L75-2) is unproven; the selftest now prints the text it matched against, so the next failure is readable.
- **L76-2**: two vcpkg checks print NOT RUN on this Mac (no vcpkg tool); CI runs them.
- **L75-1, L74-2, L73-1, L72-1, L71-1, L71-2** (unchanged): see `handoff76.md` and `handoff75.md`.

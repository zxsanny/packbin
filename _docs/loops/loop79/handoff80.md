# Handoff to loop 80

From the loop 79 record (`record79.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 79

AZ-3356 and AZ-3357 (5 points, no epic):
- One number range rule in all 8 frame drivers and the ring loader: `dir`, `tag_len`, `kind`, `n` 0 to 255; `epoch` 0 to 4,294,967,295; `out_len`, `clear_len` 0 to 65,535. Digits only; out of range is a malformed line. The C#, C++ and Go wraps and the huge-`out_len` aborts are gone.
- Six rows at the top of the ranges (`refusals <lang>: 43 rows`). The checker prints `... and N more` after 5 lines.
- The Java driver answers `BadValue` itself for an epoch above 2,147,483,647, because the Java package's epoch is an `int` (owner, U2).
- The Rust test helpers carry their callers' cfg (0 warnings in the 9 feature sets). `run-suite.sh` runs `cargo check --tests` on every test target of the 9 sets and fails on a warning (owner kept `check` over `--no-run`, D3).

## First actions of loop 80

0. CI of the loop 79 push (`dev`, then `main`): `gh run list --repo zxsanny/packbin --branch dev`. Read any red job's log with `gh api` before calling it a flake. Note the time of `suites (csharp rust)`, which was 286 s on the loop 78 push; the new check adds about 8 s cold on 4 CPUs. The first run after this push misses the Swift cache once, because its key hashes `run-suite.sh`. Put the result into the first commit of loop 80; do not push a record-only commit (LESSONS, loop 63).
1. `uptime` and `ps -Ao pcpu,command -r | head`. A total run is not a result above load 60.
2. Retro action 3 of loop 79: put the owner-held items below to the owner as one batch before picking work. The work that needs no decision is down to Low test-harness items.

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows (needs a Windows build and test first); a public-key pairing step.
- New: `_docs/_autodev_state.md` is in the project `.gitignore` since the scaffold commit (15c62c7, 2026-09-22). The autodev protocol wants it tracked so a fresh clone resumes mid-loop. Keep it ignored, or track it?

## Candidates (not specs yet; probe each on HEAD first, LESSONS loop 76)

- D5 of loop 79: a `seal` or `mac` ring row that the reference refuses crashes `ring_frame.py` with an `ff.Fault` traceback that does not name the row (exit 1). Catch it and name the row (Low).
- Multi-part MAC rows in the ring (a new driver line format).
- The AVR runtime check of the C++ `chacha20_xor` count-down loop on a 16-bit `size_t` (needs an emulator; complexity check first).
- Unchanged from `handoff75.md`: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

- **L79-1**: the first CI run of the `cargo check --tests` step on Linux is unread when this is written. It ran in `rust:1.98` locally (cold, 4 CPUs) and in step 11.
- **L79-2**: in step 11, the first build after a Rust source change runs the 9 checks cold inside the 3-suite pool: 94 s at load 15 to 26 (77 s for the whole stage warm, alone).
- **L78-2** (unchanged): the two vcpkg checks print NOT RUN on this Mac; CI runs them.
- **L76-1, L75-1, L74-2, L73-1, L72-1, L71-1, L71-2** (unchanged): see `handoff76.md` and `handoff75.md`.

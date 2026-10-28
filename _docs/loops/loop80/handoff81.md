# Handoff to loop 81

From the loop 80 record (`record80.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 80

AZ-3369 (short loop, 1 point):
- `scripts/frame/ring_frame.py`: a `seal` or `mac` row that the reference refuses ends the loader with `<file>:<line>: <case> the reference refuses the row: <kind>` (exit 1), not a traceback. `ring-frame.test.sh` has two cases and fails any case whose output holds a traceback (34 PASS).
- `scripts/loop-tests.sh`: `stamp_pass` ignores `_docs/_autodev_state.md`, so a stage that passes on a tree that is clean apart from the state file is stamped.
- Owner answer: `_docs/_autodev_state.md` is tracked (its line is out of `.gitignore`).

## First actions of loop 81

0. CI of the loop 80 push (`dev`, then `main`): `gh run list --repo zxsanny/packbin --branch dev`. Read any red job's log with `gh api` before calling it a flake. Put the result into the first commit of loop 81; do not push a record-only commit (LESSONS, loop 63).
1. `uptime` and `ps -Ao pcpu,command -r | head`. A total run is not a result above load 60 from a foreign job; the publish gate's own 8 shares took the host to load 105 in loop 80 and it still passed (633 s).
2. Put the owner-held items below to the owner as one batch before picking work: the work that needs no decision is down to Low test-harness items and ring extensions.

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows (needs a Windows build and test first); a public-key pairing step.

## Candidates (not specs yet; probe each on HEAD first, LESSONS loop 76)

- Multi-part MAC rows in the ring (a new driver line format in 8 drivers).
- Key and message-id length refusals in the ring (U1 of loop 77).
- The AVR runtime check of the C++ `chacha20_xor` count-down loop on a 16-bit `size_t` (needs an emulator; complexity check first).
- Refresh the stage stamps: `test-results/stamps/*` are at b7b8140 (loop 78), so the default `scripts/loop-tests.sh` plan lists 12 stages. One run on a tree that is clean apart from the state file writes them (`--all` is about 17 minutes at load below 20).
- Unchanged from `handoff75.md`: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

- **L80-1**: the stamp rule still needs a tree that is clean apart from the state file: an untracked or modified file under `_docs/` (a smoke script, a record) blocks a stamp, so step 11 stamps only when nothing else is dirty.
- **L80-2**: the publish gate ran 633 s in the smoke at load 20 to 105 (331 s in loop 79 at load 4 to 35); the CI job time of the loop 80 push is read in loop 81.
- **L78-2** (unchanged): the two vcpkg checks print NOT RUN on this Mac; CI runs them.
- **L79-1, L79-2, L76-1, L75-1, L74-2, L73-1, L72-1, L71-1, L71-2** (unchanged): see `handoff80.md`, `handoff76.md` and `handoff75.md`.

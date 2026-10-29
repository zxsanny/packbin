# Handoff to loop 84

From the loop 83 record (`record83.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 83

AZ-3387 to AZ-3389 (9 points, In Testing):
- `handoff.cpp` (639 lines) is `handoff.cpp` 320 + `handoff_ecc.cpp` + `handoff_frame.cpp` + `handoff_common.hpp`, built on the one compile line of `ring-lib.sh`; output identical to the HEAD binary.
- `scripts/ci/workflow_yaml.py` holds the 12 helpers both ring-wiring checkers shared; `workflow_yaml.test.sh` (16 checks) runs in the `scaffold` job.
- 14 ring rows (`R.seal.key33.*`, `R.seal.id7.*`, `R.open.key33.*`, `R.open.id7.*`): `BadValue` before `TooLong` / `BufferFull`; 56 refuse rows, 72 refusal rows per language. Rust and C++ cannot be handed the value, so those rows pin the order in 6 of 8 languages.

## First actions of loop 84

0. Read the CI of the loop 83 push (`dev` and `main`), see `record83.md` `ci:`. Put its result in the first commit of loop 84; do not push a record-only commit.
1. `uptime`, `df -h /tmp` (the publish gate needs free space; delete any scratchpad tree copies first) and `ps -Ao pcpu,command --sort=-pcpu | head`. A total run is not a result above load 60 from a foreign job.
2. The JDK is a user-directory tarball (`~/.local/share/packbin-jdk26/bin`), not on PATH by default: the ring stage needs it on PATH.

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows; a public-key pairing step.
- Multi-part MAC rows in the ring (G8m of loop 77) were owner-declined then; they need an opt-in like U1 had.

## Candidates (not specs yet; probe each on HEAD first, LESSONS loop 76)

- Make the scaffold wiring check require the steps of `yaml_get.test.sh` and `workflow_yaml.test.sh` (a mutant per step in `ring-wiring.test.sh`).
- `cpp/embedded/common/all_kinds.cpp` is 560 lines, over the 500 cap.
- The review cleanups of loop 83 (`frame_hex` over `hex_of`, copied include lists, the `id-padded` needle and the 5-line cap).
- Folding the Python version of the two `setup-python` steps and `RING_PYTHON` into one place.
- The AVR runtime check of the C++ `chacha20_xor` count-down loop on a 16-bit `size_t` (needs an emulator; complexity check first).
- Refresh the stage stamps on the owner's Mac (one clean run; this Linux clone has none).
- Unchanged from `handoff75.md`: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

- **L83-1**: the new rows prove the order in 6 of 8 languages; Rust and C++ print `BadValue` by construction (said in `fixtures/frame/README.md`).
- **L83-2**: `workflow_yaml.test.sh` runs in CI only through its `scaffold` step, which no wiring check requires yet.
- **L83-3**: the first CI run of the `CI workflow helpers` step is the push of this loop.
- **L82-2, L82-3, L81-2, L80-1, L80-2, L78-2, L79-1, L79-2, L76-1, L75-1, L74-2, L73-1, L72-1, L71-1, L71-2** (unchanged): see `handoff83.md`, `handoff82.md`, `handoff81.md`, `handoff80.md`, `handoff76.md` and `handoff75.md`.

# Handoff to loop 87

From the loop 86 record (`record86.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 86

AZ-3418 (2 points, In Testing): `cargo clippy --lib` is at 0 warnings with `--features text,ecc,frame`, default features and `--no-default-features` (HEAD had 11, none in `session_core`). Six files under `rust/src`; 876 Rust tests unchanged; the ring passed. No CI clippy job was added (owner chose cleanup only).

## First actions of loop 87

0. Read the CI of the loop 86 close push (`dev` and `main` runs); the record is `record86.md`, put any CI fix into the next commit.
1. `uptime`, `df -h /tmp` and `ps -Ao pcpu,command --sort=-pcpu | head`.
2. For the ring on this host: JDK on PATH (`~/.local/share/packbin-jdk26/bin`) and `LOOP_TESTS_PYTHON=/usr/bin/python3.14`; `scripts/loop-tests.sh --all --only ring` takes under a minute. A HEAD baseline for Rust tests needs the whole `git archive HEAD` (the tests read `../fixtures`).
3. `docker rmi packbin-embedded:w2` frees 4.9 GB when the owner agrees.

## Owner input needed


- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows; a public-key pairing step.
- Multi-part MAC rows in the ring (G8m of loop 77) were owner-declined then; they need an opt-in like U1 had.
- The hopper is empty after three hygiene loops: loop 87 needs an owner decision from the list above or a new feature (retro of loop 84, action 3).

## Candidates (not specs yet; probe each on HEAD first, LESSONS loop 76 and loop 84)

- A CI clippy job for the lib (owner declined it in loop 86; ask again only with a reason) and clippy on test targets (`nostd_*` tests warn).
- The AVR runtime check of the C++ `chacha20_xor` count-down loop on a 16-bit `size_t` (needs an emulator).
- Refresh the stage stamps on the owner's Mac.
- A Go window floor of 10 s (conditional); a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.
- `shellcheck` is not installed on this host; install it or lint the shell tests on the Mac.

## Risks


- **L84-1**: `m33f_flash_pin` has zero margin again (25,760 B measured = pin); the next edit that adds a byte to the M33F image fails the row by its own bytes.
- **L84-2** (closed): the ESP-IDF `core` jobs failed once on the source count; fixed in a9c2694, CI green. The image `espressif/idf:v5.3.2` (pulled this loop) is on the host.
- **L83-1**: the new ring rows prove the order in 6 of 8 languages; Rust and C++ print `BadValue` by construction (said in `fixtures/frame/README.md`).
- **L82-2, L82-3, L81-2, L80-1, L80-2, L78-2, L79-1, L79-2, L76-1, L75-1, L74-2, L73-1, L72-1, L71-1, L71-2** (unchanged): see `handoff83.md`, `handoff82.md`, `handoff81.md`, `handoff80.md`, `handoff76.md` and `handoff75.md`.

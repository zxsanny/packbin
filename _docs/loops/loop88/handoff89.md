# Handoff to loop 89

From the loop 88 record (`record88.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 88

AZ-3435 (docs only, In Testing): `_docs/04_deploy/release_notes_0.4.0.md`, a draft release body for 0.4.0 in the shape of the 0.3.0 release (New, Breaking changes, Build and CI, Install) plus a publisher section. Nothing was tagged or published.

## First actions of loop 89

0. Read the CI of the loop 88 close push (`dev` and `main`); a `_docs`-only push may skip CI.
1. `uptime`, `df -h /tmp` and `ps -Ao pcpu,command --sort=-pcpu | head`.
2. Ring on this host: JDK on PATH (`~/.local/share/packbin-jdk26/bin`) and `LOOP_TESTS_PYTHON=/usr/bin/python3.14`; `scripts/loop-tests.sh --all --only ring` takes under a minute.
3. `docker rmi packbin-embedded:w2` frees 4.9 GB when the owner agrees.

## Owner input needed

- Before the `v0.4.0` tag: CS-D5 (the compact text tables are frozen with the format; retraining later is another wire break) and F44 (a tag ruleset on `v*`, none exists).
- Whether to close the epic AZ-2750 in Jira (all children shipped).
- Unchanged: U24 in the C++ package; whether to drop the M4F row; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows; a public-key pairing step; multi-part MAC rows in the ring.
- The hopper is empty: loop 89 needs an owner decision from the list above or a new feature.

## Candidates (not specs yet; probe each on HEAD first, LESSONS loop 76 and loop 84)

- A CI clippy job for the lib and tests (owner declined it in loops 86 and 87).
- The AVR runtime check of `chacha20_xor` on a 16-bit `size_t` (needs an emulator).
- A Go window floor of 10 s (conditional); a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.
- `shellcheck` is not installed on this host.

## Risks

Unchanged from `handoff88.md`: L84-1 (`m33f_flash_pin` has zero margin), L83-1 and the older ones listed there.

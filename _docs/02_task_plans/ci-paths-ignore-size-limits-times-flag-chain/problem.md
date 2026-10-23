---
loop: 65
branch: dev
---

# CI paths-ignore, Rust size limits, flag-byte chain in a `times` round (loop 65)

Source: `_docs/loops/loop64/handoff65.md` (retro improvement 3, the owner items, the candidate "flag-byte chain inside a `times` round"). The hopper was empty. The owner chose three items on 2026-10-23 (AskUserQuestion) and settled the scope in three follow-up answers: stack candidate "Measure it, gate at 512 B"; Rust limits "Pin at today + 5%"; CS-D5 "Keep deferred"; CI "test.yml push only".

## Problem

1. **CI runs on record-only pushes.** A push that changes only `_docs/**` starts the whole `test.yml` on `dev` and `main` (loop 63: commit `3619a2d`, docs only, 554 s and 678 s). `push` has no `paths-ignore`.
2. **No size limits for three Rust feature sets.** `rust/embedded/limits.txt` has limits only for `base` (16,384 B flash, 512 B stack); `text`, `ecc` and `session` are `-` (no limit), so a later edit can grow them without any stage failing (AZ-2749 AC-3 waited for the owner; the owner decided on 2026-10-23: today's measured figure plus 5%).
3. **An unmeasured stack case in the C++ core.** A 3-deep `when` chain inside a `times` round is measured (scheme 0x5d, 436 B net, loop 56). A chain whose levels are held by a flag byte (`flag::HoldsFlagByte`, AZ-3141: 500 B net in a plain chain) inside a `times` round has no scheme, no test and no figure. The stack budget is 512 B with a 16 B margin (496 B deepest), so the combination could exceed it. Not a saving: a measurement with a gate.

## Code sections / UI locations for this loop

From the owner's answers of 2026-10-23 and the handoff. No UI.

| Work | Place |
|------|-------|
| CI | `.github/workflows/test.yml`, trigger `push` only |
| Rust limits | `rust/embedded/limits.txt` (rows `text`, `ecc`, `session`), read by `rust/embedded/checks.sh` / `target.sh`; `rust/embedded/README.md` and `checks.test.sh` if they restate the limits |
| Flag-byte chain in `times` | `cpp/embedded/common/all_kinds.cpp` (image scheme), `cpp/tests/core/when_chain_host_tests.cpp` (host test with Python bytes); read only: `cpp/src/core/unpack.cpp`, `pack.cpp`, `cpp/include/packbin/order.hpp`, `table.hpp` |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The new C++ case measures over 512 B of stack | report the figure and stop; no fix, no depth limit, no wire change without the owner's decision | open | Medium |
| The new case adds flash to the arm image above the 7,724 B pin | the case lives in the stage image only (`all_kinds.cpp`), not in the flash-budget image; a change to `cpp/src/core` needs a flash saving first | open | Medium |
| `paths-ignore` makes a required check missing on a docs-only push | `workflow_call` (publish.yml) and `pull_request` stay as they are; branch protection is not read here: check it before relying on it | open | Low |
| Limits pinned at +5% may be too tight for a legitimate edit | a raise needs a line saying what the bytes bought, as `flash_pin` does | accepted-risk | Low |
| CS-D5, the first `v*` / `go/v*` tags, F44, epic AZ-2750, row U24 | owner decides separately; CS-D5 stays deferred (owner 2026-10-23) | accepted-risk | Low |
| Jira connector absent | `Tracker: pending`, leftovers in `_docs/_process_leftovers/` | accepted-risk | Low |

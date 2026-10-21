# Handoff to loop 57

From the loop 56 record (`record56.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty.

## Shipped in loop 56

AZ-3143 (a `Field::flags` bit set at resolve time replaces the per-call scan of a `when`'s entries: flash 8,120 B to 8,080 B, margin 112 B; target 8,040 B missed), AZ-3144 (fold of `unpack_children` and `unpack_one` tried and not kept: 8,140 B flash, 676 B net stack; a 3-deep `when` chain inside a `times` round measured, 436 B net, image scheme 0x5d), AZ-3145 (Go, Swift and Rust heap-free loaders name a missing or unused case handler by id; no literal case count). Jira: all three In Testing; epic AZ-2645 open.

## Owner input needed

- Size limits for the Rust feature sets (`loops/loop53/smoke53.md`); CS-D5 before the first `v*` tag; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.

## Candidates (not specs yet)

- **Flash search, then the fold** (AZ-3143 AC-1, review #1 of loop 55, Medium): find 40 B or more in `cpp/src/core` (target 8,040 B), then retry the fold with `unpack_held` inlined into `unpack_children` and a frame that does not grow; the failed fold needed about 60 B of flash first and cost 100 to 180 B of stack per walk (scratchpad copies are gone; the figures are in `batch_01_loop56_report.md`).
- **Corpus guards** (loop 56 review, Low): the plain Rust loader cannot name an unused unpack/limit handler (a `match`); a Rust nostd case moving from run to a reasoned skip is not noticed (counts removed); `corpus.txt` counts (Swift 33, Rust nostd at least 33) are still hard-coded; Go `idDifference` and `sameSet` are two helpers for one check.
- **Flag-byte chain inside a `times` round** (not built).
- **Flash bound check**: nothing asserts 8,120 B; the arm stage fails only above 8,192 B.
- From loop 53: session stack (derive keys in place), `session_core` outside the clippy deny list (security O3), a ring driver for `nostd`.

## Risks

- **L56-1**: flash margin 112 B, stack margin 8 B (`AGENT_GOTCHAS.md`).
- L54-1 (a C++ `when` source more than 255 entries behind its `when` is `SchemeInvalid`), L52-1, L51-1: as in `handoff55.md`.

## CI read after the push

Read for the loop 56 push (eeba68e): `dev` run 39613482603 and `main` run 39613447961 both green, 20 jobs each, 0 not success. First action of loop 57: nothing from CI; start from the candidates above. `gh` lists runs with `gh run list --repo zxsanny/packbin --workflow test.yml`; job logs with `gh api repos/zxsanny/packbin/actions/jobs/<id>/logs --allow-escape-sequences`. The result goes into `record56.md` (`ci:`).

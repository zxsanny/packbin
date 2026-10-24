# Handoff to loop 67

From the loop 66 record (`record66.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 66

`publish-go.test.sh` sizes its proxy window from a probe of the stub (`gt_window`) and takes a `GT_GO_DELAY` for tests; the phases tests quote 25 lines of a run's output (`ph_quote`); `publish-timing.selftest.sh` knows `ph_quote`. Jira replayed: AZ-3165 to AZ-3171 exist under AZ-2645, all In Testing.

## First actions of loop 67

0. CI of the loop 66 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`; read the `publish-gate-*` jobs (one share each).
1. The first docs-only push after this one shows whether `paths-ignore` works (no `test` run for that commit). Loop 66's own push carries code, so it runs in full.
2. No retro is due (next after loop 68, or an incident).

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.
- A named consumer for the 468 B of flash margin, or a stack-reduction loop for the 612 B case.

## Candidates (not specs yet)

- **Stack of a flag scope inside a `times` round** (612 B unpack): the walk from `unpack_items` through `unpack_one` into `unpack_children`; measure shapes on a tree copy first.
- **Go window floor**: add a 10 s floor to `gt_window` if CI or a loaded run shows one stalled ask (about 7 s of test time).
- Unchanged: `item` pointer removal; out-of-line error helpers in `unpack.cpp` / `values.cpp`; session stack; `session_core` clippy; ring driver for `nostd`.

## Risks

- **L66-1**: the Go window cannot cover a single ask that stalls for 10 s or more after the probe (assessment 66, residual risk).
- **L66-2**: the container `pip install` failure of loop 65 has no known cause; if it repeats, the failure message now quotes 25 lines: read them before adding a retry.
- **L65-1**: `stack_pin` 612 B (`cpp/embedded/lib.sh`): any edit to `unpack.cpp` or `pack.cpp` that deepens the walk fails the arm stage by its own bytes.
- **L65-2**: Rust limits are +5% of the loop 65 figures.
- **L58-1**: the compose `go` stage needs outbound network from the container (`AGENT_GOTCHAS.md`).
- A new `ph_*` helper in the phases tests must be named in `ph_harness` of `publish-timing.selftest.sh`.
- Host `cpp/build/` can hold ELF objects after a `gcc:16` run: `make -C cpp clean` before a Mac `make test`.

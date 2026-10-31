# Batch 03 report — loop 97

Tasks: AZ-3504 (Go, 3), AZ-3505 (Swift, 3), AZ-3506 (Rust std + no_std, 5), AZ-3507 (C++, 5); 16 points; four workers on disjoint package trees, joined and re-run by the parent.

| Task | Status | Tests run by the parent after the join |
|------|--------|-----------------------------------------|
| AZ-3504 | Done | `golang:1.27`: gofmt clean, `go vet`, `go test -race -count=1 ./...` ok (97 s) |
| AZ-3505 | Done | `swift:6.3.3`, scratch path outside the repo, `-warnings-as-errors -strict-concurrency=complete`: 452 tests in 79 suites passed |
| AZ-3506 | Done | `.github/workflows/run-suite.sh rust` on the host (Rust 1.98): exit 0, 22 steps, 139 s |
| AZ-3507 | Done | host `make -C cpp test` exit 0; `gcc:16` container `make clean; make test` exit 0 (includes `no-text-test`, `no-ecc-test`, compile-fail checks) |

Embedded (measured by the workers on HEAD, then after; the Rust embedded stage and the C++ arm stage were run by the workers, not re-run by the parent):

| Row | Baseline | Final | Allowance |
|-----|----------|-------|-----------|
| `cpp-m33f` all-kinds flash / stack | 25,760 B / 724 B | 25,948 B / 740 B | +400 / +64 |
| `rust-m33f` ecc flash / stack | 18,764 B / 744 B | 19,140 B / 752 B | +400 / +64 |
| rust base, text, frame | 15,132/456, 27,268/2,736, 20,404/1,728 | unchanged | none |
| C++ frame image, Uno, string-free ECC-free | 8,416/912, 15,402, 21,688 | unchanged | none |

Pins raised in `cpp/embedded/lib.sh` and `rust/embedded/limits-m33f.txt`, with a line each in `_docs/AGENT_GOTCHAS.md`. The `rust-embedded` stage links only libraries already built: run `rust/embedded/run.sh libs` first.

Review: code-review (low) 0 findings. CI-parity: PASS for the suites above; not run by the parent: the `rust` and `rust-embedded` compose services (same script on the host instead), the C++ arm stage (the worker ran it on a copy of the tree), the Swift release-mode speed step, the ESP stage (no core source added).

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear/unclear |
|----------|-----------|-------------------|---------------|
| AC-9 | Go, Rust, Swift, C++ have no constructor taking both a percentage and a count; in-range `parp` pairs are last-setter-wins, out-of-range refused | as batch 2; contract states last setter wins | clear |
| AC-8 | Rust nostd: the `parity_percent` field exists only with `ecc` (an always-present field grew base/text/frame by 8 B) | keep; there is no percentage to refuse without `ecc` | clear |
| AC-10 | Rust `MixedParity { first, other }` shows the percentage when a handler has one, else the count; C++ shows 256 + p in the mix error | no new error variant; README/ring authors should know | unclear (cosmetic) |
| AC-4 | Swift and C++ scheme messages always have a type byte (L 0 never packed through a scheme); Swift round trip is 22,651 pairs through the API, L 0 at codec level | accepted | clear |
| ring | The Rust embedded container left root-owned `cpp/build/embedded/rust-m33f` and `rust-mutants` (host `make -C cpp clean` exits 1 on them) | owner: remove with a root shell | open |

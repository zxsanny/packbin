# Test run — loop 58 (step 11)

Date: 2026-10-22. Command: `scripts/loop-tests.sh` at ac3cc99 (stages planned by the stamps: go, rust, cpp; the other 11 stages unchanged since their last pass, none of their files touched).

RESULT: 3 passed, 11 skipped as unchanged, 0 failed.

| Stage | Result | Seconds |
|-------|--------|---------|
| rust | PASS | 37 |
| cpp | PASS | 41 |
| go | PASS (second invocation) | 265 |
| typescript, csharp, python, java, ac10 | SKIP (unchanged since daa302d) | — |
| swift, scaffold, cpp-embedded-arm, rust-embedded, ring, publish-gate | SKIP (unchanged since 7aa2d8a) | — |

The first invocation passed rust (37 s) and cpp (41 s) and failed go twice (10 s, 8 s): the compose `go` service has no module cache and Docker containers had no outbound network (iPhone hotspot with Low Data Mode; the host reached the Go proxy, containers did not). Nothing was substituted. After the operator joined another network, `scripts/loop-tests.sh --only go` passed through the same compose path.

Specified / executed / not run: 14 stages specified, 3 executed, 11 skipped as unchanged; none not-run.

The library source is untouched in this loop (test files only), so Cortex-M4F figures stay as measured in loop 57: flash 8,032 of 8,192 B (pin 8,032 B, margin 160 B), deepest stack 504 of 512 B. The arm stage was skipped as unchanged, not re-measured.

# Test run — loop 57 (step 11)

Date: 2026-10-22. Command: `scripts/loop-tests.sh` at 7aa2d8a (stages planned by the stamps: C++, Go, Rust, Swift loaders, scaffold, ARM stage, rust-embedded, ring, publish gate).

RESULT: 9 passed, 5 skipped as unchanged, 0 failed, 859 s. Verdict: PASS.

| Stage | Result | Seconds |
|-------|--------|---------|
| cpp | PASS | 47 |
| rust | PASS | 69 |
| go | PASS | 181 |
| scaffold | PASS | 390 |
| swift | PASS | 415 |
| cpp-embedded-arm | PASS | 13 |
| rust-embedded | PASS | 2 |
| ring | PASS | 60 |
| publish-gate (9 shares) | PASS | 321 |
| typescript, csharp, python, java, ac10 | SKIP (unchanged since daa302d) | — |

Specified / executed / not run: 14 stages specified, 9 executed, 5 skipped as unchanged; none not-run. The publish-gate share for registries reports NOT RUN for the vcpkg supports check and consumer check (no vcpkg tool on this host, as in `AGENT_GOTCHAS.md`; documented host skip).

Cortex-M4F (arm stage log): flash 8,032 of 8,192 B (pin 8,032 B, margin 160 B), deepest stack 504 of 512 B (raw 568 B less 64 B meter), largest core frame 528 B.

Review (`/code-review` high, 6 findings, all Low): 1 fixed (AGENT_GOTCHAS length), 5 skipped (count-check tautology in Rust nostd, Go refusal message, zero-slack pin, pack side not folded, no helper-level `keys_ascending` test).

# Security lite — loop 97

Diff: `cb49455~1..HEAD` without `_docs/` and without fixtures (the parity percentage in eight packages, the ECC reference and ring, 11 plus 3 tasks). Unlike loops 78 to 96 this loop changes a product code path that reads untrusted bytes: unpack now takes the parity count from the received length.

| Trigger | Hit | Note |
|---|---|---|
| T1 sensitive path | yes | `.github/workflows/` (ring self-test, eight ECC drivers); no `uses:`, `permissions:`, secret or env added; `test.yml` unchanged |
| T2 sensitive content | no | no password, secret, key, curl, wget, eval, exec, sudo, URL or `rm -rf` on added source lines (checked by grep of the diff) |
| T3 size | yes | about 7,000 added lines across packages and tests, 39 + 9 points |
| T4 dependencies | no | no manifest or lockfile changed |
| T5 carried finding | no | `security_report.md` names none of the changed unpack functions as open |
| T6 stale audit | no | not a ship loop |
| T7 lite concern | yes | untrusted input: the received length now drives the count |

Verdict: ESCALATE by T1, T3 and T7, answered with a diff-scoped pass below.

Checks on the changed lines:
- Hostile length. Each package finds the clear length by a search whose bound is the received length capped at 254: Python `range(min(sent, 254) + 1)`, Java `min(sent, MAX_BLOCK)`, Rust `(0..=sent.min(MAX_SENT))`; in TypeScript, C#, Go, Swift and C++ the buffer above 254 bytes is refused as too long before the search starts (`repairPercent`, `RepairPercent`, `repairPercent`, `receivedParity`, `received_parity`). At most 255 steps and no allocation that grows with the input (AC-12; the existing timing checks pass).
- Arithmetic. `p × L + 99` is at most `100 × 254 + 99`: it fits `int` in Java, C#, Go, Swift; C++ computes it in `unsigned` (16-bit safe); Rust uses `saturating_mul` and `saturating_add`; TypeScript and Python are unbounded. The count is capped at 32 before it is used as a size.
- A length no message has. It is `uncorrectable` with no values and no field named; the code covers the clear length, so a buffer cut or extended onto another valid length fails the syndrome check (ring rows `trunc`, `extend`, `unprotected`, `garbage`, `toolong`, `nolen`, 115 rows under a percentage, identical refusals in the eight languages: 64 pairs, 0 mismatched).
- Error handling. No `catch` was added that swallows an error; the refusals are the package's existing kinds (no new kind). The Rust driver checks the percentage against 100 before the call that panics above it, so a hostile ring line cannot panic the driver; the Rust library itself panics on a bad percentage only at scheme construction, as `with_parity` does.
- Limits. A correction limit above 16 is refused before any byte is read; a limit above `n / 2` of the message is lowered, never used to index.
- Secrets and logs: nothing added; the driver output is the result line or an error kind.
- Blast radius: schemes with a fixed count and percentage 0 take the old path (`vectors.txt` byte-identical, all old suites green).
- Out of the diff, for the record: the root-owned folders `cpp/build/embedded/rust-m33f` and `rust-mutants` left by the Rust embedded container (a build-output ownership issue, not a code path; owner to remove).

Findings: 0 Critical, 0 High, 0 Medium, 0 Low new.

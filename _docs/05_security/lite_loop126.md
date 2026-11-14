# Security lite — loop 126 (scheme depth limit)

Diff: `553812a..HEAD` without `_docs/` (nine packages, `fixtures/hostile`, `.github/workflows/run-suite.sh`, `rust/embedded/limits-m33f.txt`).

| trigger | hit |
|---------|-----|
| T1 sensitive path | yes: `.github/workflows/run-suite.sh` (CI file) |
| T2 sensitive content | no (a test env var only) |
| T3 significant size | yes: 130+ changed files, complexity 26 points |
| T4 dependencies | no |
| T5 carried finding | no |
| T6 stale audit | no (not a ship loop) |
| T7 lite concern | no finding above Low |
| T8 revisit row | no |

Verdict: ESCALATE (T1, T3), answered here at the scope of the diff: the change adds a defensive input bound (a scheme depth limit checked first, iteratively, in nine packages).
- Injection / secrets / authz / outbound / edge config: none touched.
- Input limits: the check is new and bounds recursion; scheme construction is not untrusted-byte input, but the shared hostile cases cover 257, 1,000 and 50,000 levels in all nine packages and finish in milliseconds.
- Memory safety: Rust nostd and C++ checks use no heap and no recursion; `rust-embedded` and `cpp-embedded` rows pass (no panic or heap symbol linked); C++ sanitizer run passes. C++ `check_depth` writes `ref` and resets it to -1.
- CI change: `export RUST_MIN_STACK` in the Rust suite step; no secret, no network, no permission change.
- Low: a diamond-shaped scheme (one Field reused twice per level) makes six of the nine depth walks exponential before the 257-level stop (Java dedups); the older walks had the same shape and a scheme is written by the developer. Hygiene item 4. Remediation: dedup or refuse shared fields.
- Low: the Rust nostd check is quadratic in the container count of a 32,768-entry table (hygiene item 7).

Result: PASS, no finding above Low. The full audit is not needed beyond this scoped answer.

# Security lite — loop 127 (hygiene: shared fields in the depth check)

Diff: `e04ea29..HEAD` without `_docs/` (TypeScript, Python, Dart, Swift, C#, Go, Rust sources and tests).

| trigger | hit |
|---------|-----|
| T1 sensitive path | no |
| T2 sensitive content | no |
| T3 significant size | yes: 28 files, 3 tasks of 3 points |
| T4 dependencies | no |
| T5 carried finding | no |
| T6 stale audit | no (not a ship loop) |
| T7 lite concern | no finding above Low |
| T8 revisit row | no |

Verdict: ESCALATE (T3), answered here at the scope of the diff: the change makes the scheme-depth checks and two earlier walks memoise shared nodes (an identity map or set), plus a depth check in the Rust `times` / `repeat` constructors.
- Denial of service: this removes an exponential walk (a scheme that reuses one Field twice per level cost 2^depth steps; now its size). Rust `times` / `repeat` with a 50,000-level body no longer overflows the stack (SIGABRT before). Memory is O(nodes).
- Correctness of the memo: a node is skipped only when seen at an equal or greater depth (depth checks) or for the same `inU2` answer (slot checks); tests prove a field reached shallow first and deeper later is measured at its deepest, and a wrong "skip on any sighting" rule fails them.
- Input, secrets, authz, outbound, edge config: none touched; no dependency or CI change.
- Low: shared nested rows (a diamond with no ids) are still exponential in the id walks of Dart, Swift and Go (hygiene entry 4); the Rust heap-free depth check is about 1 s on a hostile 32,768-entry table (D21, kept).

Result: PASS, no finding above Low.

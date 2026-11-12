# Security lite, loop 113

Diff: `2c285d7~1..HEAD` without `_docs/` (epic AZ-4209, a repeat must be the last thing a packet reads: 10 package tasks and AZ-4232, nine packages, 28 non-test source files, +954/-78 lines, no packet byte changes). The working tree adds only documents.

| Trigger | Hit | Note |
|---|---|---|
| T1 sensitive path | no | no deploy, infra, CI, Dockerfile, compose, `.env*`, migration or SQL file; `cpp/Makefile` (test list) and `rust/embedded/limits-m33f.txt` (flash pins) are not on the list |
| T2 sensitive content | no | 2 hits, neither a trigger: the word `HashMap` in a README line, and the `new Function` accessor helper of five older TypeScript test files (test constants) |
| T3 size or complexity | **yes** | 28 non-test source files (limit 8), task complexity 5 |
| T4 dependencies | no | no manifest, lockfile, image or workflow changed (`git diff --name-only` filtered for all of them: none) |
| T5 carried finding touched | by name only | F18 names `Walker.java`, F39 names `fields_counted.hpp`; the changed lines are REPEAT call sites and a comment, not their lines |
| T6 stale audit | no | loop 100 full pass 2026-11-11 |
| T7 lite concern | no | Low only (below) |

Checks on the changed lines:
- Injection, output encoding, authn/authz, outbound, edge config: none in the diff (library scheme-build code, tests, fixtures, probe scripts).
- Secrets and logs: refusal texts carry anchors, ids and member names declared in code; a scan of all added non-doc lines for keys, tokens, URLs, IPs and paths found none.
- Input limits: unpack changes only in Java and only by deleting code that ran for a repeat inside a round, which is now refused at build; 18.3 million unpack calls over 150 scheme variants return the same digest before and after.
- Blast radius: nine packages, one rule each; Rust heap-free `validate` pays one more pass over the table per call (about 150 B of code, no heap, no recursion).
- Low: Java, C# and Go build a scheme in O(depth squared) after a repeat (F79); one pre-existing test-only overflow found by the C++ sanitizer run (F80).

Verdict: ESCALATE (T3). The full audit ran in the same step: `_docs/05_security/security_report_loop113.md` (PASS_WITH_WARNINGS, 2 Low).

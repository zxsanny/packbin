# Autodev Loop Plan — Loop 36

loop: 36
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-18) chose "Security audit + 2 Medium findings" from the loop 35 handoff. Tickets AZ-2664, AZ-2665, AZ-2666 (epic AZ-2645).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0 |
| decompose-feature | 9.5 | Decompose Feature | no | 8 points, three small tasks |
| implement | 10 | Implement | yes | AZ-2664 (Python, TypeScript), AZ-2665 (CI speed steps), AZ-2666 (audit) |
| code-review | — | Total review | no | small diff; the security audit is the review |
| feature-assess | 10.5 | Feature Assessment | no | owner-run skill, carried |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` (python, typescript, rust, swift, scaffold) |
| test-spec-sync | 12 | Test-Spec Sync | no | no new AC beyond HD-1..5 |
| update-docs | 13 | Update Docs | no | none |
| security | 14 | Security Audit | yes | AZ-2666 |
| performance | 15 | Performance Test | no | the speed steps are AZ-2665 |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | owner-run skill, carried |
| local-deploy | — | Local deploy + open site | yes | none (library; CI is the proof) |
| smoke | — | Smoke acceptance | yes | script in `smoke36.md` |

## Implementation
### Files that change
- `python/src/packbin/_text_encode.py`, `_pack.py`, `_pack_limits.py`; `typescript/src/text.ts`, `kinds.ts`, `pack-out.ts`; tests in both.
- `.github/workflows/run-suite.sh`, `run-suite.test.sh`, `run-suite-swift.test.sh`.
- `_docs/05_security/security_report.md`.
### Order of work
1. AZ-2664 (parent). 2. AZ-2665 (parent). 3. AZ-2666 audit by reading the decoders (parent, fixes if High). 4. Step 11 on the changed stages. 5. Smoke, close, push.
### Proof
Interleaved-call tests; a release speed step in CI for Rust and Swift with mutants; the audit report.
### Risks
A release build of the Rust crate adds CI minutes; the TypeScript scratch buffers are shared module state used for speed.

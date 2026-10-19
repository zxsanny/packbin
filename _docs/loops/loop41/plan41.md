# Autodev Loop Plan — Loop 41

loop: 41
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-19) chose "AZ-2666 audit + retro" from the hopper (AZ-2666, load-aware timing bounds, AZ-2068). AZ-2666 now also covers the message ECC unpack path (AC-2). Intake commit `915a908`.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | spec already in todo/ (AZ-2666) |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| security | 14 | Security Audit | yes | AZ-2666: the decoders read untrusted bytes; run first, it is the work of the loop |
| implement | 10 | Implement | yes | fixes for High or Critical findings; the audit probes and corpora committed under `fixtures/hostile/fuzz/` (AGENT_GOTCHAS line 1) |
| feature-assess | 10.5 | Feature Assessment | yes | AC-1 and AC-2 against the addendum |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` on the stages the loop changes (`fixtures/` selects every suite) |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario change unless a fix adds a hostile case |
| update-docs | 13 | Update Docs | no | contracts change only if a fix changes a documented bound |
| performance | 15 | Performance Test | no | no perf NFR beyond the audit's own probes |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | loops 35 to 40 (6 loops since `retro_2026-10-17_loop34.md`) |
| local-deploy | — | Local deploy + open site | yes | none (library; `LOCAL_URL: none`) |
| smoke | — | Smoke acceptance | yes | script in `smoke41.md`, agent run per `deployment_procedures.md` |

## Implementation
### Files that change
- `_docs/05_security/security_report.md` (Loop 41 addendum, F51 to F60).
- Fixes: `rust/src/ecc.rs`, `rust/src/value.rs` (`BadParity`, F52), `rust/src/hostile_tests.rs`, `.github/workflows/drivers/handoff-rust/src/ecc.rs`, `rust/tests/ecc_session_dispatch_tests.rs`; `csharp/Ecc.cs` (F53), `csharp/tests/EccSessionTextTests.cs`, `csharp/EccRepair.cs` (comment); `python/src/packbin/_text_decode.py` (F54), `python/tests/test_compact_text.py`.
- Docs: `message-ecc.md` (F55 work bound, F52 dispatch), `compact-text.md` (F51, F56 C++ note), `README.md`, the 8 component descriptions.
- `fixtures/hostile/fuzz/<language>/` (the audit probes) and its README.
- Next loop: `_docs/02_tasks/todo/AZ-2713_dict_keys_ascending.md` (owner 2026-10-19: F51 Medium, ascending keys in all 8; Lows F57 to F60 and the F19 instances carried).
### Order of work
1. Audit: four read-only workers, two packages each. 2. Retrospective of loops 35 to 40 while they ran. 3. Fixes F52 (Medium), F53, F54 with tests, each shown to fail on HEAD. 4. Owner decision on F51. 5. Addendum, contracts, AZ-2713. 6. Probes into `fixtures/hostile/fuzz/`. 7. Feature assessment, step 11, smoke, close, push.
### Proof
The addendum covers every AC-1 and AC-2 item with evidence; 0 open High or Critical; the three fixes each have a test that fails without them.
### Risks
The Mac had 4.9 of 6 GB swap in use and load 4 to 14 during the audit, so timings are indicative. `fixtures/` changed, so step 11 runs every suite.

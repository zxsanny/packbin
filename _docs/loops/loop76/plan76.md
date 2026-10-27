# Autodev Loop Plan — Loop 76

loop: 76
kind: product
confirmed: true
branch: dev
ship: false

Slug `hygiene-after-frame-ports`; tasks AZ-3329..AZ-3333 (11 points), epic AZ-2645; plan folder `_docs/02_task_plans/hygiene-after-frame-ports/`.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then the 8+ point handoff to decompose — done at intake |
| decompose-feature | 9.5 | Decompose Feature | no | done at intake: 5 disjoint tasks AZ-3329..AZ-3333 written and ticketed |
| implement | 10 | Implement | yes | one wave of 5 workers with disjoint write sets |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total `scripts/loop-tests.sh --all` at the closing commit (owner: one total review and test) |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC, scenario or NFR of the product changed; the loop ACs are probe, script and doc checks |
| update-docs | 13 | Update Docs | no | no public contract or API changed; the doc edits are tasks AZ-3332 and AZ-3333 themselves |
| security | 14 | Security Audit | no | no auth, secret, network or untrusted-input surface touched |
| performance | 15 | Performance Test | no | no latency or load NFR |
| deploy | 16 | Deploy | no | `ship: false` |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | no data store or traffic change |
| retrospective | 17 | Retrospective | no | last retro covers loop 74; next due after loop 79 |
| local-deploy | — | Local deploy + open site | yes | always at close (a library repo: no site; the smoke is a script) |
| smoke | — | Smoke acceptance | yes | always at close; checklist in `smoke76.md` |

Only rows with `include: yes` are executed (plus close steps).

## Implementation

### Files that change
- AZ-3329: `fixtures/hostile/fuzz/csharp/PackbinProbe.csproj`, `EdgesText.cs`; `fixtures/hostile/fuzz/java/packbin/ProbeEdgesText.java`.
- AZ-3330: `.github/workflows/publish-timing.selftest.sh`.
- AZ-3331: `rust/src/lib.rs`, `rust/src/session_core/sha256.rs`, `hkdf.rs` (test modules), 22 files of `rust/tests/*.rs` plus `nostd_dict_tests.rs`.
- AZ-3332: `swift/Sources/Packbin/Packbin.docc/Packbin.md`, `_docs/02_document/adr/003_cpp-vcpkg-git-registry.md`, `_docs/02_document/components/05_cpp_package/description.md`.
- AZ-3333: `csharp/tests/TopRangeAndSessionTests.cs`, `EccSessionTextTests.cs`, `fixtures/hostile/fuzz/{python,typescript}/fuzz_ecc_session.*`, `fixtures/hostile/fuzz/README.md`, `fuzz_common.py`, `fuzz_common.ts`, three C# docs.

### Order of work
One wave, five workers, no dependency between tasks. The parent owns the tracker, the commit, `_docs/AGENT_GOTCHAS.md`, the loop record and the one total test run.

### Proof
Each task's ACs; `scripts/loop-tests.sh --all` at the closing commit with host load below 60 (`ps -Ao pcpu,command -r | head`, `uptime` first); CI after the push.

### Risks
The Rust embedded stage compiles `session_core/` (AZ-3331 changes test code only; AC-3 runs the stage); the C# rename and the C# suite need `MSBUILDDISABLENODEREUSE=1`.

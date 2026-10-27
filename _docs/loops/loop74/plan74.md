# Autodev Loop Plan — Loop 74

loop: 74
kind: product
confirmed: true
branch: dev
ship: false

Feature: remove the stream session; frame mode is the one session (ADR-009); one set of frame names (D1); crypto kept in C++, Go, Python, TypeScript for the frame ports (D2). Specs `_docs/02_tasks/todo/AZ-3280..AZ-3291`; frame ports `_docs/02_tasks/backlog/AZ-3292..AZ-3295` (loop 75).

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` in the intake |
| decompose-feature | 9.5 | Decompose Feature | done | 13+ points; decomposed in the intake into 12 tasks + 4 backlog specs |
| implement | 10 | Implement | yes | 4 batches below |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` total run (all 8 suites, cpp-embedded-arm, ring, publish-gate) plus `rust/embedded/run.sh host` |
| test-spec-sync | 12 | Test-Spec Sync | yes | stream scenarios retired (blackbox-tests-05, traceability rows); new crypto vector scenarios in 4 packages; delivered by AZ-3291, checked here |
| update-docs | 13 | Update Docs | yes | contract 3.0.0, public API removed and renamed; delivered by AZ-3291, checked here |
| security | 14 | Security Audit | yes | crypto code moves in C++, Go, Python, TypeScript; one independent read-only review of the loop diff (moved primitives byte-equal, no secret logged, wipes kept in the frame packages) |
| performance | 15 | Performance Test | no | no latency or throughput AC |
| deploy | 16 | Deploy | no | ship: false; tags are owner-run |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store or traffic flip |
| retrospective | 17 | Retrospective | yes | tasks of 5 points (AZ-3284, AZ-3286, AZ-3291); short, loop 74 only (the loops 70 to 73 retro is done) |
| local-deploy | — | Local deploy + open site | yes | library: no site (`LOCAL_URL: none`, `deployment_procedures.md`) |
| smoke | — | Smoke acceptance | yes | one paste script `smoke74.md`; agent-run, auto-pass on N/N (owner rule 2026-10-12) |

## Implementation

### Order of work

Batches of disjoint write sets (`feature-description.md` couplings). Workers run only their own package suite (owner, loop 16); no per-batch review; one total review and one step 11 at the end. `README.md` has one writer: the parent applies README hunks after each join.

1. **Batch 1**: AZ-3280 ring and CI (all 8 ring drivers, run-suite scripts), AZ-3281 C#, AZ-3282 Java removal, AZ-3283 Python.
2. **Batch 2**: AZ-3284 Rust removal, AZ-3285 Swift (removal and `MsgContext`; parent removes the README Swift session block), AZ-3286 C++, AZ-3287 Go.
3. **Batch 3**: AZ-3288 TypeScript, AZ-3289 Rust names, AZ-3290 Java names (parent applies the README Rust and Java frame examples).
4. **Batch 4**: AZ-3291 docs (parent).

### Proof
- Each task's ACs; 157/157 frame rows (Rust, C#, Java, Swift), 27/27 crypto rows (all 8), the ring clear and ECC stages, embedded figures against `acceptance_criteria.md`.

### Risks
- A cross-package reader missed by the inventory (`git grep` every reader before each commit, `AGENT_GOTCHAS.md`).
- Host load during step 11 (check `uptime` and `ps` first; load above 60 is not a result).

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | CLARIFY (D6, owner: add `FrameConfig` and `FrameDirections` to Java) | AZ-3322_java_frame_config | _docs/loops/loop74/assessment74.md |
| 2 | COMPLETE | none | _docs/loops/loop74/assessment74.md |

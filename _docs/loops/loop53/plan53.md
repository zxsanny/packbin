# Autodev Loop Plan — Loop 53

loop: 53
kind: product
confirmed: true
branch: dev
ship: false

Intake: hopper hit on wave C of epic AZ-2750 (`handoff53.md`): AZ-2756 (`session` feature) then AZ-2757 (hostile corpus, differential proof, publish check, nested stack probe, docs). The epic closes with this loop. Both slices write `rust/src/nostd/**`, so they run in sequence. Both are already decomposed (loop 50): no `/decompose`.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs already in `todo/` (decomposed in loop 50) |
| decompose-feature | 9.5 | Decompose Feature | no | done in loop 50 |
| implement | 10 | Implement | yes | batch 1 session (AZ-2756), batch 2 hostile/differential/probe/docs (AZ-2757); one total review at the end (owner rule) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one run at HEAD: rust, rust-embedded, ring, scaffold, publish-gate |
| test-spec-sync | 12 | Test-Spec Sync | no | the ACs live in the task specs |
| update-docs | 13 | Update Docs | yes | module layout, component description, README name `nostd`, features, CI job (AZ-2757 AC-4) |
| security | 14 | Security Audit | yes | session seal/open of untrusted bytes on caller buffers |
| performance | 15 | Performance Test | no | no latency NFR; raw memo measured inside AZ-2757 |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag (owner) |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | epic closes; last retro was loop 52, interval fine but epic close warrants one |
| local-deploy | — | Local deploy + open site | yes | none (library) |
| smoke | — | Smoke acceptance | yes | script in `smoke53.md`, run by the agent (owner rule 2026-10-12) |

## Implementation

### Files that change
`rust/src/nostd/session.rs` (new, behind `session`), the hash/KDF/pad moved to `rust/src/session_core/` (shared by `rust/src/session/**` and the core, one copy, no `chunks*`), the walk split into `pack_clear` + `read`, `.github/workflows/run-suite.sh` (+ its test), `rust/tests/nostd_session_tests.rs`, `rust/tests/nostd_hostile_replay_tests.rs`, `nostd_support/**`, `rust/embedded/feature-sets.txt` + probe, `_docs/**`.

### Order of work
1. Batch 1 (AZ-2756): read the std session; move hash / key derivation / pad into a shared core module with no `Vec`; `nostd::session` with seed, caller nonce, seal, open on caller buffers; cross-open + differential tests; refusal tests.
2. Batch 2 (AZ-2757): hostile-corpus replay runner (scheme built from case text), skip table with reasons, differential over every fixture file, nested-scheme stack probe on the device image, `session` set in `feature-sets.txt`, raw-memo measurement, `cargo publish --dry-run`, docs.

### Proof
Cross-open bytes equal std for the same seed and nonce; link check shows no heap symbol with `session` on; hostile replay: each case returns its named refusal or is skipped with the C++ runner's reason.

### Risks
Flash and stack on Cortex-M4F with `session` (no limit yet; owner owes one). The panic-path gotcha (`split_at_mut`, `copy_from_slice`, ...). Nonce reuse is the caller's duty (rustdoc).

## Assessment rounds

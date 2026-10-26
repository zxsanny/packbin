# Autodev Loop Plan — Loop 73

loop: 73
kind: product
confirmed: true
branch: dev
ship: false

Feature: wipe Rust key material through one volatile helper; clear the HKDF and stream pad temporaries (follow-up of loop 72). Plan dir: `_docs/02_task_plans/rust-hkdf-wipes/`. Task: AZ-3275 (3 points); epic AZ-3199.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` ran before this plan (3 points, one task) |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| implement | 10 | Implement | yes | parent alone: one component, files shared by every change (`session_core`) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` once on the final tree (load checked first) |
| test-spec-sync | 12 | Test-Spec Sync | no | no project-level test scenario changes; the new unit test lives in the crate |
| update-docs | 13 | Update Docs | yes | Rust description (helper, guarantee, L73-1), `module-layout.md` (`session_core/wipe.rs`), the M33F pin line in `AGENT_GOTCHAS.md` |
| security | 14 | Security Audit | yes | the loop is security hardening with a new `unsafe` block: one independent read-only review of the diff |
| performance | 15 | Performance Test | no | AC-6 is measured inside implement (HEAD copy beside this tree) |
| deploy | 16 | Deploy | no | library; no ship |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | last retro loop 69; five loops (69 to 73) |
| local-deploy | — | Local deploy + open site | yes | library: no site; the smoke script runs the crate |
| smoke | — | Smoke acceptance | yes | `smoke73.sh` with per-step PASS/FAIL |

## Implementation

### Files that change
- `rust/src/session_core/`: `wipe.rs` (new: the helper and its test), `hkdf.rs`, `sha256.rs` (`finish(&mut self)`, `wipe`), `pad.rs`, `hmac.rs`, `mod.rs`.
- `rust/src/session/mod.rs`, `rust/src/nostd/session.rs` (seed wiped in place at `open`; the forwarding `wipe` removed), `rust/src/nostd/frame/mod.rs`, `rust/src/nostd/frame/mac.rs`.
- `rust/embedded/limits-m33f.txt` (`session` 18,900 / 1,504, `frame` 20,388 / 1,728).

### Order of work
One batch, parent alone: helper, HKDF and SHA-256, pad, the existing wipes, embedded figures (out of line kept after a forced-inline run), bench against a HEAD copy, full Rust suite, docs.

### Proof
`batch_01_loop73_report.md`: embedded table, bench ratio 1.044, 972 tests passed, the code-read list.

### Risks
Divergence from the spec, recorded as Discovered 1 to 7: two more plain-loop wipes moved; `Option::take` left the seed in the session, now wiped in place; the full HMAC outputs left unwiped (not key material; owner candidate).

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | CLARIFY | none (D6 answered: out of scope) | _docs/loops/loop73/assessment73.md |
| 2 | COMPLETE | — | _docs/loops/loop73/assessment73.md |

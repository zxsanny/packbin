# Autodev Loop Plan — Loop 105

loop: 105
kind: product
confirmed: true
branch: dev
ship: true

Feature: release `v0.5.0` (owner: "make v.0.5.0", 2026-11-11, after "Yes, plan it"). No new application source: the tag is placed on the last green commit, `4e9110a`. Notes: `_docs/04_deploy/release_notes_0.5.0.md`.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | no feature |
| decompose-feature | 9.5 | Decompose Feature | no | no task |
| implement | 10 | Implement | no | no task |
| feature-assess | 10.5 | Feature Assessment | no | `not_in_plan`: no implement pass |
| run-tests | 11 | Run Tests | no | no source changed; the tagged commit has green `dev` and `main` runs of `test.yml` |
| test-spec-sync | 12 | Test-Spec Sync | no | no criteria changed |
| update-docs | 13 | Update Docs | yes | release notes; install table check |
| security | 14 | Security Audit | no | `not_in_plan`, `trivial:` no change since the loop 103 pass |
| performance | 15 | Performance Test | no | no code |
| deploy | 16 | Deploy | yes | the tag push runs `publish.yml` (ADR-002) |
| release | 16.5 | Release | yes | verify each registry, the position program, the GitHub release |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | no | the loop 104 retro is current |
| local-deploy | — | Local deploy + open site | yes | no site: the smoke script checks the registries and the tag |
| smoke | — | Smoke acceptance | yes | one paste script, `smoke105.md` |

## Implementation

### Order of work

Notes and plan committed and pushed; preconditions (tag free, `4e9110a` green, no registry holds 0.5.0, tree clean); annotated tag `v0.5.0` on `4e9110a`, pushed alone (no `--tags`, no force); watch `publish.yml` every 90 s; verify; GitHub release from the notes; record; close.

### Proof

Each registry answers 200 for 0.5.0 (npm, PyPI, NuGet, crates.io, Maven Central), the vcpkg branch holds the prepared commit, the tag `go/v0.5.0` exists at the tagged commit, the Swift consumer check job passed, and the golden position program prints `4001000065cd1d00a3e1110100`.

### Risks

A credential missing or expired (the run's credential check fails before anything is built); the optional `pubdev` skip path runs for the first time in a tag run; a Dart golden mismatch would block every language (it is green in CI); the Maven and Go waits are long.

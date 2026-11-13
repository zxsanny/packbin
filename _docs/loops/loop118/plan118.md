# Autodev Loop Plan — Loop 118

loop: 118
kind: product
confirmed: true
branch: dev
ship: false
origin: agent

Feature: AZ-4251 (3 points, `todo/`, claimed for this loop). C# drops the value of a `flags` that is a direct member of a `flags` (found in loop 113's review of AZ-4212; severity high: a value given is lost with no error). Fix the C# presence rule, pin it with tests, probe the same scheme in all nine packages. A sibling defect becomes one owner decision, not a fix in this loop.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | spec written at intake (`AZ-4251_csharp_flags_in_flags_presence.md`) |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points |
| implement | 10 | Implement | yes | C# fix and tests (parent); probe in nine packages (one worker, `scripts/probes/flags-in-flags/` only) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh`: the C# stages (`net10.0`, `netstandard2.0`) and `scaffold` (new scripts) |
| test-spec-sync | 12 | Test-Spec Sync | no | no shared vector or blackbox case changes; unit tests and a probe only |
| update-docs | 13 | Update Docs | no | no public contract changes: C# now does what its README and the other packages already say |
| security | 14 | Security Audit | yes | `lite` on the real diff (complexity 3, so not trivial); escalates on its triggers |
| performance | 15 | Performance Test | no | no perf AC; one more arm in a switch |
| deploy | 16 | Deploy | no | no tag; travels with the next release |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | yes | due by loop 118 (last: loop 113, `retro_2026-11-12_loop113.md`); loops 114 to 118 |
| local-deploy | — | Local deploy + open site | yes | no site (library): the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke118.md` and `smoke118.sh`, agent run |

## Needs

| need | for | verified by | status |
|------|-----|-------------|--------|
| .NET 10 SDK, Node 22.18+, a JDK, Python 3.13, Rust 1.98, C++17 with `PACKBIN_CXX_SYSROOT`, Swift 6, Dart 3 on this Mac | implement (probe), run-tests | `command -v` each, 2026-11-13 | ok |
| Go: no `go` on `PATH`, so the Go probe runs in `golang:1.27` | implement (probe) | `docker info` 25.0.2 answers | ok |
| host load below about 6 for step 11 | run-tests, smoke | `uptime` 10:39: load 5.4, swap 4.1 of 5 GB used | re-check before step 11 |

## Questions ahead

Scanned 2026-11-13: `java-element-row-raw-class-cast` (decided D10: A) and `java-unpack-declared-collection-type` (decided D12: B): both carry the owner's decision and name their code sections; no new question.

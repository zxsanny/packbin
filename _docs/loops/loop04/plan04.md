# Autodev Loop Plan — Loop 4

loop: 4
kind: product
confirmed: true
branch:
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | Specs already in todo: AZ-1945, AZ-1946 |
| decompose-feature | 9.5 | Decompose Feature | no | No feature-description handoff; tasks already split |
| implement | 10 | Implement | yes | AZ-1945 then AZ-1946 |
| feature-assess | 10.5 | Feature Assessment | yes | After implement |
| run-tests | 11 | Run Tests | yes | Always |
| test-spec-sync | 12 | Test-Spec Sync | yes | New ACs and scenarios |
| update-docs | 13 | Update Docs | yes | Public pack API gains a type-number node and Scheme |
| security | 14 | Security Audit | no | No auth or untrusted-input scope; security report is 2026-09-23 |
| performance | 15 | Performance Test | no | No latency or throughput NFR |
| deploy | 16 | Deploy | no | Not a ship loop |
| release | 16.5 | Release | no | Deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | No schema or traffic cut |
| retrospective | 17 | Retrospective | yes | Task complexity is 5 and 8 |
| local-deploy | — | Local deploy + open site | yes | Always at close |
| smoke | — | Smoke acceptance | yes | Always at close |

Chat stays on the launcher. Implement on `dev`. No sibling worktree this session.

## Implementation

### Files that change
Six language packages: type-number node, then Scheme and BinaryPacker.

### Order of work
AZ-1945, then AZ-1946.

### Proof
Each language suite covers AC-1 through AC-6. Golden position bytes stay the same.

### Risks
A type tag written as two bytes fails `2017`.

### Divergence
Python `Scheme.of` takes the row class. Java `Scheme.of` takes `Class<T>`. Rust binds `sid` with get/set closures. C++ binds `&MarkerRow::sid`. Those are how each language names the member without a generator.

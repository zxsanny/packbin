# Autodev Loop Plan — Loop 8

loop: 8
kind: product
confirmed: true
branch: loop/8-scheme-field-order
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | Specs AZ-2010 through AZ-2016 are in todo |
| decompose-feature | 9.5 | Decompose Feature | no | Already split into seven tasks, each at most 5 points |
| implement | 10 | Implement | yes | Anchors in six languages, Rust constructor check, failure sentence |
| feature-assess | 10.5 | Feature Assessment | yes | After implement |
| run-tests | 11 | Run Tests | yes | Always |
| test-spec-sync | 12 | Test-Spec Sync | yes | New ACs |
| update-docs | 13 | Update Docs | yes | Public constructors gain an anchor |
| security | 14 | Security Audit | no | No auth or secret scope |
| performance | 15 | Performance Test | no | No latency NFR |
| deploy | 16 | Deploy | no | Not a ship loop |
| release | 16.5 | Release | no | Deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | No cutover |
| retrospective | 17 | Retrospective | no | Four loops since the loop 4 retro |
| local-deploy | — | Local deploy + open site | yes | Loop close |
| smoke | — | Smoke acceptance | yes | Loop close |

## Implementation

### Files that change
- Scheme constructors and group helpers in csharp, typescript, python, rust, java, and cpp
- Call sites of repeat, when, times, flags, and a continuing group
- `_docs/01_solution/schema.md` order sentence

### Order of work
1. Add the anchor and the failure check in each language.
2. Close the Rust constructors that skip the walk.
3. Write the failure sentence next to field order is wire order.

### Proof
- A gap and a bad anchor fail construction in each language
- A list element and the following parent field can both be numbered 0
- A known hex is unchanged
- Rust rejects a raw field list with a gap, and a when or borrowed count that names an id not yet walked

### Risks
- A group anchor must not consume a slot, or every later id shifts.

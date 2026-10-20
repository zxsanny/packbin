# Autodev Loop Plan — Loop 51

loop: 51
kind: product
confirmed: true
branch: dev
ship: false

Intake: hopper hit on wave A of epic AZ-2750 (`handoff51.md`): AZ-2752 (flags, bits, u2, packed, sized, when) then AZ-2753 (repeat, group, times, lists, dicts), 10 points. Both write `rust/src/nostd/**`, so they run in sequence. AZ-2754 to AZ-2757 stay unclaimed in `todo/`.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs already in `todo/` (decomposed in loop 50) |
| decompose-feature | 9.5 | Decompose Feature | no | done in loop 50 |
| implement | 10 | Implement | yes | AZ-2752 batch, then AZ-2753 batch; one total review at the end (owner rule) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one run at HEAD: rust, rust-embedded, ring, scaffold, publish-gate |
| test-spec-sync | 12 | Test-Spec Sync | no | the ACs live in the task specs; the product ACs do not change |
| update-docs | 13 | Update Docs | yes | the public `nostd` API gains field kinds (Rust component doc, rustdoc) |
| security | 14 | Security Audit | yes | the decoder of untrusted bytes grows (counts, bits, conditions) |
| performance | 15 | Performance Test | no | no latency NFR; sizes are checked by the embedded stage |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | task complexity 5 (short: loop 50 ran the 47 to 50 retro) |
| local-deploy | — | Local deploy + open site | yes | none (library) |
| smoke | — | Smoke acceptance | yes | script in `smoke51.md` |

## Implementation

### Files that change
`rust/src/nostd/**` (scheme table with spans and refs, a checker, the walker split by kind group), `rust/tests/nostd_*` (differential and refusal tests per kind), `rust/embedded/**` only if the base image grows past its limits, `_docs/**`.

### Order of work
1. AZ-2752: `Field` grows to the C++ table shape (preorder entries with `span`, a ref to the `when` source or count, width and bias); builders for `flags`/flag byte/flag bit/`bool`, `bits`, `u2`, `packed`, `sized`, `when`; checks (source range, source after the `when`, empty body, duplicate name in one scope); `Row` access for presence; differential test against the std walker.
2. AZ-2753: `repeat`, `group`, `times`, lists and dicts over caller-owned storage through `Row` (item counts and element access by path); round and slot limits; ascending keys; the route-of-points worked example.

### Proof
Differential test (std bytes equal core bytes, std rows equal core rows) per kind; refusal tests; every cut and a trailing byte; the embedded stage (base set within 8,192 B flash and 512 B stack, no heap or panic link).

### Risks
The `Row` trait was designed for flat ids (card 1); nested members need a path or a scope. If the shape cannot stay a plain trait, stop and report before adding a macro or generics.

## Assessment rounds

None yet.

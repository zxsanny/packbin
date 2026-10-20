# Autodev Loop Plan — Loop 50

loop: 50
kind: product
confirmed: true
branch: dev
ship: false

Intake: hopper hit on `AZ-2749` (the only unclaimed spec, from the loop 49 record). Owner choices 2026-10-20: Complexity Budget option B (a buffer-based `core` module ported from the C++ heap-free core), "accept all recommended" on limits and epic (new epic AZ-2750), then scope "AZ-2749 + AZ-2751" and the rustup target download approved. The task was re-estimated from 5 to 34 points and decomposed into eight slices (`_docs/02_task_plans/rust-nostd-core/feature-description.md`); this loop runs the first two (10 points). The other six stay in `todo/` unclaimed for loops 51 to 53.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at intake: feature description, scenarios, eight specs |
| decompose-feature | 9.5 | Decompose Feature | no | done at intake (eight slices, tickets AZ-2749, AZ-2751 to AZ-2757) |
| implement | 10 | Implement | yes | AZ-2749 first (core, features, differential test), then AZ-2751 (embedded profile CI); same directory, so in sequence |
| feature-assess | 10.5 | Feature Assessment | yes | new subsystem; always after implement |
| run-tests | 11 | Run Tests | yes | one run at HEAD: the Rust suite, the ring, the new job, scaffold checks |
| test-spec-sync | 12 | Test-Spec Sync | no | the core ACs live in the task specs; the product ACs do not change |
| update-docs | 13 | Update Docs | yes | new public module and features: Rust component description and README (module layout done at decompose) |
| security | 14 | Security Audit | yes | a new decoder of untrusted bytes |
| performance | 15 | Performance Test | no | no latency NFR; sizes are AZ-2751 AC-2 |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | complexity 5 and due by loop 51 |
| local-deploy | — | Local deploy + open site | yes | none (library) |
| smoke | — | Smoke acceptance | yes | script in `smoke50.md` |

## Implementation

Optional; patched when a batch diverges.

### Files that change
`rust/Cargo.toml`, `rust/src/lib.rs`, new `rust/src/nostd/**`, new `rust/tests/nostd_*`, `rust/embedded/**`, the CI workflow and its job guards (AZ-2751), `_docs/**`.

### Order of work
1. AZ-2749 batch: features and the `no_std` switch, error and Result types, Reader/Writer, scalars and bytes, `Row`, scheme checks, differential test, golden on host.
2. AZ-2751 batch: target and recipe, static library linked into the QEMU image, size report, limits file, heap and panic link checks with seeded mutants, CI job and guards.

### Proof
Differential test (std equals core) on the fixtures; `cargo test` default and `--no-default-features`; the ring; the QEMU run printing the golden values and the sizes; mutants fail the link checks.

### Risks
A Rust static library may not link into the C++ startup and stack meter cleanly (card 3). If so: stop and report, no stand-in measure.

## Assessment rounds

None yet.

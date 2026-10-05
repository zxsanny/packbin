# Autodev Loop Plan — Loop 10

loop: 10
kind: product
confirmed: true
branch: loop/10-cpp-microcontroller
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` — never a plan row |
| decompose-feature | 9.5 | Decompose Feature | yes | about 29 points, handed off (`feature-description.md`) |
| implement | 10 | Implement | yes | T1–T8 from decompose; T9 (AVR) stretch per D-3 A |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always; host suite plus embedded QEMU/big-endian jobs |
| test-spec-sync | 12 | Test-Spec Sync | yes | 13 new C++ embedded ACs |
| update-docs | 13 | Update Docs | yes | public C++ API replaced (D-2 B); `languages.md`, README |
| security | 14 | Security Audit | yes | core parses untrusted radio packets into caller buffers |
| performance | 15 | Performance Test | yes | AC-5 flash/stack budget, AC-10 host throughput |
| deploy | 16 | Deploy | no | not a ship loop; registry publish waits for maintainer tokens |
| release | 16.5 | Release | no | deploy excluded |
| migration | 16.7 | Data/Traffic Cutover | no | no data store or traffic flip; wire bytes unchanged |
| retrospective | 17 | Retrospective | yes | feature is about 29 points |
| local-deploy | — | Local deploy + open site | yes | always at close (library: test compose) |
| smoke | — | Smoke acceptance | yes | always at close |

## Implementation

### Files that change
`cpp/` (new core headers and sources, host suite ported, dynamic walker removed),
Until AZ-2064 the core builds as its own test binary (`build/core_tests`, `-fno-exceptions -fno-rtti`) from `include/packbin/core.hpp` and `tests/core/`, so the old and new `packbin::` symbols never link together.
 embedded build files and examples, CI test workflow and test compose, publish script, README C++ section, `_docs/01_solution/languages.md`.

### Order of work
T1, then T2 and T6, then T3 and T4, then T5 and T7, then T8. T9 last, stretch only.

### Proof
Every hex vector asserted in `cpp/tests` before the port still asserted after it, and the same bytes on QEMU `mps2-an385` and a big-endian host.

Batch 4: the old walker is gone (one walker, `cpp/src/core/`). Embedded proof lives in `cpp/embedded/` (`run.sh arm|esp`, CI job `embedded` in `test.yml`, compose services `cpp-embedded`, `cpp-embedded-esp`). The Pico example runs on x86_64 only (no arm64 PlatformIO toolchain). The dict key order rule and the `flag_bit` rename (Arduino `bit` macro) came out of the embedded runs.

### Risks
D-2 B is a breaking C++ release. AC-12 needs a published tag and registry tokens, so it cannot be proven inside this loop.

## Course change (user, 2026-10-05)

After batch 4 the user asked for, in order: (1) a whole-project refactor check, (2) a security check, (3) the `v0.2.0` tag.

- Done: refactor Quick Assessment phases 0–1 — `_docs/04_refactoring/02-whole-project-assessment/` (baseline, discovery per package, `list-of-changes.md` C01–C31). It found cross-language logic bugs (bool bytes differ between packages, hangs on hostile packets, a thread race in C#/Java, Rust silent corruption, an unloadable Java jar, a non-atomic publish).
- Done: bug-fix epic **AZ-2069** with 36 task specs `_docs/02_tasks/todo/01_*.md` … `36_*.md` (most serious first; order and user decisions in `analysis/bugfix_task_plan.md`). Jira tickets for the 36 specs are not created yet (`Tracker: pending`).
- Next session: create the 36 Jira tickets under AZ-2069 and rename the specs to their AZ ids; add them to `_dependencies_table.md`; implement them (this loop, before the tag), then feature-assess, run tests, security audit (step 14, include the hostile-packet findings), update docs (incl. the 38-row `discovery/doc_drift.md`), then the `v0.2.0` tag (user-requested ship: deploy/release rows become `include: yes` at that point).
- AZ-2068 (AVR, stretch) stays in `todo/` behind the bug fixes.

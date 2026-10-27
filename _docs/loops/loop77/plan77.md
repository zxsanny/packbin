---
loop: 77
branch: dev
ticket: AZ-3338
points: 5
plan_confirmed: true
---

# Loop 77 Plan — Cross-language frame ring

## Summary

Add a cross-language frame ring that verifies frame-mode seal/open/mac across all 8 packages in an 8×8 matrix, following the ring-ecc.sh pattern.

## Implementation

### Wave 1 — Infrastructure (sequential, no subagents)

| Step | Files | AC |
|------|-------|----|
| 1. Ring cases fixture | `fixtures/frame/ring-cases.txt` | AC-2, AC-3 |
| 2. Reference checker | `scripts/frame/ring_frame.py` | AC-4 |
| 3. Ring script | `.github/workflows/ring-frame.sh` | AC-1, AC-8 |
| 4. Self-test | `.github/workflows/ring-frame.test.sh` | AC-5 |

### Wave 2 — 8 drivers (disjoint files, potential parallel)

| Step | Driver file | Language |
|------|-------------|----------|
| 5. Python | `.github/workflows/drivers/handoff_frame.py` | Python |
| 6. TypeScript | `.github/workflows/drivers/handoff-frame.ts` | TypeScript |
| 7. C# | `.github/workflows/drivers/csharp/HandoffFrame.cs` | C# |
| 8. Java | `.github/workflows/drivers/HandoffFrame.java` | Java |
| 9. Go | `.github/workflows/drivers/handoff-go/frame.go` | Go |
| 10. Rust | `.github/workflows/drivers/handoff-rust/src/frame.rs` | Rust |
| 11. Swift | `.github/workflows/drivers/handoff-swift/Sources/handoff-swift/Frame.swift` | Swift |
| 12. C++ | `.github/workflows/drivers/handoff_frame.cpp` | C++ |

### Wave 3 — CI + minor items

| Step | Files | AC |
|------|-------|----|
| 13. CI integration | `.github/workflows/test.yml` (ring job) | AC-8 |
| 14. Rust --all-features | `.github/workflows/run-suite.sh` | AC-6 |
| 15. Swift comment fix | `swift/Sources/Packbin/PackbinError.swift` | AC-7 |

### Step 11 — Full test run

Run ring-frame.sh locally and verify all 8 languages pass. Run the self-test. Then the existing suites.

## Decisions

- D1: Driver command is `frame-batch <file>`, following `ecc-batch <file>`.
- D2: Ring phases: seal (8 writers), open (8×8), mac (8 writers), verify (8×8). Four phases, same as the problem spec.
- D3: Checker uses framefmt.py (existing reference codec) for comparison.
- D4: Ring-cases.txt uses the 5 worked examples (E1–E5) plus length-variation and tamper cases from vectors.txt.
- D5: Each driver is a new file (matching ECC pattern), wired from the main handoff entry point.

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | CLARIFY | AZ-3341_frame_ring_tamper_wide | _docs/loops/loop77/assessment77.md |
| 2 | CLARIFY | AZ-3341 (AC-4 MAC half, AC-8 detail, AC-12); G8e awaits the owner | _docs/loops/loop77/assessment77.md (## Round 2) |

Round 1 owner answers (2026-10-27): U1 = A (key and msg_id length refusals stay out of the ring); scope = tamper rows and wider values now, refusal rows G2 and G3 to leftovers.

## Steps

| id | step | name | include | reason |
|----|------|------|---------|--------|
| implement | 10 | Implement | yes | AZ-3338 (1e2bb45, d0b8525), AZ-3341 |
| feature-assess | 10.5 | Feature Assessment | yes | round 1 CLARIFY, round 2 after AZ-3341 |
| run-tests | 11 | Run Tests | yes | one total run after round 2 |
| local-deploy | - | Local deploy | yes | no deploy path: CI ring only; smoke runs the ring locally |
| smoke | - | Smoke acceptance | yes | `smoke77.md` / `smoke77.sh` |
| update-docs | 13 | Update Docs | no | no public contract changed |
| security | 14 | Security Audit | no | test code only |

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

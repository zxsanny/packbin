---
loop: 77
branch: dev
ticket: AZ-3338
points: 5
---

# AZ-3338 Cross-language frame ring

## Summary

Add a cross-language frame ring that verifies frame-mode seal/open/mac across all 8 packages (64 pairs), following the ring-ecc.sh pattern.

## Acceptance criteria

- AC-1: `ring-frame.sh` exits 0 on HEAD with all 8 languages.
- AC-2: 8×8 seal/open matrix (64 pairs) tested.
- AC-3: MAC compute/verify cross-language (E4/E5 worked examples).
- AC-4: Reference checker rejects tampered sealed output.
- AC-5: Self-test (`ring-frame.test.sh`) proves the script detects tampered output.
- AC-6: `cargo test --all-features` in Rust CI matrix and passes.
- AC-7: Swift `PackbinError.Kind` doc comment accurate for frame kinds.
- AC-8: CI `ring` job runs `ring-frame.sh` and passes.

## Files

- `fixtures/frame/ring-cases.txt` — ring fixture
- `.github/workflows/ring-frame.sh` — ring script
- `.github/workflows/ring-frame.test.sh` — self-test
- `scripts/frame/ring_frame.py` — reference checker
- `.github/workflows/drivers/handoff_frame.py` — Python frame driver
- `.github/workflows/drivers/handoff-frame.ts` — TypeScript frame driver
- `.github/workflows/drivers/csharp/HandoffFrame.cs` — C# frame driver
- `.github/workflows/drivers/HandoffFrame.java` — Java frame driver
- `.github/workflows/drivers/handoff-go/frame.go` — Go frame driver
- `.github/workflows/drivers/handoff-rust/frame.rs` or integrated — Rust frame driver
- `.github/workflows/drivers/handoff-swift/frame.swift` or integrated — Swift frame driver
- `.github/workflows/drivers/handoff_frame.cpp` or integrated — C++ frame driver
- `.github/workflows/run-suite.sh` — add `--all-features` Rust line
- `swift/Sources/Packbin/PackbinError.swift` — fix comment

---
loop: 77
branch: dev
---

# Cross-language frame ring

## What

Frame mode shipped in all 8 packages (loops 69–76) but there is no cross-language ring: no test where language A seals a frame and language B opens it. Each package checks its own output against the reference vectors (`fixtures/frame/vectors.txt`) independently.

Add a cross-language frame ring (`ring-frame.sh` + `fixtures/frame/ring-cases.txt`) that runs the 8×8 matrix (64 pairs) for seal/open and the MAC/verify path, checked by the reference codec (`scripts/frame/framefmt.py`). Follow the established pattern of `ring-ecc.sh`.

## Who

All 8 packages: C#, TypeScript, Python, Rust, C++, Java, Go, Swift.

## In / Out

**In:** A key, epoch, direction, tag length, message id, kind, additional data, clear bytes, plaintext — the fields of a `seal` row from `vectors.txt`.

**Out per pair:** Language A seals → body bytes. Language B opens the body → plaintext. The reference codec verifies both against the expected values from `ring-cases.txt`. Exit 0 only when no row is mismatched across all 64 pairs.

## Also in this loop (minor)

- Add `cargo test --all-features` to the Rust CI matrix (`run-suite.sh`): 876 tests pass on HEAD, not currently in CI.
- Fix the Swift `PackbinError.Kind` doc comment (lines 4–5): the four frame kinds (`tag_mismatch`, `duplicate`, `too_old`, `buffer_full`) are not outcome terms of the shared hostile vectors.

---
loop: 77
branch: dev
---

# Cross-language frame ring

AZ-3338

## What

Frame mode shipped in all 8 packages (loops 69–76) and each package checks its own output against the reference vectors (`fixtures/frame/vectors.txt`) independently. There is no cross-language ring: no test where language A seals a frame and language B opens it. A subtle difference in how one package constructs the additional data, computes a tag or handles a counter would pass every per-package test but fail in production interop.

Add a cross-language frame ring that runs seal/open and MAC/verify through the 8×8 matrix (64 pairs), checked by the reference codec.

## Who

All 8 packages: C#, TypeScript, Python, Rust, C++, Java, Go, Swift.

## Behavior

1. **Fixture file** `fixtures/frame/ring-cases.txt`: rows derived from the worked examples (E1–E5) and additional vectors of `vectors.txt`. Each row is a seal or MAC instruction with its expected output, in a line-oriented format that a batch driver can read without parsing the full vectors.txt grammar.

2. **Batch drivers** — each language gets a `frame-batch <file>` command in its handoff driver (or a new driver file if the existing one is too large). The command reads `seal` and `mac` rows from the file and prints the body (or tag) as hex, one line per row. On error it prints the error kind.

3. **Ring script** `ring-frame.sh` — follows the `ring-ecc.sh` pattern:
   - Phase 1 (seal): every language seals every row → `seal.<lang>.out`
   - Phase 2 (open): every language opens every other language's sealed output → `open.<lang>.<reader>.out`
   - Phase 3 (mac): every language computes every MAC row → `mac.<lang>.out`; every language verifies every other language's tag → `verify.<lang>.<verifier>.out`
   - A Python checker (`scripts/frame/ring_frame.py`) compares all outputs against the reference codec (`scripts/frame/framefmt.py`). Exit 0 only when no row is mismatched.

4. **CI integration** — the ring script runs in the existing `ring` job of `.github/workflows/test.yml`, after `ring-ecc.sh`.

5. **Minor items** in the same loop:
   - Add `cargo test --all-features` to `run-suite.sh` Rust section (876 tests pass on HEAD, not currently in CI).
   - Fix the Swift `PackbinError.Kind` doc comment (lines 4–5): the four frame error kinds (`tag_mismatch`, `duplicate`, `too_old`, `buffer_full`) are not outcome terms of the shared hostile vectors — they are frame-mode error kinds.

## Acceptance criteria

- AC-1: `ring-frame.sh` exits 0 on HEAD with all 8 languages enabled.
- AC-2: The 8×8 seal/open matrix (64 pairs) is tested. Every seal output is opened by every language.
- AC-3: MAC compute and verify are cross-language (at least the E4/E5 worked examples).
- AC-4: The reference checker (`ring_frame.py`) rejects a tampered sealed output (one flipped byte → mismatch or open failure).
- AC-5: `ring-frame.sh` has a self-test (`ring-frame.test.sh`) that proves the script detects a tampered output.
- AC-6: `cargo test --all-features` is in the Rust CI matrix and passes.
- AC-7: The Swift `PackbinError.Kind` doc comment accurately describes which raw values are hostile-vector terms and which are frame-mode kinds.
- AC-8: CI `ring` job runs `ring-frame.sh` after `ring-ecc.sh` and passes.

## Expected I/O

**Seal driver input** (one line):
```
seal <case> <key hex> <epoch> <dir> <tag_len> <msg_id hex> <kind> <ad hex> <clear hex> <plain hex>
```

**Seal driver output** (one line per input):
```
<body hex>
```

**Open driver input** (one line):
```
open <case> <key hex> <epoch> <dir> <tag_len> <msg_id hex> <kind> <ad hex> <clear_len> <body hex>
```

**Open driver output** (one line per input):
```
<plain hex>
```
or `<error kind>` on failure.

**MAC driver input:**
```
mac <case> <key hex> <epoch> <label hex> <n> <message hex>
```

**MAC driver output:**
```
<tag hex>
```

**Verify driver input:**
```
verify <case> <key hex> <epoch> <label hex> <tag hex>
```

**Verify driver output:**
```
valid
```
or `invalid`.

## Out of scope

- Replay-window ring (the replay counter is local state, not cross-language wire format).
- Key-rotation ring (epoch changes are local decisions).
- Frame vectors.txt format changes — the ring-cases.txt is a separate file.

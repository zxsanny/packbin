---
loop: 85
branch: dev
---

# CI input guards: job-level `RING_PYTHON`, non-numeric `RING_FRAME_SHOWN` (loop 85)

Source: `_docs/loops/loop84/handoff85.md` (candidates "Low review items of loop 84"), probed on HEAD a9c2694 on 2026-10-30. The owner chose "Probe handoff candidates" for this loop; two candidates held, the rest did not (below). No UI.

## Problem

1. **A job-level `RING_PYTHON` is not compared with the compose image.** `ring-wiring-check.py` merges workflow and job env only for the ring job (`suite_errors`, line 92). `python_errors` checks the `setup-python` expression in every job, so a job that sets its own `env: RING_PYTHON: "3.12"` passes: probe on HEAD, `test.yml` copy with that env in `scaffold` gives exit 0 (wanted: rejected; the version lives at workflow level since AZ-3393).
2. **A non-numeric `RING_FRAME_SHOWN` ends in a Python traceback.** `scripts/frame/ring_frame.py:38` does `int(os.environ.get(...))` at import: `RING_FRAME_SHOWN=abc` gives `ValueError: invalid literal for int()` (hand-set only; CI never sets it).

Probed and dropped: the AVR `chacha20_xor` check (needs an emulator), the Go window floor (conditional on a stalled CI run that never happened; `go/timing_test.go:92` already caps the window), `item` pointer removal, `session_core` clippy, ring driver for `nostd`, 128 KiB image, cycle timing (each larger or without evidence; they stay in the handoff).

## Change location

No UI. Verbal: the CI wiring checker `.github/workflows/ring-wiring-check.py` with its mutant test `.github/workflows/ring-wiring.test.sh` (item 1), and the frame ring reader `scripts/frame/ring_frame.py` with `.github/workflows/ring-frame.test.sh` (item 2).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Rejecting a job-level `RING_PYTHON` must not reject the legitimate job-level `RING_*` versions of the `ring` job | AC-2 (real files stay at 0 violations) | open | Low |
| `RING_FRAME_SHOWN=0` or a negative number is numeric but meaningless | AC-4 names the accepted range | open | Low |

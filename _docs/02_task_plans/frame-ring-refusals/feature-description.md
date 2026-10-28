# Feature: frame ring refusal rows and driver hardening (loop 78)

Add by-name refusal rows (`TooLong`, `BadValue`, `BufferFull`, bad or unloaded direction, bad MAC label and `n`) to the cross-language frame ring, with `dirs` and `out_len` on the seal and open lines, so each of the 8 drivers prints the reference error name instead of aborting; make the 8 drivers strict about hex and line shape (L-1), make the Go driver check every parse (L-3), make Python answer `open-skip` / `verify-skip` with `skip`, and make `ring_frame.py` blame a writer that prints a word that is not hex (L-2). Full text: `problem.md`; ACs: `acceptance_criteria.md`; expected pairs: `input_data/expected_results/results_report.md`.

Complexity: Scope medium (8 drivers, checker, fixture, self-test, one new script, CI wiring), Novelty low (loop 77 pattern), Risk medium (loop 77's first push was red with six defects). The LESSONS `estimation` entries (probe candidates on HEAD; cross-language work runs over) round the estimate up: **8 points**. Hand off to `/decompose --feature`.

Components: CI ring (`.github/workflows`, `scripts/frame`, `fixtures/frame`) only. No package source, no public API, no contract change.

## Scenarios

See `scenarios.md` (R1-R12; R3 and R12 out-of-scope, the rest confirmed).

## Fit decisions

- **Strict hex makes a bad writer louder (resolved).** Once a reader exits non-zero on a non-hex token, a writer that prints `TooLong` for a good row makes every reader fail with "frame-batch (open) failed" and the checker never runs, so the message names the readers and not the writer (this is L-2). Resolution: the L-2 change in `ring_frame.py` lands in the same batch as, or before, the strict-hex change in any driver. Constraint for the owning task: the order of work puts the checker first.
- **Defaults keep old lines valid (resolved).** `dirs` and `out_len` are trailing and optional (`123` and 300), so the existing seal and open lines and the self-test stand-in keep working; the stand-in `fake.py` learns the two fields in the same batch.
- **Same cases as `vectors.txt` (accepted-risk).** The owner chose the full bundle on 2026-10-28 knowing the cases are also checked per package.

## Suggested split

1. Refusal rows: row kinds, `dirs`/`out_len` in checker, fixture, 8 drivers (no abort, buffer from the row), `fake.py`, self-test cases (AC-1 to AC-7, AC-12). About 5 points.
2. Driver hardening: L-2 in `ring_frame.py` first, then strict hex (L-1), Go (L-3), Python skip, the driver test script run on the real drivers and its CI wiring (AC-8 to AC-11). About 3 points. Depends on 1 (same files).

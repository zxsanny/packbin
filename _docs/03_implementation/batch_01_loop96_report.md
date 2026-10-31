# Batch Report

**Batch**: 1
**Tasks**: AZ-3495_ring_multipart_mac_rows
**Date**: 2026-10-31

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3495_ring_multipart_mac_rows | Done | 8 drivers, `ring_frame.py`, `ring-cases.txt`, `fixtures/frame/README.md`, 2 ring test scripts | ring 64 pairs x 56 rows, 0 mismatched; `ring-frame.test.sh` all passed (45); `ring-frame-drivers.test.sh` 340 checks, 0 failed; scaffold PASS; ring stage PASS | None |

## Code Review Verdict: PASS

`code-review` low: 0 findings.

## Test Suite

- `bash .github/workflows/ring-frame.sh` on HEAD 98d2202 (before): 64 pairs, 45 rows per pair, 72 refusal rows per language, mismatched 0, 30 s.
- Same on the changed tree: `30 mac rows and 11 refusal rows`, `30 verify rows for each of 8 writers, and 7 refusal rows`, 64 pairs x 56 rows, `refusals <lang>: 76 rows, 0 mismatched` (8 languages), mismatched 0, 30 s (AC-3).
- `ring-frame.test.sh`: all passed (45 checks, 7 new: four stand-in liars, `pieces-keep-bars`, `row-empty-piece-bare`, `mac-pieces-tag-changed`; line pins 17 -> 19 and 41 -> 43 after the two header lines).
- `ring-frame-drivers.test.sh`: 8 languages, 340 checks, 0 failed (8 new per language: two-piece, empty-piece and verify answers, five refused lines).
- `scripts/loop-tests.sh --all --only scaffold,ring`: scaffold PASS (182 s), ring PASS (46 s).
- AC-5 mutation: the Go driver passing only `parts[0]` (`RING_FRAME_LANGS="python go"`): exit 1, `go: P.two mac gave f4814847, wanted 56db9bec`, `P.first0`, `P.mid0`, `P.split56`, `P.split64` and 13 more per pair, 18 mismatched; file restored (compared with a copy).
- CI-parity: PASS. The CI `scaffold` and `ring` jobs run these scripts; `loop-tests.sh` runs the same lists.
- Not run locally: the language suites, `cpp-embedded-arm`, `rust-embedded`, `ac10`, publish gate (no package source changed; CI runs them on the close push).
- Environment: build output owned by root (left by container runs) first failed the C# driver build and then `language-pair.sh`; the owner ran `sudo chown -R` (owner, 2026-10-31) and both stages then passed. The count of root-owned paths is 0.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A driver that joins the pieces, or drops an empty one, hands the package the same bytes, so the HMAC is the same and no row can tell it | AZ-3495 AC-5 | AC-5 and the README say so; the stand-ins are "first piece only" and "stops at the first empty piece" | clear (HMAC over the concatenation) |
| 2 | Before the change every driver took an empty hex string as zero bytes (`ab\|\|cd` was accepted) | AZ-3495 AC-4 | each driver's piece reader refuses an empty piece before the hex reader; one rule in 8 drivers | clear |

## Commit

`[AZ-3495] Add MAC rows over a message in pieces to the frame ring`. Body: one line + `Loop: 96`.

## Next Batch: All tasks complete

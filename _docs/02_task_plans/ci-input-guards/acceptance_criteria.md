# Feature acceptance criteria — loop 85

Inherited baseline: project `_docs/00_problem/acceptance_criteria.md` (no row exercised; CI hygiene only).

## RING_PYTHON in one place (AZ-A)
- AC-1: A copy of `test.yml` with `RING_PYTHON: "3.12"` in the job env of `scaffold`: `ring-wiring-check.py` exit 1 (HEAD exit 0), message names job `scaffold` and `RING_PYTHON`.
- AC-2: The real `test.yml` and compose file: exit 0, 0 violations, unchanged from HEAD; all 42 existing mutants of `ring-wiring.test.sh` keep their verdicts.
- AC-3: `ring-wiring.test.sh` has 1 new mutant for AC-1 and passes (43 mutants).

## RING_FRAME_SHOWN input (AZ-B)
- AC-4: `RING_FRAME_SHOWN` is a decimal integer from 1 to 1000000. Any other value (`abc`, ``, `0`, `-1`, `1.5`, `1000001`): `ring_frame.py` exits 2, prints exactly one line naming `RING_FRAME_SHOWN` and the accepted range, and no traceback (HEAD: traceback, exit 1).
- AC-5: Unset gives 5, `1000` still works (the `id-padded` case of `ring-frame.test.sh` stays green); default `ring-frame.sh` output is byte-identical to HEAD (64 pairs, 0 mismatched).
- AC-6: `ring-frame.test.sh` has 1 new case that sets a bad value and expects exit 2 with the message, and passes.

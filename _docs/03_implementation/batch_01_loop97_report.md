# Batch 01 report — loop 97

Tasks: AZ-3499 (parity_percent_reference, 3 points), by the parent.

| Task | Status | Tests |
|------|--------|-------|
| AZ-3499 | Done | `fixtures/ecc/check-vectors.test.sh` 11 PASS (incl. full sweep of 22,752 pairs, 0 errors), `check-contract.sh` PASS, `ring-ecc.test.sh` PASS, `accept_table.py --check` PASS |

Figures read on HEAD in this loop: largest clear length 251 / 230 / 222 / 222 / 222 for p 1 / 10 / 25 / 50 / 100; impossible sent lengths of 0..254: 0 / 3 / 24 / 32 / 32 / 32 for p 0 / 1 / 10 / 25 / 50 / 100; `percent-vectors.txt` 1,033 rows; `vectors.txt` byte-identical to HEAD.

Changes against the plan (plan-diff-sync): the new rows are in their own file `fixtures/ecc/percent-vectors.txt` (not in `vectors.txt`), because the eight loaders read `part[2]` as a count and branch on the row word; a new word in `vectors.txt` would fail their tests before their tasks land. A row word `limp` was added (largest clear length). `p` 0 has no 254-byte limit (unprotected, as `lim.n0.255` is `ok`); AC-4 and the results report were corrected before code.

Review: code-review (low) 0 findings. CI-parity: PASS (the three scripts CI runs for this area, `test.yml` lines 392 and 394, plus `ring-ecc.test.sh`).

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear/unclear |
|----------|-----------|-------------------|---------------|
| AC-4 | p 0 has no ECC limit, not 254 | corrected in AC-4 and results report; reference follows `lim.n0.255` | clear |
| AC-15 | New rows must not enter `vectors.txt` | own file `percent-vectors.txt`; AC-15 and task specs updated | clear |
| AC-7 | 11 wrong bytes under n 20, t 10 is refused only with certainty up to `n - t` | rows are seeded patterns the reference refuses; wording fixed | clear |

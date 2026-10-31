# Loop 95 smoke — proposed checks

LOCAL_URL: none (no UI, no local deploy script; the arm stage runs in the `packbin-embedded` container)
Branch: dev

## Perform these checks (shell, repository root)

- [ ] `docker compose -f docker-compose.test.yml run --rm cpp-embedded` ends `embedded stage arm: 0 target(s) failed`; the `cpp-m33f` section shows `small no_text_tests.cpp asserted=25 run=25`, `small no_ecc_tests.cpp asserted=6 run=6` and two `object-check: 5 objects ... ` lines (AC-1, AC-2, AC-4)
- [ ] the same run shows `small: __cxa_throw=0 __cxa_allocate_exception=0 ... os_rng_symbols=0` (AC-3)
- [ ] the other rows keep their figures: 315 of 315 vectors, 25,760 B, 724 B, 8,416 B / 912 B (AC-6)
- [ ] `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded` prints `2 passed ... 0 failed` (AC-10)
- [ ] change one expected hex byte in `cpp/tests/core/no_ecc_tests.cpp`, rerun the arm stage: the `cpp-m33f` row fails (AC-5); `git checkout -- cpp/tests/core/no_ecc_tests.cpp` afterwards
- [ ] README "Microcontrollers" and `_docs/AGENT_GOTCHAS.md` no longer say the reduced build has no ARM run (AC-9)

## Notes
No credentials involved.

## Agent walk
Checks 1 to 4 and 5 (via scratch copy, repo untouched) observed in this loop: arm stage 18 s, all rows PASS, `loop-tests` 2 passed 0 failed 20 s, seeded changed value, `malloc` and codec-symbol scratch runs each failed the row with the cause named. Check 6 by `git diff`.

# Loop 28 smoke — proposed checks

LOCAL_URL: none (CI and test tooling, no UI; the proof is the CI run and the step 11 log)
Branch: dev

## Perform these checks

- [ ] CI run 38731123341 of `b7d6577` (https://github.com/zxsanny/packbin/actions/runs/38731123341): the five jobs `scaffold`, `suites`, `publish-gate`, `embedded`, `ring` are green (SP-1)
- [ ] The run took at most 25 minutes end to end (SP-2, run 1 of 2; run 2 is the close push)
- [ ] The publish gate prints 14 `publish-gate: <check> took N s` lines and a total (SP-5)
- [ ] The `cpp` stage passed in the pool without a "re-run alone" line (CR-2)
- [ ] The README Swift line and section, and ADR-005, state that a Swift 6.0 consumer and an Xcode 16.0 build are unproven (DO-1)
- [ ] `_docs/05_security/swift_peak_memory_loop28.md` holds the 4 figures, none above 1 000 MB (PM-1)

## Agent walk

No browser or UI in this loop; the agent checked each item from the CI Actions API, the step 11 log and the files.

- PASS: run 38731123341, 5 of 5 `success`
- PASS: 22 min 51 s (11:58:07 to 12:20:58); gate step 1 269 s; `suites` step 1 030 s
- PASS: 14 timing lines and `total took 1059 s in 14 checks` in the step 11 gate log
- PASS: `STAGE cpp: PASS (42s)`, no retry line, `RESULT 13 passed, 0 failed`
- PASS: README (2 places) and ADR-005 carry the limit; 0 `swift:5.9` in the README
- PASS: file present, 731 / 154 MB macOS, 738 / 147 MB container

## For the operator

- Read the README Swift section sentence "Limit: a Swift 6.0 consumer and an Xcode 16.0 build are unproven ..." and say if the wording is what you want (S3 stays B: documented, not proven).
- SP-2 needs a second run under 25 minutes: the close push of `dev` and `main` provides it; I read it after the push.

## Notes

No credentials. No tag, no registry upload.

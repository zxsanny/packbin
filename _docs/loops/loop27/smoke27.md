# Loop 27 smoke — proposed checks

LOCAL_URL: none (CI-only change; no UI, no local service)
Branch: dev

## Perform these checks (GitHub Actions page of the repository, or the API read below)

- [ ] CG-1: the latest `test.yml` run on `dev` shows `scaffold`, `embedded`, `ring` all green
- [ ] CG-2: its `publish gate` step is at most 25 min and `scaffold` at most 50 min
- [ ] CG-3: at least 2 consecutive green `test.yml` runs on `dev` with the gate step green (runs 38694589648 and 38700362252; a third at the next loop)
- [ ] CG-5: the `suites` step is shorter than the 1 238 s before the sanitizer scope (run 38700362252: 860 s)
- [ ] CG-8: `git ls-remote --tags origin` lists no tag newer than `v0.2.2`; no registry upload ran (`publish.yml` last ran 2026-10-06)
- [ ] Regression: step 11 report `_docs/03_implementation/test_run_loop27_report.md` reads 11 passed, 0 failed (cpp passed on a serial retry, race recorded as a leftover)

## Notes

No credentials needed: the repository is public and the Actions API is read without a token. The agent reads the same values with `curl` and records them under `## Agent walk`.

## Agent walk (2026-10-15, Actions REST API read with `curl`, no browser: no UI in this loop)

- PASS CG-1: runs 38694589648 (`94834ef`) and 38700362252 (`00ad75f`): `scaffold`, `embedded`, `ring` all `success`
- PASS CG-2: gate 1 322 s and 1 061 s (limit 1 500 s); `scaffold` 2 618 s and 1 977 s (limit 3 000 s)
- NOT RUN CG-3: 2 of 3 consecutive green gate runs; the third is the loop close push (read after it, or at the next loop start)
- PASS CG-5: `suites` 860 s against 1 238 s before; the local stage 349 s against 651 s
- PASS CG-8: newest tag on origin is `v0.2.2`; the last `publish` run is 2026-10-06; this loop ran only `git push origin dev`
- PASS Regression: `_docs/03_implementation/test_run_loop27_report.md`: 11 passed, 2 skipped as unchanged, 0 failed (cpp passed on the serial retry, race recorded as a leftover)

## For the operator

- The third green gate run (CG-3) comes from the close push of `dev`; nothing else to do by hand.

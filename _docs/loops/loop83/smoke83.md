# Loop 83 smoke - ring and driver tidy

LOCAL_URL: none (scripts, the ring and the CI `scaffold`, `ring` jobs; no site). Branch: dev. Script: `bash _docs/loops/loop83/smoke83.sh`. Run by the agent (owner rule 2026-10-12 in `_docs/04_deploy/deployment_procedures.md`).

## Checks

- [x] 1. No application source is dirty
- [x] 2. Every driver source is at most 500 lines (`handoff.cpp` 320, `handoff_ecc.cpp` 133, `handoff_frame.cpp` 198, `handoff_common.hpp` 23); the compile line of `ring-lib.sh` names the three and keeps `|| return` (AZ-3387 AC-1, AC-4)
- [x] 3. `gcc:16 g++ -std=c++17 -O2 -Wall -Wextra -Werror` builds the split driver and `pack-user` runs (AZ-3387 AC-2)
- [x] 4. `ring-frame.sh` 64 pairs, 0 mismatched, `refusals <lang>: 72 rows, 0 mismatched` in all 8 languages; `language-pair.sh` and `ring-ecc.sh` (64 pairs, 45440 rows, 0 mismatched) exit 0 (AZ-3387 AC-3, AZ-3389 AC-3)
- [x] 5. The 12 definitions: 0 in each checker, 12 in `workflow_yaml.py`; `ring-wiring-check.py` runs under `python3 -I` from `/`; `workflow_yaml.test.sh`, `yaml_get.test.sh`, `publish-pins.test.sh` pass; `test.yml` runs the helper test (AZ-3388 AC-1, AC-4, AC-6)
- [x] 6. 56 `refuse-` rows; `ring-wiring`, `ring-wiring-rows`, `ring-wiring-swift`, `ring-lib`, `ring-frame`, `ring-frame-drivers`, `ring-ecc`, `ring-prepare`, `publish-jobs`, `publish-workflow` tests pass (AZ-3387 AC-5, AZ-3388 AC-2, AZ-3389 AC-5)
- [x] 7. In a copy of the tree, a Python package that checks the key length after the size checks makes `ring-frame.sh` exit 1 with `python: R.open.key33...gave TooLong, wanted BadValue` lines; the real `python/` is unchanged (AZ-3389 AC-4)
- [x] 8. `bash -n`, `py_compile`, no touched source over 500 lines

## Agent walk

`smoke83.sh` at 10c9165 (the commit before the close commit), host load below 4: steps 1 to 8 PASS, `smoke83: 8 steps run, 0 failed`.

- The first trial run failed step 7 on the script, not the check: the copy lacked `scripts/crypto` (`framefmt.py` imports `chacha20`). The copy list was fixed and step 7 passed; the check was not touched.
- Step-11 stages before the smoke: `loop-tests.sh --only scaffold,ring,publish-gate --all`: scaffold 159 s PASS, ring 40 s PASS; the first publish-gate run failed in 7 s on `Disk quota exceeded` (the three worker tree copies in the scratchpad, 1.7 GB, had filled /tmp); after removing them publish-gate PASS in 151 s.
- Step 7 prints only 5 of the new-row lines (the ring caps mismatch lines per reader at 5).

## Result

10c9165: 8/8 steps passed; agent run, owner rule 2026-10-12 in `deployment_procedures.md`. Smoke: PASS.

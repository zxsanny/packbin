# Loop 84 smoke - CI wiring, all_kinds.cpp, review cleanups

LOCAL_URL: none (scripts, the cpp and ARM stages, the ring and the CI `scaffold` job; no site). Branch: dev. Script: `bash _docs/loops/loop84/smoke84.sh`. Run by the agent (owner rule 2026-10-12 in `_docs/04_deploy/deployment_procedures.md`).

## Checks

- [x] 1. No application source is dirty
- [x] 2. `cpp/embedded/common` sources are at most 500 lines (`all_kinds.cpp` 314, `all_kinds_rounds.cpp` 246); `Makefile`, `arm.sh` (4 or more lines) and the ESP `CMakeLists.txt` name `all_kinds_rounds`; `m33f_flash_pin=25760` (AZ-3391 AC-1, AC-3)
- [x] 3. `loop-tests.sh --only cpp,cpp-embedded-arm --all`: 2 stages pass (host build gcc:16 `-Werror`, ARM stage with the M33F image against the raised pin) (AZ-3391 AC-2, AC-5)
- [x] 4. The wiring check: real files clean from `/` under `python3 -I`; `SCAFFOLD_SCRIPTS` names both new scripts; copies with the "CI YAML reader" step removed, the "CI workflow helpers" step removed, `RING_PYTHON: "3.13"` and a literal `python-version` in `scaffold` all exit 1 with the script or variable named; `ring-wiring.test.sh` 42 `rejects:`; rows, swift, pins, reader and helper tests pass; `test.yml` names 3.14 once (AZ-3390 AC-1 to AC-4, AZ-3393 AC-1 to AC-4)
- [x] 5. `ring-frame.sh` 64 pairs, 0 mismatched, 72 refusal rows x 8; `ring-frame.test.sh` and `ring-frame-drivers.test.sh` pass (AZ-3392 AC-4)
- [x] 6. In a copy of the tree with 10 rows sorted ahead of the `id-padded` needle, the new `ring-frame.test.sh` passes and HEAD's (a925aa7) fails `id-padded` (AZ-3392 AC-3)
- [x] 7. `bash -n`, `py_compile`, no touched source over 500 lines

## Agent walk

`smoke84.sh` at 202a6ed (the commit before the close commit), host load below 4: steps 1 to 7 PASS, `smoke84: 7 steps run, 0 failed`. The trial run (steps 1, 2, 4, 6, 7) passed first time; step 3 took 76 s because the embedded image was warm from the earlier loop-tests run.

Not covered here: the ESP-IDF stage (`embedded-esp-core`, `embedded-esp-packages`) has no local image; its source list was read against the parts. The swift consumer resolve is NOT RUN (no swift on PATH), as in loop 83. `shellcheck` is not installed.

## Result

202a6ed: 7/7 steps passed; agent run, owner rule 2026-10-12 in `deployment_procedures.md`. Smoke: PASS.

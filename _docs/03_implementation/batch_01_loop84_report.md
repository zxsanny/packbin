# Batch 1 report - loop 84

Tasks: AZ-3390 (scaffold requires the two helper-test steps), AZ-3391 (split `all_kinds.cpp`), AZ-3392 (loop 83 review cleanups), AZ-3393 (one place for the Python version). One parallel wave, three workers in separate tree copies (W1: AZ-3390 then AZ-3393; W2: AZ-3391; W3: AZ-3392), paths disjoint; the parent compared each owned path with HEAD before copying it back and ran the union.

## Task results

| Task | Status | Result |
|------|--------|--------|
| AZ-3390 | Done | `SCAFFOLD_SCRIPTS` 3 -> 5 entries; 2 mutants (step deleted) in `ring-wiring.test.sh`; HEAD exit 0 -> exit 1 with the script named, for both deleted steps and for `if` / `continue-on-error` on either |
| AZ-3391 | Done (owner decision on the M33F pin) | `all_kinds.cpp` 560 -> 314 + `all_kinds_rounds.cpp` 246 + `all_kinds_internal.hpp` 25 (the two `differs` templates); `Makefile` x2, `arm.sh` (compile, 3 links, s390x sources) and the ESP `CMakeLists.txt` list both parts; vectors output identical to HEAD; M4F flash probe 7,712 B and stack 540 B unchanged; the Cortex-M33F image grew 25,720 -> 25,760 B (+40, two translation units), so `m33f_flash_pin` was raised to 25,760 with the owner's answer of 2026-10-30 and a line in `AGENT_GOTCHAS.md` |
| AZ-3392 | Done, 0 includes removed | all 13 includes of `handoff_ecc.cpp` / `handoff_frame.cpp` have 1 or more uses (counts in the worker report), `handoff.cpp` has none to remove; `RING_FRAME_SHOWN` (default 5) lifts the print cap for the `id-padded` case; with 10 extra rows ahead of the needle HEAD's test FAILS, the changed one passes and still catches the lying go driver; default `ring-frame.sh` output identical (64 pairs, 0 mismatched, 72 refusal rows x 8); C++ driver identical over 1,705 invocations |
| AZ-3393 | Done | `RING_PYTHON` is a workflow-level `env`; the `setup-python` steps of `publish-gate-rest` and `scaffold` read `${{ env.RING_PYTHON }}`; `grep -c '3\.14' test.yml` 3 -> 1; the checker merges workflow env under job env, rejects `RING_PYTHON: "3.13"` against `python:3.14` and a literal `python-version` in any job; 2 new mutants (4 new in all with AZ-3390: 38 -> 42 `rejects:`) |

## Parent-owned edits

- `.github/workflows/ring-frame.sh` header: `RING_FRAME_SHOWN` added to the environment list.
- `_docs/04_deploy/ci_cd_pipeline.md` lines 21 and 37: `RING_PYTHON` is in the workflow env, read by the `setup-python` steps.
- `cpp/embedded/lib.sh` `m33f_flash_pin=25760` and `_docs/AGENT_GOTCHAS.md` (the figure and the reason).

## Tests (parent, merged tree, host load below 4)

- `scripts/loop-tests.sh --only cpp,scaffold,cpp-embedded-arm,ring,publish-gate --all`: 5 passed, 0 failed, 605 s (cpp 58 s, scaffold 156 s, cpp-embedded-arm 258 s, ring 46 s, publish-gate 145 s; the tree was identical before and after the shares). Arm rows: m0plus, m3-qemu, m4f (7,712 B / 540 B), m33f (25,760 B / 724 B), s390x (315 of 315, packet equals the Cortex-M3 bytes), avr-uno.
- Wiring tests: `ring-wiring.test.sh` 53 lines, 42 `rejects:` (HEAD 49 / 38); `ring-wiring-rows.test.sh` 25 / 19 and `ring-wiring-swift.test.sh` 67 / 53, output identical to HEAD; `publish-pins.test.sh`, `yaml_get.test.sh`, `workflow_yaml.test.sh`, the checker on the real `test.yml`: exit 0.
- Not run: the ESP-IDF stage (no image, `CMakeLists.txt` read against the parts); `shellcheck` (not installed); the swift consumer resolve (no swift on PATH, as in loop 83).

CI-parity: PASS for the jobs the diff touches (`scaffold`, `ring`, `embedded-arm`, `cpp`, `publish-gate`) by the stages above; the two ESP jobs are NOT RUN here, so CI is their first run.

## Review

PASS_WITH_WARNINGS (parent read every diff; 0 bugs, 4 Low): (1) a job-level `RING_PYTHON` override in a non-ring job is not compared with the compose image (the literal check still forces `setup-python` to read the variable); (2) a non-numeric `RING_FRAME_SHOWN` gives a Python traceback (hand-set only); (3) the new check also rejects a `setup-python` step with no `python-version` (stricter, none exists); (4) `m33f_flash_pin` has again zero margin.

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear / unclear |
|----------|-----------|-------------------|-----------------|
| AZ-3391 AC-5 | the second translation unit costs 32 B (M4F `ac2` image) and 40 B (M33F) of flash; the M33F pin had zero margin | owner chose to raise the pin by 40 B (done, with the gotcha line) | clear |
| AZ-3391 | `arm.sh` has 3 link lines for `all_kinds.o` besides the compile and sources lines the spec counted | all updated | clear |
| AZ-3392 AC-1 | no include of the two parts has 0 uses | nothing removed; recorded | clear |
| AZ-3392 AC-3 | `ring-frame.sh` header did not list the new variable | parent added it | clear |
| AZ-3393 | `ci_cd_pipeline.md` said `RING_PYTHON` is in the job env and the version "written out in the step" | parent updated both lines | clear |

## Commit

`[AZ-3390] [AZ-3391] [AZ-3392] [AZ-3393] Scaffold requires the helper-test steps, split all_kinds.cpp, one Python version place`

Next batch: none.

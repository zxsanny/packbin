# Autodev loop record — loop 47

loop: 47
branch: dev
plan_artifact: _docs/loops/loop47/plan47.md
tasks_shipped: [AZ-2744, AZ-2745]
decisions:
  - hopper hit (loop 46 record leftovers and `handoff47.md`); owner 2026-10-20 asked once and chose "accept all recommended": CI-split (AZ-2744, 3 points) and TSan (AZ-2745, 2 points); AZ-2742 (C++ shortcut, needs a flash and stack saving and the arm embedded stage) stays To Do
  - agent: two specs and two Jira tasks under epic AZ-2645 written from the handoff; two workers with disjoint files (the CI ring, the Swift suite script), the parent reviewed the diff and ran step 11 once; retrospective and feature-assess not in the plan (CI scripts only, 1 loop since the last retro)
  - agent: `ring-lib.sh` holds the work and driver paths, `run_lang` and `handoff`; `language-pair.sh` sources it and checks both the file and the function by name (452 lines, was 545); `ring-wiring.test.sh` builds one concatenated file of lib and rows so every exact-line guard keeps reading one text; the session-ecc check has its own file; `test.yml` and `scripts/loop-tests.sh` run the two new tests (no new job)
  - agent: `ring-wiring.test.sh` is still exactly 500 lines (its comments were tightened to stay there)
leftovers:
  - AZ-2742 (C++ shortcut for the repeated text, 3 points, To Do) and the 1 s bound it restores
  - comments in `ring-cxx.sh`, `ring-go.sh`, `ring-swift.sh`, `ring-prepare.sh`, `ring-toolchains.sh` and `publish-vcpkg.test.sh` still say `language-pair.sh` for what now lives in `ring-lib.sh` (comment text only)
  - `ring-wiring.test.sh` sits at exactly 500 lines: the next change to it needs a split first
  - CS-D5 (retrain the tables on the owner's 100 to 200 real messages) waits for the owner; the first `v*` and `go/v*` tags and F44 are owner-run
  - not run here: the vcpkg supports and consumer checks (no vcpkg on this Mac), the ESP stage (CI only); AZ-2744 and AZ-2745 CI timing (ring job, Swift sanitized step) is read after the push
  - Jira: epic AZ-2645 stays open (AZ-2742)
smoke: PASS (agent run 7/7 at 85a4714, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop47/smoke47.md
step11: RESULT 13 passed, 0 skipped as unchanged, 0 failed, 1704 s at 85a4714
loop_end_merge: main

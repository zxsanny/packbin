# Autodev loop record - loop 122

loop: 122
branch: dev
plan_artifact: _docs/loops/loop122/plan122.md
tasks_shipped: [AZ-4277, AZ-4278]
origin: agent
decisions:
  - agent: the hygiene queue item (2 entries) ran as one loop of two tasks, serial by the parent (agent-made loop 2 of 3 in a row)
  - agent: D17 applied (Debian clang-19 in the gcc:16 image, major pinned in tool-pins.txt)
  - agent: the sanitizer build is a step of the cpp suite, not a CI job: test.yml is at the 20 jobs publish-jobs-layout.py allows and its suites matrix takes only the nine language names
measurements:
  - Dart cost test: best of 3 builds; a quadratic first-writer walk takes 10.0 to 15.2 s against 300 ms and fails it; 3 of 3 alone at load 14 to 24
  - first CI-image sanitizer build found two defects the Mac's Apple clang does not show: a fold of 302 nodes over clang 19's nesting limit 256 (-fbracket-depth=512 in SAN_FLAGS) and memcpy/memcmp from an empty vector's null data() in ecc_percent_host_tests.cpp (guarded); a recover-mode run then showed no other report
  - cpp suite in gcc:16: plain 52 to 171 s (load), clang install 7 to 35 s, sanitizer build and run 52 to 110 s
  - step 11 `scripts/loop-tests.sh --jobs 4` (13 stages) at load 25 to 154: java, dart, go, cpp, swift failed in the pool (load spike to 154 and container DNS loss: go `proxy.golang.org: no such host`, cpp apt could not reach Debian) and passed on the serial retry; publish-gate failed once on `unexpected tool: clang` (PINS_NAMES, fixed) and passed alone (389 s); vcpkg NOT RUN (N2)
  - smoke `smoke122.sh` 7/7 PASS at `e25c8d6`
review: "PASS_WITH_WARNINGS (`_docs/03_implementation/batch_01_loop122_report.md`): 5 findings; 2 fixed (apt retries, missing-pin message), 1 already handled, 2 carried to hygiene (Low)"
feature_assessment: COMPLETE, round 1 (`assessment122.md`)
security: "`_docs/05_security/lite_loop122.md` ESCALATE (T1, T4) -> `security_report_loop122.md` PASS, 1 Low (L1: clang-19 tied to the floating gcc:16 base)"
retro: none (due by loop 123)
leftovers:
  - _docs/02_tasks/backlog/hygiene.md (2 entries: `cpp-fold-depth-upstream-clang`, `cpp-sanitizer-clang-base`)
  - _docs/OPERATOR_TODO.md D17 (applied, may be overturned); N1, N2, N4, D5, D6, D9, D11 unchanged
  - AZ-4278 AC-1 (three green CI runs on dev): the close push is run 1; runs 2 and 3 are read at the next loop's pushes
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop122/smoke122.md
assessment_artifact: _docs/loops/loop122/assessment122.md
loop_end_merge: main

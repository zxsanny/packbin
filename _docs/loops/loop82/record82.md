# Autodev loop record — loop 82

loop: 82
branch: dev
plan_artifact: _docs/loops/loop82/plan82.md
tasks_shipped: [AZ-3381_ci_yaml_reader_and_pin, AZ-3382_publish_precheck_python, AZ-3383_publish_workflow_python, AZ-3384_ring_wiring_python, AZ-3385_publish_jobs_python, AZ-3386_publish_pins_guard_and_docs]
decisions:
  - owner (handoff82, confirmed at intake 2026-10-29): replace Ruby with Python in the CI scripts; the owner confirmed the Phase 1 summary (10 scripts, one shared reader, PyYAML pinned, the release-path precheck on the standard library, every check kept)
  - agent: this host has no `ruby`, so the port is proven without the Ruby original running: a label inventory per script (nothing dropped), deliberate mutations on copies, and the old messages kept byte for byte; CI's first run of the six scripts that never ran on the loop 81 host is the differential check
  - agent: `publish-jobs.test.sh` runs its mutation snippets with `exec` on repository-owned Python text (never workflow text); the `if:` evaluator is a tokenizer and a recursive-descent parser with no `eval`, `exec` or `compile` (a check keeps it so)
  - agent: the install step in `test.yml` is `actions/setup-python` (Python 3.14, the SHA of the ring job) plus `pip install --only-binary=:all: "pyyaml==$(tool-pin.sh pyyaml)"` in `scaffold` and `publish-gate-rest`; the Python version is a literal beside `RING_PYTHON`
  - agent: Jira AZ-3381 to AZ-3386 created by new-task/decompose (Task, Medium, 5, 3, 5, 5, 5, 5 points, no epic); In Progress, then In Testing after each batch commit (AZ-3386 after the push)
  - agent: no per-batch code review (owner preference since loop 70); the parent re-ran every worker's tests and read the precheck diff and the `if:` evaluator
  - agent: three workers ran in parallel in batch 2 (disjoint file lists, no commit, no tracker); the parent kept the commits, the tracker and the batch reports
measurements:
  - HEAD 5a78fb8: 10 scripts name `ruby`; after: `grep -rniE 'r[u]by'` over `.github`, `scripts` finds 0
  - mutants: `publish-jobs.test.sh` 110 `mutant` + 5 `gate_mutant` calls at HEAD (the specs said 111: the grep counted the function definition), 115 rejects after; `publish-precheck.test.sh` 11 of 11; `publish-workflow.test.sh` 31 old + 12 new = 43 rejects; `ring-wiring.test.sh` 1 accepts + 38 rejects; `ring-wiring-swift.test.sh` 1 accepts + 53 rejects; `ring-wiring-rows.test.sh` 19 rejects (unchanged)
  - file sizes: `publish-jobs.test.sh` 384 to 75 lines (+ `publish-jobs-layout.py` 406, `publish-jobs-mutate.py` 67, `publish-jobs-mutants.test.sh` 126); `publish-workflow.test.sh` 241 to 150 (+ `publish-workflow-structure.py` 361); `ring-wiring.test.sh` 278 to 161, `ring-wiring-swift.test.sh` 425 to 358 (+ two checkers of 249 and 200); all at or under 500
  - this host (Linux, python 3.14.4, PyYAML 6.0.3, no ruby, no java on PATH): `loop-tests.sh --only scaffold,ring,publish-gate --all`: scaffold 157 to 163 s, ring 41 s, publish-gate 144 to 145 s (share 7 130 s, swift 73 s); `smoke82.sh` 411 s, 8 of 8
  - the first `--only ring` without a JDK on PATH failed in 5 s on `java: command not found`; with the user-directory JDK on PATH and `RING_GCC=16`, `CXX=ring-cxx.sh` it passed
  - the reader found a YAML error in the first draft of the new `test.yml` step: an unquoted `--only-binary=:all: ` in a plain scalar (a `: ` starts a mapping); quoted
  - CI of the loop 82 push (dbf9a57, read 2026-10-29): `dev` run 40904985660 and `main` run 40904988952 both success, 309 s wall (loop 81: `dev` 298 s, `main` 465 s as separate runs); every job success; in the `dev` log: `report row tests passed`, `run-suite.test.sh: all checks passed`, `ring wiring checks passed` (x2: ring and swift), `ring row wiring checks passed`, `yaml_get.test.sh: all checks passed`, `job layout checks passed`, `publish-precheck checks passed`, `publish gate tests passed` x8 (publish-gate-rest: workflow 35 s, pins 24 s); 0 FAIL lines, 0 NOT RUN lines, 0 mentions of ruby; scaffold 182 s, publish-gate-rest 169 s, ring 151 s (first run on the pinned Node 24, GCC 16, Rust 1.98: success)
  - CI of the loop 81 push (read at the start of this loop): `dev` success in 4 m 58 s, `main` success in 7 m 45 s
review: "no per-batch code review (owner preference); feature assessment by the parent: round 1 COMPLETE, 17 covered / 3 out-of-scope (assessment82.md); security lite diff-scoped, 0 findings (_docs/05_security/lite_loop82.md)"
retro: not due (loops 75 to 79 done in loop 79; next after loop 84)
leftovers:
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port should drop `supports: linux | osx`; a public-key pairing step
  - ring, open: multi-part MAC messages (G8m of loop 77, owner-declined then; needs an owner opt-in like U1); which error comes first for a row that combines a wrong-length key or id with a second refusal (not walked, no such row)
  - Mac: the stage stamps of `scripts/loop-tests.sh` are stale (b7b8140); one clean run on the Mac refreshes them (this Linux clone has none)
  - this host: a JDK 26 must be on PATH for the ring stage (`~/.local/share/packbin-jdk26/bin`, a tarball) and `ruby` is no longer needed; the documented `apt install openjdk-26-jdk-headless` is still open
  - the two ring-wiring checkers duplicate about 50 lines of small helpers (`to_s`, `inspect`, `dig`, `steps_of`, `code_lines`); a shared module next to `scripts/ci/yaml_get.py` would remove them (a refactor, not a defect)
  - the Python version `3.14` is written in the two new `setup-python` steps beside `RING_PYTHON`; folding it into one place needs `ring-wiring-check.py` to know the second job
  - `handoff.cpp` is 639 lines, over the 500-line cap; splitting it was never part of a loop
  - open: L76-1 (timing-selftest flake cause unproven); Go intermittent failure L74-3
  - Jira: AZ-3381 to AZ-3385 In Testing, AZ-3386 In Testing after the push; the description of AZ-3385 says 111 mutants (HEAD has 110 + 5 gate mutants); AZ-3378 and earlier In Testing
lessons:
  - A guard that scans the tree for a word must not contain the word: the first name of the new scan function matched its own scan; spell the pattern with a bracket (`r[u]by`) and name the function by its role.
  - A count taken with `grep -c '^mutant'` includes the function definition `mutant()`: the specs said 111, HEAD has 110 calls. Count call lines with their argument shape (`^mutant "`) before a number goes into an acceptance criterion.
  - When the original's runtime is absent from the host (no Ruby), a port cannot be compared by running both; the proof is a label inventory per script, deliberate mutations on copies, messages kept byte for byte, and a read of the original, with CI as the first differential run. Say so in the spec instead of promising a differential test.
smoke: PASS (agent run, owner rule 2026-10-12: 8 of 8 steps)
ci: PASS (dev and main success, the six scripts PASS in the log; AZ-3386 AC-6 / AC-C1 met)
smoke_artifact: _docs/loops/loop82/smoke82.md
assessment_artifact: _docs/loops/loop82/assessment82.md
loop_end_merge: main

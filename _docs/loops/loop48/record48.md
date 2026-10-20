# Autodev loop record — loop 48

loop: 48
branch: dev
plan_artifact: _docs/loops/loop48/plan48.md
tasks_shipped: [AZ-2742, AZ-2747]
decisions:
  - hopper hit (loop 47 record leftovers and `handoff48.md`); owner 2026-10-20 asked once and chose "accept all recommended": AZ-2742 (C++ repeated-text shortcut, 3 points), the ring cleanup (AZ-2747, 1 point, new Jira task under epic AZ-2645) and the push of `dev` with the loop close
  - agent: where the previous bytes live was decided with measured figures: the caller's `Scratch` words 0 and 1 hold the payload offset and length of the last raw field of the same `pack`; `pack_table` clears word 0 at the start and every parse clears it unless it ends raw. No pack-frame state, so the stack stays 504 B and the `PACKBIN_NO_TEXT` budget image stays 7,920 B; the all-kinds image grew 64 B (19,120 B)
  - agent: compact fields have no memo (comparing a compact field needs the previous text, which the core does not keep): a repeated text that compacts still parses each round; the 1 s bound holds for the test text, which is raw
  - agent: AZ-2747 by one worker (comments, `ring-wiring.test.sh` into `ring-wiring.test.sh` 270 + `ring-wiring-rows.test.sh` 244 + `ring-wiring-lib.sh` 11); the parent added `ring-wiring-rows.test.sh` to the `static` list of `publish-jobs.test.sh`, fixed three stale comments and added the mutant for the new scaffold step
  - agent: one total review (read-only agent): no Critical or High; Lows applied (raw check on the q text, the stale-memo test, the rows-step mutant, swift comment); the `at` guard comment and file modes 755 left as they are
leftovers:
  - compact repeated text still parses every round in C++ (no memo for compact fields); only worth a task if an owner message set shows long repeated texts
  - the forget after a compact result in `encode_field` is not pinned by a test (the review's finding 1 covers the `pack_table` reset only; the mutant needs a parse that leaves matching words)
  - CS-D5 (retrain the tables on the owner's 100 to 200 real messages) waits for the owner; the first `v*` and `go/v*` tags and F44 are owner-run
  - not run here: the vcpkg supports and consumer checks (no vcpkg on this Mac), the ESP stage (CI only); the CI time of `test.yml` is read after the push
  - Jira: epic AZ-2645 stays open
smoke: PASS (agent run 8/8 at b95a0d0, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop48/smoke48.md
step11: RESULT 5 passed, 8 skipped as unchanged, 0 failed, 640 s at b95a0d0
loop_end_merge: main

# Autodev loop record - loop 107

loop: 107
branch: dev
plan_artifact: none (short loop on the launcher, no plan file)
tasks_shipped: [AZ-4196]
decisions:
  - owner (2026-11-11): chose "Automate key upload" from three options for the empty hopper (the other two were the runner DNS cause and a retro of loops 105-106)
  - agent: the build phase writes the public key and fingerprint (publish-sign.sh); the upload phase sends it with curl (publish-upload.sh), because the build phase writes to no registry and publish-upload.sh may not call gpg (static check AZ-2096 AC-5); an unconfirmed key is a warning and the run goes on to Central, which stays the authority
measurements:
  - AZ-4196 was created in Jira first; the intake commit had cited an id that did not exist and was amended before any push
  - local runs on this Mac need Python 3.13 first on PATH (the default 3.9 fails the pip pin of idf-component-manager in `ph_setup`): groups `phases` 137 s and `phases-rerun` 141 s pass; `static`, `workflow`, `pins`, `registry` pass
  - `publish-timing.selftest.sh` failed once: the new helper `ph_key_upload` was counted as a phase check; added to its `ph_harness` list, then green
  - mutation check: the stub matches `upload*` by prefix, so a first mutant (`/uploadX`) passed unnoticed; a mutant that the stub rejects (`/up`) failed 5 assertions, so the scenarios do run
  - smoke: 7/7 (`smoke107.sh`, `smoke107.md`), including a live GET of the production key on keys.openpgp.org (HTTP 200)
review: "none (CI files only: two publish scripts, their test and a test harness list)"
retro: none (next due by loop 109)
leftovers:
  - the real keyserver upload path (key missing on keys.openpgp.org) is tested only against the stub: it runs for real at the first tag run after the key drops; the `publish-key` workflow stays as the manual fallback
  - from loop 106 (unchanged): the embedded-arm host-network build goes around the runner's bridge DNS without finding the cause
  - from loops 105-106 (unchanged): owner's first `dart pub publish`; the autodev rule file `worktree-isolation.md` is outside this repository; keyserver.ubuntu.com did not answer in loop 105
  - Jira: AZ-4196 To Do until CI is read (then In Testing); AZ-4191, AZ-4153, AZ-4168, AZ-4169 In Testing
smoke: PASS (agent run, owner rule 2026-10-12: 7/7 steps passed at cc9b439; checks in smoke107.md)
smoke_artifact: _docs/loops/loop107/smoke107.md
loop_end_merge: main

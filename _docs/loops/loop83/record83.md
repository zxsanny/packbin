# Autodev loop record - loop 83

loop: 83
branch: dev
plan_artifact: _docs/loops/loop83/plan83.md
tasks_shipped: [AZ-3387_split_handoff_cpp, AZ-3388_ring_wiring_shared_module, AZ-3389_ring_key_id_second_refusal_rows]
decisions:
  - owner (2026-10-29, hopper empty): took three candidates of handoff83 and asked for parallel work: split handoff.cpp, one shared module for the ring-wiring checkers, ring rows that put a wrong-length key or id before a second refusal
  - agent: three workers in parallel, each in its own copy of the tree (the C++ build edit of AZ-3387 and the ring runs of AZ-3389 would have raced in one tree); the parent diffed each copy against HEAD for the owned paths before copying them back
  - agent: Jira AZ-3387 to AZ-3389 created at new-task (Task, Medium, 3 points each, no epic); In Progress, then In Testing after the batch commit
  - agent: `ring-frame.test.sh` line 184 (needle of `id-padded`) and `test.yml` (a step for the new helper test) were edited by the parent: forced by the new rows and by AC-5 of AZ-3388
  - agent: code review of the batch PASS_WITH_WARNINGS (5 low cleanups, 0 bugs), feature assessment round 1 COMPLETE (11 covered)
  - agent: `_docs/_autodev_state.md` untracked and added to `.gitignore` at intake (the protocol says it is runtime state)
measurements:
  - HEAD dbf9a57 baseline on this host: `ring-frame.sh` 64 pairs, 45 rows per pair, 58 refusal rows per language, 0 mismatched; wiring tests 49 / 25 / 67 lines with 38 / 19 / 53 `rejects:`; `ring-frame.sh` takes about 4 s with the drivers built (the spec said 30 s)
  - after: refuse rows 42 -> 56 (27 seal, 20 open, 9 mac); refusal rows per language 58 -> 72; the three wiring logs identical to HEAD
  - sizes: `handoff.cpp` 639 -> 320 (+133 +198 +23); `ring-wiring-check.py` 249 -> 185, `ring-wiring-swift-check.py` 200 -> 136, `workflow_yaml.py` 73, `workflow_yaml.test.sh` 41 (16 checks); identical lines between the checkers 52 -> 0
  - AZ-3387: the HEAD binary and the new binary give the same stdout, stderr and exit code over 108 invocations; gcc:16 `-Werror` clean
  - AZ-3388: 52 compared cases (real file, 20 mutants, bad inputs) byte-identical; the three wiring tests did not catch a broken `inspect` quote escape, `workflow_yaml.test.sh` does (5 mutations)
  - AZ-3389: no package answers another error first; the Python key check moved after the size checks gives 7 mismatches, ring exit 1
  - `loop-tests.sh --only scaffold,ring,publish-gate --all`: scaffold 159 s, ring 40 s, publish-gate 151 s (after the quota fix); `smoke83.sh` 8 of 8
review: "batch review PASS_WITH_WARNINGS (5 cleanups, 0 bugs); feature assessment round 1 COMPLETE (assessment83.md); no security audit in plan (no auth, secret or untrusted input)"
retro: not due (last loop 79; next after loop 84)
leftovers:
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx`; a public-key pairing step
  - ring, open: multi-part MAC rows (G8m of loop 77, owner-declined then; need an owner opt-in like U1)
  - CI wiring: `SCAFFOLD_SCRIPTS` of `ring-wiring-check.py` does not require the scaffold steps of `yaml_get.test.sh` and `workflow_yaml.test.sh`; deleting a step leaves every wiring test green (needs a mutant per step)
  - cleanups from the review, not applied: `frame_hex` wraps `hex_of` (one differs by `-` for empty); the include lists of the two new `.cpp` files were copied from the original; `kMax` in `handoff_common.hpp` is read by one part only; the `id-padded` needle of `ring-frame.test.sh` depends on the 5-line cap of mismatch lines
  - `cpp/embedded/common/all_kinds.cpp` is 560 lines (over the 500 cap), not picked by the owner
  - candidates unchanged from handoff83: fold the two `setup-python` steps and `RING_PYTHON`; the AVR check of `chacha20_xor` on a 16-bit `size_t`; refresh the stage stamps on the Mac; a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part
  - open: L76-1, L74-3 (see handoff82)
  - Jira: AZ-3387 to AZ-3389 In Testing; AZ-3381 to AZ-3386 and earlier In Testing
lessons:
  - Tree copies for parallel workers cost disk: three 300 MB copies plus the first workers' build output filled the /tmp tmpfs quota and the publish gate aborted in 7 s with `Disk quota exceeded` (no test failed). Delete worker copies before any `loop-tests.sh` run and check `df -h /tmp`.
  - A test that greps a capped list of output lines (`ring-frame.sh` prints 5 mismatch lines per reader) breaks when new rows sort ahead of its needle; pick a needle from the sorted head of the list or lift the cap in the test.
  - A refactor of a checker is proven by its own mutation tests only if they cover the moved code: the three wiring tests passed with a broken `inspect`; move a helper together with a test that fails when the helper breaks.
  - A smoke step that copies part of the tree must copy what the script imports (`framefmt.py` imports `scripts/crypto`): the trial run found it, as trial runs are for.
smoke: PASS (agent run, owner rule 2026-10-12: 8 of 8 steps)
ci: pending (read after the push, `ci_cd_pipeline.md` polling: `dev` and `main`)
smoke_artifact: _docs/loops/loop83/smoke83.md
assessment_artifact: _docs/loops/loop83/assessment83.md
loop_end_merge: main

# Autodev loop record - loop 96

loop: 96
branch: dev
plan_artifact: _docs/loops/loop96/plan96.md
tasks_shipped: [AZ-3495_ring_multipart_mac_rows]
decisions:
  - owner (2026-10-31, hopper empty): chose "multi-part MAC rows in the ring" from the loop 95 leftovers; it is the opt-in G8m of loop 77 waited for
  - agent: the message field of a mac, verify and refuse-mac row and driver line is its pieces joined by `|`, each hex or `-`, as `parts` in `vectors.txt`; one piece is unchanged; an empty piece written as nothing is a malformed line in all 8 drivers
  - agent: AC-5 was corrected during implementation: a driver that joins pieces or drops an empty one gives the same HMAC and no row can tell it; the stand-ins are "first piece only" and "stops at an empty piece"
  - owner (2026-10-31): "replace the folders" for the root-owned build output, then ran `sudo chown -R zxsanny` on csharp, cpp/build, rust/target, python, test-results (0 root-owned paths after)
  - agent: Jira AZ-3495 created at intake (Task, Medium, no story points, no epic); In Progress, then In Testing after the batch commit (read back from the transition results)
measurements:
  - ring on HEAD 98d2202 before the edit: 64 pairs x 45 rows, 72 refusal rows per language, mismatched 0, 30 s; after: 64 pairs x 56 rows, 76 refusal rows per language, mismatched 0, 30 s
  - `ring-frame.test.sh` 45 checks passed; `ring-frame-drivers.test.sh` 8 languages, 340 checks, 0 failed
  - `scripts/loop-tests.sh --all --only scaffold,ring`: scaffold PASS 182 s, ring PASS 46 s
  - AC-5 mutation: the Go driver passing only `parts[0]` gave 18 mismatches per pair naming `P.two`, `P.first0`, `P.mid0`, `P.split56`, `P.split64`; restored
review: "code-review (low): 0 findings; feature assessment COMPLETE (assessment96.md); security lite: 0 findings (_docs/05_security/lite_loop96.md)"
retro: none (5 points, no incident; next retro due after loop 97)
leftovers:
  - not run locally this loop: the language suites, cpp-embedded-arm, rust-embedded, ac10 and the publish gate (no package source changed); CI runs them on the close push
  - `shellcheck` is not installed on this host (`bash -n` only)
  - the reduced no-text, no-ECC ARM image's flash and stack are not pinned (accepted-risk, Low, from loop 95)
  - `_docs/04_deploy/release_notes_0.4.0.md` has uncommitted edits that are not from this loop
  - owner: close the epic AZ-2750; U24; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step
  - Jira: AZ-3495 In Testing
smoke: PASS (owner, 2026-10-31: answered PASS to the smoke gate; no UI, no local deploy; checks in smoke96.md)
smoke_artifact: _docs/loops/loop96/smoke96.md
assessment_artifact: _docs/loops/loop96/assessment96.md
loop_end_merge: main

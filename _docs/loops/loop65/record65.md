# Autodev loop record — loop 65

loop: 65
branch: dev
plan_artifact: _docs/loops/loop65/plan65.md
tasks_shipped: [AZ-PENDING_ci_paths_ignore_rust_limits_flag_round_chain]
decisions:
  - owner (2026-10-23, AskUserQuestion): loop 65 = CI paths-ignore + stack margin + owner-input items; scope answers: stack "measure it, gate at 512 B" (over: report and stop), Rust limits "pin at today + 5%", CS-D5 "keep deferred", CI "test.yml push only"
  - agent: my option text called the flag-byte chain in a `times` round a stack saving; it is an unbuilt, unmeasured case. Corrected with the owner before the claim (lesson in LESSONS.md)
  - measured on HEAD d67c654: Rust embedded base 14,700 B / 456 B, text 26,632 / 2,760, ecc 17,980 / 760, session 18,404 / 1,832; limits set at the figure +5% rounded up
  - measured with scheme 0x5e: unpack 612 B net (676 raw less 64), pack 464 B; budget 512 B was exceeded. Owner (2026-10-23, in chat, after asking what the budget means and what RAM a Cortex-M4F has): stack budget 2,048 B and a pin at 612 B, "ok" for parts with 8 KB of RAM or more
  - agent: `ring-wiring.test.sh` forbade any push filter (AZ-2193); it now requires exactly `paths-ignore: ["_docs/**"]` and rejects a broader one
  - agent: no change to `cpp/src/core` or `cpp/include`: flash stays at the pin of 7,724 B
leftovers:
  - owner: size limits are now set (text, ecc, session); CS-D5 stays deferred; first `v*` / `go/v*` tags; F44; close the epic AZ-2750; U24 in the C++ package
  - candidate: stack-reduction of the unpack walk for a flag scope inside a `times` round (612 B today; a part with 4 KB of RAM or less cannot use that scheme shape); other candidates unchanged (`item` pointer removal, out-of-line error helpers in `unpack.cpp` / `values.cpp`, session stack, `session_core` clippy, ring driver for `nostd`)
  - publish gate: two timing-bound checks fail when the 8 shares run together under load (`publish-go.test.sh` AC-3 with a 3 s proxy window; `publish-phases-failures.test.sh` AZ-2096 AC-4, a container `pip install`); each passes alone. A load-aware window (AGENT_GOTCHAS timing rule) is a candidate; the container pip error is not kept in the log
  - Jira: connector absent; AZ-3163 and AZ-3164 To Do; six tasks have no key yet (`2026-10-22_loop60_jira_create_tasks.md`); epic AZ-2645 open
  - CI: loop 64 push read at loop 65 start, green on `dev` (run 39971129190) and `main` (39971134308) for `28c0f21`; the CI of this loop's push is read at the next loop start
smoke: PASS (agent run 6/6, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop65/smoke65.md
assessment_artifact: _docs/loops/loop65/assessment65.md
step11: RESULT 6 passed, 7 skipped as unchanged, 1 failed (publish-gate, see leftovers), 965 s at f3738da; publish-gate rerun alone 0 passed 1 failed (the same go check), go alone 28 s PASS, phases alone 325 s PASS, share 7 alone 1,057 s PASS
review: feature-assess COMPLETE (11 of 11 ACs covered); no per-batch code review (owner preference)
security: not in plan
retro: not in plan (last retro loops 61 to 63; next after loop 68)
loop_end_merge: main

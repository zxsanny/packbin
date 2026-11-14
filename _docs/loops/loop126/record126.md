# Autodev loop record - loop 126

loop: 126
branch: dev
plan_artifact: _docs/loops/loop126/plan126.md
tasks_shipped: [AZ-4294, AZ-4295, AZ-4296, AZ-4297, AZ-4298, AZ-4299, AZ-4300, AZ-4301, AZ-4302, AZ-4303]
origin: operator
decisions:
  - operator: D18 "Shared limit (256)" (2026-11-14), the answer to the loop 125 findings
  - agent: contract counting rule 1.0.1 (a list or dict counts one level plus its element's own kind; a flag bit and a u2 add none)
  - agent: D19 applied: keep 256 although 256 levels overflow a debug build on a small thread (Rust map API about 3 MiB, Swift 640 KiB, flags 1.5 MiB); `RUST_MIN_STACK=8388608` in the Rust suite; open to B or C
  - agent: Go, Java and C# walk-timing tests build 250 levels through the full build and keep the large chain on the walk alone
  - agent: Rust pins re-measured (+168 B flash all four, +16 B stack base and ecc); C++ merged `check_subtree` and `check_children` so 256 levels compile in constexpr
measurements:
  - probe over nine packages after the change: 60 lines, all `refused`, 64 s (before: raw stack errors, crashes, hangs)
  - step 11 `scripts/loop-tests.sh --jobs 3` at `1f2848a`: 15 passed (Java on its serial retry: AC-8 speed check at host load 45), 0 failed, 1,657 s; Dart re-run alone at `10ba849`: PASS
  - smoke `smoke126.sh` 6/6 PASS
review: "inline /code-review (high): 10 findings; fixed: Dart counted a flag bit; the rest are hygiene items 4 to 9 and one contract question (C# typed element row)"
security: "`_docs/05_security/lite_loop126.md` ESCALATE (T1, T3) answered in the same file: PASS, no finding above Low"
retro: none (next due by loop 128)
leftovers:
  - _docs/02_tasks/backlog/hygiene.md (9 entries, ready)
  - _docs/OPERATOR_TODO.md: D19 new (applied); N1, N2, N4, D5, D6, D11 unchanged
assessment_artifact: _docs/loops/loop126/assessment126.md
decisions_artifact: _docs/02_task_plans/scheme-depth-limit/queue_item.md
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop126/smoke126.md
loop_end_merge: main

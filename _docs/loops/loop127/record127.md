# Autodev loop record - loop 127

loop: 127
branch: dev
plan_artifact: _docs/loops/loop127/plan127.md
tasks_shipped: [AZ-4306, AZ-4307, AZ-4308]
origin: operator
decisions:
  - operator: "Run hygiene loop" (2026-11-14), the hygiene queue item of loop 126
  - agent: entries 1 (debug frames) and 5 (typed element row, decision D20) split out of the loop; D20 asked, default A
  - agent: D21 applied: keep the quadratic heap-free Rust depth check (both linear variants break a device pin)
  - agent: the walks before the id check (Dart `checkErrors` / `checkSlots`, Swift `checkNodes` / `checkSlots`, Go `checkNodes`) also memoise shared nodes: the diamond hung there too
  - agent: Python accessor block moved to `_accessors.py` and the TypeScript depth walk to `scheme-depth.ts` to keep files under 500 lines
measurements:
  - a 60-level diamond of shared fields: refused in about 0 ms in TypeScript, Python, Dart, Swift, C# and Go (before: 2^depth, TypeScript 876 ms at 25 levels, Swift 27 s at 25)
  - Rust `times` / `repeat` body of 50,000 levels: refused with the contract text (before: SIGABRT)
  - Rust nostd depth check on 32,768 entries: 1.09 s (kept, D21)
  - step 11 `scripts/loop-tests.sh --jobs 3` at `4f49270`: 12 passed, 3 skipped as unchanged, 0 failed, 1,060 s; TypeScript and ring re-run at `aad063b`: PASS
  - smoke `smoke127.sh` 6/6 PASS
review: "inline /code-review (high): 4 low findings; fixed: the TypeScript flags wrapper count; the rest are low and in hygiene or noted"
security: "`_docs/05_security/lite_loop127.md` ESCALATE (T3) answered in the same file: PASS, no finding above Low"
retro: none (next due by loop 128)
leftovers:
  - _docs/02_tasks/backlog/hygiene.md (4 entries: debug frames, typed element row, Go foreignNames cubic, nested-row diamond)
  - _docs/OPERATOR_TODO.md: D20 open (default A); D21, D19 applied; N1, N2, N4, D5, D6, D11 unchanged
assessment_artifact: _docs/loops/loop127/assessment127.md
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop127/smoke127.md
loop_end_merge: main

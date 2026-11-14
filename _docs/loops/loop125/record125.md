# Autodev loop record - loop 125

loop: 125
branch: dev
plan_artifact: _docs/loops/loop125/plan125.md
tasks_shipped: [AZ-4291]
origin: agent
decisions:
  - agent: D9 applied at option A (probe all nine first); the limit decision is the new row D18 (open)
  - agent: Rust and Swift probes build in release by default (a debug build overflows earlier; `PROBE_PROFILE=debug`)
  - agent: Java `group-5000` is the edge of the limit and flips between build and unpack; the smoke leaves it out of the repeat check
measurements:
  - full `scripts/probes/scheme-depth/run.sh`: 60 lines, 303 s, exit 0
  - nine packages, no depth limit: TypeScript, Python, Dart, Java raw stack error (Python between 400 and 500 levels); C#, C++, Rust map API, Swift process crash at 50,000; Go and Swift (nested groups) and Rust nostd (`when`) do not finish in 60 s at 5,000; Rust nostd refuses at 50,000 with its own MAX_FIELDS 32,768
  - step 11: only `scaffold` applied: PASS at `c76f445` (375 s); a first pass on the uncommitted tree failed once under host load in `ring-prepare.test.sh` and passed on the serial retry
  - smoke `smoke125.sh` 6/6 PASS at `c76f445`
review: "PASS (inline; probes and documents only, no package source; AC-5 checked by the smoke)"
security: "not_in_plan: trivial (probes and documents only, loops 112 and 116 precedent)"
retro: none (next due by loop 128)
leftovers:
  - _docs/02_tasks/backlog/scheme-depth-limit-all-nine.md (blocked on D18)
  - _docs/OPERATOR_TODO.md: D18 new; N1, N2, N4, D5, D6, D11 unchanged
assessment_artifact: _docs/loops/loop125/assessment125.md
smoke: PASS (agent-verified)
smoke_artifact: _docs/loops/loop125/smoke125.md
loop_end_merge: main

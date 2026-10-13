# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process
- [2026-10-11] [process] Check each AC of a cross-package spec against the reference rows it must keep before the specs are written: AZ-2331 AC-3 contradicted the loop 18 row `W-split-false-body-given`, six workers read it two ways, and it cost one owner question plus three follow-up workers. Put one cross-package table in front of the owner after the first wave
  Source: _docs/06_metrics/retro_2026-10-11_loop19.md
- [2026-10-11] [testing] Tell every reviewer to probe with a hostile value outside the type's range and with a row that packed before the change: the loop 19 review found Java `intValue()` ahead of the round cap, a C# count-0 regression and a C++ legitimate row now refused, all green in the package suites
  Source: _docs/06_metrics/retro_2026-10-11_loop19.md
- [2026-10-11] [architecture] A cap on one count does not bound the output: the audit measured 4.29 GB written for a 64 KB request through a lone `utf8` under one `times` (F28). Bound the bytes written per call, not only each count
  Source: _docs/06_metrics/retro_2026-10-11_loop19.md
- [2026-10-12] [testing] A construction check that mirrors a binding must be the binding's own predicate, tested as "builds if and only if it binds": the C# round collection rule was written from spec text and inverted (a buildable scheme refused, an unbindable one accepted); 23 member types times U8/U32 times Repeat/Times pinned it.
  Source: _docs/06_metrics/retro_2026-10-12_loop20.md
- [2026-10-12] [architecture] A byte and slot budget bounds the output, not the work: an empty round body charges 0 and a 1.1 MB request bought 93 s of CPU in TypeScript (F33); every unit of work, the empty one included, must charge at least one unit.
  Source: _docs/06_metrics/retro_2026-10-12_loop20.md
- [2026-10-12] [testing] A test that starts a child interpreter must give it the parent's import path: the AC-1 memory test passed with the worker's editable install and failed in the clean CI container with ModuleNotFoundError; and a timing bound that fails under load is settled by an idle A/B of the previous commit against HEAD in the same image (the budget cost 13 to 20 %).
  Source: _docs/06_metrics/retro_2026-10-12_loop20.md
- [2026-10-12] [tooling] On this Mac a subagent output file is a symlink (heartbeat must `stat -L`), `setsid` does not exist, monitor and `alarm` timers count wall time across sleep, and a network drop kills subagents and downloads: wait on one single-shot task that exits when the run is done, re-arm monitors, resume failed subagents by id.
  Source: _docs/06_metrics/retro_2026-10-12_loop20.md
- [2026-10-12] [architecture] A slot budget is a memory ceiling of maxSlots times the per-slot cost, and the cost differs by package (the same 4.3 MB packet: TypeScript 1 072 MB, Python 548 MB); removing Python's first-round surcharge raised its worst case from 90 MB to 548 MB. Change any charge only with a measured worst-case memory A/B in the same loop.
  Source: _docs/06_metrics/retro_2026-10-12_loop21.md
- [2026-10-12] [process] A parity decision must name the constructs it covers and both the with-value and no-value rows: U3 was built for repeat only and U7's no-value row (010000) stayed inconsistent with U6 until the reference worker flagged it.
  Source: _docs/06_metrics/retro_2026-10-12_loop21.md
- [2026-10-12] [testing] Fixtures first, then one loader worker per package: the loaders found two parity gaps (Rust late when in a bit body, C++ absent split body) that each package's own pins missed.
  Source: _docs/06_metrics/retro_2026-10-12_loop21.md
- [2026-10-12] [tooling] A stage timeout written as `perl alarm` counts wall time across laptop sleep and its alarm survives `exec` into `docker compose`, which ignores it: step 11 stage 1 died with rc 142 and the ESP stage ran hours over its limit; check `uptime` and `sysctl vm.swapusage` before a total run (a swapping host turned a 107 s ring into 11 296 s and flaked three timing tests).
  Source: _docs/06_metrics/retro_2026-10-12_loop22.md
- [2026-10-12] [architecture] A lowered limit lowers peak memory by less than its ratio: a quarter of the slots gave 29 to 33 % of the old peak because the runtime and the packet stay; state memory acceptance in absolute MB per package and give a test bound 50 % slack.
  Source: _docs/06_metrics/retro_2026-10-12_loop22.md
- [2026-10-12] [testing] A hostile construct case whose scheme another rule refuses first passes for the wrong reason: the empty-when cases were refused by the scope rule in five packages; check which rule fires per package when a case is added and pin it.
  Source: _docs/06_metrics/retro_2026-10-12_loop22.md
- [2026-10-12] [architecture] Validation state stored on a user's node leaks between schemes: Python kept `count_source` on the shared leaf and the last scheme won; copy the node at bind, as a `times` already was.
  Source: _docs/06_metrics/retro_2026-10-12_loop22.md
- [2026-10-12] [process] Probe the 'the other packages do X' premise of a parity spec before writing the AC: two of the loop 22 premises (U14, U15) were false or ambiguous and the reference probe section caught them.
  Source: _docs/06_metrics/retro_2026-10-12_loop22.md

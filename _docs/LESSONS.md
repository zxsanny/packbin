# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

- [2026-11-11] [testing] A builder that keys maps by node identity must be tested with one field object used in two places (a shared member list): 1,887 tests missed it and a random differential run against TypeScript found a High; give every new language one reviewer slice of random schemes against the reference (loop 99).
  Source: _docs/06_metrics/retro_2026-11-11_loop99.md
- [2026-11-11] [testing] Never assert elapsed time in a unit test that the loop runs under load (624 ms against 500 ms at host load 30): count the operation instead (keyed reads on the map), and keep time bounds for the compiled speed program (loop 99).
  Source: _docs/06_metrics/retro_2026-11-11_loop99.md
- [2026-11-11] [process] Mint a short-lived credential in the step that uses it and compare its lifetime with the run order (an OIDC token minted before a build and a Maven wait expires before the upload); a Docker `network is unreachable` is an environment fault: restart Docker Desktop (restart policy was no on all 18 containers: start them again) and rerun only the failed stages (loop 99).
  Source: _docs/06_metrics/retro_2026-11-11_loop99.md
- [2026-11-11] [testing] When a change turns a refused shape into a buildable one, probe every public door that reaches it (`bind`, typed rows, elements) and fuzz hostile bytes over each: a typed `bind` of an empty nested row threw a cast error out of unpack and only an assessment probe found it (loop 100).
  Source: _docs/06_metrics/retro_2026-11-11_loop100.md
- [2026-11-11] [process] Run both packages on the premises of a decision list before asking the owner, and print expected packets by running the reference: two premises of the Dart-vs-TypeScript list were wrong and the colliding-key packet exists only because TypeScript was run (loop 100).
  Source: _docs/06_metrics/retro_2026-11-11_loop100.md
- [2026-11-11] [tooling] A total `loop-tests.sh` run needs Python 3.13 (the only one with PyYAML), `RUSTUP_TOOLCHAIN=1.98` and `PACKBIN_CXX_SYSROOT` set before it starts; without them `scaffold`, the ring and the publish gate fail in seconds and the run must be stopped and redone for those stages (loop 100).
  Source: _docs/06_metrics/retro_2026-11-11_loop100.md
- [2026-11-11] [process] When one package writes something its own reader refuses, probe every sibling in the same loop with committed probes and give the owner one decision for the class: Dart, then TypeScript, then 2 of 6 others (C# and Java) had the same unreadable dictionary packet (loops 100 to 103).
  Source: _docs/06_metrics/retro_2026-11-11_loop104.md
- [2026-11-11] [testing] A test input the framework cannot carry (a lone surrogate in xUnit `[InlineData]` comes back as U+FFFD) is built in the test body or written as code-unit hex, and each new test is run once against the old source: the first C# tests passed for the wrong reason (loop 103).
  Source: _docs/06_metrics/retro_2026-11-11_loop104.md
- [2026-11-11] [tooling] A push that changes only `_docs/**` starts no CI run (`test.yml` has `paths-ignore`): check `git diff --name-only` before arming a CI watcher, and look a run up by commit with `gh run list --commit` (loop 102).
  Source: _docs/06_metrics/retro_2026-11-11_loop104.md
- [2026-11-11] [tooling] A CI-only failure that the local tool cannot reproduce (Compose 2.24 has no Bake, and CI refused `network: host` twice) is fixed by calling the version-independent command directly (`docker buildx build --allow network.host`), not by a third compose variant (loop 106).
  Source: _docs/06_metrics/retro_2026-11-11_loop108.md
- [2026-11-11] [process] Check what a release needs outside the repository before the tag, not at the step that uses it: the first v0.5.0 run published five registries and then failed all four Maven signatures because the public key was on no keyserver; every publish run now uploads it (loops 105 and 107).
  Source: _docs/06_metrics/retro_2026-11-11_loop108.md
- [2026-11-11] [testing] A stub that matches a request by prefix lets a mutant pass (`/uploadX` was accepted): mutate to a request the stub rejects (`/up`) and count the failed assertions before trusting the scenarios (loop 107).
  Source: _docs/06_metrics/retro_2026-11-11_loop108.md
- [2026-11-12] [process] A probe that decides a class of defects must also run the next-deeper container of each shape the rule will name: loop 112 probed a repeat in a round and not in a group of a round, and two of nine packages (Dart, C++) had the second (loop 113).
  Source: _docs/06_metrics/retro_2026-11-12_loop113.md
- [2026-11-12] [testing] A wall-clock test in a new worker task uses the package's load helper from the first run, and the worker prompt says so; a package without one writes it first (Dart did, mid-loop, after a fixed bound failed under host load 50).
  Source: _docs/06_metrics/retro_2026-11-12_loop113.md
- [2026-11-12] [process] Read each worker report against the contract the day it arrives: the contract's Java text for "a repeat in a round" was false for Java and went from 1.0.0 to 1.0.2 in one loop; an error text is true or it is not written.
  Source: _docs/06_metrics/retro_2026-11-12_loop113.md

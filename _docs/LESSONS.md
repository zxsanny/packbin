# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

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
- [2026-11-12] [tooling] A CI job that is red on a push which changed no workflow starts with the runner image `Version:` line of its log against the last green run's: `ubuntu-latest` (now ubuntu-26.04) changed image between two pushes the same day and `dotnet --version` returned an 11.0.100 SDK; pin the SDK in the repository (`global.json`) and the version check stays honest (loop 113).
  Source: _docs/06_metrics/retro_2026-11-12_loop113.md
- [2026-11-13] [testing] When one switch over field kinds lacks a kind its sibling switches in the same file have (C# `BitOn` had no `Flags` arm, `ChildPresent` had one), the missing arm is the defect and every form that calls it is a victim: here also the split flag byte; review lists the arms of the sibling switches side by side (loop 118).
  Source: _docs/06_metrics/retro_2026-11-13_loop118.md
- [2026-11-13] [testing] Run a new probe and every new proving test once against the old code before the commit: loop 118's tests failed 5 of 13 and 2 of 6 there and the probe printed `0102 differs`; a probe that never saw the defect proves only the fix.
  Source: _docs/06_metrics/retro_2026-11-13_loop118.md
- [2026-11-13] [process] A documentation move that rewrites comment lines in CI scripts or pinned files goes in its own commit or is counted in the loop plan: in loop 118 such lines added seven step 11 stages and turned the lite security check into a full audit (T1).
  Source: _docs/06_metrics/retro_2026-11-13_loop118.md

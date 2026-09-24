# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

- [2026-09-23] [process] Publish packbin by pushing a `v*` tag; do not add `scripts/deploy.sh` beside `.github/workflows/publish.yml`.
  Source: _docs/06_metrics/retro_2026-09-23_loop1.md
- [2026-09-23] [testing] Measure the one-second bound with the 100000-iteration loop inside each language suite.
  Source: _docs/06_metrics/retro_2026-09-23_loop1.md
- [2026-09-23] [architecture] Keep the six packages as peers with zero imports; a shared walker would contradict ADR-001.
  Source: _docs/06_metrics/retro_2026-09-23_loop1.md
- [2026-09-23] [tooling] Two C# executables in one directory need separate output paths, or `dotnet run` builds the other `Main`.
  Source: _docs/06_metrics/retro_2026-09-23_loop2.md
- [2026-09-23] [testing] A language handoff must unpack the bytes the producer just wrote.
  Source: _docs/06_metrics/retro_2026-09-23_loop2.md
- [2026-09-23] [tooling] On this Mac, pass `PACKBIN_CXX_SYSROOT` so clang finds the SDK C++ headers.
  Source: _docs/06_metrics/retro_2026-09-23_loop2.md
- [2026-09-24] [testing] Compare a shared marker as the full hex in every language. A prefix match hides a different tail.
  Source: _docs/06_metrics/retro_2026-09-24_loop4.md
- [2026-09-24] [tooling] When a C++ file is split, add the new files to every driver compile line, including the publish gate.
  Source: _docs/06_metrics/retro_2026-09-24_loop4.md
- [2026-09-24] [architecture] A typed Rust scheme needs the same value kinds as the map scheme, including u2 and dict, or the spec must exclude them.
  Source: _docs/06_metrics/retro_2026-09-24_loop4.md

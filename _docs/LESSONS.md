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

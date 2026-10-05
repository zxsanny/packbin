# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process

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
- [2026-09-29] [testing] Delete `cpp/build` before the container C++ suite, or the container runs the host binary.
  Source: _docs/06_metrics/retro_2026-09-29_loop9.md
- [2026-09-29] [process] Implement a product loop in its worktree. Loop 9's commits landed on launcher `dev` while `loop/9-pack-session` stayed at the start commit.
  Source: _docs/06_metrics/retro_2026-09-29_loop9.md
- [2026-09-29] [tooling] When `cargo audit` rejects a CVSS 4.0 advisory file, record the empty dependency list. That failure is not a CVE in this crate.
  Source: _docs/06_metrics/retro_2026-09-29_loop9.md
- [2026-10-05] [testing] A 64-bit host fuzz cannot show 32-bit narrowing faults. Put a vector for every packet-count path in a `VECTOR_TESTS` file so the Cortex-M3 QEMU run executes it; that run caught the `size_t` wrap that 20 M sanitizer-checked packets missed.
  Source: _docs/06_metrics/retro_2026-10-05_loop10.md
- [2026-10-05] [architecture] Clamp every count read from a packet just under `SIZE_MAX` before narrowing it, so the short-packet and capacity checks fail it instead of a wrapped small number passing.
  Source: _docs/06_metrics/retro_2026-10-05_loop10.md
- [2026-10-05] [process] Ask a fresh reviewer to read the batch diff before the commit. In loop 10 it found a zero-width `times` that spun for seconds and a stack budget used to the byte.
  Source: _docs/06_metrics/retro_2026-10-05_loop10.md
- [2026-10-05] [testing] Run a hostile-input fix's new test against the pre-fix tree and require it to fail; the spec's literal packets (`01ffffffff`) passed on the old code in several packages, and only a longer amplifier packet or an exact-shape assert (`needed`, `left`, kind) discriminated.
  Source: _docs/06_metrics/retro_2026-10-05_loop11.md
- [2026-10-05] [tooling] CI has no typecheck job, so tests and Docker CI pass a TypeScript type error; run `tsc --noEmit --strict` over `typescript/src` before each TypeScript commit until a CI job exists (a reviewer FAIL caught four TS2345 call sites in loop 11).
  Source: _docs/06_metrics/retro_2026-10-05_loop11.md
- [2026-10-05] [testing] Keep the auditor's cross-package fuzz generators and drivers in the repo and run them whenever unpack changes; the scratch differential over 276 855 packets per package found three Medium defects (u64 top-range exception, `__proto__` dict key, `when` in `repeat`) that eight reviewer reports missed.
  Source: _docs/06_metrics/retro_2026-10-05_loop11.md

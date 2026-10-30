# Lessons Log

A ring buffer of the last 15 actionable lessons extracted from retrospectives and incidents.
Downstream skills consume this file:
- `.cursor/skills/new-task/SKILL.md` (Step 2 Complexity Assessment)
- `.cursor/skills/plan/steps/06_work-item-epics.md` (epic sizing)
- `.cursor/skills/decompose/SKILL.md` (Step 2 task complexity)
- `.cursor/skills/autodev/protocols/bootstrap-lessons.md` (Bootstrap B2 — Surface Recent Lessons)

Categories: estimation · architecture · testing · dependencies · tooling · process
- [2026-10-27] [estimation] Before a spec refuses a case in one package of a shared API, read how the sibling packages treat it (the Java spec refused an empty direction set that Rust, C# and Swift accept), and diff the public API of all packages when a rename must match everywhere (Swift `Freshness`) (loop 74).
  Source: _docs/06_metrics/retro_2026-10-27_loop74.md
- [2026-10-27] [architecture] A declaration a package emits is part of what a consumer compiles: `declare [Symbol.dispose]` in the TypeScript classes put `Symbol.dispose` into the published `.d.ts`, which a consumer on lib ES2022 cannot type-check; only the publish gate's consumer check (AZ-2103 AC-2) found it, not the package's own tests (loop 75).
  Source: _docs/loops/loop75/record75.md
- [2026-10-27] [estimation] Put the 500-line cap and the "no new `lib` requirement for consumers" rule in every worker prompt: a worker test file reached 544 lines and one declaration needed a newer lib, both found after the fact (loop 75).
  Source: _docs/loops/loop75/record75.md
- [2026-10-27] [estimation] Probe each handoff candidate on HEAD before writing its spec: in loop 76 three of seven descriptions were wrong or incomplete (a probe that crashed instead of doing an extra compile; a Rust failure in 22 test files and not only the frame set; a probe FAIL that was a key-order error in the probe) and the wrong key order also sat in two more probes the handoff did not list (loop 76).
  Source: _docs/loops/loop76/record76.md
- [2026-10-27] [tooling] A CI suite that names its test targets one by one (`--test <name>`) hides a missing feature gate in every other test file; build every feature set with `--no-run` after adding a test file (loop 76).
  Source: _docs/loops/loop76/record76.md
- [2026-10-27] [process] A self-test that replaces the drivers with a stand-in proves the script and the checker and nothing else: the frame ring was pushed with only that run, CI went red on `dev` and `main` with six defects (Swift 6 on Linux refused `stderr`; a test script still counted 13 cargo runs; the C++ driver did not link `frame.cpp`; the TypeScript and Java drivers called `FrameDirections` wrongly; the self-test ran in no CI job), and the first real run found two of them in 21 s. Run the real ring and every CI step in `test.yml` order before the first push, and read CI on `dev` before `main` (loop 77).
  Source: _docs/loops/loop77/record77.md
- [2026-10-27] [process] A comparison harness with only good rows passes a package that accepts forgeries: add rows that must be refused and a stand-in reader that accepts them, and show once that a real defective driver turns the harness red (the TypeScript short-packet name did, loop 77); `vectors.txt` already held the refusals per package, which is why the ring keeps only tamper rows and leaves the refusal-by-name rows to a later loop.
  Source: _docs/loops/loop77/record77.md
- [2026-10-28] [process] A CI step added to `test.yml` also goes into `scripts/loop-tests.sh` in the same commit: step 11 of loop 77 passed 14 stages without running the frame ring or its self-test, because the `ring` and `scaffold` stages list their scripts by hand (found in loop 78 by comparing the two).
  Source: _docs/loops/loop78/record78.md
- [2026-10-28] [testing] A new check over real drivers is proven by putting an old defective driver back (`git show <commit>:<file>` in a scratch copy) and seeing it fail: the lenient TypeScript and Swift drivers gave 8 FAIL; 44 of 44 green on the first run proves nothing alone (loop 78).
  Source: _docs/loops/loop78/record78.md
- [2026-10-28] [process] Measure a new CI step cold with the runner's CPU count (`docker run --cpus 4`) and name the job it lands on before agreeing the command with the owner: `cargo test --no-run` for 7 Rust feature sets added 64 s to `suites (csharp rust)`, the job that sets the CI wall, and `cargo check --tests` 8 s (loop 79).
  Source: _docs/06_metrics/retro_2026-10-28_loop79.md
- [2026-10-28] [testing] An intake probe builds every configuration the ACs will name, not a sample: loop 79's probe built 2 of the 9 Rust feature sets and blamed the default set's warning on `from_hex`; the worker, building all 9, found `take` in `counters.rs` (loop 79).
  Source: _docs/06_metrics/retro_2026-10-28_loop79.md
- [2026-10-28] [estimation] A handoff line names one instance of a defect class, not the class: "a direction above 255 wraps in the C#, C++ and Go drivers" was one field; a probe ring with every number field at its edge also found the C++ tag length and kind and the Go epoch (loop 79).
  Source: _docs/06_metrics/retro_2026-10-28_loop79.md
- [2026-10-30] [estimation] A zero-margin byte pin makes a no-behaviour file split an owner decision: a second translation unit cost 32 B on the Cortex-M4F image and 40 B on the Cortex-M33F one (shared literal pool, alignment), so run the arm stage at intake when a task touches a pinned image (loop 84).
  Source: _docs/06_metrics/retro_2026-10-30_loop84.md
- [2026-10-30] [tooling] A worker told to build the project's own embedded image (`cpp/embedded/Dockerfile`, about 3.5 min) found the M33F pin failure that no host build shows; "NOT RUN, no toolchain" is the wrong stop when the stage has a documented image (loop 84).
  Source: _docs/06_metrics/retro_2026-10-30_loop84.md
- [2026-10-30] [process] A review cleanup in a handoff is a lead, not a defect: two of four from loop 83 did not exist on HEAD (`kMax` is read by two parts, `frame_hex` differs on purpose) and the include prune removed nothing, so probe each before it gets a spec line (loop 84).
  Source: _docs/06_metrics/retro_2026-10-30_loop84.md

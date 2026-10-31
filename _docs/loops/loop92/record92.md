# Autodev loop record - loop 92

loop: 92
branch: dev
plan_artifact: _docs/loops/loop92/plan92.md
tasks_shipped: [AZ-3452_avr_chacha20_runtime_check]
decisions:
  - owner (2026-10-31, hopper empty): chose "AVR chacha20_xor check" from the handoff candidates, then confirmed the Phase 1 summary and the change location (`target_avr_uno` in `cpp/embedded/arm.sh`, `chacha20_xor` in `crypto.cpp`)
  - agent: problem pack probed on HEAD e64e3eb first: `simavr` 1.6 installs from Ubuntu universe; a probe ELF ran under it; the console register prints nothing in 1.6 and its header is not C++, so the image reports over the UART
  - agent: the check extends `target_avr_uno` (no new report row), so the pinned row counts of `lib.test.sh` and `run-parts.test.sh` stay; the gate is one `diff` of the UART report against `avr/chacha20_expected.txt`, plus a 30 s limit and a missing-tool failure
  - agent: the planned separate parser unit test was dropped (a new test script needs CI wiring in four files); the five real-path failure runs cover AC-5
  - agent: Jira AZ-3452 created at intake (Task, Medium, 5 points, no epic); In Progress, then In Testing after the commit (read back from the transition results)
measurements:
  - first emulated run on the ATmega328P (16-bit `int` and `size_t`): `SIZES size_t=2 int=2`, `RFC 114/114`, `STREAM 9/9`, `RESTORED 9/9`, `EDGE 5/5`, `DONE`; no defect in `chacha20_xor`
  - RFC 8439 2.4.2 ciphertext recomputed in Python, equal to the repo vector
  - check image 3,798 B of flash and 316 B of static RAM; Uno example 15,402 B and 196 B unchanged
  - five injected failures through the real `cpp-avr-uno` row, each reverted: changed byte (`RFC 113/114`), defect in `chacha20_xor` (`STREAM 2/9`, `EDGE 3/5`), image that never ends (30 s), `simavr` missing, `simavr` silent: all exit 1
  - `scripts/loop-tests.sh --only cpp-embedded-arm,scaffold`: 2 passed, 0 failed, 184 s; the arm stage 6 of 6 rows PASS, 21 s; repeated for the smoke walk
review: "code-review (low): 0 findings; feature assessment COMPLETE (assessment92.md)"
retro: _docs/06_metrics/retro_2026-10-31_loop92.md (loop 92; next retro due after loop 97)
leftovers:
  - the wrap near 64 KiB (the one the code comment names) cannot be reached on a 2 KB part: the run checks the 16-bit arithmetic of the length, block-count and counter-limit paths; Medium concern open in the spec, out of scope
  - not run locally this loop (the change is the embedded stage): the go, typescript, csharp, python, rust, java, cpp, swift stages, the Rust embedded stage, the ring, ac10 and the publish gate; CI runs them on the close push
  - `shellcheck` is not installed on this host (`bash -n` only)
  - owner: apply the F44 ruleset and tag `v0.4.0` (CS-D5 is decided); close the epic AZ-2750; U24; the M4F row; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step; multi-part MAC rows in the ring
  - Jira: AZ-3452 In Testing
smoke: PASS (owner, 2026-10-31: the agent walked all 6 checks, the owner answered PASS; no UI, no local deploy)
smoke_artifact: _docs/loops/loop92/smoke92.md
assessment_artifact: _docs/loops/loop92/assessment92.md
loop_end_merge: main

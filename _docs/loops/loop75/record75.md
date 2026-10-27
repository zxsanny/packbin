# Autodev loop record — loop 75

loop: 75
branch: dev
plan_artifact: _docs/loops/loop75/plan75.md
tasks_shipped: [AZ-3292_cpp_frame_mode, AZ-3293_go_frame_mode, AZ-3294_python_frame_mode, AZ-3295_typescript_frame_mode]
decisions:
  - owner (2026-10-26, loop 74 D4): the four frame ports are written in loop 74 and run in loop 75 (no new owner decision this loop)
  - agent: Go uses an `RWMutex` (`Seal` and `Open` read-lock; `SetPrevious`, `ClearPrevious`, `Close` write-lock); C++ `seal` and `open` are `const` reads; Python and TypeScript state the caller's duty (the specs left the mechanism to the plan)
  - agent: `MacKey` in C++, Go, Python and TypeScript holds the 32-byte `K_label`, not the precomputed pad states (as C#, Java and Swift; only Rust precomputes); the tag bytes are equal; written in the README, the component descriptions and the contract's consumers note, no normative text changed
  - agent: Go error kinds gained `BufferFull`; Python gained the error classes `BadValue` and `BufferFull`; TypeScript errors keep the package's `{ ok: false, kind }` style with snake_case kinds
  - agent: C++ `open` reads `body` twice (tag, then decrypt) and the requirement "must not change during the call" is in the header and the README; a stack copy of 255 B was not added (it would raise the `cpp-m33f` frame pin of 912 B): OWNER DECISION below
  - agent: a C++ `seal` overlap guard cost +72 B of flash on the frame image (over the 8,416 B pin) and was reverted; the rule is documented
  - agent: the TypeScript `[Symbol.dispose]` is a runtime property only, not in the declared types (a consumer on lib ES2022 could not type-check it); `close()` is the documented release
measurements:
  - frame rows 157 of 157 and crypto rows 27 of 27 in C++, Go, Python and TypeScript (and unchanged in Rust, C#, Java, Swift); fixtures, golden hex and the contract's normative sections unchanged
  - tests after the loop (loop 74 close -> now): TypeScript 2,446 -> 2,541; Python 3,793 -> 3,894; Go 365 `--- PASS` under `-race` (the worker's count; the loop 74 figure of 325 was top-level tests, so not comparable); C++ target vector runners 296 -> 315 asserted (`frame_tests.cpp` 19)
  - C++ pins: new frame image on the `cpp-m33f` row 8,416 B flash / 912 B stack (`m33f_frame_flash_pin`, `m33f_frame_stack_pin`), deepest call `MacKey::derive` (976 B raw less the 64 B meter); cpp-m4f 7,712 / 540, cpp-m33f all-kinds 25,720 / 724, AVR Uno unchanged; no new embedded row (lib.test.sh and run-parts.test.sh unchanged)
  - step 11 `scripts/loop-tests.sh --all` at 5391686, host load 20 to 113 (the parallel suites): typescript 31 s, csharp 105 s, rust 51 s, java 38 s, python 181 s, go 216 s, cpp 81 s, swift 450 s, scaffold 492 s, cpp-embedded-arm 17 s, rust-embedded 3 s, ring 79 s, ac10 7 s PASS; publish-gate 439 s: 7 of 8 shares PASS, share 7 FAIL (2 failures, below)
  - smoke `smoke75.sh` 10 of 10 on the first run at a671a02 (host load about 10)
step11_failures:
  - publish-gate share 7 AZ-2103 AC-2: the emitted `frame-session.d.ts` and `mac-key.d.ts` named `Symbol.dispose`, which a consumer on lib ES2022 could not type-check: a real defect of this loop, fixed in fc16af4, share 7 rerun alone PASS (165 s)
  - publish-gate share 7 AZ-2563 `publish-timing.selftest.sh`: `printf: write error: Broken pipe` then "alpha has no timing line" at host load near 100; no file of this loop touches it; passed in the rerun at load 12; cause not proven (its `printf | grep -q` pipes under `pipefail` are the suspect)
review: "feature-assess round 1 EXTEND (4 Low gaps), round 2 COMPLETE after the fix batch (assessment75.md); independent read-only security review of 88cbb2b..99b7dec: PASS_WITH_WARNINGS, 0 Critical/High/Medium, 5 Low and 6 Info, L1 to L4 and I3, I4 fixed in 5391686, L5 documented (`_docs/05_security/frame_ports_review_loop75.md`); no per-batch code review (owner preference)"
retro: not due (last: loop 74; next due after loop 79)
leftovers:
  - OWNER DECISION: should C++ `open` copy the body (255 B of stack, the frame pin 912 B would rise by about that) so a receive ring written by an interrupt handler or DMA cannot change between the tag check and the decrypt? Today it is a documented requirement on the caller (C#, Go, Python and TypeScript copy it themselves)
  - open: the `publish-timing.selftest.sh` broken-pipe flake under load (L75-2)
  - open: Go intermittent failure L74-3 did not show in 3 Go runs this loop (step 11, smoke, the worker's two); not a diagnosis
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; release notes of the next 0.x (removal of `PackSession`, the frame renames, frame mode in four more packages); meshbell renames its Rust `Session` to `FrameSession`
  - candidates: a cross-language frame ring (`fixtures/frame/ring-cases.txt`); a public-key pairing step; the pre-existing items of `handoff76.md`
  - Jira: AZ-3292..AZ-3295 In Testing (read back); AZ-3280..AZ-3291 and AZ-3322 In Testing since loop 74; epic AZ-3199
lessons:
  - A declaration a package emits is part of what a consumer compiles; only the publish gate's consumer check found `Symbol.dispose` in the TypeScript `.d.ts`.
  - Put the 500-line cap and the "no new lib requirement for consumers" rule in every worker prompt.
smoke: PASS
smoke_artifact: _docs/loops/loop75/smoke75.md
assessment_artifact: _docs/loops/loop75/assessment75.md
loop_end_merge: main

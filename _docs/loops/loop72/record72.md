# Autodev loop record — loop 72

loop: 72
branch: dev
plan_artifact: _docs/loops/loop72/plan72.md
tasks_shipped: [AZ-3254_csharp_frame_hardening, AZ-3255_java_frame_hardening, AZ-3256_swift_frame_hardening]
decisions:
  - owner (2026-10-25, AskQuestion at loop start, recommended option): harden frame mode in C#, Java and Swift, closing loop 71 review items 5, 6, 7, 8 and 10 (meshbell's C# server, Android and iOS run this code)
  - agent fit decisions, auto-applied: F2 per-instance Java MAC counter; F3 C# `Seal` builds the body in a stack buffer and writes `output` last; F4 C# `Load` with no direction matches the others (owner's option text)
  - owner (2026-10-26, decision B, after two explanation rounds): test hooks use each language's official own-tests visibility. Swift `@_spi(Vectors) public` becomes `package` (SE-0386); C# `internal` + `InternalsVisibleTo` and Java package-private stay. This replaced the auto-applied F1-A (hooks deleted plus reflection in C# and Java; Swift `internal` + `@testable`), which broke the one release test build (`run-suite.sh` `swift_speed`). The owner called the SPI an unofficial workaround and asked for the proper design.
  - owner (2026-10-26, within B): the Swift stream `PackSession.wipe` goes through `FrameCrypto.wipe`; the workers' extra wipes stay
  - agent: three workers on disjoint trees, resumed once for design B; the parent wrote the docs, the batch report, the review record and the smoke
measurements:
  - Swift release speed run, 3 runs each on the same host: HEAD (SPI) 2.062 to 2.089 s; `internal` + `-enable-testing` 2.079 to 2.115 s (two tests +7%); `package` on a HEAD copy 2.082 s; build 67 / 66 / 57 s
leftovers:
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row
  - owner (unchanged): frame mode in Python, TypeScript, C++ and Go and their order; a cross-language frame ring; a replay window per key slot (F69-2); whether `frame` is on with `std`; hardening of the Rust `hkdf.rs` temporaries
  - open: CI of the loop 72 push (Swift Linux job with `package` access passed in the docker stage here)
  - Jira: AZ-3254..AZ-3256 In Testing (descriptions updated to decision B); AZ-3232..3235 story points read back (5)
lessons:
  - Before removing a test-hook mechanism, read why it was chosen and look for the language's official access level first. The Swift SPI comment said "release build too, where `@testable` does not work"; I replaced it with `internal` + `@testable` and broke the release test build. Swift `package` (tools 5.9+) was the right tool, and two explanation rounds with the owner were needed to get there.
step11: "`scripts/loop-tests.sh` at ce0658a: java 24 s, csharp 93 s, swift 458 s (with the Linux `swift:6.3.3` job), scaffold 351 s, ring 87 s, ac10 5 s, publish-gate 355 s, all PASS; vcpkg supports and consumer checks NOT RUN (no vcpkg tool here, as in loop 71)"
review: "independent read-only security review of ce0658a against dc98688: PASS, no finding (`_docs/05_security/frame_hardening_review_loop72.md`); feature-assess COMPLETE (`assessment72.md`); no per-batch code review (owner preference)"
smoke_artifact: _docs/loops/loop72/smoke72.md
assessment_artifact: _docs/loops/loop72/assessment72.md
loop_end_merge: main

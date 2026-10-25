# Autodev loop record — loop 71

loop: 71
branch: dev
plan_artifact: _docs/loops/loop71/plan71.md
tasks_shipped: [AZ-3232_csharp_frame_mode, AZ-3233_java_frame_mode, AZ-3234_swift_frame_mode, AZ-3235_frame_mode_docs_csharp_java_swift]
decisions:
  - owner (2026-10-25, AskQuestion at loop start, recommended option): the loop is frame mode in C#, Java and Swift
  - owner (2026-10-25, "accept all recommended"): all three packages in this loop, PB-02 primitive tests included, frame API on its own type (`FrameSession`) always built, one caller-owned replay window, same vectors, kinds and bytes as Rust, README example per language, no cross-language ring
  - owner (2026-10-25, "accept all recommended" after the security review): fix the Java Medium by documentation (no new lock), copy the body once in C# and Java, use the platform fixed-time compare, correct the overstating docs; carry the other Lows
  - agent: three package workers on disjoint trees; parent wrote the docs task; no per-batch review or test run (owner rule 2026-10-06)
  - agent: Swift got a fourth kind `bufferFull` (C# and Java got `BadValue` and `BufferFull` classes): the packages had none
  - agent: the loop-tests step 11 was stopped once (2 hours at host load 112 from an unrelated Archangel `tippecanoe` job, three publish-gate shares failed on swift-crypto cache and downloads) and rerun: swift alone (README block test fix), the gate alone (PASS 391 s), then again on the final tree (PASS 330 s)
leftovers:
  - owner: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row
  - owner: frame mode in Python, TypeScript, C++ and Go and the order; a cross-language frame ring (`fixtures/frame/ring-cases.txt`); a replay window per key slot (F69-2); whether `frame` is on with `std`; hardening of the `hkdf.rs` temporaries
  - security Lows carried (`_docs/05_security/frame_mode_managed_loop71.md` items 5 to 8, 10): test hooks in release builds, unwiped ChaCha state in C# and Java `SessionPad`, a production-path MAC counter in Java, C# `Load` null for an empty direction set, C# `Seal` with overlapping buffers
  - open: CI of the loop 71 push (Swift on Linux, Java on the CI JDK)
  - open: story points of AZ-3232..3235 were sent as "Story point estimate" but not echoed by the create call; read them in Jira
  - Jira: AZ-3232..AZ-3235 In Testing at close (read back)
smoke: PASS (agent run 8/8, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop71/smoke71.md
assessment_artifact: _docs/loops/loop71/assessment71.md
step11: `scripts/loop-tests.sh`: csharp, java, swift (rerun alone after the README block fix), scaffold, ring, ac10, publish-gate PASS; csharp and java rerun after the security fixes PASS; publish-gate rerun on the final tree PASS; `vcpkg` checks not in this loop's stages
review: independent security review (read-only agent) of the three implementations: no Critical or High, one Medium (Java) fixed by documentation; feature-assess COMPLETE (12 covered, 1 out-of-scope); no per-batch code review (owner preference)
loop_end_merge: main

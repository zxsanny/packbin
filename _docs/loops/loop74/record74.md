# Autodev loop record — loop 74

loop: 74
branch: dev
plan_artifact: _docs/loops/loop74/plan74.md
tasks_shipped: [AZ-3280_ring_ci_stream_removal, AZ-3281_csharp_stream_removal, AZ-3282_java_stream_removal, AZ-3283_python_stream_removal_crypto, AZ-3284_rust_stream_removal, AZ-3285_swift_stream_removal_and_names, AZ-3286_cpp_stream_removal_crypto, AZ-3287_go_stream_removal_crypto, AZ-3288_typescript_stream_removal_crypto, AZ-3289_rust_frame_names, AZ-3290_java_frame_names, AZ-3291_docs_stream_removal, AZ-3322_java_frame_config]
decisions:
  - owner (2026-10-26, AskQuestion at loop start, recommended): "Session wipe at destroy" for the stream session; replaced in the same intake when the owner asked in chat what the stream session is for ("I'm not sure it is needed at all ... wss ... public-private key")
  - owner (2026-10-26, AskQuestion "Stream mode", recommended): remove the stream session from all eight packages (ADR-009); 0.x minor step
  - owner (2026-10-26, chat): "let it be FrameSession, and match everywhere"; "add frame mode to C++, Go, Python and TypeScript, maybe put that as an additional task"
  - owner (2026-10-26, "Decisions", accept all recommended): D1 one set of frame names (the C# set; Java adds FrameSealed); D2 the HKDF, HMAC, SHA-256 and ChaCha20 of C++, Go, Python and TypeScript become an internal module tested on the 27 crypto rows; D3 the contract file keeps its name, 3.0.0; D4 the four frame ports are written now and run in loop 75; D5 ADR-009 accepted; D6 tickets under AZ-3199
  - owner (2026-10-27, assessment round 1, AskQuestion "Java shape", recommended): Java gains FrameConfig and FrameDirections (AZ-3322)
  - owner (2026-10-27, smoke gate, AskQuestion, recommended): after one intermittent Go failure, rerun the whole smoke with failure logs kept
  - agent: an empty FrameDirections set loads a session that refuses every call, as in Rust, C# and Swift (the AZ-3322 spec first said otherwise; corrected); Swift `Freshness` moved to a top-level enum (a D1 gap found by the Java worker); the Rust `FrameSession` lives in `nostd/frame/mod.rs` and `session.rs` is gone; the Rust frame example in the README is the module doc test, and `scripts/frame/readme-examples.sh` checks it
measurements:
  - diff 10cc0be..11fbea7: 311 files, +6,388 / -12,300 lines; application code and tests (without `_docs` and the README) 226 files, +3,901 / -11,558
  - test counts, HEAD → final: C# 4,319 → 4,287; Java checks 9,815 → 9,725; Python 3,877 → 3,793; TypeScript 2,442 → 2,446; Go top level 355 → 325; Rust default `cargo test` 832 → 809, CI step list 912 passed; Swift 461 → 427; C++ vector sites per target 290 → 268 → 296 (the new `crypto_tests.cpp`, 28 asserts, on Cortex-M3, Cortex-M33F, s390x)
  - frame 157 of 157 rows (Rust, C#, Java, Swift); crypto 27 of 27 rows in all eight packages (C++, Go, Python, TypeScript through an internal module, each with mutant copies caught); fixtures `frame/vectors.txt`, `crypto/vectors.txt`, `golden.hex` SHA-256 unchanged
  - Rust embedded, equal to loop 73 to the byte: M4F base 15,060 / 456, text 27,156 / 2,736, ecc 18,692 / 744, frame 20,332 / 1,728 (bound 20,480); M33F pins 15,132, 27,268, 18,764, 20,404 flash; `session` sets gone; C++ pins cpp-m4f 7,712 / 540 B, cpp-m33f 25,720 / 724 B, largest core frame 528 B → 328 B (`PackSession::open` → `Sha256::compress`); AVR Uno 15,402 B / 196 B
  - ring: 64 pairs, 45,440 ECC rows, 0 mismatched, after every batch
leftovers:
  - open: CI of the loop 74 push
  - open (L74-3): one intermittent failure of the Go step (`go test -race`, `FAIL ... 87.215s`) in smoke run 3, test name unknown, 7 other runs of the same code green; `smoke74.sh` keeps failing logs now (`handoff75.md`)
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x release; meshbell renames its Rust `Session` to `FrameSession`
  - next loop: AZ-3292..AZ-3295 frame mode in C++, Go, Python, TypeScript (in `_docs/02_tasks/backlog/`)
  - candidates: the pre-existing issues listed in `handoff75.md` (NFC/NFD edges probe, `ns20` csproj, Rust no-std all-targets test build, Swift DocC frame types, vcpkg `supports` line, AVR runtime check of `chacha20_xor`), accepted review notes F2 and F3, a cross-language frame ring, a public-key pairing step
  - Jira: AZ-3280..AZ-3291 and AZ-3322 In Testing; AZ-3292..AZ-3295 To Do; epic AZ-3199
lessons:
  - Before hardening a type (wiping its keys at destroy), ask what the type is for: the loop 74 intake began as a wipe task for a session that no application needed, and one owner question replaced it by a removal.
  - When tests of a removed feature go, list what else only they covered (targets, byte order, integer widths): the C++ session vector test was the only on-target check of the crypto, found by the security review.
  - Before specifying a refusal for one package of a shared API, read how its sibling packages treat the case: the AZ-3322 spec refused an empty direction set that Rust, C# and Swift accept.
  - A smoke or test script that deletes its work directory on exit loses the log of a failure that does not repeat: keep step logs on failure.
step11: "`scripts/loop-tests.sh --all` at 11fbea7: 14 of 14 PASS (typescript 12 s, csharp 65 s, python 162 s, go 181 s, rust 126 s, java 22 s, cpp 66 s, scaffold 325 s, cpp-embedded-arm 16 s, rust-embedded 3 s, ac10 5 s, publish-gate 951 s; swift 7,489 s and ring 3,525 s are wall time across a laptop sleep of about 2.5 hours, their real times about 10 minutes and 70 s). A first run on the same tree minus the review fixes was stopped after 2 minutes on purpose so the run is made once on the final tree"
review: "independent read-only security review of 10cc0be..df01e11: PASS_WITH_WARNINGS, one Low (the C++ crypto lost its on-target test) and five Info; the Low, the narrow OS-random scan and the stale text fixed in 11fbea7; the crypto shipped in published artifacts and the unused dependencies accepted under D2; `_docs/05_security/stream_removal_review_loop74.md`; feature-assess CLARIFY (Java shape, answered) then COMPLETE (`assessment74.md`); no per-batch code review (owner preference)"
retro: _docs/06_metrics/retro_2026-10-27_loop74.md
smoke: PASS
smoke_artifact: _docs/loops/loop74/smoke74.md
assessment_artifact: _docs/loops/loop74/assessment74.md
loop_end_merge: main

# Autodev loop record — loop 26

loop: 26
branch: dev
plan_artifact: _docs/loops/loop26/plan26.md
tasks_shipped: [AZ-2513, AZ-2514, AZ-2515, AZ-2516, AZ-2517, AZ-2518, AZ-2519, AZ-2520, AZ-2521, AZ-2522, AZ-2523, AZ-2524]
leftovers:
  - owner rows of the loop 27 handoff: F44 (tag ruleset, the owner applies it); the first tags (the first `vX.Y.Z` with the Swift check, the first `go/vX.Y.Z`)
  - first CI run unknowns (nothing here ran on an Ubuntu runner): the `swift` service and the Linux swift-crypto path, `RING_SWIFT` 6.3.3 against the runner's Swift, the thread sanitizer under Docker (`vm.mmap_rnd_bits`), scaffold job time (60 minutes), the `swift:6.3.3` pull
  - owner question not yet answered: speed up the Swift stage and the publish gate now (sanitizer on the concurrency and session suites only, a named build-cache volume, one shared consumer build cache in the gate; estimate: the `swift` stage 741 s to about 5 minutes, the gate 1 338 s to 15 to 20 minutes)
  - review26 carried: #3 scaffold sanitizer budget, #4 a Swift 6.0 consumer resolve, #5 peak memory of the max-slots unpack (the audit measured 729 MB), #8 README says Linux before a first Linux run
  - the unverified parts: Swift 6.0 itself, building this repository on Xcode 16.0 (swift-asn1 1.7.3 needs a 6.1 toolchain), tvOS, watchOS, Android, Windows, WASI
  - the `@_optimize(none)` zeroing helper in `ChaCha20.swift` (underscored attribute; the alternative is `memset_s` / `explicit_bzero` per platform)
  - small items of handoff26 not done: `go/mem_test.go` compile step, the Rust and Go ring launchers, the checker's per-case grep, `mypy --strict` (16 errors in 4 files), rustfmt and clippy for the Rust crate; `language-pair.sh` (494 lines) and `ring-wiring.test.sh` (500) at the cap, the next language needs a table-driven ring; the C++ pool race on the shared `cpp/build`
  - AZ-2068 (C++ AVR stretch) stays in `todo/`; the epic AZ-2223 stays open until the first tag resolves
smoke: PASS (script 5/5 at 735cec7; the first run 4/5 on a stale expected test count, fixed in the script)
smoke_artifact: _docs/loops/loop26/smoke26.md
assessment_artifact: _docs/loops/loop26/assessment26.md
loop_end_merge: main

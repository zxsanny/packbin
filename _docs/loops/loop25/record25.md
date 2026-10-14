# Autodev loop record — loop 25

loop: 25
branch: dev
plan_artifact: _docs/loops/loop25/plan25.md
tasks_shipped: [AZ-2472, AZ-2473, AZ-2474, AZ-2475, AZ-2476, AZ-2477, AZ-2478, AZ-2479]
leftovers:
  - owner rows of the loop 26 handoff: G1 (C++ error names the wrapped id), D1b (Rust id slot and Java `Boolean.FALSE` differences), P1 (publish gate package caches), F44 (tag ruleset, the owner applies it)
  - small items: compile `go/mem_test.go` under its tag in CI, the Rust and Go ring launchers, the checker's per-case grep, `mypy --strict` (16 errors in 4 files), rustfmt and clippy for the Rust crate, `ring-wiring.test.sh` at the 500-line cap
  - the first `go/vX.Y.Z` tag and the live proxy check: only on the owner's explicit go, with the F44 ruleset applied and CI green on `dev`
  - AZ-2068 (C++ AVR stretch) stays in `todo/`; Swift (AZ-2223) if the owner wants a next language
  - ESP targets of `cpp-embedded-esp` not run locally (the CI `embedded` job runs them on the push)
  - the commits `3897c85`, `b5c804e` and `58d912c` name AZ-2452 to AZ-2459 (not the real tickets AZ-2472 to AZ-2479); nothing was pushed before the close, so a history rewrite is possible if the owner wants it
smoke: PASS (script 12/13 at 28adfa8; the TypeScript timing test failed at load 35, the owner relaxed its bound to 1,400 ms, the stage re-run alone passed 967 of 967)
smoke_artifact: _docs/loops/loop25/smoke25.md
assessment_artifact: _docs/loops/loop25/assessment25.md
loop_end_merge: main

# Autodev loop record — loop 24

loop: 24
branch: dev
plan_artifact: _docs/loops/loop24/plan24.md
tasks_shipped: [AZ-2440, AZ-2441, AZ-2442, AZ-2443, AZ-2444, AZ-2445, AZ-2446, AZ-2447, AZ-2448, AZ-2449, AZ-2450, AZ-2451]
leftovers:
  - owner rows D1 to D7 of the assessment (empty anchored group id, `u2` as a list/dict element, `Nested` slot width, zero-width repeat shape, `BadValue` from unpack, missing manifest in `run-suite.sh`, split bit inside a false `when`) — `_docs/loops/loop25/handoff25.md`
  - the short wave decided on 2026-10-13 and not started: U25 A (C++ id range), U24 B (README), U26 A (C# nested dictionary), review23 Low 1 (Python `ValueError`) — loop 25
  - D8: Go peak-memory measurement (gap-clear, 1 point)
  - F44: the owner applies a tag ruleset on `go/v*` and `v*`; F10 and F12 stay open (Medium)
  - the first `go/vX.Y.Z` tag and the live proxy check: only on the owner's explicit go (CI is green on `dev` and `main` at `38414db` after two CI fixes, `0737002` and `38414db`: `-buildvcs=false` for the Go commands in the container, `-C` first in `go build`)
  - AZ-2068 (C++ AVR stretch) stays in `todo/`; Swift (AZ-2223) if the owner wants a next language
  - ESP targets of `cpp-embedded-esp` not run locally (CI `embedded` job runs them on the push)
smoke: PASS
smoke_artifact: _docs/loops/loop24/smoke24.md
assessment_artifact: _docs/loops/loop24/assessment24.md
loop_end_merge: main

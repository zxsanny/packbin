# Autodev loop record — loop 40

loop: 40
branch: dev
plan_artifact: _docs/loops/loop40/plan40.md
tasks_shipped: [AZ-2704]
decisions:
  - owner 2026-10-19 ("accept all recommended"): a short loop of the loop 39 review Lows; Rust `DispatchHandler::parity()` required; the default correction limit 0 and the 254-byte limit kept; `main` fast-forward at the close per `ci_cd_pipeline.md`
  - agent: one order of the call checks in all eight packages, Go's: not open, no handler, duplicate type, parity mix, limit; none moves the receive index. The survey found the same Lows in Java, C# and Python too (the review named four packages); all fixed. Go and C++ code unchanged; a Go test added for duplicate before the mix
  - agent: new `UnpackError::NoHandlers` in Rust (an empty list spent a position and gave `Type`); C# and Java throw `ArgumentException` / `IllegalArgumentException` "unpack needs at least one handler"
  - agent: the C++ session answers `BadValue` when not open, the other seven a short result; the contract says so, no C++ change
  - housekeeping: AZ-2664, AZ-2665, AZ-2674 to AZ-2676 moved to done/; AZ-2689 AC-3 met (median 210.5 s of runs 39135620507 and 39140952528); epic AZ-2677 Done
leftovers:
  - review (total, 5 Lows): 3 fixed (contract C++ wording, Rust `check_unique` without a `HashSet`, README error row); 2 accepted: Swift `readRow`/`readMap` rely on callers running `checkSchemes`, Java `Ecc.sharedParity` repeats the null checks of `byType`
  - timing checks fail under parallel load and pass alone: Go `TestACTextLoneStringUnderTimesIsParsedOnce`, Rust debug `nfr_round_trips_under_one_second`, Python EC-13 (this loop), as the TypeScript and Java ones before; a load-aware bound like the Python AC-10 fix of `75b1d39` would cover them
  - not run locally: vcpkg checks, ESP32-S3/C3, Pico and Arduino builds with ECC on
  - `/feature-assess`, `/security` (AZ-2666) and the retrospective of loops 35 to 40 are owner-run; D5 real messages, F44 and the first v*/go/v* tags; AZ-2068 in todo/
smoke: PASS (agent run 8/8 at 01276b7, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop40/smoke40.md
step11: RESULT 10 passed (go rust python only on the serial retry), 3 skipped as unchanged, 0 failed, 1194 s at 01276b7
loop_end_merge: main

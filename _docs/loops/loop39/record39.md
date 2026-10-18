# Autodev loop record — loop 39

loop: 39
branch: dev
plan_artifact: _docs/loops/loop39/plan39.md
tasks_shipped: [AZ-2694, AZ-2695]
decisions:
  - owner 2026-10-18: loop 39 scope is the loop 38 review cleanups, short loop; the parity setter shape, the default correction limit and the 254-byte limit stay out
  - agent: a duplicate type number is refused before the receive index advances in all eight packages (TypeScript, C#, Rust, Swift and C++ moved; Go, Python and Java already did, tests added); the contract `message-ecc.md` Dispatch row says so
  - agent: Go, Swift and C++ report a buffer above 254 bytes as a distinct `TooLong` (`too_long`); the contract row "Unpack, longer than 254" now requires it in every package. Pack above 254 - n stays a pack error in Go and Swift; C++ pack uses `TooLong`
  - agent: the ring drivers for Go, Swift and C++ map `TooLong` to `too_long` (found by the step 11 ring, fixed in `ad3ddd0`)
  - agent: Rust `DispatchHandler::parity()` defaults to 0
leftovers:
  - review (total, 4 Lows, none blocking): TypeScript and C# check a duplicate type before the not-open check, the other five packages check not-open first; an empty scheme list spends a position in Swift and Rust, Go refuses it first; a duplicate plus a mixed-parity list gives a different error in Rust than in the others; the Rust `parity()` default of 0 gives a hand-written handler of a scheme with parity no repair and no compile error (the mix-of-counts check still refuses a mix with `On`) - the owner may prefer a required method
  - not run locally: vcpkg supports and consumer checks, ESP32-S3/C3, Pico and Arduino builds with ECC on, the `test.yml` median over two CI runs (AZ-2689 AC-3, budget 238.5 s)
  - the timing checks `round-scope-cost` (TypeScript) and `publish-go.test.sh` AC-3 (3 s proxy window) fail under load and pass alone; the serial retry hides the first, the publish gate has no retry
  - `/feature-assess`, `/security` (AZ-2666) and the retrospective of loops 35 to 39 are owner-run and not done; the epic AZ-2677 is still To Do in Jira
  - owner decisions still open: the default correction limit (0, detect only) and the 254-byte limit; D5 real messages, F44 and the first v*/go/v* tags; AZ-2068 in todo/; main not pushed
  - CI on `dev`: run 39129310171 (`7a3bd91`, the loop 38 close) FAILED in `suites (python)` step `suite` after 110 s; the annotations do not name the test (the job log needs a token) and the same suite passed locally at `64db597` and in run 39135620507 (`1e07978`, the loop 39 close push): success, 205 s wall, the first of the two runs AZ-2689 AC-3 needs for the `test.yml` median (budget 238.5 s). The cause of the 39129310171 failure is not known; a timing check under CI load is the guess, not a finding
smoke: PASS (agent run 8/8 at ad3ddd0, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop39/smoke39.md
step11: RESULT 11 passed (typescript only on the serial retry), 1 failed (ring, fixed in ad3ddd0), 1013 s at 65bf37d; re-run at ad3ddd0 scaffold, ring passed, publish gate failed once on a load flake and passed alone (298 s)
loop_end_merge: main (not executed: the dev push only, as in loops 37 and 38; the owner is asked)

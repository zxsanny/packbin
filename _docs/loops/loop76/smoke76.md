# Loop 76 smoke — hygiene after the frame ports

LOCAL_URL: none (library; no site). Branch: dev at 48412cd. Script: `bash _docs/loops/loop76/smoke76.sh`. Run by the agent on 2026-10-27 at host load about 10 to 15, under the owner rule of 2026-10-12: one paste script, with the agent auto-passing the gate when every step passes. The Mac was held awake.

## Checks

- [x] 1. No application source is dirty
- [x] 2. Timing selftest: 0 `printf | grep` pipes, a mutated alpha line is caught with the captured output, 20 of 20 runs pass under 12 CPU burners (240 lines)
- [x] 3. C# probe: builds without `CS7022`, `edges` 64 PASS 0 FAIL, the ns20 probe builds
- [x] 4. Java `edges` probe: 65 PASS, 0 FAIL
- [x] 5. Rust: 8 of 8 feature sets compile their tests (Cargo 1.79); the frame set passes (26 tests); the Docker `rust:1.98` frame set compiles
- [x] 6. DocC lists 10 of 10 frame types; no `os_random` reason; the vcpkg `supports` line, its check and the README are unchanged
- [x] 7. No stale "Session" name (the one history row); C# lists 4,220 tests; both renamed fuzz probes exit 0
- [x] 8. Frame, crypto, ECC and hostile-case fixtures, golden hex and the contracts equal their a50e750 content
- [x] 9. No touched source file grew past 500 lines
- [x] 10. Python and TypeScript `edges` probes accept the NFC/NFD case (NFD first), 0 FAIL

## Agent walk

10 PASS, 0 FAIL, 0 NOT RUN (`smoke76: 0 failed`, exit 0) at the closing commit. The first trial run (before step 10 existed) failed steps 3 and 7 on a script bug (`env VAR=1 limit ...`: `env` cannot call a shell function); fixed, those two steps passed alone, then the full script passed.

## For the operator

Nothing: every check ran in the script.

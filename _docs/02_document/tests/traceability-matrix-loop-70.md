# Traceability matrix — loop 70 (AZ-3231)

| AC | Behavior | Status | Test IDs |
|----|----------|--------|----------|
| AZ-3231 AC-1 | libraries for `thumbv8m.main-none-eabihf` in a folder of their own | Covered | FT-X-161 (`run.sh libs` builds 5 sets into `build-m33f/`; M4F paths unchanged) |
| AZ-3231 AC-2 | the row runs on `mps2-an505` | Covered | FT-X-161 (`FAILURES 0`, `GOLDEN_OK 1`, 5 sets) |
| AZ-3231 AC-3 | heap, panic, stream and RAM checks | Covered | FT-X-161 (same `heap_hits`, `panic_hits`, `stream_hits`, `ram=0`) |
| AZ-3231 AC-4 | same bytes as the M4F image | Covered | FT-X-161 (`ROUTE_HEX` compared per set) |
| AZ-3231 AC-5 | ceilings 64 KB / 8 KB and pins at the measured figures | Covered | FT-X-161, FT-X-162 (`checks.test.sh`) |
| AZ-3231 AC-6 | the pins bite | Covered | FT-X-162 (one byte low: `flash 20236 B over 20235 B`); the ceiling check uses the same `within` |
| AZ-3231 AC-7 | M4F row unchanged | Covered | FT-X-161 run (M4F 15,060 / 20,164 B, limits file untouched; mutants PASS) |
| AZ-3231 AC-8 | harness and CI | Covered | `test.yml` installs both targets; `publish-jobs`, `publish-workflow`, `publish-pins`, `run-parts`, `lib` self-tests pass |
| AZ-3231 AC-9 | notes | Covered | `rust/embedded/README.md`, `AGENT_GOTCHAS.md`, Rust description, `architecture.md`, `tests.md` |
| AZ-3231 AC-10 | source untouched | Covered | `git diff 999b5a3 --stat`: no file under `rust/src`, `cpp/src/core`, `cpp/include` |
| Assessment70 S6/S8 | CI runs the row and its figures stay under the pins | Open | read after the push (loop close) |

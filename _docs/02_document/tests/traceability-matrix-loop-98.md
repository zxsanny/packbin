# Traceability matrix - loop 98 (AZ-3524, AZ-3525, AZ-3526)

Scenarios FT-E-17 and FT-E-18 in `blackbox-tests-27-loop98-percent-device-run.md`. Evidence: `batch_01_loop98_report.md`, `scripts/loop-tests.sh --all --only rust,cpp,python,typescript,cpp-embedded-arm,rust-embedded` (all six passed at 279ef54; the rust stage after the stale host-built test binaries were rebuilt).

| AC | Behavior | Status | Test IDs |
|----|----------|--------|----------|
| AZ-3524 AC-1 | the Swift DocC page describes the percentage; 0 missing symbols | Covered (by search; no DocC build here) | symbol check in the batch report |
| AZ-3524 AC-2 | the Go package doc describes it; `go doc` lists the three names | Covered (`go vet` not run: no network for `x/crypto`) | `gofmt -l`, `go doc` in the batch report |
| AZ-3524 AC-3 | both pages equal the README | Covered | read side by side; README Go/Swift 254-byte cells fixed |
| AZ-3525 AC-1 | 13 cases on the vector runner | Covered | FT-E-17 |
| AZ-3525 AC-2 | M3 and M33F, same bytes | Covered | FT-E-17 |
| AZ-3525 AC-3 | rounding mutation turns the run red | Covered | FT-E-17 |
| AZ-3525 AC-4 | pins hold | Covered | FT-E-17 |
| AZ-3526 AC-1 | percentage round trip passes on the M33F image | Covered | FT-E-18 |
| AZ-3526 AC-2 | both rows agree | Covered for the one row left (M4F dropped, loop 94) | FT-E-18 |
| AZ-3526 AC-3 | count round trip still 0; mutation bites | Covered | FT-E-18 |
| AZ-3526 AC-4 | pins hold or are re-pinned with the owner's yes | Covered (ecc re-pinned 19,996 B / 664 B) | FT-E-18 |
| Closes | Open 1 of `traceability-matrix-loop-97.md`: the percentage on a Cortex-M33F image | Closed on QEMU `mps2-an505` (C++ and Rust); no physical board | FT-E-17, FT-E-18 |
| Not run | the Go, C#, Java and Swift suites, the ring, AC-10 and the publish gate (no source of those changed; Swift is not installed here, Go needs the network); the ESP stage and the CI publish gate for `codec_ecc.hpp` (CI after the push) | | |

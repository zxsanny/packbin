# Batch 01 report - loop 98

Tasks: AZ-3524 (docs, 2), AZ-3525 (C++ device run, 3), AZ-3526 (Rust device probe, 3). Disjoint files; AZ-3524 and AZ-3525 by two workers in parallel, AZ-3526 by the parent after them (both embedded stages share the build directories).

## Task results

| Task | Status | Evidence |
|------|--------|----------|
| AZ-3524 | Done | `Packbin.md` gains "A percentage instead of a count" and the API list entries; `go/doc.go` gains the percentage paragraph and signatures. Symbols checked against the sources (0 missing); `gofmt -l` clean and `go doc` lists the three names (Go 1.27 from the local image). `go vet` did not run (module needs `x/crypto`, no network; comment-only change). DocC and the Swift compiler are not installed: Swift symbols checked by search only. |
| AZ-3525 | Done | New `cpp/tests/core/ecc_percent_tests.cpp`, 13 cases, 25 checks, rows verbatim from `fixtures/ecc/percent-vectors.txt`; in `VECTOR_TESTS`; runs on host, Cortex-M3 (`mps2-an385`), Cortex-M33F (`mps2-an505`) and s390x, FAILURES 0, 340 of 340 vector sites (was 315); 12 percentage packets identical on M3 and M33F (compared in `arm.sh`). Rounding mutation (`+ 99u` to `+ 0u`) failed M3, M33F and s390x; reverted. |
| AZ-3526 | Done | `ecc_extra.rs` runs a percentage round trip (25 % gives 4 parity bytes, 50 % gives 7, n / 2 bytes damaged, limit 16 lowered to n / 2, clear values compared) on the `rust-m33f` row: EXTRA_RESULT 0, FAILURES 0. Mutation (`saturating_add(99)` to `(0)` in `ecc_core.rs`) gave EXTRA_RESULT 350; reverted (`git diff -- rust/src` empty). |

## Pins

- Cortex-M33F C++ all-kinds image 25,948 B / 740 B and frame image 8,416 B / 912 B: unchanged (the new test is only in `vectors.elf`, which has no pin).
- Rust `ecc`: 19,140 B / 752 B to 19,996 B / 664 B (+856 B flash, -88 B stack). The owner agreed to the re-pin on 2026-11-01; `limits-m33f.txt` and `_docs/AGENT_GOTCHAS.md` record it. The stack pin is lowered to the measured figure. Other sets unchanged: base 15,132/456, text 27,268/2,736, frame 20,404/1,728.
- The M4F row no longer exists (dropped in loop 94, AZ-3479): the spec's "both rows" is one row, `rust-m33f`.

## Review

code-review (low): 0 findings. CI-parity: `make -C cpp test` all passed; `docker compose -f docker-compose.test.yml run --rm cpp-embedded` (arm stage) 0 targets failed; `rust/embedded/run.sh libs` then `run --rm rust-embedded` PASS; `rust/embedded/checks.test.sh` passed. Not run: the Go, TypeScript, C#, Python, Java, Swift and Rust std suites, the ring, AC-10 and the publish gate (no source of those packages changed; `go/doc.go` and the Swift page are comments and docs; the README edit is two table cells no test reads).

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear / unclear |
|----------|-----------|-------------------|-----------------|
| AZ-3524 | README ecc table said the 254-byte error is `TooMany` (Go) and `.tooMany` (Swift); both packages give `TooLong` / `.tooLong` | fixed the two cells in this batch | clear |
| AZ-3525 | `cpp/tests/core/main.cpp` calls each test by hand, so a new `VECTOR_TESTS` file needs two lines there too (not on the worker's owns list) | accepted; two lines added | clear |
| AZ-3525 | The s390x stage runs the percentage test but does not compare its packets with M3 | out of the ACs; leave | clear |
| AZ-3526 | The ecc pin counts the probe's own test code, so every probe case spends pin bytes | recorded in AGENT_GOTCHAS | clear |
| AZ-3524 | Go `WithLimits(Limits)` copies the scheme; not verified that the percentage survives it | not documented; open for assessment | unclear |
| AZ-3524 | Go refuses a count-and-percentage mix only at Unpack (no single call takes both); Swift refuses it in one `withLimits` call | worded per package in the pages | clear |

## Commit

`[AZ-3524] [AZ-3525] [AZ-3526] Percentage docs for Swift and Go; percentage test on the M3 and M33F images; Rust probe round trip` (trailer `Loop: 98`)

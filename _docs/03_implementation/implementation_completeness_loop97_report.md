# Implementation completeness — loop 97 (parity percentage)

Tasks: AZ-3499 to AZ-3509 (11, 39 points). Method: each task's Outcome and Scope against the code at HEAD 433ed19, and a scan for scaffolds.

| Task | Verdict | Evidence |
|------|---------|----------|
| AZ-3499 reference, vectors, contract 1.1.0, ADR 010 | PASS | `eccfmt.py` percent functions; `percent-vectors.txt` 1,032 rows; `check-vectors.test.sh` 11 cases; contract 1.1.0 and `adr/010` |
| AZ-3500 Python | PASS | `_ecc.py`, `_scheme.py`; 4992 tests |
| AZ-3501 TypeScript | PASS | `ecc.ts`, `index.ts`; 3622 tests, `tsc` clean |
| AZ-3502 C# | PASS | `Ecc.cs`, `EccRepair.cs`, `Packbin.cs`; 5340 tests, both targets |
| AZ-3503 Java | PASS | `Scheme.java`, `Ecc.java`, `EccRepair.java`, `BinaryPacker.java`; 11,685 checks |
| AZ-3504 Go | PASS | `ecc_percent.go` and four edited files; `go test -race` ok |
| AZ-3505 Swift | PASS | five files under `Sources/Packbin`; 452 tests |
| AZ-3506 Rust | PASS | std and `nostd` (behind `ecc`); `run-suite.sh rust` exit 0; `ecc` pin 19,140 B / 752 B |
| AZ-3507 C++ | PASS | `parity_percent`, `codec_ecc.hpp`; host and `gcc:16` tests; `cpp-m33f` pin 25,948 B / 740 B |
| AZ-3508 ring | PASS | 377 ring rows, eight drivers; real ring 64 pairs, 52,800 rows, 0 mismatched; mutation proof |
| AZ-3509 docs | PASS | README section, glossary, component rows, module-layout |

Scaffold scan (`TODO|FIXME|placeholder|stub|fake|passthrough|not implemented`) over the added source lines of the eight packages and `scripts/ecc`: no hit. The percentage is computed and searched by the production code in every package; the ring compares the real packages with the reference.

Files over 500 lines introduced by the loop: found two in the C++ package (`codec.hpp` 598, `ecc_percent_host_tests.cpp` 624) and fixed in `433ed19` (382 / 232 and 374 / 226 / 99).

Not covered here (accepted, in the batch reports): clear length 0 through a scheme in Swift, C++, Python, C#, Java and Go (a scheme message always has a type byte; covered at codec level); `parp` in-range pairs through a constructor (no such constructor, last setter wins); the Swift DocC page and the Go `doc.go` still describe only the count.

## System pipeline audit

Pipeline: caller sets a percentage -> pack derives `n` -> bytes on the wire -> unpack finds `L` -> repair -> dispatch. WIRED in all eight packages (the ring runs it end to end, 64 pairs). The embedded probes (Rust) and the C++ arm image do not exercise the percentage on a device: size, stack and link are held; behaviour on the Cortex-M33F is the host test run (accepted-risk, Low; same as the loop 95 and 96 notes).

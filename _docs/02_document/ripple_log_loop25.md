# Ripple log — loop 25

The seven packages do not import each other, so a source change in one package does not stale another package's modules. This loop changed three sources and added probe tests in five packages.

- `components/05_cpp_package/description.md` — `cpp/include/packbin/table.hpp` (`leaf`) and `fields_counted.hpp` (`counted_leaf`) refuse ids outside 0 to 32,767 (U25 A, AZ-2472). New bullet "Id range of the builder". No other package imports them.
- `components/01_csharp_package/description.md` — `csharp/Walker.cs`, `Walker.Presence.cs`, `Walker.Collections.cs` and `Walker.Elements.cs` read and return a nested-row group through the nested dictionary (U26 A, AZ-2473). The "Scope" bullet no longer says dictionary overloads take one flat dictionary.
- `components/03_python_package/description.md` — `python/src/packbin/_pack.py` and `_pack_rounds.py` raise `ValueError` (Low-1 A, AZ-2474). The open row (review23 1) is closed.
- `components/07_go_package/description.md` — `go/mem_test.go` (AZ-2475), a paragraph on the measured peak memory.
- `components/04_rust_package/`, `06_java_package/`, `02_typescript_package/` — no source change; probe tests only (Rust and Java), none in TypeScript.
- `module-layout.md` — a loop 25 line in the csharp, python, rust, cpp, java and go blocks, and a loop 25 bullet in `workflows` (`run-suite.sh` fails on a missing manifest, AZ-2477; the ring builds the C# and C++ drivers once a run into a private directory; `check-cases.sh`).
- `interaction-risks.md` — the open row of loop 23 (U24 to U26, Python `RuntimeError`) is closed.
- `tests/` — `blackbox-tests-18-loop25-owner-batch.md` (FT-X-113 to FT-X-121), `traceability-matrix.md` (31 rows, 13 closed), `resource-limit-tests.md` (NFT-RES-LIM-05), file 15 (a Go row in the memory table) and file 17 (FT-X-111 closed).
- `README.md` — the "Decided in loop 25" bullet, the D1 and D7 probe bullet and the Go memory figures.
- `_docs/04_deploy/ci_cd_pipeline.md` — `run-suite.sh` fails when its manifest is missing; the ring paragraph.

Import parse found no cross-package edge.

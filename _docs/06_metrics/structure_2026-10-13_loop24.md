# Structure — 2026-10-13 loop 24

| Metric | Value | Versus 2026-10-11 loop 18 |
|--------|-------|---------------------------|
| Components | 7 (the six language packages and the new Go package, peers) | +1 |
| Cross-component imports | 0 (`go/` imports only the Go standard library and `golang.org/x/crypto`; the ring driver module `handoff-go` imports `go/` through a `replace` and is a test driver, not a component) | 0 |
| Cycles | 0 | 0 |
| Contracts | the existing library contracts and the session contract (the Go session follows `contracts/library/pack-session.md` v1.0.0) | 0 |
| `shared/` | none | 0 |

Loop 24 added `go/`: 27 non-test files (4 851 lines: `fields`, `scheme`, `checks`, `refs`, `bind`, `values`, `places`, `rows`, `pack`, `unpack`, `flagbits`, `counted`, `rounds*`, `collections*`, `limits`, `session`, `errors`, `doc`) and 63 test files (10 418 lines, 284 test, fuzz and example functions, a 56-file fuzz seed corpus). Largest source file 341 lines, largest test file 390 lines (cap 500). Shared files touched: `run-suite.sh`, both compose files, `test.yml` (scaffold and ring jobs), the ring (`language-pair.sh`, `ring-go.sh`, `drivers/handoff-go/`), the publish chain (`publish-go.sh`, `publish-lib.sh`, `publish-check.py` and four more), `fixtures/hostile/` (checker and README), ADR-004. Public API surface of the Go package: `doc.go` (field constructors, `Bind`, `Pack`/`Unpack`/`UnpackMap`, `Limits`, `PackSession`, `Error` kinds).

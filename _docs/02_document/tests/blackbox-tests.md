# Blackbox Tests (index)

The blackbox scenarios were one file of 1 990 lines. Loop 19 (step 12) split them by category so that each file stays under the 500-line soft cap. Scenario ids (FT-P, FT-N, FT-U, FT-L, FT-D, FT-H, FT-S, FT-B, FT-C, FT-O, FT-K, FT-E, FT-X) and their text did not change in the split; look an id up in the file below. The AC to test mapping is in [traceability-matrix.md](traceability-matrix.md); inputs and expected values are in [test-data.md](test-data.md).

| File | Scenarios | Content |
|------|-----------|---------|
| [blackbox-tests-01-publish-and-bytes.md](blackbox-tests-01-publish-and-bytes.md) | FT-P-01 to FT-P-10, FT-N-01 to FT-N-04, SM-01, SM-02 | position bytes, flag widths, groups, publish and CI, production smoke |
| [blackbox-tests-02-strings-lists-dicts.md](blackbox-tests-02-strings-lists-dicts.md) | FT-U-01 to FT-U-04, FT-L-01 to FT-L-04, FT-D-01 to FT-D-05, FT-H-01 to FT-H-03 | UTF-8 strings, lists, dictionaries, six-language handoffs |
| [blackbox-tests-03-schemes-and-markers.md](blackbox-tests-03-schemes-and-markers.md) | FT-S-01 to FT-S-07, FT-B-01 to FT-B-05 | the scheme type byte, dispatch, field ids, flag-bit accessors |
| [blackbox-tests-04-counted-and-order.md](blackbox-tests-04-counted-and-order.md) | FT-C-01 to FT-C-05, FT-O-01 to FT-O-06 | borrowed counts, field order and anchors |
| [blackbox-tests-05-sessions.md](blackbox-tests-05-sessions.md) | FT-K-02 to FT-K-09 | sessions over one connection |
| [blackbox-tests-06-embedded.md](blackbox-tests-06-embedded.md) | FT-E-01 to FT-E-13 | C++ core on microcontrollers (no heap, flash and stack budgets, targets in CI) |
| [blackbox-tests-07-hostile-case-file.md](blackbox-tests-07-hostile-case-file.md) | FT-X-01 to FT-X-10 | the hostile case file (40 cases after loop 20), C++ scope rules, bool and `eq` rules, the pack stage |
| [blackbox-tests-08-rounds-and-flags-loop18.md](blackbox-tests-08-rounds-and-flags-loop18.md) | FT-X-11 to FT-X-16 | lone values in a round, `when`/`times`/`repeat` as `flags` members, flag-byte scope, split-bit numbering (loop 18) |
| [blackbox-tests-09-csharp-typed-rows.md](blackbox-tests-09-csharp-typed-rows.md) | FT-X-17 to FT-X-21 | C# typed rows, `Flags` elements and rings, strict slots, dictionary repack (loop 18) |
| [blackbox-tests-10-catchup-loops-13-15.md](blackbox-tests-10-catchup-loops-13-15.md) | FT-X-22, FT-X-23 | catch-up: C# loud pack (AZ-2088, AZ-2191), round limits on unpack (AZ-2216 to AZ-2220) |
| [blackbox-tests-11-loop19-rounds-and-split-form.md](blackbox-tests-11-loop19-rounds-and-split-form.md) | FT-X-24 to FT-X-30 | loop 19: pack round cap, Python round scope, split flag byte, lone bytes, Rust flags scope, C++ empty-group source, count 0 with values |
| [blackbox-tests-12-loop19-construction-and-harness.md](blackbox-tests-12-loop19-construction-and-harness.md) | FT-X-31 to FT-X-37 | loop 19: Python short list, C# element members, `eq` at construction, fraction probe, C++ lone flag member, run-suite venv check, file splits |
| [blackbox-tests-13-loop20-pack-budget-and-parity.md](blackbox-tests-13-loop20-pack-budget-and-parity.md) | FT-X-38 to FT-X-52 | loop 20: pack output budget (`maxBytes`), slots and `repeat` cap on pack, count 0 after the byte, combined `flags` skipped count, C++ count behind a clear `when`, C# whole floats and enum pins, Java fractions and sink, C# typed round unpack, review fix regressions, file splits and hostile replay |
| [blackbox-tests-14-loop21-slot-rule-and-parity.md](blackbox-tests-14-loop21-slot-rule-and-parity.md) | FT-X-53 to FT-X-65 | loop 21: one slot-width rule, short optional list, split-bit clear bit, C++ late `when` in a bit body (arm budgets), count behind a clear `when`, C# exact integer types, typed rounds bound to rows, dict member refused, empty round body refused, `sliceRound` cost, hostile rule tables, C# count text and `WithLimits`, 55 hostile cases |

Non-functional files: [performance-tests.md](performance-tests.md), [resilience-tests.md](resilience-tests.md), [resource-limit-tests.md](resource-limit-tests.md), [security-tests.md](security-tests.md); environment in [environment.md](environment.md).

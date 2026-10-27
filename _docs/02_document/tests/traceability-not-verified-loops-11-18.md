# Traceability: loops 11 to 18 specs not yet verified

Split out of [traceability-matrix.md](traceability-matrix.md) in loop 23 (step 12) so the matrix stays under the 500-line soft cap. The text below is unchanged from the matrix of loop 22.

## Loops 11 to 18: specs with no AC rows yet (Not verified)

Step 12 of loop 19 added AC rows for the specs the handoff named (AZ-2088, AZ-2191, AZ-2216 to AZ-2220) and for loop 19. The specs below closed in loops 11 to 18 (they appear in a `batch_*_loop11` to `batch_*_loop18` report) and still have no AC row. This is a pointer for a later sync, not coverage: a row is added only when each AC is mapped to a test name read in the package. Their behavior is partly described by FT-X-01 to FT-X-21. The AC count is the number of `**AC-n` headings in the spec.

### With a test file that cites the task id (file level only, ACs not mapped)

| Spec | Name | ACs | Files that cite the id |
|------|------|-----|------------------------|
| AZ-2072 | TypeScript hostile-packet unpack | 7 | `typescript/tests/support/hostile-cases.ts` |
| AZ-2074 | Java hostile-packet unpack | 6 | `java/src/test/java/packbin/HostileUnpackTest.java`, `java/src/test/java/packbin/HostileVectorTest.java` |
| AZ-2077 | Java thread-safe flags unpack | 5 | `java/src/test/java/packbin/FlagStateTest.java` |
| AZ-2084 | TypeScript numeric range check on pack | 6 | `fixtures/hostile/README.md` |
| AZ-2085 | Rust typed-scheme integrity | 6 | `java/src/test/java/packbin/EqBoolTrueOnlyTest.java` |
| AZ-2087 | C# reference scope check | 5 | `.github/workflows/language-pair.sh`, `fixtures/hostile/README.md` |
| AZ-2089 | Java reference scope and bool placement | 8 | `java/src/test/java/packbin/BoolPlacementTest.java`, `java/src/test/java/packbin/FlagStateTest.java`, `java/src/test/java/packbin/HostileUnpackTest.java`, `java/src/test/java/packbin/HostileVectorTest.java`, `java/src/test/java/packbin/ReferenceScopeTest.java` and 2 more |
| AZ-2090 | TypeScript `when`/count reference resolution | 6 | `fixtures/hostile/README.md` |
| AZ-2091 | TypeScript nested-group structure fixes | 7 | `.github/workflows/language-pair.sh` |
| AZ-2092 | C# typed binding per scope | 8 | `.github/workflows/language-pair.sh`, `csharp/tests/TypedBindingTests.cs`, `csharp/tests/TypedParityTests.cs` |
| AZ-2093 | C# honest AC-10 test | 3 | `csharp/tests/Ac10TimingTests.cs` |
| AZ-2094 | Java 17 / Android API 26 artifact | 6 | `java/src/test/java/packbin/ApiSafeReplacementsTest.java` |
| AZ-2095 | Publish gated on test.yml | 6 | `.github/workflows/publish-gate.test.sh` |
| AZ-2096 | Two-phase publish (build, then upload) | 6 | `.github/workflows/publish-phases.test.sh` |
| AZ-2097 | Re-runnable publish with declared required registries | 7 | `.github/workflows/publish-rerun.test.sh` |
| AZ-2098 | Buildable vcpkg port with consumer check | 5 | `.github/workflows/publish-vcpkg.test.sh` |
| AZ-2101 | Java typed nested rows | 6 | `java/src/test/java/packbin/TypedNestedRowTest.java` |
| AZ-2102 | TypeScript group/flags as list and dict elements | 6 | `.github/workflows/drivers/HandoffElements.java`, `.github/workflows/drivers/handoff.py`, `.github/workflows/drivers/handoff.ts`, `.github/workflows/language-pair.sh` |
| AZ-2103 | npm package as JavaScript + .d.ts | 6 | `.github/workflows/publish-npm.test.sh` |
| AZ-2110 | Java zero-width elements and orphan flag bits | 5 | `java/src/test/java/packbin/ZeroWidthElementTest.java` |
| AZ-2113 | Python refuses when and count names that point to a later field | 4 | `fixtures/hostile/README.md`, `python/tests/test_bool_placement.py`, `python/tests/test_zero_width_elements.py` |
| AZ-2114 (retired in loop 74, ADR 009) | Hostile session unpack tests for C#, Java and Rust | 2 | `csharp/tests/HostileSessionTests.cs`, `java/src/test/java/packbin/HostileSessionTest.java`, `rust/src/session_hostile_tests.rs` |
| AZ-2115 | Pin the split-form reference bytes in TypeScript and C# tests | 1 | `csharp/tests/SplitFormReferenceTests.cs`, `typescript/tests/split-form-reference.test.ts` |
| AZ-2119 | C# group as list or dict element throws KeyNotFoundException on unpack | 3 | `.github/workflows/drivers/csharp/HandoffElements.cs`, `csharp/tests/GroupElementTests.cs` |
| AZ-2121 | Orphan flag-bit tests for every container | 4 | `csharp/tests/FlagScopeContainerTests.cs`, `java/src/test/java/packbin/FlagScopeContainerTest.java` |
| AZ-2127 | Java nested rounds | 4 | `java/src/test/java/packbin/HostileUnpackTest.java`, `java/src/test/java/packbin/NestedRoundTest.java`, `java/src/test/java/packbin/RepeatRoundTest.java` |
| AZ-2131 | Java empty group refused | 4 | `java/src/test/java/packbin/BoolPlacementTest.java`, `java/src/test/java/packbin/FlagStateTest.java`, `java/src/test/java/packbin/TypedNestedRowTest.java` |
| AZ-2133 | Rust and C++ bitwhen | 2 | `.github/workflows/out/artifacts/rust/stage/src/flag_presence_tests.rs`, `rust/src/flag_presence_tests.rs` |
| AZ-2134 | Aligned round values | 4 | `.github/workflows/language-pair.sh`, `fixtures/hostile/README.md` |
| AZ-2147 | C++ empty group without member | 2 | `cpp/tests/core/scheme_tests.cpp` |
| AZ-2179 | Rounds ring in `language-pair.sh` | 4 | `fixtures/hostile/README.md` |
| AZ-2180 | C# scheme clones its flag-bit groups | 5 | `csharp/tests/FlagGroupCopyTests.cs` |
| AZ-2181 | C# count source is an integer field | 4 | `csharp/tests/CountKindTests.cs`, `csharp/tests/CountOverflowTests.cs`, `csharp/tests/EqBoolTrueOnlyTests.cs`, `csharp/tests/HostileUnpackTests.Counts.cs` |
| AZ-2182 | C# lone value in a round | 7 | `csharp/tests/LoneRoundValueTests.cs` |
| AZ-2185 | TypeScript `times` list longer than the count is an error | 6 | `fixtures/hostile/README.md` |
| AZ-2186 | Python `times` list longer than the count is an error | 6 | `fixtures/hostile/README.md` |
| AZ-2187 | Java `times` list longer than count is refused | 6 | `fixtures/hostile/README.md`, `java/src/test/java/packbin/TimesLongerTest.java` |
| AZ-2188 | TypeScript duplicate member names refused at construction | 7 | `typescript/tests/nested-group.test.ts`, `typescript/tests/round-values.test.ts` |
| AZ-2190 | Java pack range and type check for integers and floats | 7 | `java/src/test/java/packbin/PackStrictTest.java` |
| AZ-2193 | `language-pair.sh` in CI | 7 | `.github/workflows/ring-wiring.test.sh` |
| AZ-2214 | Pin actions by commit and tools by exact version (F12) | 8 | `.github/workflows/publish-pins.test.sh` |
| AZ-2215 | Read-only repo mount for the publish containers (F13) | 8 | `.github/workflows/publish-readonly.test.sh` |
| AZ-2230 | Python numbers split bits by scheme order | 10 | `fixtures/hostile/README.md` |
| AZ-2232 | vcpkg port limited to Linux and macOS, `find_package` version rule "same minor" for 0.x | 6 | `.github/workflows/publish-vcpkg.test.sh` |
| AZ-2233 | Java nested row: a flag bit with no flag byte inside the row is refused at construction | 6 | `java/src/test/java/packbin/SplitBitOrderTest.java` |
| AZ-2234 | Java pack: missing nested rows and null group elements throw, `u2` honours the round item | 9 | `java/src/test/java/packbin/FlagPresenceTest.java`, `java/src/test/java/packbin/MissingNestedValueTest.java`, `java/src/test/java/packbin/PackStrictTest.java`, `java/src/test/java/packbin/RepeatRoundTest.java` |
| AZ-2235 | Java typed rows: a list or dict element nested-row group without a factory is refused at construction | 6 | `java/src/test/java/packbin/TypedElementScopeTest.java`, `java/src/test/java/packbin/TypedNestedRowTest.java` |
| AZ-2237 | Rust pack reads what it wrote | 8 | `rust/src/when_kept_tests.rs` |
| AZ-2238 | Three harness fixes: `publish-position.sh` installs with `cd` + `npm ci`, `examples.sh` captures `find` output before it picks the first line, `language-pair.sh` names a failing consumer | 5 | `.github/workflows/publish-gate.test.sh`, `.github/workflows/publish-position.test.sh`, `.github/workflows/ring-wiring.test.sh` |
| AZ-2239 | `listgroup` ring in `language-pair.sh` for the packages that support the shapes | 6 | `.github/workflows/drivers/HandoffElements.java`, `.github/workflows/drivers/csharp/HandoffElements.cs`, `.github/workflows/drivers/handoff.py`, `.github/workflows/drivers/handoff.ts`, `.github/workflows/language-pair.sh` |
| AZ-2240 | `publish-check.py` checks `exports`, `types` and the dist modules of the npm tarball, and the CMake file, LICENSE and host dependencies of the vcpkg port | 6 | `.github/workflows/publish-npm.test.sh`, `.github/workflows/publish-vcpkg.test.sh` |
| AZ-2243 (retired in loop 74, ADR 009) | TypeScript `PackSession.load` takes only a `Uint8Array` seed | 6 | `typescript/tests/session.test.ts` |
| AZ-2246 | Java duplicate member names refused at construction | 11 | `java/src/test/java/packbin/DuplicateNamesTest.java` |

### No test or fixture file cites the id (Not verified: tests may exist under another name)

| Spec | Name | ACs |
|------|------|-----|
| AZ-2071 | Python hostile-packet unpack | 7 |
| AZ-2073 | C# hostile-packet unpack | 6 |
| AZ-2075 | Rust hostile-packet unpack | 5 |
| AZ-2076 | C# thread-safe flags unpack | 5 |
| AZ-2079 | C# bool presence and 9th flag bit | 8 |
| AZ-2080 | TypeScript bool presence and flag-bit limit | 8 |
| AZ-2082 | Rust flag bits and bool rule | 5 |
| AZ-2083 | Python bool placement and flag-bit limit | 5 |
| AZ-2086 | Rust typed times | 6 |
| AZ-2099 | Embedded harness fails a target on any failed command | 6 |
| AZ-2100 | Python split form and repeat/times fixes | 9 |
| AZ-2104 | Python seed check (retired in loop 74, ADR 009) and safe star-import | 5 |
| AZ-2105 (retired in loop 74, ADR 009) | Rust session pack error | 4 |
| AZ-2107 | Python zero-width elements | 4 |
| AZ-2108 | TypeScript zero-width elements and orphan flag bits | 5 |
| AZ-2109 | C# zero-width elements and orphan flag bits | 5 |
| AZ-2111 | Rust zero-width elements and orphan flag bits | 5 |
| AZ-2112 | TypeScript accepts u64 counts for sized, packed and times | 3 |
| AZ-2116 | C# unpack returns exact integer types | 2 |
| AZ-2117 | Rust scope check covers name-based references | 4 |
| AZ-2118 | Rust pack borrowed_count uses checked_add | 1 |
| AZ-2122 | TypeScript __proto__ dict key, when-in-repeat round scope, BOM kept | 4 |
| AZ-2123 (session counter part retired in loop 74, ADR 009) | C# top-range u64/i64 overflow, capacity reserve, atomic session counter | 4 |
| AZ-2124 (retired in loop 74, ADR 009) | Java atomic PackSession send counter | 2 |
| AZ-2125 | Rust cap collection capacity at the bytes left | 2 |
| AZ-2129 | TypeScript constructor checks | 4 |
| AZ-2130 | C# empty nested-row group | 4 |
| AZ-2132 | Python empty group refused | 3 |
| AZ-2175 | C# `when` reads what pack wrote | 7 |
| AZ-2176 | C# nested rounds refused at construction | 3 |
| AZ-2177 | TypeScript nested rounds refused at construction | 4 |
| AZ-2178 | Rust typed `times` shape pins | 7 |
| AZ-2183 | TypeScript pack finds flags under a split bit and inside flags | 7 |
| AZ-2184 | TypeScript dict entries stay out of the row's members | 7 |
| AZ-2189 | Rust map `times` refuses a per-name value it cannot align | 4 |
| AZ-2192 | Python float fields accept only numbers and name the field on overflow | 6 |
| AZ-2197 | TypeScript `when` reads what pack wrote | 6 |
| AZ-2231 (retired in loop 74, ADR 009) | Python `PackSession.load` takes only a bytes-like seed | 5 |
| AZ-2236 | TypeScript refuses an anchored group as a list or dict element when the scheme is built | 7 |
| AZ-2244 (retired in loop 74, ADR 009) | Python `PackSession.start` and `join` take only a bytes-like nonce | 9 |
| AZ-2245 | Python duplicate member names refused at construction | 10 |
| AZ-2247 | Rust duplicate data member names refused at construction | 11 |
| AZ-2248 | Python `times` short or empty list for a member under `flags` | 8 |
| AZ-2249 | Python refuses an attribute-style accessor inside a `list` or `dict` element group when the scheme is built | 10 |

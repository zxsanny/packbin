# Batch Report

**Batch**: 5 (loop 16, round 2 after feature assessment round 1; wave A: four package workers, wave B: two harness workers)
**Tasks**: AZ-2230, AZ-2231, AZ-2232, AZ-2233, AZ-2234, AZ-2235, AZ-2236, AZ-2237, AZ-2238, AZ-2239, AZ-2240
**Date**: 2026-10-06

Specs written by spec authors who reproduced every probe (owner answer to the assessment: take all recommendations, implement everything now). One worker per package on disjoint paths, one review per package plus one for the harness, a fix pass after the reviews (Rust, TypeScript, Python, Java, harness H2), parent-run verification on a clean `HEAD` overlay that carries none of the owner's uncommitted C# work.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2230_python_split_bits_scheme_order | Done (AC-1 to AC-10): Python numbers split flag bits by scheme order; one `flag_byte()` handle can be shared by schemes and read twice; an unplaced bit leaves its bit clear | `python/src/packbin/_flag_scope.py` (new, 83), `_nodes.py`, `_scheme.py`, `_validate.py` (-50: `_check_flag_scopes` and `_validate_flag_bits` replaced), tests `test_split_bits_field_order.py` (new, 281), `test_split_form.py`, `test_bool_placement.py` | Python 286 to 326 | wire change only for a shared handle, a byte read twice or bits created out of scheme order (`[m, m.bit(a), m, m.bit(b)]` with only `b` set: `01000109`, was `01020209`); 12,000 and 22,000 random schemes equal to HEAD / TypeScript |
| AZ-2231_python_session_load_bytes_only | Done: `PackSession.load` returns `None` for anything that is not bytes, bytearray or memoryview of 32 bytes (a released memoryview too, after the review) | `python/src/packbin/_session.py`, `test_session.py` (+72) | in the Python count | constructor and session vectors unchanged; `PackSession([7]*32)` still builds (excluded) |
| AZ-2232_vcpkg_supported_platforms_minor_version | Done: port `"supports": "linux | osx"`; `SameMinorVersion` while the major is 0 | `cpp/CMakeLists.txt` (host branch), `.github/workflows/publish-embedded.sh`, `publish-vcpkg.test.sh` (490 lines: supports dry-run for x64-windows refused and x64-linux planned, version matrix, second consumer) | real vcpkg gate PASS; AC-4 matrix matches CMake 4.1.1 | `find_package(packbin 0 ...)` finds nothing for 0.x, ranges spanning minors are refused too (documented); the vcpkg gate takes 19 s warm against 9 s at HEAD |
| AZ-2233_java_nested_row_orphan_bit_refused | Done: a flag bit whose only flag byte lies outside its nested row is refused when the scheme is built (orphan message) | `java/src/main/java/packbin/SchemeOrder.java`, `Field.java` | Java 1324 to 1501 checks (all three Java specs) | a nested row whose member is the row itself (`identity`) is refused too: documented, workaround in the README |
| AZ-2234_java_pack_fails_loudly_nulls_u2 | Done: `missing group`, `missing list element I`, `missing dict element "k"` for null or absent nested rows and elements outside `flags`; `u2` inside a round packs the round item | `Walker.java`, `VarFields.java`, `Containers.java`, `Packbin.java`, new `MissingNestedValueTest.java` | in the Java count | 194 of about 1.54M differential rows that read back modulo nulls at HEAD now throw (spec-literal) |
| AZ-2235_java_typed_element_groups_checked | Done: a list or dict element group on a typed row (or below a group with a factory) built with the old overload is refused when the scheme is built (`list element: nested group on a typed row needs a child factory`) | `SchemeOrder.java` (`requireElementFactory`), `Packbin.java` Javadoc, `TypedNestedRowTest.java` (496 lines), new `TypedElementScopeTest.java` | in the Java count | S4, S5, S8 (typed accessors in anchored/flags elements and on Map rows) stay a `ClassCastException` on unpack: owner options A to D |
| AZ-2236_typescript_direct_element_kinds_refused | Done: an anchored `group` as a direct list or dict element (at any depth) is a `RangeError` at construction; `when` and `times` already were | `typescript/src/element-kinds.ts` (new, 31), `index.ts` (+2), new `typescript/tests/list-element-kinds.test.ts` | TypeScript 437 to 463 | the spec text "never packed a row" was false (empty lists pack) and is corrected; the ticket text was partly wrong (only the anchored group was a late error) |
| AZ-2237_rust_map_pack_when_written_values | Done: map pack decides every `when` from the values it wrote in that scope; a count that names a skipped field is `Missing`; a longer `times` list is `PackError::Type`; after a `times` its round names are lists in the parent (`RoundLists`) | `rust/src/walk/pack.rs` (`Written`), new `walk/flag_bits.rs` (the HEAD text moved), `walk/times.rs` (`check_longer`), `walk/mod.rs`, `lib.rs`, new tests `when_written_tests.rs`, `when_kept_tests.rs`, `when_names_tests.rs`, `times_longer_tests.rs` | Rust 288 to 331 | review F1 to F3 (Medium) fixed; flat-scheme release cost about 1.3x to 1.57x (optional follow-up) |
| AZ-2238_harness_hygiene_prefix_find_consumer | Done: `publish-position.sh` installs after a `cd` (symlinked temp dir), `examples.sh` and `lib.test.sh` no longer pipe `find` into `head` under pipefail, `language-pair.sh` names the consumer, the producer and the ring on every failure | `publish-position.sh`, new `publish-position.test.sh` (56), `cpp/embedded/examples.sh`, `lib.test.sh`, `language-pair.sh`, `ring-wiring.test.sh`, `publish-gate.test.sh` (+2 lines wiring) | `ring-wiring.test.sh` (29 checks plus 4 names the pair), `publish-position.test.sh`, `lib.test.sh` | Linux-only proof: `npm ci --prefix` through a symlink, mawk |
| AZ-2239_listgroup_cross_language_ring | Done: rings `listgroup`, `dictgroup`, `listflags` among TypeScript, Python and Java with the pinned bytes, and each package refuses the same packets cut short | `language-pair.sh`, `drivers/handoff.ts`, `handoff.py`, `Handoff.java`, new `HandoffElements.java` | ring PASS 65 s (84 s cold) | Rust refuses these schemes at construction, C++ builds an invalid scheme, C# throws until AZ-2119: recorded, not worked around |
| AZ-2240_publish_guard_dist_and_port_asserts | Done: the tag-time guard asserts the npm `exports`, `types`, every dist file the entry points import and no `src/`, and the vcpkg port `CMakeLists.txt`, `LICENSE` and host dependencies | `publish-check.py` (+25 lines) and `publish-phases.test.sh` (1 fixture hunk) through the patch route (staged hunks; the owner's C# hunks byte-identical), `publish-npm.test.sh` (221, `npm_guard_checks`), `publish-vcpkg.test.sh` (`vcpkg_guard_checks`) | 24 npm and 14 port mutants rejected; 9 of 9 new rules each fail a check when removed | the tag-time guard does not assert `supports` (open, optional one-line `need`); the import regex counts comments and strings, misses `require` and undeclared bare imports (open Low) |

## Code Review Verdict: see `_docs/03_implementation/reviews/batch_05_loop16_review.md` (PASS_WITH_WARNINGS; three Medium found in Rust, all fixed)

## Test Suite

Parent-run on a clean `HEAD` overlay plus the round 2 files (the owner's C# work is not part of it; `check-foreign.sh` OK before and after), CI toolchains in Docker:

| Stage | Result |
|-------|--------|
| strict `tsc --noEmit` | PASS |
| TypeScript (node 24) | 463 pass (437 at HEAD) |
| Python (3.14) | 326 pass (286) |
| Rust (1.98) | 331 pass (288) |
| Java (26) | PASS, 1501 `expect*` checks (1324) |
| C++ host | PASS |
| scaffold (report row, hostile cases, `lib.test.sh`, `ring-wiring.test.sh`) | PASS |
| `language-pair.sh` ring (`PACKBIN_CXX_SYSROOT`) | `language pairs passed`, 65 s |
| publish gate | no failures in 401 s; the two vcpkg checks NOT RUN without a vcpkg tool |
| publish gate `--vcpkg` with the real vcpkg 2026-09-26 (arm64-osx) | `vcpkg port checks passed` |
| embedded ARM | 4/4 PASS |

Not run in this batch: C# (unchanged by round 2, runs from a clean export in step 11), the ESP stage (re-run in step 11), anything that only the Ubuntu runner proves (see the review).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A bit that is created and never placed leaves its bit clear without a message (Python, as TypeScript) | AZ-2230 Risk 2 | owner to confirm; an optional later spec could warn | unclear |
| 2 | Java typed-accessor element cases S4 (anchored group), S5 (`flags`) and S8 (typed accessors on `Map` rows) fail on unpack with `ClassCastException`; options B (refuse anchored/flags/u2 elements on a typed row), C (overload), D (leave) | AZ-2235 | owner chooses | unclear |
| 3 | The Java message says "typed row" for a `Map` row whose nested row has a `Map` factory | AZ-2235 | owner: keep or reword | unclear (low) |
| 4 | `missing group` has no round index or path; the ticket said `missing field N` | AZ-2234 | owner: keep the pinned wording | unclear (low) |
| 5 | TypeScript: a multi-slot `u2` as a direct element builds and fails at pack; `flagByte` as an element drops values; `when` and `times` direct elements say "eq names field id N" not their kind | AZ-2236 Excluded | follow-up spec if the owner wants them refused | unclear |
| 6 | Rust: release pack of a flat scheme costs about 1.3x (nfr shape) to 1.57x (12 fields) because every written field is recorded; an optional flag computed in `MapScheme::new` records only when the scheme has a `when` or a count | AZ-2237 F4 | optional Low follow-up | unclear (low) |
| 7 | Rust: a multi-name `u2` in a map `times` fed per-name lists is `Missing` (HEAD too) | AZ-2237 | open | clear |
| 8 | Harness guard: no `supports` assert at tag time; import regex accepts comments/strings, misses `require` and undeclared bare imports; non-UTF-8 member gives a traceback | AZ-2240 | optional one-line asserts after the owner commits the C# work | clear |
| 9 | Only the Ubuntu runner proves: the first `ring` run (node 24, JDK 26, Python 3.14), `npm ci --prefix` through a symlinked temp path on Linux, mawk, vcpkg `x64-linux` dry-run and the second consumer, `GITHUB_ACTIONS=true` turning a missing tool into a failure | AZ-2232, AZ-2238, AZ-2239 | first CI run | clear |
| 10 | The held decisions are unchanged: `when`/`times`/`repeat` as a `flags` member (all packages), C++ flags/flag-bit scope parity, C# parts (AZ-2092, 2093, 2119, 2120, 2180, 2181, 2182, 2191, AZ-2126, AZ-2194, the C# parts of AZ-2114/2115/2121/2128/2135) | loop 16 plan | land with the owner's C# work | clear |

## Commit

`[AZ-2230] [AZ-2237] [AZ-2232] Close the assessment gaps in six packages` (≤72 chars). Body: the eleven ids, one line per package, `Loop: 16`.

## Next: step 10.5 (feature assessment round 2), 11 (run tests from a clean export), 14 (security), 17 (retrospective), then loop close

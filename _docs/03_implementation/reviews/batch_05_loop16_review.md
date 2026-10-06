# Code Review Report

**Batch**: 5 (loop 16, round 2 after the feature assessment): AZ-2230 to AZ-2240 | **Date**: 2026-10-06 | **Mode**: Full, one read-only reviewer per package (Python, TypeScript, Java, Rust) and one for the harness (vcpkg, guard, ring), each on scratch copies with a differential against the `HEAD` classes, then fix passes | **Verdict**: PASS_WITH_WARNINGS (no Critical or High; three Medium found in Rust and fixed)

## Findings and disposition

### Python (AZ-2230, AZ-2231)

| # | Severity | Category | File:Line | Title | Disposition |
|---|----------|----------|-----------|-------|-------------|
| F1 | Low | Spec-Gap | README, `03_python_package/description.md`, `tests.md` | Docs listed as included still state the old Python rules | CLOSED by the docs pass of this batch |
| F2 | Low | Spec-Gap | `_session.py:33` | `load` of a released `memoryview` raised `ValueError` | FIXED: only that `ValueError` is caught and returns `None`; a hostile `__bytes__` still propagates; test added |
| F3 | Low | Bug (spec Risk 2) | `_flag_scope.py:57` | A last bit that is created and never placed is dropped silently (`[m, a]` with `b` created: `{a:1, b:2}` packs `010101`) | OPEN for the owner; TypeScript behaves the same; stated in the README |
| F4 | Low | Maintainability | `test_split_bits_field_order.py` | No test pinned that a flag byte read inside a `group` stays visible to a later bit (mutant copying `reads` survived) | FIXED: test added, the mutant now fails |

### TypeScript (AZ-2236)

| # | Severity | Category | File:Line | Title | Disposition |
|---|----------|----------|-----------|-------|-------------|
| F1 | Medium | Spec-Gap (text) | spec NFR Compatibility, Risk 1 | "A scheme that is refused now never packed a row" is false: `{g: []}`, a `repeat` with zero rounds and an anchored group of only optional members pack at HEAD | FIXED in the spec text; the upgrade note says a scheme that only packed empty lists or dropped values now fails at build |
| F2 | Medium | Spec-Gap | README, `02_typescript_package/description.md`, `tests.md` | Docs listed as included not updated | CLOSED by the docs pass |
| F3 | Low | Maintainability | `element-kinds.ts:20` | `case "flags"` reported unreachable | KEPT: it is reachable for a `flags` nested directly in `flags`; a test now reaches it (mutation: removing the case fails it) |

### Java (AZ-2233, AZ-2234, AZ-2235)

| # | Severity | Category | File:Line | Title | Disposition |
|---|----------|----------|-----------|-------|-------------|
| F1 | Low | Spec-Gap | `SchemeOrder.java:73` | A nested row whose member is the row around it (`group(identity(), ignore(), m.bit(x))`) now refuses an outside flag byte; HEAD packed it correctly (`01 01 05`) | DOCUMENTED: the rule is by scope; Javadoc of `bindFlagBits` and `Field.bit` corrected; README names the shape and the workaround (`group(identity(), ignore(), m, m.bit(x))`, `01 00 01 05`) |
| F2 | Low | Maintainability | `SchemeOrder.java:152` | The element scope is built with `typed=false`; no test pinned it | FIXED: new `TypedElementScopeTest` (3 cases); the mutant passing `typed` now fails |
| F3 | Low | Style | `SchemeOrder.java:182-186` | The message says "typed row" for a Map scheme whose nested row has a Map factory | OPEN for the owner (wording); workaround and the rule are in the README |
| F4 | Low | Spec-Gap | `Walker.java:181` | Rows that read back modulo nulls at HEAD (`repeat(g)` with `{g:[null,null]}`, `{g:[{v:1}, null]}`, an absent row whose body writes 0 bytes) now throw `missing group` | DOCUMENTED in the README upgrade note; the spec literally asks for it (AZ-2234 AC-3); `{}`, `{g:null}`, `{g:[]}` still pack `01` |

### Rust (AZ-2237)

| # | Severity | Category | File:Line | Title | Disposition |
|---|----------|----------|-----------|-------|-------------|
| F1 | Medium | Bug / Spec-Gap | `walk/pack.rs:311-342` | `Written` never got the names a `times` publishes into the parent; unpack-then-repack of `0101000007` returned `Missing("4")` (and a row holding `4=9` wrote `010100000709`, which its own unpack rejects) | FIXED: `RoundLists` puts one list per round name into the parent record after a `times` (both branches); 5 tests |
| F2 | Medium | Bug | `walk/times.rs:101-113` | `check_longer` refused lists under flags, flag-byte and group names that pack never reads (HEAD packed `010200050006`; the README edit path broke) | FIXED: data members only; 3 tests; the five AC-6 tests stay green |
| F3 | Medium | Test gap | `when_written_tests.rs`, `when_kept_tests.rs` | Removing the `Flags` byte record or the `FlagByte` record passed all tests | FIXED: 6 tests naming the byte pack wrote (`0105010709`, `0101010508`, `010105aa`, `01010105aa`); both mutants now fail 3 and 4 tests |
| F4 | Low | Performance | `walk/pack.rs:374,405` | An unread `Written` Vec allocated per list/dict element | FIXED for elements (`Written::unread()`; 60k-element list pack now 1.01x HEAD). Remaining cost on a flat scheme: about 1.3x on the `nfr` shape, 1.57x on a 12-field flat pack (release, same load; 15 ns per written field) | 
| F5 | Low | Docs | `walk/mod.rs:20-26`, README 901/923/1068, `description.md:93` | Rustdoc slightly wrong; old Rust limitation text | FIXED (rustdoc); README and description.md by the docs pass |
| F6 | Low | C15 | `walk/pack.rs:335` | Error precedence changes for rows with two defects (a longer `times` list is refused before item errors, as TypeScript does) | DOCUMENTED (one sentence) |

### Harness (AZ-2232, AZ-2238, AZ-2239, AZ-2240)

| # | Severity | Category | File:Line | Title | Disposition |
|---|----------|----------|-----------|-------|-------------|
| F1 | Low | Maintainability | `publish-position.test.sh` | The header said "sourced" but the gate runs it as a child; duplicated helpers | FIXED: plain script, 56 lines |
| F2 | Low | Spec-Gap | `cpp/CMakeLists.txt:49` | Version ranges that span minors (`0.9...0.10`, `0.9...<1.0`, `0.8...0.9`) are refused too (CMake's own SameMinor template) | DOCUMENTED in the README version paragraph and the C++ description |
| F3 | Low | Bug | `cpp/embedded/lib.test.sh:28` | `find ... \| head)` with no argument was not flagged | FIXED: regex `head([^a-zA-Z0-9_-]\|$)`; 14 synthetic cases correct on macOS awk and mawk 1.3.4 |
| F4 | Low | Bug | `publish-check.py:98` | The import regex hits comments and strings; `require(...)` and bare imports missing from `dependencies` pass; a non-UTF-8 member gives a traceback instead of a named part | OPEN (Low): the file carries the owner's uncommitted C# hunks; spec Risk 1 accepts the comment/string hits |
| F5 | Low | Maintainability | `language-pair.sh:174` | The short-check message blamed a short element when the driver crashed | FIXED: the line says it read a short element or the driver crashed (see the output above) |
| F6 | Low | Performance | `publish-vcpkg.test.sh` | The vcpkg gate runs 19 s warm against 9 s at HEAD; the spec asked for added checks under 10 s | ACCEPTED: 10 s over HEAD, the cause is the intended checks (supports dry-runs, version matrix, second consumer, guard mutants) |

## Existing tests changed

- Python: `test_split_form.py` (the refusal of a flag byte listed without its bits became AC-9's assertion `0100`, same scheme); `test_bool_placement.py::_nine_bits_split` (ids `i+1` to `i`, built through `Scheme(...)`; still expects the scheme error). Intent kept.
- Java: `SplitBitOrderTest.ac1NestedRowReadsStayInsideTheRow` (the `seenInside` assertion is a refusal now: sanctioned by AZ-2233). Every other change is additive.
- Rust: none. TypeScript: none.
- Harness: fixtures gained the `types` and `exports` entries (`npm()` in `publish-phases.test.sh`, `good` in `npm_layout_checks`); the old negatives still fail with the same keywords. No check weakened.

## Evidence

- Differentials against the `HEAD` classes on scratch copies: Python 60,000 random split-form schemes (and 22,000 harder ones with shared and re-read handles, equal to TypeScript byte for byte on 78,000 packs); TypeScript 20,000 random schemes (0 mismatches against an independent oracle, built-both-sides schemes pack and unpack identically on 40,000 rows); Java about 1.57M rows over 280,000 schemes (0 rows that both pack differ; every refusal predicted by a reference binder); Rust about 10M row comparisons over 100,000 map schemes (0 panics; every difference is in a bucket the spec names; the one exact-round-trip regression, F1, is fixed and the harness re-run on the final code: 0 violations in map and typed form).
- Mutation checks per package: each rule of each spec has a test that fails when the rule is undone (Python 7 mutants, TypeScript 8, Java 7, Rust 6 plus the two the review found, harness 9 guard rules and the vcpkg `supports` and version-rule mutants).
- Harness: real vcpkg `--vcpkg` gate passes; the guard accepts the real tarball (26 files) and the real staged port and rejects 24 npm and 14 port mutants; the patch route (`git apply --check` of the staged diff against the `HEAD` blobs) holds and the owner's C# hunks are byte-identical.

## Only CI proves

Node 24 with `--experimental-strip-types` in the ring drivers, JDK 26 compiling `HandoffElements.java`, Python 3.14 in the ring, `npm ci` through a symlinked temp path on Linux (the bug was observed on macOS only), `mawk` as the scan awk on the Ubuntu runner, the vcpkg `x64-linux` dry-run and the second consumer project, `GITHUB_ACTIONS=true` turning a missing tool into a failure, Windows refusal by the port.

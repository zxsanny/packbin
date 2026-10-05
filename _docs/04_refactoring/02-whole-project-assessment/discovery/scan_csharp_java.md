# Discovery scan — C# and Java packages

**Run**: 02-whole-project-assessment (Quick Assessment, phase 1, read-only)
**Scope**: `csharp/` (incl. `csharp/tests/`, `tests/compile-fail/`, `Packbin.csproj`), `java/` (incl. `java/src/test/`, `java/test.sh`). 46 tracked files (`git ls-files csharp java`). Generated `bin/`, `obj/`, `java/out/` (gitignored) excluded.
**Method**: every file read in full; lizard 1.24 (`-C 10 -L 50 -a 6`); grep counts below; behavior confirmed with throw-away probes compiled from **copies** of the sources in the session scratchpad (`csprobe/`, `csprobe2/`, `jprobe/`) — nothing in the repo was built or changed.
**Component write-ups**: `components/01_csharp.md`, `components/06_java.md`.

Constraints honored: ADR-001 (each language walks its own list, no shared walker or generator — `_docs/LESSONS.md` 2026-09-23), the six packages stay peers, the wire bytes must not change (AC-1..AC-9, F-AC-1..10, scheme-field-order AC-6). Architecture Vision principles are not targets.

## (a) Smell table S01–S32

| ID | Smell | Result | Evidence (file:line, counts, top offenders) | Change / deferral |
|----|-------|--------|---------------------------------------------|-------------------|
| S01 | Long Method | found | C# `Walker.WriteScalar` 70 NLOC CCN 19 (`Walker.Scalars.cs:8`), `Walker.PackField` 57 NLOC CCN 17 (`Walker.cs:58`), `SchemeOrder.Walk` 52 NLOC (`Packbin.cs:194`). Java: no function > 50 NLOC (max `SchemeOrder.walk` 43). | Deferred: flat kind dispatch, one case per kind, low cognitive load |
| S02 | Large Class / God file | found | `csharp/tests/LayoutTests.cs` **517 lines** (> 500 soft cap). Near cap: `Walker.java` 497, `VarFields.java` 462, `Walker.cs` 455 (partial class `Walker` = 941 lines over 3 files), `Walker.Counted.cs` 376. | A13 (test split). Walker.java: split only if a fix pushes it over 500 (noted on A3/A7) |
| S03 | Long Parameter List | found | C# `Field` ctor 16 params (`Field.cs:48`), `Be()` re-passes all 16 (`Field.cs:86`). Java `Field` ctor 15 **positional** params (`Field.java:46`) called from 12 factories with runs like `null, null, null, 0, null, -1, 0, null, false`. Java unpack helpers take 6 params (16 signatures). | A16 (Java factories, low) |
| S04 | Primitive Obsession | found | Errors are `object?` / `Object` with no common type (`Packbin.cs:134`, `BinaryPacker.java:19`); callers type-test. Field label is a `string` carrying a member name (C#) or an id (Java). Java `Getter`/`Setter` are `Object → Object`. | Public API; part of A9 decision, otherwise deferred |
| S05 | Data Clumps | found | `(bytes, ref offset, values, repeatLists)` in 12 C# signatures (`Walker.cs`, `Walker.Counted.cs`); `(data, offset, row, seen, asList)` in 16 Java signatures (`Walker.java`, `VarFields.java`). | Deferred: internal, no defect |
| S06 | Duplicated Code | found | 2-byte LE count write ×4 and read ×4 per language (`Walker.Counted.cs:229-230,244,261-262,281,314-320,337,346`; `VarFields.java:257-258,273,293-294,315,344-353,373,382`). Packed width math (`max/shift/per`) twice per language. Kind classification lists: C# `Field.IsValueBearing` + `Walker.IsScalarOrBytes`; Java `Field.isValueBearing` + `Walker.childOn` + `VarFields.isLeaf` — they disagree (see S32). `bits` ≡ `packed(1, …, bias 0)` on the wire. Tests: C# `ParseHex` ×3, `MismatchedBytes` ×3, `FindGoldenFixture` ×2, `PositionRow` ×3, golden hex const ×3; Java `toHex` ×3, `expectEq/expectTrue/fail` ×4 files. | A5 (kind lists), A13 (tests). `bits`/`packed` merge rejected (cross-language API) |
| S07 | Dead Code | found | C# public `Bound<T>` unused (`ObjectValues.cs:7`); `MemberAccess.Get/Set` built, never read (`FieldAccess.cs:9-10,39-52`); `FlagGroup.Name` always `""` (`Walker.cs:8,12`); `if (field.Name.Length > 0)` dead branches (`Walker.cs:283,304`); discard-only bodies `_ = field; _ = values; _ = buffer;` (`Walker.cs:147-149,159-160`); `coverlet.collector` referenced, never run (`tests/Packbin.Tests.csproj:11`). Java: `Bound.field()/needed()/left()` unused (`Packbin.java:190-206`); `FlagGroup.bits()` unused (`Field.java:346`); `@SafeVarargs` on a non-generic varargs ctor (`Scheme.java:13`); `java/.gitkeep`, `java/src/test/.gitkeep` in non-empty dirs. | A10 |
| S08 | Speculative Generality | found (minor) | C# `UnpackResult` is public but only produced/consumed internally (`Packbin.cs:104`); Java `Packbin.Bound` public with a private ctor. | A10 |
| S09 | Lazy Class | note | C# `MemberAccess` only yields `Name`; Java `Walker.isPresent` = `value != null`. | A10 (MemberAccess) |
| S10 | Data Class | note | `Field` holds every kind's data; behavior in `Walker`/`SchemeOrder`. By design of the walker. | n/a |
| S11 | Feature Envy | note | C# `FlagGroup.Compute` (`Walker.cs:21`) is presence logic calling back into `Walker.GroupOn/IsPresent`. | Folded into A1/A5 |
| S12 | Inappropriate Intimacy | found | `Scheme<T>` stores the caller's `params Field[]` without a copy (`Packbin.cs:14`) — mutable after validation (Java copies, `Scheme.java:20`). `SchemeOrder.Resolve` mutates shared `Field.CountName` and `Condition.FieldName` (`Packbin.cs:275,284,289`; `Field.cs:84`; `Packbin.cs:68`). Walker writes `FlagGroup.Unpacked` on the shared scheme (`Walker.cs:285,306`; `Walker.java:246,271`). | A2, A11 |
| S13 | Message Chains | not_found | Only short internal chains (`field.Children[i].Inner!`). | — |
| S14 | Middle Man | found (justified) | C# `Fields<T>`: 31 one-line forwards to `Field.*` (`Fields.cs:8-60`) — needed for `T` inference in `new Scheme<T>(n, f => …)`. Java `Packbin.*` forwards to `Field.*`. | Keep |
| S15 | Divergent Change | found | `Walker.cs` changed in 9 of 17 C# commits, `Walker.java` in 9 of 17 Java commits — every new wire kind lands there. | Deferred (inherent to one walker per language) |
| S16 | Shotgun Surgery | found | One new kind edits, per language: `Kind` enum, factory, `Fields<T>` mirror (C#), `PackField`, `UnpackField`, `SchemeOrder.Walk`, `ResolveField`, `IsValueBearing`, `IsScalarOrBytes`/`childOn`/`isLeaf` (≈8 C# sites, ≈7 Java) — then ×6 languages by ADR-001. | Accepted by ADR-001; A5 removes one of the lists |
| S17 | Switch / type soup | found | Switches on `Kind`: C# 6 (`PackField`, `UnpackField`, `WriteScalar`, `ReadScalar`, `Walk`, `ResolveField`); Java 9 (`packField`, `unpackField`, `childOn`, `writeScalar`, `readScalar`, `walk`, `resolveField`, `isValueBearing`, `isLeaf`). | Table-drive rejected (see Rejected) |
| S18 | Temporary Field | found | `Field` has 16 (C#) / 15 (Java) members, most meaningful for one kind (`Pred` only for When, `Bias` only for Packed/Times, `SlotIds/Names` only for U2). `FlagGroup.Unpacked` is a per-call temporary stored on a shared object. | A2 (Unpacked); rest deferred |
| S19 | Parallel Inheritance | n/a | No hierarchies. (Parallel kinds `bits` / `packed(1)` noted under S06.) | — |
| S20 | Magic number / string | found | `65535` ×4 per language; `(count + 7) / 8`, `(n + 3) / 4`, `>> 8`/`<< 8` count codec; `"times"` as a field name (`Field.cs:148`, `Field.java:81`); ChaCha20 sigma inline in C# (`SessionPad.cs:33-36`, named `CONSTANTS` in Java); sentinel errors `ShortPacket("", 1, 0)` ×3 C# / ×9 Java `ShortPacket("", …)`; `ShortPacket(name, 0, 0)` for duplicate key (`Walker.Counted.cs:358`, `VarFields.java:391`); `TypeMismatch(0, …)` C# vs `(-1, …)` Java. | A9 (sentinels); count literal naming folded into A3 |
| S21 | Hardcoded configuration | found (INV) | 21 rows below: 0 business, 1 system (`java/test.sh` JDK path list), 20 code-ok protocol/manifest constants. | A15 |
| S22 | String SQL | not_found (INV) | 0 hits — inventory below. | — |
| S23 | Stringly-typed APIs | found | C# runtime values are a flat `Dictionary<string, object?>` keyed by member name (`ObjectValues.cs:22-50`) — the cause of the name-clash bug (L6); Java map rows `Access.get("key")`; error `field` mixes names, ids and `""`. | A6, A9 |
| S24 | Mutable global SoT | found | No static mutable globals, but per-call state on shared, `static readonly` scheme objects (`FlagGroup.Unpacked`), and construction-time mutation of shared `Field`/`Condition`. | A2, A11 |
| S25 | Silent failure swallow | found (behavioral) | No empty `catch` in production (2 catches, both rethrow typed: `BinaryPacker.java:84`, `SessionPad.java:39`). Silent **data** drops instead: C# `PackScalar`/`PackBytes` write nothing for an absent value outside a flag bit (`Walker.cs:248,264`); 9th flag bit lost (`Walker.cs:31`, no cap in `FlagGroup.AddBit`); Java forward `when` drops the group. Tests: empty `catch (IllegalArgumentException)` that names the expected exception (`LayoutTests.cs:206`, `FieldIdBindingTest.java:166`, `SchemeTest.java` `expectThrows`) — allowed by the coding rule. | A5, A4 |
| S26 | Circular dependency | note | Within one package: C# `FlagGroup` ↔ `Walker`; Java `Walker` ↔ `VarFields`, `FlagGroup` ↔ `Walker.childOn`. No cross-package import (module-layout rule holds). | No change |
| S27 | Framework leak | n/a | No framework. | — |
| S28 | Secret in source | not_found | Only `javax.crypto.spec.SecretKeySpec` class names; test seeds are synthetic `1..32`. | — |
| S29 | High cognitive / cyclomatic complexity | found | CCN > 10: C# 4 (max 19 `WriteScalar`), Java 7 (max 19 `packField`). Cognitive hot spots: C# `ObjectValues.Apply`/`ContainsAny` recursion, `Walker.GroupOn`. | Via A6 only |
| S30 | Shotgun resources | n/a | No upload dirs, caches or limits beyond the 65535 wire cap (S20). | — |
| S31 | Embedded HTML | not_found (INV) | 0 hits — inventory below. | — |
| S32 | Hidden domain rule | found | (1) Flag presence of `bool`: C# = non-null (`false` sets the bit, `Walker.cs:29`), Java = `TRUE.equals` (`Walker.java:22`). (2) A flag group with no children stores `true` on unpack (`Walker.cs:328`, `Walker.java:304`). (3) A flag group's bit ignores Sized/Bits/Packed/U2 children in C# (`Walker.cs:54-56`) and U2 in Java (`Walker.java:31`). (4) Error label = member name (C#) / order id (Java) / `""`. (5) Duplicate dict key reported as `ShortPacket(…, 0, 0)`. (6) Session-not-open reported as `ShortPacket("", 1, 0)`. (7) `u2Slot` is a `U8` of size 0 (`Packbin.java:107`). (8) Repeat count = longest child list; a non-list value counts as 1 (`Walker.cs:208`, `Walker.java:173`). (9) C# list/dict elements see a copy of the whole parent map (`Walker.Counted.cs:266,322`). | A1, A5, A9 |

## (b) INV inventories

### S21 — config in code

Scan: full read of all 46 files, plus `grep -nE "const |static final|static readonly"` and a literal sweep (`65535`, `0x`, numeric literals in predicates) over `csharp/*.cs java/src/main/java/packbin/*.java java/test.sh csharp/**/*.csproj`.

| # | File | Line | Symbol / preview | Classification | Notes | Change / deferral |
|---|------|------|------------------|----------------|-------|-------------------|
| 1 | csharp/PackSession.cs | 7-8 | `SeedSize = 32`, `NonceSize = 16` | code-ok | pack-session contract sizes | — |
| 2 | csharp/PackSession.cs | 67 | HKDF info `"packbin"u8` | code-ok | contract constant | — |
| 3 | csharp/SessionPad.cs | 10, 17, 33-36, 46 | 12-byte nonce, 64-byte block, sigma words, 10 double rounds | code-ok | RFC 8439 algorithm constants | — |
| 4 | csharp/Walker.Counted.cs | 227, 259, 301, 309 | `65535` | code-ok | 2-byte count limit (strings-lists-dicts restriction); unnamed ×4 (S20) | A3 (name it while touching the count codec) |
| 5 | csharp/Packbin.cs | 10 | type number `0..255` | code-ok | one wire byte | — |
| 6 | csharp/Field.cs | 140-143 | packed width `1|2`, bias `0|-1` | code-ok | schema rule | — |
| 7 | csharp/Packbin.csproj | 4-14 | `net10.0`, `Version 0.1.0`, `Authors`, `RepositoryUrl`, `MIT` | code-ok | package manifest; publish overrides `Version` (`publish-inside.sh:16`) | — |
| 8 | csharp/tests/Packbin.Tests.csproj | 11-14 | test package versions | code-ok | manifest | `coverlet` unused → A10 |
| 9 | csharp/tests/PackbinTests.cs | 155-165 | `100_000` iterations, `1.0` s | code-ok | AC-10 numbers in the test | path measured → A8 |
| 10 | csharp/tests/PackbinTests.cs | 204 | GPU library deny-list | code-ok | test fixture | — |
| 11 | csharp/tests/*.cs | PackbinTests:37, SchemeTests:70, SessionTests:37 | golden hex `4001000065cd1d00a3e1110100` | code-ok (test) | tests.md says read the fixture, do not copy the hex | A13 |
| 12 | java/src/main/java/packbin/PackSession.java | 7-8 | `SEED_SIZE`, `NONCE_SIZE` | code-ok | contract | — |
| 13 | java/src/main/java/packbin/SessionPad.java | 10-13 | `INFO`, `CONSTANTS` | code-ok | contract / RFC 8439 | — |
| 14 | java/src/main/java/packbin/VarFields.java | 254, 290, 332, 349 | `65535` | code-ok | as row 4 | A3 |
| 15 | java/src/main/java/packbin/Scheme.java | 15 | `0..255` | code-ok | one wire byte | — |
| 16 | java/src/main/java/packbin/Packbin.java | 116-121 | packed width / bias | code-ok | schema rule | — |
| 17 | java/src/main/java/packbin/Field.java | 329 | flag group `>= 8` bits | code-ok | one flags byte | C# lacks it → A5 |
| 18 | java/test.sh | 16-20 | JDK candidates `jdk-21`, `jdk-11`, `openjdk@21/17/11` | **system** | machine-specific fallback paths; JDK 11/17 cannot compile the sources (pattern `instanceof` needs 16+); `JAVA_HOME` is already honored first | A15 |
| 19 | java/src/test/java/packbin/PackbinTest.java | 27, 221, 236, 249 | golden hex, `100_000`, `1.0`, GPU list | code-ok (test) | as rows 9-11 | A13 |
| 20 | java/src/test/java/packbin/SchemeTest.java | 67 | golden hex copy | code-ok (test) | as row 11 | A13 |
| 21 | (outside scope, noted) `.github/workflows/publish-inside.sh` | 69-99 | Maven `groupId io.github.zxsanny`, POM metadata | system / build | lives in a CI script, not in `java/`; the Java package has no build manifest of its own | cross-ref to the CI scan |

Business catalogs: 0. Uncertain: 0.

### S22 — string SQL

**0 hits.** Command: `xargs grep -niE "\b(select|insert|update|delete)\b.+\b(from|into|set|where)\b|SqlCommand|ExecuteSql|FromSqlRaw|executeQuery|prepareStatement|jdbc|java\.sql" < files.txt` over the 46 tracked files from `git ls-files csharp java`. The library has no database (architecture §2).

| file | line | API | sql_preview | change |
|------|------|-----|-------------|--------|
| — | — | — | 0 hits | — |

### S31 — embedded HTML

**0 hits.** Command: `xargs grep -niE "<!doctype|<html|<body|<div|text/html" < files.txt` over the same 46 files. No HTTP surface in either package.

| file | line | kind | served_as | change |
|------|------|------|-----------|--------|
| — | — | — | 0 hits | — |

## (c) Logical flow findings

Probe IDs (P#) refer to the caveat tables in `components/01_csharp.md` (C#) and `components/06_java.md` (Java).

| # | Lang | Class | Finding | Evidence |
|---|------|-------|---------|----------|
| L1 | C# | logic bug (cross-language byte drift, AC-3) | A non-nullable `bool false` in `Flags` sets its bit and unpacks as `true`. Java (and the README's Python example) clear the bit. Same row → different bytes. | `Walker.cs:29` uses `IsPresent`; probe C# P1 `0101` vs Java `0100` |
| L2 | C#, Java | logic bug | `Bool` outside a flags byte is accepted: C# writes 0 bytes and always unpacks `true`; Java writes 0 bytes and stores nothing. README defines `bool` as "a flag bit with no payload". | `Walker.cs:145-163`, `Walker.java:85,129`; C# P2, Java P9 |
| L3 | C# | logic bug (silent data loss) | A 9th field in one `Flags` is accepted and silently dropped (`(byte)(1 << 8) == 0`). Java rejects > 8. | `Walker.cs:14-19,31`; C# P3 |
| L4 | C# | logic bug (silent data loss, cross-language drift) | An absent value bound to a non-flag scalar/bytes field writes nothing; the peer then misreads every later field. Java throws `missing field`. | `Walker.cs:248,264`; C# P4 |
| L5 | C# | logic bug (silent data loss) | `Scheme<Row>` accepts `Field.X<OtherRow>`; binding is by member-name string, so an unknown name packs nothing. | `Packbin.cs:8`, `Field.cs:96`; C# P5; test `FieldIdBindingTests.cs:132` already mixes `MarkerRow` into a `PointsRow` scheme |
| L6 | C# | logic bug (silent corruption) | `ObjectValues` flattens nested rows into one name map, so an outer and a nested member with the same name overwrite each other. `SchemeOrder` cannot see it (nested ids restart at 0). | `ObjectValues.cs:37-50`; C# P6 `010202` |
| L7 | C# | logic bug + documentation drift | Typed list/dict elements that are row objects do not work: pack throws (`expected string`), unpack throws `InvalidCastException`, a list of nested groups writes the count and no element bytes. The README's C# headline example (`README.md:157-200`) fails both ways. Tests and the C# language-pair driver only use dictionaries. | `Walker.Counted.cs:266`, `ObjectValues.cs:99-119`; C# P7 |
| L8 | C#, Java | logic bug (thread safety; violates architecture NFR "one call does not share state") | Unpack stores the flags byte in `FlagGroup.Unpacked` on the shared scheme. C#: both `Flags` and `FlagByte` forms; Java: split `flagByte()` form. Concurrent unpack yields wrong rows. Tests only check concurrent **pack**. | C# P8 2 860 / 400 000; Java P1 11 593 / 400 000 |
| L9 | C#, Java | logic bug (unpack of hostile bytes throws instead of returning an error) | A count read from the packet that is negative or > `int.MaxValue` throws (`OverflowException`, `ArgumentOutOfRangeException`, `NegativeArraySizeException`, `IllegalArgumentException`). Unpack's contract is error-as-value (AC-8/9). | `Walker.Counted.cs:71,111,126`; `VarFields.java:46,128,149`; C# P9, Java P7 |
| L10 | C#, Java | logic bug (hang) | `repeat` whose children can consume 0 bytes (a `bool`, a false `when`) loops forever when bytes remain. | `Walker.cs:362`, `Walker.java:336`; C# P10, Java P8 |
| L11 | C#, Java | logic bug + contract drift | Construction accepts `when`/count ids that are walked **later** (resolve runs over the full scope). C#: pack writes the group, unpack cannot read its own bytes. Java: `when` silently drops the group; a forward count throws at pack. README: "The tested field must already have been read"; scheme-field-order AC-4 states this for Rust. | `Packbin.cs:191`, `SchemeOrder.java:16`; C# P11, Java P5/P6 |
| L12 | Java | logic bug | Typed nested-row `group(getter, setter, …)` unpack creates a `HashMap` child and passes it to the typed setter → `ClassCastException` unless the POJO pre-initializes the member. Tests use `Map` rows only. | `Walker.java:313-319`; Java P2 |
| L13 | Java | logic bug | Nested rows reuse the parent's id-keyed `seen` map although their ids restart at 0, so a later parent `when`/count can read a nested child. | `Walker.java:170,297`; Java P3 |
| L14 | Java | logic bug | `repeat` containing `flags`/`when`/`group` NPEs on pack (`child.get` is null for non-leaf children). | `Walker.java:176`; Java P4 |
| L15 | C# | logic bug (minor) | `When` on a float field holding NaN/∞ throws `OverflowException` (`Convert.ToDecimal`). Java compares with `Double.compare`. | `Walker.cs:448`; C# P12 |
| L16 | C# | design contradiction | Scheme keeps the caller's array (mutable after validation) and construction mutates shared `Field.CountName` / `Condition.FieldName`; a `Field`/`Condition` reused in a second scheme is re-bound for the first. | `Packbin.cs:14,275,284,289` (code read; not probed) |
| L17 | C# | performance waste + test honesty (AC-10 risk) | The AC-10 test times the dictionary + internal `Read` path (81 ms Release / 195 ms Debug per 100 000). The public typed path (`Pack(scheme, row)` + `Unpack(handler)`) takes 719 ms Release / 933 ms Debug on an M-series Mac — the CI suite runs Debug (`dotnet test`) on slower runners. `ObjectValues.Members` re-reflects every call. Real-results rule: the test does not measure what callers run. | `PackbinTests.cs:151-166`, `ObjectValues.cs:121-145`; probe timings |
| L18 | C#, Java | design contradiction / documentation drift | Error label differs: C# member name (`"Lon"`), Java order id (`"8"`), TS name (`"lon"`), Python id (`"0"`), C++ order id; `""` for flags byte, list/dict count (Java), empty buffer, session not open. Duplicate key → `ShortPacket(…, 0, 0)`; no handler → `TypeMismatch(expected 0)` in C#, `(-1)` in Java. `languages.md`: "Field names inside the list stay the same strings, so a short-packet error names the same field." AC-8 requires the error to name the field. | `Walker.cs:281,302`, `Walker.java:243,269`, `VarFields.java:313,371-391`, `Packbin.cs:144,154`, `BinaryPacker.java:36`, `PackSession.cs:54`, `PackSession.java:59` |
| L19 | Java | design contradiction (packaging) | The jar is compiled by the CI JDK 26 without `--release`; code uses `Arrays.compareUnsigned(byte[],byte[])` (Android API 33) and `List.copyOf` (API 30). Android is the named consumer and nothing checks it. | `publish-inside.sh:67`, `VarFields.java:342`, `Field.java:68` |
| L20 | C#, Java | documentation drift | `schema.md` C# snippets use the removed API (`Packet.Of`, `Field.U8("type")`, `Field.FlagByte("motion")`, `Eq("profile", …)`, dictionary packing) — `SchemeTests.Ac1` asserts `Packbin.Packet` no longer exists; `flags(anchor, name, fields)` has no name in C#/Java. | `_docs/01_solution/schema.md` |
| L21 | C#, Java | documentation drift | Component docs: interface `BinaryPacker.Unpack(scheme, bytes) → row or error` (actual: `Unpack(bytes, handlers…)` → error or `null`, row via handler); Input DTO "name to integer…" (map rows); Java "Potential race conditions: None" (L8); `module-layout.md` lists one public API file per package, but C# public types span `Packbin.cs`, `Field.cs`, `Fields.cs`, `ObjectValues.cs`, `PackSession.cs`, and Java spans 9 files. | `components/01_csharp_package/description.md`, `06_java_package/description.md`, `module-layout.md` |
| L22 | C#, Java | test gap | Public split form `FlagByte()`/`.Bit()` has 0 tests in either package. Compile-fail checks pass on **any** build failure (exit code ≠ 0), not on the missing-overload error. Java runner aborts all later tests on one uncaught exception. | `grep FlagByte\|\.Bit( csharp/tests java/src/test` = 0; `SchemeTests.cs:204`, `SchemeTest.java:215` |
| L23 | C# | contract check — OK | PackSession matches the contract: HKDF(seed, salt = nonce, info `packbin`, 64 B), opener/waiter halves, LE counter nonce, block 0, same-length XOR, seed zeroed, bad lengths open 0 sessions. Same in Java. Dict order (unsigned UTF-8 bytes) and the 65535 caps match `strings-lists-dicts/restrictions.md` in both. | `PackSession.cs`, `SessionPad.cs`, `PackSession.java`, `SessionPad.java` |

Totals: **logic bugs 15** (L1–L15; 7 C#-only, 4 Java-only, 4 in both), performance waste 1 (L17), design contradictions 3 (L16, L18, L19), documentation drift 3 (L20, L21, plus the README parts of L7/L11), test gaps 1 (L22).

## (d) Candidate changes

Complexity points: 1 / 2 / 3 / 5. Each keeps the golden bytes (AC-1..AC-9, F-AC-1..10, field-order AC-6) unless it says otherwise; each fix needs a failing test first.

### A1: One bool rule — bit set only for `true`, bool only inside a flags byte
- **File(s)**: csharp/Walker.cs, csharp/Field.cs, csharp/Packbin.cs (SchemeOrder), java/src/main/java/packbin/SchemeOrder.java, java/src/main/java/packbin/Walker.java
- **Problem**: C# sets the bit for `false` (L1) — the same row packs differently in C# and Java. Both accept `bool` outside a flags byte and then write nothing and read back a constant (L2).
- **Change**: C# computes a bool bit from the value being `true`, like Java. Construction rejects a `bool` that is not a direct flag bit, in both packages.
- **Rationale**: AC-3 (identical bytes), AC-5 (absence vs value), README "a flag bit with no payload".
- **Constraint Fit**: no golden fixture holds a `false` bool; the route fixture sets the bit for `true` and stays `3410…`. Rejecting top-level bool removes only a form that never round-tripped.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 2

### A2: Keep unpack state per call, not on the scheme
- **File(s)**: csharp/Walker.cs, java/src/main/java/packbin/Walker.java, java/src/main/java/packbin/Field.java (FlagGroup)
- **Problem**: The flags byte read during unpack is stored on the shared, usually `static readonly`, scheme (`FlagGroup.Unpacked`); concurrent unpacks corrupt rows (L8: 2 860 and 11 593 wrong rows per 400 000).
- **Change**: The flags byte read in one unpack call lives in that call's state (the values map / `seen` map keyed by the flag group); `FlagGroup` keeps only the bit list.
- **Rationale**: Architecture NFR "one call does not share state with another"; silent wrong rows.
- **Constraint Fit**: no byte change; no API change.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 2

### A3: Unpack of hostile counts returns an error, never throws or hangs
- **File(s)**: csharp/Walker.cs, csharp/Walker.Counted.cs, java/src/main/java/packbin/Walker.java, java/src/main/java/packbin/VarFields.java
- **Problem**: Negative or > `int.MaxValue` counts throw five different exception types out of `Unpack` (L9); a `repeat` iteration that consumes 0 bytes loops forever (L10).
- **Change**: A count outside `0..bytes left` becomes the existing `ShortPacket(field, needed, left)` (negative counts: the error type chosen in A9's decision); a repeat iteration that consumes 0 bytes ends the repeat and the leftover bytes become `TrailingBytes`, or construction rejects a repeat whose children can all be zero-width (pick one; the second is simpler). Name the `65535` limit once per package while touching the count codec.
- **Rationale**: AC-8/AC-9 error-as-value; a library parsing network input must not be DoS-able by one byte.
- **Constraint Fit**: valid packets unchanged. Watch `Walker.java` (497 lines): if the fix pushes it over 500, move the scalar codec out by responsibility.
- **Risk**: low
- **Dependencies**: A9 only for the negative-count error label
- **Complexity**: 3

### A4: Reject forward references at construction
- **File(s)**: csharp/Packbin.cs (SchemeOrder), java/src/main/java/packbin/SchemeOrder.java, plus tests
- **Problem**: `when` and borrowed counts may name a later id (L11); C# then cannot read its own bytes, Java silently drops the group or throws at pack.
- **Change**: Resolve each condition/count id against the ids walked so far; a later id fails construction.
- **Rationale**: README "The tested field must already have been read"; parity with Rust's scheme-field-order AC-4; removes a silent drop.
- **Constraint Fit**: all fixtures reference earlier ids (route: count 5 before `times 7`, `when` tests 3); bytes unchanged.
- **Risk**: low
- **Dependencies**: None (A11 touches the same C# resolver — do together)
- **Complexity**: 2

### A5: C# fails loudly instead of dropping values (absent required field, 9th flag bit, foreign row type, group presence rule)
- **File(s)**: csharp/Walker.cs, csharp/Field.cs, csharp/Packbin.cs
- **Problem**: An absent value outside a flag bit packs nothing (L4); a 9th flag bit is dropped (L3); a field declared on another row type packs nothing (L5); a flag group's bit ignores Sized/Bits/Packed/U2 children (S32-3, Java ignores U2) because the kind lists disagree (S06).
- **Change**: Pack throws for an absent value that is not under a flag bit, `when`, or repeat/times slot (Java already does); `FlagGroup` caps at 8 bits at construction; `Scheme<T>` rejects fields bound to a different row type (each `Field` records its declaring type); one kind classification per package decides group presence.
- **Rationale**: silent data loss; cross-language drift with Java; coding rule "never suppress errors silently".
- **Constraint Fit**: valid schemes and fixtures unchanged. A caller that relied on silently omitting a nullable non-flag field now gets an exception — that packet was already unreadable by the peer.
- **Risk**: medium (behavior change for misuse)
- **Dependencies**: None
- **Complexity**: 3

### A6: C# binds nested rows, list and dict elements per scope instead of one flat name map
- **File(s)**: csharp/ObjectValues.cs, csharp/Walker.cs, csharp/Walker.Counted.cs, csharp/Packbin.cs, csharp/Field.cs, README.md (C# example)
- **Problem**: `ObjectValues` flattens every nested member into one dictionary keyed by member name: names clash (L6), row-object list/dict elements fail both ways and the README C# example throws (L7), and every call re-reflects the type (L17).
- **Change**: Pack and unpack walk the typed row with the accessor each field already captured (as Java's `Getter`/`Setter` path does): a nested group reads/writes its member object, a list/dict element is bound to the element row type. The dictionary overload stays for tests and drivers. Accessors are compiled once per field, not reflected per call.
- **Rationale**: correctness of the documented C# API; removes the hidden flat-namespace rule; addresses the AC-10 headroom of L17.
- **Constraint Fit**: wire bytes unchanged (language-pair and golden tests are the guard); still one walker per language (ADR-001). Public API unchanged except that documented typed lists/dicts start working.
- **Risk**: high (core binding path)
- **Dependencies**: A5 (absence rules), A8 (measures the result)
- **Complexity**: 5

### A7: Java typed nested rows — create the right child type, scope ids, repeat over non-leaf children
- **File(s)**: java/src/main/java/packbin/Walker.java, java/src/main/java/packbin/Packbin.java, java/src/main/java/packbin/Field.java, java/src/main/java/packbin/VarFields.java
- **Problem**: Typed nested-row unpack throws `ClassCastException` (L12); nested rows share the parent's `seen` ids (L13); `repeat` with a `flags`/`when`/`group` child NPEs on pack (L14); typed list/dict row elements become `HashMap`s (06_java P10).
- **Change**: A nested `group` (and row-typed list/dict elements) carries a way to create its row (e.g. a `Supplier`, or the row `Class`), and unpack uses it; nested rows get their own `seen` scope; repeat counts list lengths from leaf children only.
- **Rationale**: correctness of the typed API Android callers use.
- **Constraint Fit**: bytes unchanged; adding a factory parameter to `group(getter, setter, …)` is a public API change — needs the user's OK (Java has not reached a 1.0 API promise; check whether 0.1.0 is on Maven Central).
- **Risk**: medium
- **Dependencies**: None
- **Complexity**: 3

### A8: AC-10 test measures the public typed path (C#)
- **File(s)**: csharp/tests/PackbinTests.cs
- **Problem**: `Nfr_RoundTripsWithinOneSecond` times `Pack(scheme, dictionary)` + internal `Read`, ~9× faster than what callers run (L17); the public path is at 72–93% of the bound on a fast Mac.
- **Change**: Time `BinaryPacker.Pack(scheme, row)` + `BinaryPacker.Unpack(bytes, scheme.On(...))`. If it fails the bound in CI, A6's accessor caching is the fix — not a looser test.
- **Rationale**: real-results rule; AC-10.
- **Constraint Fit**: AC-10 unchanged.
- **Risk**: low (may turn the suite red — that is the point)
- **Dependencies**: None (A6 if it fails)
- **Complexity**: 1

### A9: One error-label rule and real error types for non-short failures (needs a user decision)
- **File(s)**: csharp/Packbin.cs, csharp/Walker.cs, csharp/Walker.Counted.cs, csharp/PackSession.cs, java/src/main/java/packbin/{Packbin,BinaryPacker,Walker,VarFields,PackSession}.java, `_docs/01_solution/languages.md`
- **Problem**: `ShortPacket.field` is a member name in C#, an order id in Java/Python/C++, a name in TS, and `""` for flags bytes, list/dict counts, the empty buffer and a closed session (L18). A duplicate dict key and a closed session are reported as fake short packets; `TypeMismatch.expected` is 0 vs −1.
- **Change**: After the user picks the canonical label (order id — what C++ and Python already return — or field name), C# and Java emit it for every short packet, including flags bytes and counts; duplicate key and closed session get their own error values; `TypeMismatch.expected` gets one convention. Update `languages.md`.
- **Rationale**: AC-8 ("names the field"); `languages.md` promise; hidden conventions (S32).
- **Constraint Fit**: no byte change; error shape is public API in six packages → cross-language decision first (the other scans own TS/Python/Rust/C++).
- **Risk**: medium (public error values)
- **Dependencies**: user decision
- **Complexity**: 3

### A10: Remove dead code and unused surface
- **File(s)**: csharp/ObjectValues.cs (`Bound<T>`), csharp/FieldAccess.cs (`Get`/`Set`), csharp/Walker.cs (`FlagGroup.Name`, dead `Name.Length > 0` branches, discard-only bodies), csharp/Packbin.cs (`UnpackResult` → internal), csharp/tests/Packbin.Tests.csproj (`coverlet.collector`, or wire coverage — the CI scan owns that), java/src/main/java/packbin/Packbin.java (`Bound` accessors / visibility), java/src/main/java/packbin/Field.java (`FlagGroup.bits()`), java/src/main/java/packbin/Scheme.java (`@SafeVarargs`), java/.gitkeep, java/src/test/.gitkeep
- **Problem**: S07/S08 evidence: unused public types and members widen the API and mislead readers.
- **Change**: Delete or make internal; keep `coverlet` only if coverage is wired.
- **Rationale**: no-dead-code rule.
- **Constraint Fit**: removing public `Bound<T>` / `UnpackResult` from the NuGet surface is breaking if 0.1.0 was published — verify on nuget.org first; otherwise no behavior change.
- **Risk**: low
- **Dependencies**: A6 (touches `ObjectValues.cs`/`FieldAccess.cs` — do after, or `MemberAccess` becomes the accessor A6 needs)
- **Complexity**: 1

### A11: C# scheme owns its field list and its resolved names
- **File(s)**: csharp/Packbin.cs, csharp/Field.cs
- **Problem**: `Scheme<T>` keeps the caller's array; resolution mutates shared `Field.CountName` and `Condition.FieldName` (L16).
- **Change**: Copy the field list; keep resolved count/condition bindings in the scheme (or bind by id at run time as Java does) instead of mutating shared objects.
- **Rationale**: a reused `Field`/`Condition` silently re-binds another scheme; same theme as A2.
- **Constraint Fit**: no byte or API change.
- **Risk**: low
- **Dependencies**: A4 (same resolver)
- **Complexity**: 2

### A12: Documentation drift for C# and Java
- **File(s)**: _docs/01_solution/schema.md, _docs/01_solution/languages.md, _docs/02_document/components/01_csharp_package/description.md, _docs/02_document/components/06_java_package/description.md, _docs/02_document/module-layout.md, README.md (C# example after A6; "tested field must already have been read" after A4)
- **Problem**: L20, L21, README parts of L7/L11.
- **Change**: Rewrite the C# snippets in `schema.md` to the `Scheme<T>` API and drop the flags name argument; fix the interface tables (`Unpack(bytes, handlers…)`, typed rows, error set), Java race note, public-file lists; align `languages.md` with A9.
- **Rationale**: docs are the contract the six languages follow.
- **Constraint Fit**: docs only.
- **Risk**: low
- **Dependencies**: A4, A6, A9
- **Complexity**: 2

### A13: Test hygiene — split LayoutTests, share helpers, cover the split flag form, read the fixture
- **File(s)**: csharp/tests/LayoutTests.cs, csharp/tests/PackbinTests.cs, csharp/tests/SchemeTests.cs, csharp/tests/SessionTests.cs, java/src/test/java/packbin/*.java
- **Problem**: `LayoutTests.cs` is 517 lines (> 500 cap); hex/fixture/assert helpers are copied 2–4× per package; golden hex copied into 3 C# and 2 Java files against tests.md; the public `FlagByte()/.Bit()` form has 0 tests (L22); compile-fail checks accept any build failure.
- **Change**: Split `LayoutTests` by responsibility (flags/groups vs counted fields); one helper class per package; tests read `fixtures/golden.hex`; add split-form tests (including the concurrent unpack from A2); make compile-fail assert the expected diagnostic (C# `CS1501`/`CS7036`, javac "no suitable method").
- **Rationale**: quality thresholds (file length), real-results rule for compile-fail, AC traceability.
- **Constraint Fit**: tests only.
- **Risk**: low
- **Dependencies**: None (A2 adds the race test)
- **Complexity**: 2

### A14: Decide and enforce the Java bytecode / Android API level (needs a user decision)
- **File(s)**: java/src/main/java/packbin/VarFields.java, java/src/main/java/packbin/Field.java, `.github/workflows/publish-inside.sh` (CI scan owns the edit), `_docs/02_document/components/06_java_package/description.md`
- **Problem**: L19 — the published jar's class-file level is whatever JDK CI runs (26), and the code uses Android API 30/33 methods; no check covers Android, the named consumer.
- **Change**: User picks the minimum (e.g. `--release 17` + an Android minSdk); compile with `--release N`; replace `Arrays.compareUnsigned` / `List.copyOf` if below their API level; document it.
- **Rationale**: the package exists for Android (`languages.md`).
- **Constraint Fit**: no byte change; restrictions say "current stable toolchain" — a `--release` floor is compatible with building on it.
- **Risk**: medium (unknown until checked)
- **Dependencies**: user decision
- **Complexity**: 2

### A15: `java/test.sh` — drop dead JDK fallbacks; isolate test failures
- **File(s)**: java/test.sh, java/src/test/java/packbin/PackbinTest.java (runner)
- **Problem**: S21 row 18 — fallback list includes JDK 11/17, which cannot compile the sources; one uncaught exception ends the run and hides later failures (L22).
- **Change**: Keep `JAVA_HOME` / `java_home` / a 21+ candidate; each test method's unexpected exception counts as one failure and the run continues.
- **Rationale**: diagnosable failures without a re-run (coding rule on test output).
- **Constraint Fit**: CI image unchanged.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 1

### A16: Java `Field` factories without 15 positional arguments (optional)
- **File(s)**: java/src/main/java/packbin/Field.java
- **Problem**: 12 call sites pass `null, null, null, 0, null, -1, 0, null, false`-style runs; swapping `countId`/`bias` compiles (S03/S06).
- **Change**: One private factory with defaults per concern (kind + id + accessors, then count/bias/children), as C# does with named optional arguments.
- **Rationale**: maintainability of the file every kind change touches.
- **Constraint Fit**: internal only.
- **Risk**: low
- **Dependencies**: after A7 (same file)
- **Complexity**: 2

### A17: C# float condition equality without decimal conversion
- **File(s)**: csharp/Walker.cs
- **Problem**: L15 — `Convert.ToDecimal` throws for NaN/∞/large floats.
- **Change**: Compare as `double` when either side is a float (as Java does), integers as `decimal`/`long`.
- **Rationale**: pack/unpack must not throw on a valid value.
- **Constraint Fit**: no byte change.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 1

### Priority order

A2, A1, A4, A3, A5 (bugs, small) → A8 (measure) → A6 / A7 (binding rewrites) → A9 + A14 (user decisions) → A11, A17, A10, A13, A15, A12, A16.

## Rejected ideas

| Idea | Reason |
|------|--------|
| Shared walker, shared checker, or a generator across C#/Java (or all six) | Violates ADR-001, scheme-field-order restrictions ("No shared checker"), `_docs/LESSONS.md` 2026-09-23 |
| Table-driven kind dispatch to remove the `switch` statements (S17) | The switches are the walker; CCN 17–19 is flat one-case-per-kind dispatch. More indirection, no defect fixed |
| Replace hand-written ChaCha20/HKDF with platform crypto | .NET has no raw ChaCha20 stream (`ChaCha20Poly1305` adds a tag → payload length changes, contract break); Java `javax.crypto.KDF` is JDK 24+ and absent on Android; Android `ChaCha20` cipher availability unverified |
| JUnit + Maven/Gradle for the Java tests | New tooling surface with downloads; the zero-dependency `javac` runner works; A15 fixes the real gap |
| Merge `bits` into `packed(1, …, bias 0)` (same wire) | Public helper in six languages; needs a cross-language API decision, no defect |
| Make `Fields<T>` the only C# builder (remove public `Field.X<T>`) | Breaking public API; A5's declaring-type check fixes the defect without removing anything |
| Cursor/context object for the `(bytes, offset, values, repeatLists)` clump (S05) | Internal signature churn only; no rule or AC violated |
| Split `Walker.java` now | 497 lines is under the cap; split only if A3/A7 push it over |
| Reflection caching in Java `newRow` | Java's AC-10 test already measures the public path and passes; no evidence of need |

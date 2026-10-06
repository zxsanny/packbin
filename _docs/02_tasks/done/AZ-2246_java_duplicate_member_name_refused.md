# Java refuses a member name used twice when the scheme is built

**Task**: AZ-2246_java_duplicate_member_name_refused
**Name**: Java duplicate member names refused at construction
**Description**: `new Scheme<>(...)` throws `IllegalArgumentException`, naming the member, when two fields write the same `Access.set(key)` key in one scope (the top level, one nested row, or one `list` or `dict` element; once outside and once inside a `repeat` or `times` round of that scope included), unless one of the two sits under a `when`. Java fields carry no names, so a name is known only for the setters made by `Access.set(String)`; typed accessors and hand-written lambdas are not checked.
**Complexity**: 2 points
**Dependencies**: AZ-2188_typescript_duplicate_member_names (the rule, done in TypeScript); AZ-2233_java_nested_row_orphan_bit_refused and AZ-2101_java_typed_nested_rows (a nested row is a scope of its own for flag bytes and ids)
**Component**: java
**Tracker**: AZ-2246
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment round 2 (`_docs/loops/loop16/assessment16.md`, row X3), option A: TypeScript refuses a member name declared twice in one scope (AZ-2188); Java builds the same schemes and loses a value. Observed on `35544ed` (a `git archive` export, JDK 21 compiling with `--release 17`, `Scheme<Map>` rows). In this table `u8(id, key)` is `Packbin.u8(id, Access.get(key), Access.set(key))`; `u16`, `boolField`, `sized(id, key, countId)` and `slot(id, key)` (`Packbin.u2Slot`) are the same shape; `list(xs, element)` and `dict(m, element)` use `Access.get`/`Access.set` of that key; `group(g, fields...)` is the nested row `Packbin.group(Access.get("g"), Access.set("g"), fields...)` and `group(0, ...)` an anchored group. Ids are Java's (an anchor and the first field it holds share one id):

| Scheme | Today | What is lost |
|--------|-------|--------------|
| `u8(0, "x"), u8(1, "x")` | builds; `{x=5}` packs `010505`; unpack of `010708` gives `{x=8}`; the unpacked row packs `010808` | the 7 |
| `u8(0, "x"), u8(1, "c"), times(2, 1, u8(2, "x"))` | builds; unpack of `0105020708` gives `{c=2, x=[5, 7, 8]}` (the outer 5 became the first entry); packing that row throws `IllegalArgumentException: 0: expected int, got ArrayList`; `{x=5, c=2}` packs `0105020505` | the outer 5 |
| `u8(0, "c"), times(1, 0, u8(1, "x")), u8(2, "x")` | builds; unpack of `0102070809` gives `{c=2, x=9}`; the unpacked row packs `0102090909`, not the bytes it came from | the 7 and the 8, silently |
| `u8(0, "x"), repeat(1, u8(1, "x"))` | builds; unpack of `01050607` gives `{x=[5, 6, 7]}`; packing that row throws `0: expected int, got ArrayList` (Java loses here, Rust does not) | the outer 5 |
| `u8(0, "n"), times(1, 0, u8(1, "v")), u8(2, "m"), times(3, 2, u8(3, "v"))` | builds; unpack of `01020a0b010c` gives `{m=1, n=2, v=[10, 11, 12]}`; packing that row throws `1: list has 3 entries for a count of 2` | the round boundary |
| `u2(slot(0, "a"), slot(1, "b")), u8(2, "a")` | builds; `{a=1, b=2}` packs `010901`; unpack of `010907` gives `{a=7, b=2}` | the u2 slot `a` |
| `u8(0, "n"), sized(1, "b", 0), sized(2, "b", 0)` | builds; `{n=1, b=[7]}` packs `01010707` | one of the two |
| `flags(0, u8(0, "a"), u8(1, "a"))`; `u8(0, "a"), flags(1, u8(1, "a"))` | build; `{a=3}` packs `01030303` and `01030103` | |
| `flags(0, boolField(0, "on"), boolField(1, "on"))`; `m = flagByte()`, `u8(0, "a"), m, m.bit(u8(1, "a"))`; `group(0, u8(0, "a")), u8(1, "a")` (an anchored group) | build; the last two pack `01050105` and `010303` | |
| `list(xs, u8(0, "e")), list(xs, u8(0, "e"))`; `list(xs, u8(0, "e")), u8(0, "xs")` | build | one of the two |
| `list(xs, group(0, u8(0, "a"), u8(1, "a")))`; the same in a `dict`; `group(g, u8(0, "a"), u8(1, "a"))` (a nested row) | build; `{xs=[{a=1}]}` packs `0101000101` | |
| one `Setter` object (`Access.set("x")`) used by two fields | builds | |
| a typed row: two fields that read and write `R.x` through `Access.get((R r) -> r.x)` and `Access.set((R r, Object v) -> r.x = ...)` | builds; `{x=5}` packs `010505`; unpack of `010708` gives `x=8` | the 7 |
| hand-written lambdas on one key: `Packbin.u8(0, r -> ((Map) r).get("x"), (r, v) -> ((Map) r).put("x", v))` twice | builds; unpack of `010708` gives `{x=8}` | the 7 |

What the ticket and the assessment text say, against what I observed. The assessment's Java probe is reproduced exactly (`{c=2, x=[5, 7, 8]}`, `IllegalArgumentException: 0: expected int, got ArrayList`). Three things the ticket does not say:

1. **Java fields carry no names.** `Field` holds an id, a `Getter` and a `Setter`, which are opaque lambdas (`SchemeOrder` and `Rounds` say it in comments: "Fields carry no names"). The only member name a scheme can read without running caller code is the key of a setter made by `Access.set(String)`, and today that setter is a lambda that hides its key. So "refuse a name used twice" can mean only: two fields whose setters are `Access.set(key)` with the same key. Typed rows (`Access.set(BiConsumer)`), hand-written lambdas, `Access.ignore()` and `Access.identity()` have no name, so a duplicate in them cannot be seen when the scheme is built (the two last rows of the table: they build today and after). This is the one choice the ticket does not make by itself; Risk 1 gives the options and the report to the owner carries it.
2. **The setter is the name, not the getter.** A scheme that reads one key twice for packing (`Access.get("a")` with `Access.ignore()` or `Access.set("b")` as the setter) loses nothing on unpack and packs the same value twice on purpose (`u8(0, "a"), Packbin.u8(1, Access.get("a"), Access.set("b"))` packs `010505` and unpacks `010507` to `{a=5, b=7}`): it stays legal.
3. **A nested row's key is not a data name.** Two nested rows with the same key share one child map (`group(Access.get("g"), Access.set("g"), u8(0, "a")), group(Access.get("g"), Access.set("g"), u8(0, "b"))` unpacks `010102` to `{g={a=1, b=2}}` and packs it back), and `group(Access.identity(), Access.ignore(), ...)` is the row around itself, so the key of a nested row is a container, not a member; it is not checked against data names or against another nested row. The members inside a nested row are checked in the row's own scope. Left alone and reported: `group(g, ...)` beside `u8(.., "g")` builds and unpacks `010709` to `{g=9}`, and `u8(.., "a")` beside `group(identity(), ignore(), u8(.., "a"))` loses a value.

## Outcome

- `new Scheme<>(...)` throws `IllegalArgumentException` with `member x: declared twice in one scope; a row holds one value per name, so one would be lost` (TypeScript's wording, the key as `x`) when two fields whose setters are `Access.set("x")` are declared in one scope and neither sits under a `when`.
- A field is named when its setter was made by `Access.set(String)`; a `u2` is named by each slot's setter. Every other setter (a typed `Access.set(BiConsumer)`, a hand-written lambda, `Access.ignore()`, `Access.identity()`) has no name and is not checked. No caller code runs and no exception is caught at construction: `Access.set(String)` returns a small package-private setter class that holds its key (`Access.KeySetter`, same behaviour as the lambda it replaces) and the check reads that field.
- The scope: the top level, one nested row (`group(get, set, ...)`), or one `list` or `dict` element. A `when` body, `flags`, a flag bit, an anchored `group`, a `repeat` body and a `times` body belong to the scope around them, so a name inside a round clashes with the same name outside it, before or after, and an inner `repeat` or `times` shares the names of its outer round (AZ-2127).
- How it composes with the scope rules of AZ-2233, AZ-2101 and AZ-2234: the boundaries are the same two (a nested row, a list or dict element start a scope that sees nothing of the row around; ids and flag bytes already follow them), but a round is not a boundary for names, where it is one for ids and flag bytes: the values of a round are stored in the row around it under the same keys. The nested row's own key is not a member (see Problem, point 3); its members and the members of a nested row inside a list or dict element are checked in their own scope, so `u8(0, "a")` beside `group(g, u8(0, "a"))` still builds. The pack failures of AZ-2234 (`missing group`, `missing list element I`) are not touched.
- A second declaration is refused only when both sit outside every `when`; a name declared under a `when` and once outside is accepted whichever comes first; two declarations inside one `when` body are accepted too (TypeScript's rule and its known gap, AZ-2188).
- The check runs after every check that exists today (`SchemeOrder.validate` and `SchemeOrder.bindFlagBits`), so a scheme refused today keeps its message.
- Every scheme that builds after the change packs and unpacks to the same bytes and values as at HEAD: the check only throws.

## Scope

### Included
- A construction check on the names of `Access.set(String)` setters: a new package-private `MemberNames` (`java/src/main/java/packbin/MemberNames.java`, about 70 lines), called last in the `Scheme` constructor (`Scheme.java`); `Access.set(String)` returns a named setter (`Access.java`, the lambda body moves into a package-private `KeySetter` class that holds the key; `Setter` and the public signature do not change).
- Tests for the probes below in a new `java/src/test/java/packbin/DuplicateNamesTest.java`, called from `PackbinTest.main`.
- The text that says the old behaviour (the docs pass; sentences under Constraints): README, `_docs/02_document/components/06_java_package/description.md` (§2 `Scheme` row, §7) and its `tests.md`.

### Excluded
- Typed rows and every accessor that is not `Access.set(String)`: not nameable at construction (Risk 1). `Packbin.u8(0, Access.get((R r) -> r.x), Access.set((R r, Object v) -> ...))` twice builds as before.
- The key of a nested row against data names or against another nested row, and the row-around-itself case `group(identity(), ignore(), ...)` (Problem, point 3).
- The getter side of a field (a key read twice for packing).
- Two declarations inside the same `when` body (they build and the value is written twice): TypeScript's rule leaves it open, so does this task.
- Probing a recording `Map` through the getters and setters to name hand-written lambdas (Risk 1, option B), and adding names to the API (option C).
- Other packages (ADR-001): Python is AZ-2245, Rust AZ-2247.

## Acceptance Criteria

In every AC `Maps.scheme(1, ...)` is the test helper that builds a `Scheme<Map>`, and `u8(id, key)` is `Packbin.u8(id, Access.get(key), Access.set(key))`.

**AC-1: The same key twice at one level is refused**
Given `u8(0, "x"), u8(1, "x")`
When the scheme is built
Then it throws `IllegalArgumentException: member x: declared twice in one scope; a row holds one value per name, so one would be lost` (today it builds: `010505`, `010708` unpacks to `{x=8}`, repack `010808`).

**AC-2: A key outside and inside a `times` or `repeat` round is refused, in either order**
Given `u8(0, "x"), u8(1, "c"), times(2, 1, u8(2, "x"))`, `u8(0, "c"), times(1, 0, u8(1, "x")), u8(2, "x")`, `u8(0, "x"), repeat(1, u8(1, "x"))`, and `repeat(0, u8(0, "n"), times(1, 0, u8(1, "v")), u8(2, "v"))`
When each is built
Then each throws the AC-1 message for `x`, `x`, `x` and `v` (today all build; the unpacked rows cannot be packed again, or pack other bytes: `0102090909` for `0102070809`).

**AC-3: Two `times` bodies, or two fields of one body, that share a key are refused**
Given `u8(0, "n"), times(1, 0, u8(1, "v")), u8(2, "m"), times(3, 2, u8(3, "v"))`
When the scheme is built
Then it throws the AC-1 message for `v`.

**AC-4: Every named kind and every container that shares the scope is checked**
Given `u2(slot(0, "a"), slot(1, "b")), u8(2, "a")`; `u8(0, "n"), sized(1, "b", 0), sized(2, "b", 0)`; `flags(0, u8(0, "a"), u8(1, "a"))`; `u8(0, "a"), flags(1, u8(1, "a"))`; `flags(0, boolField(0, "on"), boolField(1, "on"))`; `m = flagByte()` with `u8(0, "a"), m, m.bit(u8(1, "a"))`; `group(0, u8(0, "a")), u8(1, "a")`; `list(xs, u8(0, "e")), list(xs, u8(0, "e"))`; `list(xs, u8(0, "e")), u8(0, "xs")`; two fields built with one shared `Access.set("x")` object
When each is built
Then each throws the AC-1 message for the repeated key (`a`, `b`, `a`, `a`, `on`, `a`, `a`, `xs`, `xs`, `x`).

**AC-5: A list or dict element, and a nested row, are scopes of their own**
Given `list(xs, group(0, u8(0, "a"), u8(1, "a")))`, `dict(m, group(0, u8(0, "a"), u8(1, "a")))`, `group(g, u8(0, "a"), u8(1, "a"))` and `flags(0, group(g, u8(0, "a"), u8(1, "a")))` (a nested row `g` is `Packbin.group(Access.get("g"), Access.set("g"), ...)`), and `list(xs, group(p, u8(0, "a"), u8(1, "a")))`
When each is built
Then each throws the AC-1 message for `a` (the repeated key is inside the element or the nested row). And `u8(0, "a"), list(xs, group(0, u8(0, "a"), u8(1, "b")))` and `u8(0, "a"), group(g, u8(0, "a"))` build, as today: `{a=7, xs=[{a=1, b=2}]}` packs `010701000102` and unpacks back, and `{a=7, g={a=9}}` packs `010709` and unpacks back.

**AC-6: Alternate `when` branches keep sharing a key**
Given `u8(0, "k"), when(1, eq(0, 0), u8(1, "s")), when(2, eq(0, 1), u16(2, "s"))`; `u8(0, "k"), u8(1, "s"), when(2, eq(0, 1), u16(2, "s"))`; `u8(0, "k"), when(1, eq(0, 1), u8(1, "s"), u8(2, "s"))`; and `u8(0, "n"), when(1, eq(0, 1), times(1, 0, u8(1, "v"))), when(2, eq(0, 2), times(2, 0, u8(2, "v")))`
When each is built
Then each builds, as today; the first packs `{k=1, s=300}` as `01012c01` and unpacks `01012c01` to the same row; the second unpacks `010107ff00` to `{k=1, s=255}`; the third unpacks `01010708` to `{k=1, s=8}`.

**AC-7: A flag-byte handle read more than once, and getter-only echoes, stay legal**
Given `m = flagByte()` with `m, m.bit(u8(0, "a")), m, m.bit(u8(1, "b"))`; `u8(0, "a"), Packbin.u8(1, Access.get("a"), Access.ignore())`; and `u8(0, "a"), Packbin.u8(1, Access.get("a"), Access.set("b"))`
When each is built
Then each builds, as today; the first packs `{a=5, b=9}` as `0101050109` and unpacks it to the same row; the second packs `{a=5}` as `010505` and unpacks `010507` to `{a=5}`; the third packs `{a=5}` as `010505` and unpacks `010507` to `{a=5, b=7}`.

**AC-8: Nested-row keys and accessors that carry no name are not checked**
Given `group(g, u8(0, "a")), group(g, u8(0, "b"))` (a nested row twice), a typed `Scheme<R>` whose two fields read and write `R.x` through `Access.get(Function)` and `Access.set(BiConsumer)`, hand-written lambdas on one key (`Packbin.u8(0, r -> ((Map) r).get("x"), (r, v) -> ((Map) r).put("x", v))` twice), and `u8(0, "x"), Packbin.u8(1, Access.get("x"), (r, v) -> ((Map) r).put("x", v))`
When each is built
Then each builds, as today: the first unpacks `010102` to `{g={a=1, b=2}}` and packs it back, the typed one packs `{x=5}` as `010505` and unpacks `010708` to `x=8`, the lambdas unpack `010708` to `{x=8}`.

**AC-9: Existing refusals keep their message and win**
Given `u8(0, "x"), u8(1, "x"), u8(5, "y")`; the same two with `when(2, eq(9, 1), u8(2, "y"))`; with a flag bit that has no flag byte (`m.bit(u8(2, "b"))`); with a flag byte whose bit sits in a nested row it does not share a scope with (`m, group(g, m.bit(u8(0, "v"))), u8(0, "x"), u8(1, "x")`); with nine bits on one flag byte; with `group(2)`; and `u8(0, "x"), u8(0, "x")`
When each is built
Then each throws the message it has today: `field id 5 must be 2`, `when 2 tests field 9, which is not an earlier integer or bool field in its scope`, `flag bit U8 2 has no flagByte before it in the same scope`, `flag bit U8 0 has no flagByte before it in the same scope`, `flags already has 8 bits`, `empty group 2 has no fields and no accessor, so its bit can never be set`, `field id 0 must be 1`.

**AC-10: `Access.set(String)` behaves as before**
Given `Access.set("k")` applied to a `HashMap` row and to a row that is not a `Map`
When it is called
Then it puts `k` on the map, and throws `IllegalArgumentException: expected map` for the other row, as the lambda did; the return type stays `Setter`, `Access.get`, `Access.set(BiConsumer)`, `identity()` and `ignore()` are unchanged, and `java/api-check.sh` passes (no API above Android API 26: `List.of` fails it).

**AC-11: Existing tests and drivers are unchanged**
Given the Java suite (`PackbinTest`, `SchemeTest`, `FieldIdBindingTest`, `SessionTest`, all through `java/test.sh`) and the Java hand-off driver (`.github/workflows/drivers/Handoff.java`, `HandoffElements.java`, `Position.java`: `pack-user`, `pack-nested`, `pack-boolflag`, `pack-booltrue`, `pack-bitwhen`, `pack-roundflags`, `pack-roundwhen`, `pack-session`, `pack-listgroup`, `pack-dictgroup`, `pack-listflags`, their `unpack-*` commands and the three `unpack-*-short` commands)
When they run
Then every test passes, the position golden is `4001000065cd1d00a3e1110100`, the session vector is `b55d0a29c56c203712b241232e`, and the driver output is the same text as at HEAD (a throwaway version of the check on a scratch copy gave exactly this; the test output differs only in the timing line `NFR round trips`).

## Non-Functional Requirements

**Compatibility**
- The check throws or does nothing: it changes no wire byte and no unpacked value of a scheme that builds. A scheme that no longer builds could not read its own bytes back (it throws, or packs other bytes, on repack).

**Reliability**
- The mistake is reported when the scheme is built, not on the first pack, and the message names the key.
- No caller code runs at construction and nothing is caught: the check reads one field of a class this package owns.

**Portability**
- Java 17 sources, no API above Android API 26 (`java/api-check.sh`, Animal Sniffer): `Collections.singletonList`, not `List.of`.

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1 | `u8 x, u8 x` | `IllegalArgumentException` with the exact message | `java/src/test/java/packbin/DuplicateNamesTest.java` |
| AC-2 | the four round shapes | the message, key by key | `DuplicateNamesTest.java` |
| AC-3 | two `times` bodies | the message for `v` | `DuplicateNamesTest.java` |
| AC-4 | the ten kind and container shapes | the message for each key | `DuplicateNamesTest.java` |
| AC-5 | the five element and nested-row shapes, and the two that build | the message; the listed bytes and rows | `DuplicateNamesTest.java` |
| AC-6 | four `when` shapes | build; `01012c01`, `010107ff00`, `01010708` | `DuplicateNamesTest.java` |
| AC-7 | handle read twice, two getter-only echoes | build; `0101050109`, `010505` | `DuplicateNamesTest.java` |
| AC-8 | nested row twice, typed row, lambdas, mixed | build; the listed bytes and rows | `DuplicateNamesTest.java` |
| AC-9 | seven schemes refused today | the existing message | `DuplicateNamesTest.java` |
| AC-10 | `Access.set` on a map and on a non-map | `put`; `expected map` | `DuplicateNamesTest.java` |
| AC-11 | the suite and the driver | pass; unchanged | `java/test.sh`; `.github/workflows/language-pair.sh` (Java participant) |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-11 | `.github/workflows/drivers/Handoff.java`, `HandoffElements.java` (the `user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `roundflags`, `roundwhen`, `session`, `listgroup`, `dictgroup` and `listflags` hand-offs and the `-short` refusals) and `Position.java` | pack and unpack as the ring does | unchanged hex, 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: Java only; no shared walker, no cross-package import. TypeScript's `member-names.ts` is the intent, not code.
- Files at or under 500 lines: `Access.java` is 51 (about 63 after), `Scheme.java` 76 (+1), `PackbinTest.java` 396 (+1); the check goes in the new `MemberNames.java` (about 70 lines) and the tests in a new file.
- Error kind and label of existing errors unchanged (decision C15): every existing message keeps its text (AC-9); the new check runs after `SchemeOrder.validate` and `SchemeOrder.bindFlagBits`. The new error is an `IllegalArgumentException`, as the other construction errors are.
- The wire bytes of every row that packs and unpacks today, for a scheme that still builds, are unchanged (AC-6 to AC-8, AC-11).
- No public API change: `Access.set(String)` still returns `Setter`; the named class is package-private. No new dependency; Java 17, Android API 26.
- Probes in the Problem table and AC-1 to AC-9 were run on `35544ed` by throwaway classes in package `packbin` (public API only, `Maps`-style `Scheme<Map>` rows). The target messages and the passing suite come from a throwaway `MemberNames` and `KeySetter` on a scratch copy (the walk: `U8..UTF8`, `BOOL`, `SIZED`, `BITS`, `PACKED` and each `U2` slot declared; `LIST` and `DICT` declared and their element walked in a new scope; a nested-row `GROUP` walked in a new scope and not declared; an anchored `GROUP`, `FLAGS`, a flag bit's inner field, `REPEAT` and `TIMES` walked in place; `WHEN` walked as conditional; `FLAG_BYTE` skipped), called after `bindFlagBits`: all existing tests passed (the output equals HEAD's but for the timing line), `api-check` passed and the driver output was identical. The worker re-derives them from a real run.
- Docs pass (exact sentences proposed; the worker may reword, not drop the facts):
  - README, the construction-refusals list (`## Untrusted input`), after the TypeScript bullet on member names: "In Java, a key written twice in one scope: two fields whose setters are `Access.set(\"x\")` (`member x: declared twice in one scope; a row holds one value per name, so one would be lost`), also once outside and once inside a `repeat` or `times` round, unless one of the two sits under a `when`. A nested row and a `list` or `dict` element are scopes of their own, a nested row's own key is not checked, and a typed accessor (`Access.set(BiConsumer)`) or a hand-written lambda has no key, so a repeat there is not seen when the scheme is built."
  - README, the upgrade paragraphs (a new Java paragraph, or the one that starts "Java typed nested rows work"): "Java now refuses a key used twice in one scope when the scheme is built (`u8(0, \"x\"), u8(1, \"x\")` packed `01 05 05` and kept only the last value on unpack; a key outside and inside a `times` or `repeat` round could not be packed again, or packed other bytes). It reads the key from `Access.set(\"x\")`; typed accessors are not checked. In calling code, rename the repeated member."
  - `description.md` §2 `Scheme` row, Error Types: add "a key written twice in one scope through `Access.set(String)` (outside every `when`, also outside and inside a round; a nested row and a list or dict element are scopes of their own, `MemberNames.java`)". §7 Known limitations, two items: "Fields carry no names: only `Access.set(String)` setters are named, so a duplicate through a typed accessor or a hand-written lambda builds and loses a value, and so does a nested row's key beside a data key (`group(g, ...)` with `u8(.., \"g\")`) and `group(identity(), ignore(), ...)` beside a member of the same name (AZ-2246, open)" and "Two declarations inside one `when` body still build (AZ-2188 gap)". §7, after "Reference and placement rules", a short "Member names" paragraph with the scope rule above.
  - `tests.md`, Loop 16 table: "`DuplicateNamesTest` | the schemes of AC-1 to AC-5 fail at construction with `member x: declared twice in one scope; ...`; `when` branches, a flag-byte handle read twice, getter-only echoes, a nested row's key, typed and hand-written accessors stay legal; existing refusals keep their message; `Access.set` is unchanged (AZ-2246) | `java/src/test/java/packbin/DuplicateNamesTest.java`"; add AZ-2246 to the section title.
- Differential (rows that must stay byte-identical against HEAD): every scheme that has no duplicated `Access.set(String)` key by this rule builds and packs and unpacks exactly as at HEAD: the check returns without touching the fields, and `KeySetter.set` runs the lambda's body. The rows to compare are the suite, the hand-off driver output, the position golden and every row of AC-5 to AC-8. The only schemes that change are those listed in the Problem table as "builds" with a repeated `Access.set(String)` key.

## Risks & Mitigation

**Risk 1: Java can name only `Access.set(String)` members, so the rule cannot be the same as in TypeScript**
- *Risk*: the owner chose "refuse a member name used twice, as TypeScript does". In Java the name exists only for `Access.set(String)` setters; a typed row (the usual shape in the tests: `Access.get((R r) -> r.x)`) or a hand-written lambda can repeat a member and nothing at construction sees it.
- *Mitigation*: this spec takes the smallest design that runs no caller code: a named setter class and one pass over the fields. The options, for the owner: **A** (this spec) check the `Access.set(String)` keys only. **B** probe each accessor at construction with a recording `Map` (getter and setter), which also names hand-written Map lambdas but runs caller code at construction and has to catch the exceptions a typed or computing accessor throws (`ClassCastException`, `NullPointerException`); typed rows stay unnamed. **C** add the name to the API (a `String` on each field helper), which names everything and is an API change in every call. **D** leave Java and state in the README that only TypeScript, Python and Rust check. This is the choice the ticket text does not make: report it.

**Risk 2: Two nested rows with one key are left alone**
- *Risk*: `u8(.., "g")` beside `group(g, ...)` builds and loses a value (`010709` unpacks to `{g=9}`); the nested row's own key is not checked.
- *Mitigation*: two nested rows may share one child map on purpose (`{g={a=1, b=2}}`), so refusing them would take away a scheme that round-trips; a check of the container key against data keys only can follow if the owner wants it.

**Risk 3: A scheme that built and never read its own bytes back**
- *Risk*: a caller scheme with a repeated key (for example a second field kept as a mirror, both setters writing the same key) is refused.
- *Mitigation*: such a scheme keeps one value per key on unpack; the message names the key; `Access.ignore()` or another key for the mirror's setter keeps the packing side (AC-7).

## Owner decision (2026-10-06)

DECIDED, assessment round 2 X3, option A (the recommendation, as the ticket records it): refuse a member name used twice in one scope when the scheme is built, for Python, Java and Rust, with TypeScript's exemption for names under different `when`s; a Java nested row is a scope of its own. Reading the code: Java fields carry no names, so the rule reaches the members whose setter is `Access.set(String)`; typed accessors and hand-written lambdas cannot be checked when the scheme is built (Risk 1, owner to confirm the scope of the rule).

## Loop 16 result (2026-10-06)

Done in loop 16 (round 3), option A, the spec's default. `new Scheme<>(...)` throws `IllegalArgumentException` (`member x: declared twice in one scope; a row holds one value per name, so one would be lost`) when two fields whose setters are `Access.set("x")` sit in one scope outside every `when`: the same key twice at one level, outside and inside a `repeat` or `times` round, in two `times` bodies, for every named kind (a `u2` is named by each slot's setter, a `list` or `dict` by its own). `u8(0, "x"), u8(1, "x")` packed `01 05 05`, and `010708` unpacked to `{x=8}` and repacked as `010808`; a key outside and inside a `times` unpacked to `{c=2, x=[5, 7, 8]}` and repack threw; `times` then an outer `x` repacked to `0102090909`, different bytes without a word; outside plus `repeat` unpacked to `{x=[5, 6, 7]}` and repack failed (Java loses a value here, Rust did not).

What shipped: `Access.java` (+14/-2, 63 lines): `Access.set(String)` returns the package-private `Access.KeySetter implements Setter`, which holds `key` and has the old lambda body; `MemberNames.java` (new, 53 lines): a walk over the bound fields with a `Set<String>` per scope (the top level, one nested row, one `list` or `dict` element; rounds, `flags`, flag bits and anchored groups share the scope around them; a nested row's own key is not a name; a declaration under a `when` is not counted); `Scheme.java` (+1, 77 lines): `MemberNames.validate(this.fields)` is the last line of the constructor, after `SchemeOrder.validate` and `bindFlagBits`; `PackbinTest.java` (+1). Fields carry no names (`SchemeOrder`), which is why only an `Access.set(String)` setter can be named, and the setter is the name, not the getter (`get("a")` with `ignore()` or `set("b")` is a legal echo). `javap -public` of `Field`, `Scheme`, `Packbin`, `Access`, `PackSession`, `BinaryPacker`, `Getter` and `Setter` is byte-identical to HEAD.

Tests (`java/src/test/java/packbin/DuplicateNamesTest.java`, new, 317 lines; 37 new refusal checks went red on the HEAD classes, the unchanged-behavior checks passed there): AC-1 `ac1SameKeyTwiceAtOneLevelIsRefused`; AC-2 `ac2KeyOutsideAndInsideARoundIsRefused` (four shapes); AC-3 `ac3TwoTimesBodiesThatShareAKeyAreRefused`; AC-4 `ac4EveryNamedKindAndSharedContainerIsChecked` (the ten spec shapes, a `u2` with two equal slots, a list then a dict) and `ac4EveryScalarKindIsNamed` (14 kinds); AC-5 `ac5ElementsAndNestedRowsAreScopesOfTheirOwn` (five refusals; two builds round-trip as `010701000102` and `010709`); AC-6 `ac6AlternateWhenBranchesKeepSharingAKey`; AC-7 `ac7HandleReadTwiceAndGetterOnlyEchoesStayLegal`; AC-8 `ac8NestedRowKeysAndUnnamedAccessorsAreNotChecked`; AC-9 `ac9ExistingRefusalsKeepTheirMessageAndWin` (seven messages); AC-10 `ac10AccessSetBehavesAsBefore`. `bash java/test.sh` exits 0, all four mains pass, `api-check` PASS for Android API 26, its output equals the HEAD run except the NFR timing line; all checks pass and `DuplicateNamesTest` adds 124 (no total is quoted: counting the runtime calls of the expect helpers in an instrumented copy gave 1,667 at HEAD and 1,791 now, and the earlier "1501" came from another counting method). `javadoc --release 17` exits 0 with the same 93 warnings as HEAD.

Evidence: a differential of 35,000 random schemes over the public API, each unpacked from 40 random byte strings and repacked, HEAD classes against the new ones, with its own oracle for "a key set twice in one scope outside a `when`": all 35,000 build at HEAD; the 24,041 without a repeated key are identical (about 1.4 M inputs); the 10,959 with one are each refused with exactly the oracle's key; 0 mismatches. The hand-off driver (26 commands: 11 `pack-*`, 11 `unpack-*`, 3 `-short`, `Position`) exits 0 with identical text at HEAD and now; position prints `4001000065cd1d00a3e1110100`, `pack-session` prints `b55d0a29c56c203712b241232e`. The new rule refuses no existing test scheme, hostile vector or driver scheme.

Open (owner): Risk 1, only `Access.set("x")` members are named: typed accessors, hand-written lambdas, `identity()` and `ignore()` carry no name, so two `Access.set(BiConsumer)` setters on one key, or `u8 a` beside `group(identity(), ignore(), u8 a)`, still build; options B (probe a recording `Map`, which runs caller code and needs catches), C (add names to the API) and D (leave Java as is) stay with the owner. Risk 2: `group(g, u8 a)` beside `u8(0, "g")` builds. A repeated key inside a nested row that itself sits under a `when` builds (`when(1, eq(0, 1), group(g, u8 a, u8 a))`), the same gap as two declarations inside one `when` body and as TypeScript's unanchored group (owner). The total review (F1, Medium) found that a `list` or `dict` element under a `when` also built, unlike TypeScript and Python; fixed in loop 16: `MemberNames.walk` passes `false` into an element scope, test `ac5ElementUnderAWhenIsStillAScopeOfItsOwn`. `Access.set((String) null)` used twice is now refused as `member null: ...` (the old lambda accepted a null key): a real duplicate. Docs: README patch, Java description and `tests.md`.

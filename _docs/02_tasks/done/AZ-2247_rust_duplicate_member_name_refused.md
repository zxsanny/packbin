# Rust refuses a data member name used twice when the scheme is built

**Task**: AZ-2247_rust_duplicate_member_name_refused
**Name**: Rust duplicate data member names refused at construction
**Description**: `MapScheme::new(...)` and `Scheme::new(...)` panic, naming the member, when a data name is declared twice in one scope (the top level or one `list` or `dict` element), once outside and once inside a `repeat` or `times` round of that scope included, unless one of the two sits under a `when`. A flag-byte handle read more than once, a name that two `when` branches share and a name inside a `list` or `dict` element that the row around it also uses stay legal.
**Complexity**: 2 points
**Dependencies**: AZ-2188_typescript_duplicate_member_names (the rule, done in TypeScript); AZ-2237_rust_map_pack_when_written_values (pack keeps what each scope wrote, by name)
**Component**: rust
**Tracker**: AZ-2247
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment round 2 (`_docs/loops/loop16/assessment16.md`, row X3), option A: TypeScript refuses a member name declared twice in one scope (AZ-2188: "a row holds one value per name, so one would be lost"); Rust builds the same schemes and loses a value. Observed on `35544ed` (a `git archive` export, cargo 1.79, `MapScheme::new` / `pack` / `unpack` from a throwaway integration test):

| Scheme (map form) | Today | What is lost |
|-------------------|-------|--------------|
| `u8("x"), u8("x")` | builds; `{x: 5}` packs `010505`; unpack of `010708` gives `{x: U8(8)}`; the unpacked values pack `010808` | the 7 |
| `u8("x"), u8("c"), times(2, "c", [u8("x")])` | builds; unpack of `0105020708` gives `c = U8(2)`, `x = List([U8(7), U8(8)])` and `__times_2 = Groups([{x: 7}, {x: 8}])`; packing those values returns `Err(Type("int"))`; `{x: 5, c: 2}` returns `Err(Missing("x"))` | the outer 5 (the round list replaced it) |
| `u8("c"), times(1, "c", [u8("x")]), u8("x")` | builds; unpack of `0102070809` gives `x = U8(9)` and the rounds only under `__times_1`; packing them returns `Err(Type("times at id 1: list for 'x' disagrees with its rounds"))` | the row cannot be packed again |
| `u8("n"), times(1, "n", [u8("v")]), u8("m"), times(3, "m", [u8("v")])` | builds; unpack of `01020a0b010c` keeps `v = List([U8(12)])` (the second `times` only); packing them returns `Err(Type("times at id 1: list for 'v' disagrees with its rounds"))` | the first list |
| `u8("c"), times(1, "c", [u8("a"), u8("b"), u8("a")])` | builds; unpack of `0101020304` gives `a = List([U8(4)])` | the first `a` |
| `u8("x"), repeat(1, [u8("x")])` | builds; unpack of `01050607` gives `x = U8(5)` and the rounds only under `__repeat__ = Groups([{x: 6}, {x: 7}])`; the unpacked values pack `01050607` | nothing: Rust round-trips this one (a `repeat` publishes no per-name list into the scope around it) |
| `u2(&["a", "b"]), u8("a")` | builds; `{a: 1, b: 2}` packs `010901`; unpack of `010907` gives `a = U8(7)` | the u2 slot `a` |
| `u2(&["a", "a"])` | builds; `{a: 1}` packs `0105` (the same value in both slots) | one slot |
| `u8("n"), sized("b", "n"), sized("b", "n")`; `u8("n"), bits("a", "n"), packed(1, "a", "n", 0)`; `f32("a"), utf8("a")`; `u8("a"), bytes("a", 2)`; `dict("d", u8("e")), list("d", u8("e"))`; `list("xs", u8("e")), u8("xs")` | build (`{n: 1, b: [7]}` packs `01010707`) | one of the two values |
| `flags(0, "f", [u8("a"), u8("a")])` | builds; `{a: 3}` packs `01030303` | |
| `flags(0, "f", [group(0, "on", []), group(1, "on", [])])` | builds; `{on: 1}` packs `0103` (both bits set) | |
| `u8("a"), group(1, "g", [u8("a")])`; `u8("a"), m.byte(), m.bit(u8("a"))` (`m = flag_byte("m")`) | build; the first packs `010303`, the second `01050105` | |
| typed: `Scheme::<R>::new(1, [SchemeItem::Field(u8("x")), SchemeItem::Field(u8("x"))])` | builds (a raw `Field` in a typed scheme packs nothing: `Err(Missing("x"))`) | |

What the ticket and the assessment text say, against what I observed: the assessment's two probes are reproduced exactly (`x=List([7,8])`, `Type("int")`). Two things differ from "a round clash loses data": (1) the same name outside and inside a `repeat` round does not lose anything in Rust and the values round-trip (row 6), because only `times` publishes its per-name lists into the scope around it; the rule below still refuses it, as TypeScript (AZ-2188 AC-3) and the assessment's cross-language rule "same scheme, same result" ask, and Risk 1 says what flipping that costs. (2) In the typed `Scheme<T>` form a member name is its field id (`BoundField::u8(0, ...)` is named `"0"`), and ids are already unique by the existing order check: two bound fields with id 0 panic with `field id 0 is not the next order 1` today, and an element of a typed `times` that reuses id 0 panics the same way. Duplicate names can reach the typed form only through a raw `SchemeItem::Field` (which packs nothing). Two bound fields with different ids that read and write the same struct member (`BoundField::u8(0, |r| r.x, ...)` and `BoundField::u8(1, |r| r.x, ...)` pack `010505`) are closures, and Rust cannot tell at build; that stays outside this task.

## Outcome

- `MapScheme::new` (and so `Scheme::new`, which builds a `MapScheme` from its items) panics with `member "x" is declared twice in one scope; a row holds one value per name, so one would be lost` when a data name is declared twice in one scope and neither declaration sits under a `when`. The wording is TypeScript's (`member a: declared twice in one scope; ...`) with the name quoted as the other Rust construction panics quote theirs (`names field "1"`).
- The scope is the one a TypeScript row has: the top level, or one `list` or `dict` element (an element holds one name, so it can only be checked against nothing; it never clashes with the row around it). A `when` body, a `flags` group, a flag bit, a non-empty `group`, a `repeat` body and a `times` body belong to the scope around them, so a name inside a round clashes with the same name outside it, before or after.
- A data name is the name of an integer, float, bytes, utf8, `sized`, `bits`, `packed`, `list` or `dict` field, each name of a `u2`, and a bool (an empty `group`). Not data names: a `flag_byte` handle, the name of a `flags(anchor, name, ...)` byte and the name of a non-empty `group`, which are never members of a row (the byte is stored under its name in the unpacked values, see Excluded).
- Alternate `when` branches may share a name, as in TypeScript: the second declaration is refused only when both sit outside every `when`; a name declared under a `when` and once outside is accepted whichever comes first, and two declarations inside one `when` body are accepted too (the TypeScript rule, AZ-2188 Flagged concerns).
- The check runs after every check that exists today (`check_order`, `check_shape`, `check_integrity`), so a scheme refused today keeps its message.
- Every scheme that builds after the change packs and unpacks to the same bytes and values as at HEAD: the check only panics.

## Scope

### Included
- A construction check on data names in the layout the map and the typed form share: a new `rust/src/field/names.rs` (about 60 lines, `check_names`), called last in `MapScheme::new` (`rust/src/field/map_scheme.rs`), plus `mod names;` in `rust/src/field/mod.rs`. `Scheme::new` needs no change: it calls `MapScheme::new` with the compiled fields.
- Tests for the probes below in new files `rust/src/duplicate_names_tests.rs` (the refusals) and `rust/src/duplicate_names_kept_tests.rs` (the shapes that must keep building; one file came to 519 lines, over the 500 cap), both registered in `rust/src/lib.rs`.
- The text that says the old behaviour (the docs pass; sentences under Constraints): README, `_docs/02_document/components/04_rust_package/description.md` (§2 `Scheme` row, §7 known limitations) and its `tests.md`.

### Excluded
- A data name equal to a `flag_byte` name or a `flags` byte name. The byte is stored in the unpacked values under its name, so `u8("m"), m.byte(), m.bit(u8("a"))` unpacks `01070105` to `m = U8(1)` (the data 7 is replaced by the flag byte) and packs the values back as `01010105`; `m.byte(), u8("m")` and `flags(0, "f", [...]), u8("f")` collide the other way (the data wins, the byte is lost). The ticket says a flag-byte handle read in two scopes stays legal and does not decide a clash with a data name; it builds today and builds after. Reported, not changed.
- Two `BoundField`s that read and write the same struct member under different ids (typed form): closures, not decidable at build.
- Two declarations inside the same `when` body (they build and the value is written twice): TypeScript's rule leaves it open (AZ-2188, "Open"), and so does this task.
- Numeric names (`u8("0"), u8("0")`): already refused by the id order check (`field id 0 is not the next order 1`); not changed.
- Renaming rows, the `__repeat__` and `__times_<anchor>` keys, and the typed `__bound_N` and `__flags_N` internal names (unique by construction).
- Other packages (ADR-001): Python is AZ-2245, Java AZ-2246.

## Acceptance Criteria

**AC-1: The same name twice at one level is refused**
Given `MapScheme::new(1, vec![u8("x"), u8("x")])`
When it is called
Then it panics with `member "x" is declared twice in one scope; a row holds one value per name, so one would be lost` (today it builds: `010505`, `010708` unpacks to `{x: 8}`, repack `010808`).

**AC-2: A name outside and inside a `times` round is refused, in either order**
Given `u8("x"), u8("c"), times(2, "c", [u8("x")])` and `u8("c"), times(1, "c", [u8("x")]), u8("x")`
When each is built
Then each panics with the AC-1 message for `x` (today both build and their unpacked values cannot be packed: `Err(Type("int"))` and `Err(Type("times at id 1: list for 'x' disagrees with its rounds"))`).

**AC-3: Two `times` bodies, or one body, that share a name are refused**
Given `u8("n"), times(1, "n", [u8("v")]), u8("m"), times(3, "m", [u8("v")])` and `u8("c"), times(1, "c", [u8("a"), u8("b"), u8("a")])`
When each is built
Then they panic with the AC-1 message for `v` and for `a`.

**AC-4: A name outside and inside a `repeat` round is refused**
Given `u8("x"), repeat(1, [u8("x")])`
When it is built
Then it panics with the AC-1 message for `x`. Today it builds and round-trips (`01050607` unpacks to `x = U8(5)` and `__repeat__` rounds, and packs back to `01050607`): this is the one refusal that takes away a scheme that works; see Risk 1.

**AC-5: Every data kind, and every container that shares the scope, is checked**
Given `u2(&["a", "b"]), u8("a")`; `u2(&["a", "a"])`; `u8("n"), sized("b", "n"), sized("b", "n")`; `u8("n"), bits("a", "n"), packed(1, "a", "n", 0)`; `f32("a"), utf8("a")`; `u8("a"), bytes("a", 2)`; `dict("d", u8("e")), list("d", u8("e"))`; `list("xs", u8("e")), u8("xs")`; `flags(0, "f", [u8("a"), u8("a")])`; `u8("on"), flags(1, "f", [group(1, "on", [])])`; `flags(0, "f", [group(0, "on", []), group(1, "on", [])])`; `u8("a"), group(1, "g", [u8("a")])`; `u8("a"), m.byte(), m.bit(u8("a"))` and `u8("a"), m.byte(), m.bit(group(2, "g", [u8("a")]))` with `m = flag_byte("m")`
When each is built
Then each panics with the AC-1 message for the repeated name (`a`, `a`, `b`, `a`, `a`, `a`, `d`, `xs`, `a`, `on`, `on`, `a`, `a`, `a`).

**AC-6: Alternate `when` branches keep sharing a name**
Given `u8("k"), when(1, eq("k", U8(0)), [u8("s")]), when(2, eq("k", U8(1)), [u16("s")])`; the same two branches inside `repeat(0, [u8("k"), when(1, ...), when(2, ...)])`; `u8("k"), u8("s"), when(2, eq("k", U8(1)), [u16("s")])`; `u8("k"), when(1, eq("k", U8(1)), [u8("s")]), u8("s")`; and `u8("k"), when(1, eq("k", U8(1)), [u8("s"), u8("s")])`
When each is built
Then each builds, as today; the first packs `{k: 1, s: U16(300)}` as `01012c01` and unpacks `01012c01` to the same values; the repeat form packs and unpacks `010007012c01` (rounds `{k: 0, s: 7}`, `{k: 1, s: 300}`); the third unpacks `010107ff00` to `k = 1, s = U16(255)`. `u8("k"), when(1, eq("k", U8(1)), [u8("s")]), u8("s"), u8("s")` panics (two declarations outside every `when`).

**AC-7: A flag-byte handle read more than once stays legal**
Given `m = flag_byte("m")` and `m.byte(), m.bit(u8("a")), m.byte(), m.bit(u8("b"))`; `u8("c"), times(1, "c", [m.byte(), m.bit(u8("a"))]), m.byte(), m.bit(u8("b"))`; and `flags(0, "f", [u8("a")]), flags(1, "f", [u8("b")])` (a `flags` byte name used twice)
When each is built
Then each builds, as today; the first packs `{a: 5, b: 9}` as `0101050109` and unpacks it to `a = 5, b = 9, m = 1`; the third packs `{a: 5, b: 9}` as `0101050109`.

**AC-8: A list or dict element is a scope of its own**
Given `u8("e"), list("xs", u8("e"))`, `u8("x"), list("l", utf8("x"))` and `list("l", list("m", u8("e"))), u8("m")`
When each is built
Then each builds, as today; `{e: 7, xs: [1, 2]}` packs `010702000102` and `{x: 1, l: ["a"]}` packs `01010100010061`.

**AC-9: The typed `Scheme<T>` is covered**
Given `Scheme::<R>::new(1, [SchemeItem::Field(u8("x")), SchemeItem::Field(u8("x"))])` and `[BoundField::u8(0, ..), SchemeItem::Field(u8("x")), SchemeItem::times(2, 0, .., [SchemeItem::Field(u8("x"))])]`
When each is built
Then each panics with the AC-1 message for `x` (today both build). Two bound fields with id 0, and a typed `times` element that reuses id 0, keep `field id 0 is not the next order 1`. A typed scheme with distinct ids (the README snippets, the position scheme, `SchemeItem::times` with element ids that continue the anchor, `SchemeItem::when(1, eq(0, U8(0)), [Field(u8("s"))])` beside `SchemeItem::when(2, eq(0, U8(1)), [Field(u16("s"))])`) builds and packs the bytes it packs today.

**AC-10: Existing refusals keep their message and win**
Given `u8("x"), u8("x"), when(2, eq("zz", U8(1)), [u8("y")])`; `u8("x"), u8("x"), u8("5")`; `u8("x"), u8("x"), repeat(2, [repeat(2, [u8("y")])])`; a nine-bit flag byte after a duplicate; `u8("0"), u8("0")`
When each is built
Then each panics with the message it has today: `when at id 2 names field "zz", which is not in the same scope (a field must be declared earlier in the same container; a repeat, times, list or dict body is a scope of its own)`, `field id 5 is not the next order 2`, `repeat at id 2 is inside a repeat or times round; a round keeps no inner repeat rounds`, `flag byte "m" has more than 8 bits; the 9th is field "b8"`, `field id 0 is not the next order 1`.

**AC-11: Existing tests and fixtures are unchanged**
Given the 253 library tests and the 78 integration tests (331), the README typed snippets, the position golden and the `handoff-rust` driver (`pack-user`, `pack-nested`, `pack-boolflag`, `pack-booltrue`, `pack-bitwhen`, `pack-roundflags`, `pack-roundwhen`, `pack-session` and their `unpack-*` commands)
When they run
Then all 331 pass, the golden is `4001000065cd1d00a3e1110100`, the session vector is `b55d0a29c56c203712b241232e`, and the driver output is the same text as at HEAD (a throwaway version of the check on a scratch copy gave exactly this).

## Non-Functional Requirements

**Compatibility**
- The check panics or does nothing: it changes no wire byte and no unpacked value of a scheme that builds. A scheme that no longer builds could not read its own bytes back, except the `repeat` form of AC-4 (Risk 1).

**Reliability**
- The mistake is reported when the scheme is built, not on the first pack; the message names the member.

**Performance**
- One pass over the fields at construction, a hash map of the names of one scope; no cost on pack or unpack.

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1 | `u8 x, u8 x` | `#[should_panic(expected = "member \"x\" is declared twice in one scope")]` | `rust/src/duplicate_names_tests.rs` |
| AC-2 | outside then `times`, `times` then outside | the same panic, both orders | `rust/src/duplicate_names_tests.rs` |
| AC-3 | two `times` bodies, two names in one body | panic naming `v`, `a` | `rust/src/duplicate_names_tests.rs` |
| AC-4 | outside and `repeat` | panic naming `x` | `rust/src/duplicate_names_tests.rs` |
| AC-5 | the fourteen kind and container shapes | panic naming each repeated name (one test per shape, or a loop that checks the message) | `rust/src/duplicate_names_tests.rs` |
| AC-6 | `when` branches at the top level and in a `repeat` round, outside-then-`when`, `when`-then-outside, twice in one `when`, and the refused two-outside case | build and the listed bytes and values; the refused case panics | `rust/src/duplicate_names_kept_tests.rs` (the refused case in `rust/src/duplicate_names_tests.rs`) |
| AC-7 | a flag byte read twice, in a `times` round and at the top level, two `flags` named alike | build; `0101050109` | `rust/src/duplicate_names_kept_tests.rs` |
| AC-8 | three element shapes | build; the listed bytes | `rust/src/duplicate_names_kept_tests.rs` |
| AC-9 | typed `Field` twice, `Field` outside and inside a typed `times`, the unchanged id panics, distinct ids | panic naming `x`; the id message; builds | `rust/src/duplicate_names_tests.rs` |
| AC-10 | five schemes that are refused today for another reason | the existing message | `rust/src/duplicate_names_tests.rs` |
| AC-11 | the whole suite and the driver | pass; unchanged | `cargo test`; `.github/workflows/language-pair.sh` (Rust participant) |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-11 | `.github/workflows/drivers/handoff-rust` (the `user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `roundflags`, `roundwhen` and `session` hand-offs) and `.github/workflows/drivers/rust` (position) | pack and unpack as the ring does | unchanged hex, 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: Rust only; no shared walker, no cross-package import. TypeScript's `member-names.ts` is the intent, not code.
- Files at or under 500 lines: `field/mod.rs` is 467 (+1 line), `map_scheme.rs` 100 (+2), `lib.rs` 57; the check goes in the new `field/names.rs` (about 60 lines) and the tests in a new file, not in `integrity.rs` (125) or an existing test file.
- Error kind and label of existing errors unchanged (decision C15): every existing panic keeps its text (AC-10); the check runs after them. The new panic is a `panic!` with a `String`, as the other construction errors are.
- The wire bytes of every row that packs and unpacks today, for a scheme that still builds, are unchanged (AC-6, AC-7, AC-8, AC-11).
- No new dependency; no public API change (the check is `pub(crate)`).
- Probes in the Problem table and in AC-1 to AC-10 were run on `35544ed` by a throwaway integration test (`MapScheme::new`, `pack`, `unpack`, `Scheme::new`). The target messages and the 331 passing tests come from a throwaway `names.rs` on a scratch copy (about 60 lines: a map from name to "declared outside every when", `Int|Float|Bytes|Utf8|Sized|Bits|Packed|List|Dict` names, each `U2` name and an empty `Group` declared; `Flags`, `Repeat`, `Times` and a flag bit's field walked in place; `When` walked as conditional; `FlagByte` and a non-empty `Group` name skipped), called after `check_integrity`. The worker re-derives them from a real run.
- Docs pass (exact sentences proposed; the worker may reword, not drop the facts):
  - README, the construction-refusals list (`## Untrusted input`), extend the TypeScript bullet ("A member name declared twice ...") or add: "In Rust, a data name declared twice in one scope panics when the scheme is built (`member \"a\" is declared twice in one scope; a row holds one value per name, so one would be lost`), unless one of the two sits under a `when`: the second `u8(\"a\")`, a name inside and outside a `times` or `repeat` round, a `u2` slot or a `sized`, `bits`, `packed`, `list` or `dict` named like another member. A flag byte read twice, a `flags` byte name, a `group` name and a name inside a `list` or `dict` element are not data names. In the typed `Scheme<T>` a name is the field id, which is already unique; the check reaches only a raw `SchemeItem::Field`."
  - README, the Rust upgrade paragraph (the one that starts "Rust `PackSession::pack` returns"): append "A data member name declared twice in one scope now panics when the scheme is built (`u8(\"x\"), u8(\"x\")` packed `01 05 05` and lost the 7 on unpack; a name outside and inside a `times` could not be packed again; one inside a `repeat` round round-tripped and is refused now too). In calling code, rename the repeated member."
  - `description.md` §2 `Scheme` row, Error Types: add "a data member name declared twice in one scope (outside every `when`), also once outside and once inside a `repeat` or `times` round (`field/names.rs`)". §7 Known limitations, two items: "A data name equal to a `flag_byte` or `flags` byte name builds and one value replaces the other in the unpacked values (`u8(\"m\")` with `m.byte()` gives `m = 1`); the check does not cover byte names (AZ-2247, open)" and "Two typed `BoundField`s with different ids that read and write the same struct member build and pack the value twice; Rust cannot see closures (AZ-2247, open)".
  - `tests.md`, Loop 16 table: "`AZ-2247 a data member name declared twice is refused` | `MapScheme::new` and `Scheme::new` panic for the shapes of AC-1 to AC-5 and AC-9; `when` branches, flag-byte handles read twice, `flags` byte names and element names stay legal; existing refusals keep their message | `rust/src/duplicate_names_tests.rs`"; add AZ-2247 to the section title.
- Differential (rows that must stay byte-identical against HEAD): every scheme that has no duplicate data name by this rule builds and packs and unpacks exactly as at HEAD, because the check returns without touching the fields. The rows to compare are the 331 tests, the `handoff-rust` driver output, the position golden, the typed README snippets, and every row of AC-6 to AC-8. The only schemes that change are those listed in the Problem table as "builds" and now panic.

## Risks & Mitigation

**Risk 1: `u8 x` beside `repeat { u8 x }` is refused although Rust round-trips it**
- *Risk*: AC-4 takes away a scheme that works in Rust today. A caller that never reads the unpacked `x` of a round (the rounds live under `__repeat__`) loses nothing, and now cannot build.
- *Mitigation*: TypeScript, and the other packages after AZ-2245 and AZ-2246, refuse it, so one scheme means one result in every package (the assessment's cross-language rule); the message names the member and the fix is a rename. If the owner prefers to refuse only where Rust loses data, drop AC-4 and make the check treat a `repeat` body as a scope of its own (a one-line change in `names.rs`); `times` and every other row of the table stay refused. This is the one choice the ticket text does not make by itself: report it to the owner.

**Risk 2: A name that two schemes share through a helper, or built once and reused**
- *Risk*: a caller builds the field list from a helper that repeats a name (for example one `u8("status")` added twice by two builders).
- *Mitigation*: the scheme could not be read back anyway; the panic names the member.

**Risk 3: A data name equal to a flag byte name still collides**
- *Risk*: `u8("m")` beside `flag_byte("m")` builds, and the unpacked value of `m` is the flag byte, not the data (Excluded).
- *Mitigation*: documented in the Rust description as open; a follow-up can extend `check_names` to byte names against data names without touching a handle read twice.

## Owner decision (2026-10-06)

DECIDED, assessment round 2 X3, option A (the recommendation, as the ticket records it): refuse a data member name used twice in one scope when the scheme is built, for Python, Java and Rust, with TypeScript's exemption for names under different `when`s; Rust refuses a repeated data name too but not a flag-byte handle read in two scopes, which is legal there. Reading the code: the typed `Scheme<T>` names its members by field id, so the check reaches it only through a raw `SchemeItem::Field`; the `repeat` form of the clash round-trips in Rust and is refused for cross-language equality (Risk 1).

## Loop 16 result (2026-10-06)

Done in loop 16 (round 3). `MapScheme::new` and `Scheme::new` panic with `member "x" is declared twice in one scope; a row holds one value per name, so one would be lost` for a data name declared twice at the top level, or once outside and once inside a `repeat` or `times` round (either order), unless one of the two sits under a `when`. A data name is the name of an integer, float, bytes, utf8, `sized`, `bits`, `packed`, `list` or `dict` field, each name of a `u2` and a bool (an empty `group`); a flag byte, a `flags` byte name and a non-empty `group` name are not data names, and a `list` or `dict` element holds one name and is a scope of its own. At HEAD `u8("x"), u8("x")` packed `01 05 05` and lost the 7 on unpack (`010708` gives `x=U8(8)`, repack `010808`); a name outside and inside a `times` repacked to `Type("int")`; `times` then an outer `x` repacked to `Type("times at id 1: list for 'x' disagrees with its rounds")`; `u8("c"), times(1, "c", [a, b, a])` unpacked `0101020304` to `a = [4]` and repacked to `0101040304`. No wire byte or unpacked value changes for a scheme that still builds.

Files (`rust/`): `src/field/names.rs` (new, 73 lines, `check_names`: a map of each name to "declared outside every `when`"); `src/field/map_scheme.rs` (+3/-1: the import, the call after `check_integrity`, one doc-comment line); `src/field/mod.rs` (+1, 468 lines); `src/lib.rs` (+4); `src/duplicate_names_tests.rs` (new, 320 lines) and `src/duplicate_names_kept_tests.rs` (new, 210 lines; the spec named one file, one file came to 519 lines, so the spec text and `tests.md` name both).

Tests (29, written first: 10 of the 29 failed before `names.rs` existed, all the refusals; the 19 pinning tests passed; each refusal test compares the whole panic text): AC-1 `ac1_the_same_name_twice_at_one_level_is_refused`; AC-2 `ac2_a_name_outside_then_inside_a_times_round_is_refused` and the reverse; AC-3 two tests (two `times` bodies share a name, a body names a member twice); AC-4 `ac4_a_name_outside_and_inside_a_repeat_round_is_refused`; AC-5 `ac5_every_data_kind_and_every_container_that_shares_the_scope_is_refused` (14 shapes, exact message each); AC-6 five tests in the kept file (alternate `when` branches at the top level and in a `repeat` round, outside then under a `when`, under a `when` then outside, twice in one `when` body) and `ac6_a_name_under_a_when_and_twice_outside_is_refused` in the main file; AC-7 three kept tests (a flag byte read twice, in a `times` round and at the top level, two `flags` bytes named alike); AC-8 three kept tests (list elements named like row members); AC-9 five tests (a raw `SchemeItem::Field` twice in a typed scheme, outside and inside a typed `times`, the unchanged id messages, distinct ids build); AC-10 five tests (each existing message wins after a duplicate); AC-11 the suite. Rust is 360 pass (282 lib + 78 integration; 331 before), debug and release, on cargo 1.79; nothing was run on CI's 1.98.

Evidence: 280,000 random map-form schemes over seven seeds against a `git archive HEAD` export, each packet the shortest clean-parsing prefix of a random stream, unpacked then repacked, with an oracle of its own (a name with two declarations outside every `when`): 112,000 schemes without a duplicate that build are byte-identical to HEAD; 163,000 that built at HEAD and hold a duplicate panic on every one, naming the oracle's name; about 3,500 refused for another reason keep their message; 0 mismatches. Six mutations of `names.rs` (`repeat` as its own scope, a `when` counted as unconditional, `flags` members skipped, `packed` skipped, a flag bit skipped, a bool `group` not declared) fail the new tests, and a seventh (a conditional declaration never upgrading) fails the refused-after-`when` test. `handoff-rust` and the `rust` driver built in scratch against HEAD and the change: every `pack-*` is identical and every `unpack-*` of it exits 0 (session `b55d0a29c56c203712b241232e`, position `4001000065cd1d00a3e1110100`). clippy 1.79 shows 6 warnings in the lib, none in these files, as at HEAD; rustfmt shows no new difference.

Discoveries and open items: `u8("x"), repeat(1, [u8("x")])` round-trips at HEAD (`01050607` repacks to itself) and is refused now, for equality with the other packages and TypeScript's AC-3; flipping it is one line (make `Repeat` its own scope in `names.rs`; only the AC-4 test then fails; open, flagged for the owner, who chose refusal). Excluded and open (a follow-up ticket): a data name equal to a `flag_byte` or `flags` byte name builds and one value replaces the other (`u8("m"), m.byte(), m.bit(u8("a"))`: `01070105` unpacks to `m = 1`, repack `01010105`; a handle read twice must stay legal); two declarations inside one `when` body build (`s = 8` for `01010708`), the same open item as TypeScript. In the typed `Scheme<T>` a name is the field id, already unique (`field id 0 is not the next order 1`), so the check reaches typed only through a raw `SchemeItem::Field`; two `BoundField`s with different ids that write the same struct member are not decidable (Rust cannot see closures). `u2(a, b), u8("a")` unpacked values do not repack (`Err(Type("a"))`): no action, the refusal covers it. Docs: README patch, Rust description and `tests.md`.

# TypeScript package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for Vue, React, and Node.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's client. Vue and React import this package. They do not get their own package.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `scheme`, `new Scheme` | type number, fields by order id | scheme | No | a type number outside 0..255, a gap, a repeated id, an anchor that is not the next value id, a flag bit whose flag byte is not read earlier in the same scope, a bool or empty group that is not directly in `flags` or a flag-byte bit, an `eq` or count id that is not an earlier field of the same scope, a member name used inside an unanchored group and outside it, a member name declared twice in one scope, or a `repeat` or `times` inside a `repeat` or `times` round (§7) |
| `flags`, `flagByte(...).bit` | fields | field | No | `flags(...)` with nine members; the ninth `.bit(...)` of one read of a flag byte fails later, when the `Scheme` is built (§7) |
| `BinaryPacker.pack` | scheme, row | bytes | No | `RangeError` for an integer or float that does not fit its width or is not a number, a count above 2^53 or a negative one, a `times` list longer than its count, a count whose field pack did not write, or a set flags group that lacks a required member (§7) |
| `BinaryPacker.unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch, a `repeat` or `times` round past the scheme's limits; never throws on bytes (see §7) |
| `Scheme.withLimits`, `maxRounds`, `maxSlots`, `Scheme.DefaultMaxRounds`, `Scheme.DefaultMaxSlots`, type `SchemeLimits` | `{ maxRounds?, maxSlots? }` | a new scheme with those unpack limits | No | `RangeError` for a limit that is not a positive safe integer (§7) |

**Input DTOs**:

```
Value:
  fields: name to number, string, list, dictionary, or absence (required) — absence omits the field
```

**Output DTOs**:

```
Bytes:
  length: number — sum of present field widths
ShortPacket:
  field: string
  needed: number
  left: number
```

### Interface: PackSession

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `load` | 32 bytes | a session, or nothing | No | length other than 32 creates 0 sessions |
| `start` | none, or 16 bytes | 16 bytes | No | a nonce length other than 16 opens 0 sessions |
| `join` | 16 bytes | the waiter | No | length other than 16 joins 0 sessions |
| `pack` | scheme, row | payload the same length as clear pack | No | pack before start or join produces 0 payloads |
| `unpack` | payload, scheme | the row, or the clear-unpack error | No | — |

## 4. Data Access Patterns

No queries and no cache.

**Seed data**: the shared golden hex file.

**Rollback**: deprecate the npm version.

## 5. Implementation Details

**State Management**: clear pack is stateless. Source layout: `walker.ts` is the unpack walker, `pack-fields.ts` the pack walker (split out of `walker.ts` in loop 11), `flag-scope.ts` the construction checks for flag bits (`bindFlagBits`, which also numbers them; `validateFlagScopes` before loop 16) and for where a bool or empty group may stand (`validatePresenceMarks`). Added in loop 13: `ref-scope.ts` binds every `eq` and count id to a member name (`bindReferences`, `refName`), `member-names.ts` refuses a name with two places (`validateMemberNames`), and `rounds.ts` holds the round logic (`validateRoundNesting`, `roundNames`, `roundCount`, `sliceRound`, `refuseLongLists`, `RoundLists`, `appendList`), used by both walkers. Loop 15: the unpack counters (`maxRounds`, `maxSlots`, `slots`) live on `ViewCursor` in `kinds.ts`, and `refuseRound` in `walker.ts` checks them. Loop 16: `flag-bits.ts` holds which flag bits pack sets (`collectFlagBits`, `bitOn`, `flagValueFor`, moved out of `fields.ts`; the dead `scalarChildNames` and `groupOn` of `kinds.ts` are gone), `fields.ts` holds `itemGroup`, `elementOf` and the merge of group objects into the row (`flattenValues`), and `pack-fields.ts` keeps a map of what pack wrote in each scope (`wrote`). A session keeps one send counter and one receive counter.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime data view writes little-endian fields |

**Error Handling Strategy**:
- A short field returns an error and zero values
- Hostile bytes return an error value, never an exception (§7)
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator
- A `when` or count inside a `list` or `dict` element names an earlier field of that element; one with nothing earlier in its scope is a construction error (loop 13). A `list` or `dict` whose element is an unanchored `group` or a `flags` packs and unpacks one object per item (loop 16, AZ-2102); an anchored `group`, a `when` or a `times` as a direct element keeps the old flat path, so an anchored group there throws `missing a` on pack, as does a group inside a `repeat` round given as a list of objects (`g: [{a: 1}, {a: 2}]`)
- A `when`, `repeat` or `times` as a member of `flags` or as the field of a flag bit never sets its bit and is not written, with no error (`bitOn` in `flag-bits.ts`). The owner holds it for the loop that lands the C# work, so the six packages are decided together (AZ-2128, AZ-2120)
- `eq` may name any value field here (float, bytes, utf8, bool), where Java, C++ and Rust take integer or bool only (AZ-2126). An `f32` source is compared as unpack reads it, rounded to 32 bits, so a decimal `eq` such as `0.1` never matches on pack or on unpack
- A bit of the same flag byte placed inside a combined `flags` that is itself the field of a split bit is dropped on pack: `m, m.bit(flags(0, [m.bit(u8 c), u8 d]))` with `{c: 1, d: 2}` packs `01 01 03 02`, with `c` missing (AZ-2135 follow-up, open)
- Two declarations of one member name inside the same `when` body still build (the check only refuses a second declaration in the same scope outside a `when`), and the value is written twice (AZ-2188)
- A lone non-list value for a name in a round is broadcast to every round, pinned by a test; C# packs it into round 0 only (AZ-2182). A group written as a nested object inside a round counts as present in every round, so `{mark:{v:[7,undefined,9]}}` throws `missing v`; a round takes flat per-round lists

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time bound set by the input length and, for rounds, a memory bound set by the scheme's round limits (below). It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In TypeScript it is a short-packet result built by `unreadable` in `walker.ts` (and `readUtf8` in `kinds.ts`): the counted field, `needed` 0, the bytes left. A `times` round uses the name of its first body field as the label, a list or dict element uses the list's name. A count read from a `u64` or `i64` field is a `bigint`; `countNumber` and `validCount` in `kinds.ts` turn it into a number while a number holds it exactly (2^53 - 1 at most) and refuse a count above that, a negative one and the `i64` minimum, for `sized`, `bits`, `packed` and `times` alike (loop 16, AZ-2112: before, only `bits` accepted a `bigint`). Unpack returns the interim bad-value error for such a count, and pack throws a `RangeError`, so a row that unpack returned packs again.

**Construction rule**: a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body sees the bytes read before it, but a flag byte read inside a `when` is not visible after it. The `Scheme` constructor runs `bindFlagBits` (`flag-scope.ts`) on the flattened fields; a violation is a `RangeError`. `bindFlagBits` (loop 16, AZ-2135) also numbers the bits. Each read of a flag byte gets an id of its own in the scheme's copy of the fields, and each bit is numbered by its place among the bits that follow that read (`taken`): bit 0 is the first, as in the combined form and in Rust and C++. A `flagByte(name)` handle therefore holds no bit (`.bit(field)` returns a bit numbered 0 that the scheme renumbers): it can be a member of any number of schemes and can be read more than once, and a second read starts its own bits (`[m, m.bit(a), m, m.bit(b)]` with only `b` set packs `01 00 01 09`). Bits nested in one another number the outer one first, a bit created before another but placed after it takes its place in the scheme, and the ninth bit of one read throws `flag byte "m": ninth bit (f8); a flag byte holds 8 bits` when the scheme is built, not when `.bit(...)` is called (a handle can be shared, so `.bit` cannot count). A bit with no flag byte to follow is named by the number of bits met so far for that handle (`flag bit 0 (a): its flag byte is not read earlier in the same scope`). The scheme's copies carry the new ids, so `Scheme.fields` shows bits numbered for that scheme.

**Bool rule** (loop 12). A `bool` or an empty group is a mark with no bytes, only a flag bit. It is allowed only as a direct member of `flags` or the field of a flag-byte bit; anywhere else (top level, a non-empty group, `when`, `repeat`, `times`, a list or dict element) `validatePresenceMarks` throws a `RangeError` naming the member. Its bit is set only for `true` (`bitOn` in `flag-bits.ts`): `false`, no value, and any other value (`1`, `"yes"`) leave it clear. Unpack sets the member to `true` only under a set bit; a clear bit leaves it out of the row. A ninth bit throws a `RangeError`: `flags(...)` with nine fields when it is declared, and the ninth bit of one read of a flag byte when the `Scheme` is built (before loop 16, at the ninth `.bit(...)` call).

**Constructor** (loop 12). `new Scheme(typeNumber, fields)` runs every check: the type number (0..255), `validateFieldIds`, then `bindFlagBits(flatten(...))` (`validateFlagScopes` before loop 16), `validatePresenceMarks`, `validateMemberNames` and `validateRoundNesting` (the last two since loop 13) on the flat list, and `bindReferences` last. `scheme(...)` only calls it, so both refuse the same schemes with the same message. `Scheme.fields` holds the flattened fields, with the `when`, `sized`, `bits`, `packed` and `times` fields as copies that carry their bound member name.

**Reference scope** (loop 13, `ref-scope.ts`). Every `eq` field id, and the count id of `sized`, `bits`, `packed` and `times`, names a value field read earlier in the same scope: the top level, a `repeat` or `times` body, a `list` or `dict` element, or an unanchored group (its ids restart at 0). `flags`, flag bits, an anchored group and `when` share the scope around them, and a nested scope is closed in both directions. A count must name an integer (`int` or a `u2` slot); `eq` may name any value field. A later field, an unknown id, an outer field from inside a body, and a field of an earlier nested scope are a `RangeError` naming the referring and the referenced id. `bindReferences` runs last in the constructor and gives the scheme a copy of each reference field with the member name filled in (`Scheme.fields`; `index.d.ts` is unchanged), so pack and unpack no longer search the scheme for an id on every call. `eq` compares numbers and bigints by value (`sameValue` in `kinds.ts`): `1`, `1n` and an unpacked `1n` match, so a `u64` source works.

**Range checks** (loop 13, `writeInt` and `writeFloat` in `kinds.ts`). Pack refuses with a `RangeError` that starts with the member name: a value that is not a `number` or `bigint` for an integer field, a number that is not a safe integer, a number or bigint outside the width and sign (an integer number past 2^53 that fits the width gets "pass a bigint"), a `bigint`, string or other non-number for a float, and a finite value an `f32` would turn into an infinity. NaN and the infinities pass for floats, and `-0` packs as `0`. The check is made before the field is written, so a failed pack returns no bytes and a failed `PackSession.pack` leaves the pad position alone. Unpacked `u64` and `i64` rows pack again, also where a `u64` or `i64` drives a count (loop 16).

**Written values** (loop 16, AZ-2197; `pack-fields.ts`). Pack decides every `when` and count from what it wrote in the scope, as unpack does from what it read. `packFields` takes a `wrote` map for the scope (the top level, a round, a list or dict item), a field enters it when it is written, and a `when` or count reads only that map. A `when` on a skipped or absent field sees `undefined`, so it does not match, and `eq(id, undefined)` matches an absent field, as on unpack; `eq(boolId, false)` on a clear bit does not write its body; an `f32` is recorded rounded to 32 bits (`Math.fround`), as unpack reads it. A count whose field was not written throws a `RangeError` (`<member>: count <name> was not written`). A `times` list longer than its count throws a `RangeError` before the round is written (`refuseLongLists` in `rounds.ts`: `x: 3 items, times count 2`; AZ-2185).

**List and dict elements** (loop 16, AZ-2102, AZ-2184; `fields.ts`, `pack-fields.ts`, `walker.ts`). An unanchored `group` element, and a `flags` element (`elementOf` holds it as an unanchored group of its own), is an item group (`itemGroup`): pack walks each item's own members (`packItem`; an item that is not an object throws `<list>: expected an object for each item`) and unpack returns one object per item, with the same bytes as Python. A list or dict element is a scope of its own for ids, references, flag bytes and member names. `flattenValues(values, fields)` merges into the row only the declared members of a declared group that is given as an object; the entries of a dict and the items of a list are values, so a key cannot overwrite or supply a row member, and a member given both flat and inside its group object takes the group object's value. An own `__proto__` key from `JSON.parse` stays an ordinary key (`copyKeys` defines it).

**Member names** (loop 13, `member-names.ts`). A row is one flat map: the members of a group are merged into the row beside the group's own name. A name declared inside an unanchored group and anywhere else, including a group named like one of its children or like a member of another unanchored group, would let one value overwrite the other, so the constructor throws a `RangeError` naming the member. An anchored group, `when`, `flags`, `repeat` and `times` share the place around them, so two `when` branches may write one member. Since loop 16 (AZ-2188) a name declared twice in one place is refused too (`member a: declared twice in one scope; ...`), unless one of the two sits under a `when`: `u8 a` beside an anchored `group` holding `u8 a`, `u8 x` beside a `repeat` holding `u8 x` and an anchored group named like its own child no longer build. A `list` or `dict` element is a row of its own and has a namespace of its own, checked by the same rules.

**Flags in groups** (loop 13, `fields.ts`). `flatten` also flattens the members of a `flags`, and `collectFlagBits` descends into groups and into a flag bit's field, so a `flags` inside an anchored or unanchored group is packed (`{a:1, g:{b:2, c:3}}` packs `0101020103`). Since loop 16 (`flag-bits.ts`; AZ-2128, AZ-2183) `bitOn` is true when the field holds a value at any depth: a group is on for its own name or any member, nested groups and `flags` included, a `u2` for any slot, and `bits`, `sized`, `packed` and the scalar kinds for their own value; a `bool` or an empty group is on only for `true`. A set group that lacks a required member throws `missing <name>`. `flags` under a split flag bit and a `flags` directly inside `flags` pack their values (`{g:{a:7, c:2}}` under a split bit packs `01 01 07 01 02`). A `when`, `repeat` or `times` never sets a bit (held, see §7). The value of a flag byte is walk state only: unpacked rows have no `""` key, no `motion` key for a split-form byte, and no list of flag bytes inside a round.

**Round limits** (loop 15, AZ-2217; `index.ts`, `kinds.ts`, `walker.ts`). A `Scheme` carries `maxRounds` (default `Scheme.DefaultMaxRounds`, 65,535) and `maxSlots` (default `Scheme.DefaultMaxSlots`, 4,194,304). `scheme.withLimits({ maxRounds, maxSlots })` returns a new `Scheme` with the same type number and fields; a member left out takes the default, not the receiver's value, so two chained calls drop the first, and the receiver is unchanged. The constructor takes the same object as an optional third argument (`SchemeLimits`, exported), and `scheme(...)` does not. A limit that is not a positive safe integer throws a `RangeError` (`checkedLimit`); there is no unlimited value. `unpackBody` puts both limits and a slot counter on the call's `ViewCursor`, and the `repeat` and `times` branches of `unpackFields` call `refuseRound(cur, started, width)` as each round starts, before the round is read or padded; `width` is the size of `roundNames` of the body. The round that would be the 65,536th of one field, or would take the slot total past `maxSlots`, returns `unreadable(...)` (the first body field's name, `needed` 0, the bytes left): no row, no handler call. A `times` count is not refused up front. Dispatch uses the limits of the matched handler's scheme.

**Rounds** (loop 13, `rounds.ts`). A round is addressed by index. The names a round can hold are its own fields and those under `when`, `flags`, flag bits and groups. Pack reads item i of each name's list for round i (`sliceRound`), so a `when`, flags or group inside a round packs (it threw); a `repeat` runs as many rounds as its longest list and a `times` its borrowed count. Unpack builds one list per name with one entry per round, `undefined` where the round skipped it (`RoundLists`, padded as rounds set values; `JSON.stringify` shows `null`), and a bool under flags is `true` or `undefined`. A `when` or count read inside a round sees only that round's own value, with no fallback to a same-named outer value. `validateRoundNesting` refuses a `repeat` or `times` inside a round, directly or under `when`, `flags`, a flag bit or a group, with a `RangeError` naming the nested container; a `list` or `dict` element starts outside any round. `walker.ts` and `pack-fields.ts` call `rounds.ts`; the branches that handle a nested round there are unreachable while the refusal stands (Java packs and unpacks nested rounds since AZ-2127; TypeScript has no spec to lift its refusal).

**Package layout** (loop 16, AZ-2103; `package.json`, `tsconfig.build.json`). The npm package ships compiled ES-module JavaScript and `.d.ts` files, not the `.ts` sources. `tsconfig.build.json` compiles `src` to `dist` (`target` ES2022, `module` and `moduleResolution` NodeNext, `strict`, `declaration`, `rewriteRelativeImportExtensions`, `rootDir` `src`, `outDir` `dist`); the relative `.ts` specifiers become `.js` in the JavaScript, and the `.d.ts` files keep `./x.ts` specifiers. `package.json` has `exports` `{".": {"types": "./dist/index.d.ts", "import": "./dist/index.js"}}` (only the `packbin` entry point, so `packbin/src/...` fails with `ERR_PACKAGE_PATH_NOT_EXPORTED`), `types` `./dist/index.d.ts`, `files` `["dist", "README.md"]` and the script `build` (`tsc -p tsconfig.build.json`). `dist/` is never committed (`.gitignore`). The publish build phase (`publish-inside.sh`) copies `typescript/` without `node_modules` and `dist`, sets the version, runs `npm ci --ignore-scripts && npm run build` in the copy from the committed lockfile and then `npm pack`; `publish-check.py` requires `package/dist/index.js` and `package/dist/index.d.ts` and no `package/src/`. Repo-internal users still run from `src` (the tests with `node --test`, the CI drivers with `--experimental-strip-types`, `publish-position.sh`). A consumer needs TypeScript 5.0 or newer unless it sets `skipLibCheck`, and in a TypeScript project must annotate the accessor parameter (`(x: Target) => x.sid`): the helpers do not infer the row type, so `x` is `unknown` (TS18046 under `strict`, TS2339 without it); a default type parameter is an open owner decision.

**Breaking changes for callers, loop 11** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.

**Breaking changes for callers, loop 12**:
- A `bool` or empty-group mark that is `false` (or any value other than `true`) packs a clear bit (`0100`, was `0101`), as in Python. Unpack leaves the member out; it used to read `true`.
- A `bool` or empty group outside a flag bit is refused at construction. It never round-tripped: it always unpacked `true`.
- A ninth flag bit is refused when declared. Pack used to write it, and the package's own unpack then failed with trailing bytes.
- `new Scheme(...)` refuses what `scheme(...)` refuses, and its `fields` is the flattened list. The constructor used to run no check.

**Breaking changes for callers, loop 13**:
- Pack throws a `RangeError` for an integer outside its width, a non-integer or a number past 2^53 in an integer field, a `bigint` or string in a float field, and an `f32` overflow. It wrapped or coerced before. Numbers above 2^53 go as a `bigint`.
- `scheme(...)` and `new Scheme(...)` refuse a `when` or count that names a later field, an unknown id, a field of another scope or (for a count) a bool or float. They also refuse a member name used inside an unanchored group and outside it, and a `repeat` or `times` inside a round. Before, a bad id threw at pack or a `when` never matched.
- The unpacked row has no `""` or flag-byte member. In a round, every name the round can hold is a list with one entry per round, `undefined` for a skipped round (it appended only the rounds that set it). A `sized`, `bits` or `packed` whose count is a field of the same round now unpacks (it failed with `needed 0`).
- A `when` in a round reads only the round's own value (it fell back to a same-named outer value).
- `Scheme.fields` holds copies of the five reference kinds, with `nameById` and the `allFields` parameter of `unpackFields` removed (internal; `index.d.ts` is identical).
- Unpack of a round costs about 8 bytes times the names a round can hold times the packet bytes in memory (1 MB zero packet with a 36-name `when` body: 299 to 313 MB heap, 11 to 19 MB before); linear, not count-driven. Capped by the round limits since loop 15.

**Breaking changes for callers, loop 15** (AZ-2217; pack output and the bytes of every packet within the limits are unchanged):
- Unpack refuses a packet whose `repeat` or `times` starts more than 65,535 rounds, or whose rounds hold more than 4,194,304 slots together, until the scheme raises the limits with `withLimits`.

**Breaking changes for callers, loop 16** (AZ-2112, AZ-2102, AZ-2183, AZ-2184, AZ-2185, AZ-2188, AZ-2197, AZ-2128; the bytes of a row that packed before are unchanged except where noted):
- A count (`sized`, `packed`, `times`) can come from a `u64` or `i64` field; a count above 2^53, or a negative one, is refused (error value on unpack, `RangeError` on pack).
- `list` and `dict` accept a `group` or `flags` element, one object per item. A dict key or list item no longer joins the row, so a key cannot overwrite a row member any more.
- `times` pack throws a `RangeError` for a list longer than the count (it dropped the extra entries).
- A member name declared twice in one scope fails at construction (`u8 a` plus an anchored `group{u8 a}`, `u8 x` plus `repeat{u8 x}`, an anchored group named like its own child built before).
- A flags group is on when any value inside it is present at any depth; flags under a split flag bit and `flags` directly inside `flags` pack their values (they were dropped, and a group holding only `u2`, `bits`, `sized` or `packed` left its bit clear).
- Pack decides each `when` from the fields it wrote: a `when` on a skipped field no longer matches, `eq(boolId, false)` on a clear bit no longer writes its body, and a count whose field was not written throws `<member>: count <name> was not written`.
- Split-form flag bits are numbered by their place in the scheme (AZ-2135): a handle shared by two schemes no longer shifts the second one (`[m, m.bit(x)]` with `x` = 5 packed `010105` and `010205`, now `010105` twice), a bit created early but placed late takes its place (`[m, early, late]`, only `late` set: `010209`, was `010109`), and a second read of a flag byte starts its own bits (`01000109`, was `01020209`). The ninth bit of one read throws when the scheme is built.
- The npm package holds compiled JavaScript and `.d.ts` files and exports only `packbin` (AZ-2103); versions published before ship `.ts` sources that plain Node cannot import.

**Potential race conditions**:
- None

**Performance bottlenecks**:
- The same AC-10 loop, on one core, in this language

## 8. Dependency Graph

**Must be implemented after**: the golden fixture file

**Can be implemented in parallel with**: the other five language packages

**Blocks**: the first version tag, together with the other five language packages

## 9. Logging Strategy

| Log Level | When | Example |
|-----------|------|---------|
| none | the library returns the error | the caller logs the three error fields |

**Log format**: none inside the package

**Log storage**: none

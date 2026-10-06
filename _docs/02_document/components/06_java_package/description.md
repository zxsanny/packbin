# Java package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for a Java program.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's Java program. Kotlin is not this package.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme` | type number, row class, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, a flag bit whose flagByte is not read earlier in the same scope (a nested row is a scope of its own: a byte read inside it belongs to it, and one read outside it is not visible inside), a ninth bit in one read of a flagByte, a `when` or count that does not name an earlier integer or bool field in its scope, a `bool` or empty group that is not a direct flag bit, an empty `group(anchor)`, or a nested `group(get, set, fields...)` on a typed row or below a nested row that has a child factory, also as the element of a `list` or `dict` there (see §7). Each is an `IllegalArgumentException` |
| `BinaryPacker.pack` | scheme, row | bytes | No | `IllegalArgumentException` naming the field id for an integer out of range, a `BigInteger` that would wrap, a fraction, a string or boolean for a number, a finite value too large for `f32` or `f64`, a `times` list longer than its count, an inner `repeat` written a second time in one call, a nested row that is `null` or absent (`missing group`) or a `null` element of a list or dict of nested rows (`missing list element 1`, `missing dict element "b"`), or a set flags group that lacks a required value (§7) |
| `BinaryPacker.unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch, a `repeat` or `times` round past the scheme's limits; never throws on bytes (see §7) |
| `Scheme.withLimits`, `maxRounds()`, `maxSlots()`, `Scheme.DEFAULT_MAX_ROUNDS`, `DEFAULT_MAX_SLOTS` | `maxRounds` (int), `maxSlots` (long) | a new scheme with those unpack limits | No | `IllegalArgumentException` for a limit below 1 (§7) |

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

**Rollback**: drop the Maven Central version from new consumers. Central does not delete a published version.

## 5. Implementation Details

**State Management**: clear pack is stateless. Unpack keeps the flag bytes it reads in the call's own map, keyed by flag group, so a scheme holds no per-call state and is shared by threads (two threads, 200 000 unpacks each, in the race test). Source layout: `Walker.java` walks fields, `Containers.java` holds `list` and `dict`, `VarFields.java` the counted fields and the `times` count, `Rounds.java` the `repeat` and `times` rounds, `Cursor.java` (loop 15) the read position and round budget of one unpack call, `Scalars.java` the numbers, `SchemeOrder.java` the construction checks (id order, references, bool and empty-group placement) and `SchemeOrder.bindFlagBits`, which checks the flag scope and numbers the split bits (loop 16). A session keeps one send counter and one receive counter.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime writes little-endian fields |

**Target platform** (loop 14, AZ-2094): the jar targets Java 17 and Android API 26. `java/test.sh` compiles main and tests with `javac --release 17`, and the publish build (`publish-inside.sh`) compiles the jar and its javadoc with `--release 17`; `publish-check.py` reads class major version 61 from the class bytes. Main sources may use no API above Android API 26: `java/api-check.sh` runs Animal Sniffer 1.28 (`java/tools/ApiCheck.java`) with the `android-api-level-26` signature on the compiled main classes, inside `java/test.sh`. The tool jars and the signature are pinned by version and SHA-256 and fetched from Maven Central by `java/tools/Fetch.java` into `java/out/api-tools` (gitignored, kept between runs); a hash mismatch fails the check. Replacements that keep the wire bytes and the immutability: `Containers.compareUnsigned` for dict key order (unsigned UTF-8 bytes, then length; `Arrays.compareUnsigned` needs API 33), `Field.immutableCopy` for `Field.children`, `Field.slotIds` and `Scheme.fields` (unmodifiable copy that rejects null items, as `List.copyOf` does; that call needs API 30), and `((Buffer) buf).flip()` in `Walker` (under `--release 17` the `ByteBuffer.flip()` call resolves to a Java 9 method that API 26 lacks).

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
- A count may name a bool field and the scheme builds, but Java does not read a bool as a 0/1 count: pack throws `IllegalStateException` and unpack returns a `ShortPacket` (open on AZ-2126)
- An anchored `group` or a `flags` element of a `list` or `dict` on a typed row (S4, S5) still unpacks into a `Map` (a new `HashMap`), and so does an element group of a `Map` scheme with no factory (S8), so typed accessors in them fail with `ClassCastException` at unpack. Construction cannot tell typed accessors from `Map` accessors, so AZ-2235 refuses only a nested-row element group `group(get, set, fields...)` that has no factory on a typed row (§7); the owner has options B to D for the rest. An anchored-group element of a typed list that itself holds a nested-row element group without a factory is not refused either (every element scope is checked as untyped)
- An inner `repeat` has no end marker, so pack refuses only the second write of the same inner `repeat` in one call. A `repeat` that one outer round reaches while later rounds follow, and a field written after an inner `repeat`, still pack bytes that read back differently (AZ-2127; owner call)
- A `when`, `times` or `repeat` as a `flags` member never sets its bit and is not written, held by the owner for the loop that lands the C# work (AZ-2128, AZ-2120)

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time bound set by the input length and, for rounds, a memory bound set by the scheme's round limits (below). It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In Java it is a `ShortPacket` and the numbers differ by case: an absent or negative count reports `needed` as `Integer.MAX_VALUE`, invalid UTF-8 reports `needed` as the string length with `left` 0, and a zero-width `times`, `list` or `dict` round reports `needed` 0. A zero-width `times` round is labelled with the `times` field, a list or dict element with `""`. Counts stay `long` until compared with the bytes left.

**Construction rule**: a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body sees the bytes read before it, but a flag byte read inside a `when` is not visible after it. `Scheme`'s constructor runs `SchemeOrder.validate` and then `SchemeOrder.bindFlagBits` (`requireFlagBytes` before loop 16); a violation is an `IllegalArgumentException` that names the bit by kind and id (`flag bit U8 0 has no flagByte before it in the same scope`).

**Split-bit numbering** (loop 16, AZ-2135; `SchemeOrder.bindFlagBits`, `Field.java`). A bit is numbered by its order among the bits of the flag byte read it follows, as in Rust and C++, so `Field.bit(field)` returns an unbound bit and the `flagByte()` handle holds none: it can be a member of any number of schemes and can be read more than once. `bindFlagBits` walks the fields with a map from the handle to the latest read this point can see, gives every read of every scheme a `FlagGroup` of its own (`withGroup`, `withChildren` rebuild the fields; `Scheme.fields` holds the rebuilt copies) and reserves the next position of that read for each bit (`FlagGroup.reserve`, at most eight, so the ninth bit throws `IllegalArgumentException("flags already has 8 bits")` when the scheme is built, not at `.bit(...)`). A second read starts its own bits (`[m, m.bit(a), m, m.bit(b)]` with only `b` set packs `01 00 01 09`, it packed `01 02 02 09`), a bit created early but placed late takes its place in the scheme (`[m, early, late]`, only `late` set: `01 02 09`, was `01 01 09`), and bits nested in one another number the outer one first. The visible reads are copied at a `when` body, a `flags` member and a flag bit's field and are shared by an anchored group, so a byte read inside one of them is not visible after it; a nested row (`group(get, set, ...)`), a repeat, times, list or dict element starts with none. A nested row is a scope of its own for flag bytes (AZ-2233): a byte read inside it belongs to that row and is not visible after it, and a byte read before the row is not visible inside it, so the row reads its own byte (`[m, m.bit(a), group(g, m, m.bit(x)), m.bit(b)]` with `{a: 1, g: {x: 2}, b: 3}` packs `01 03 01 01 02 03`). A bit inside a nested row whose only flag byte was read outside it fails when the scheme is built, `flag bit U8 0 has no flagByte before it in the same scope`; `[m, group(g, m.bit(x))]` used to build, pack `01 00 05` for `{g: {x: 5}}` and read back as trailing bytes. The rule is by scope, not by what the member is: `[m, group(identity(), ignore(), m.bit(x))]`, whose member is the row itself, fails too, and `group(identity(), ignore(), m, m.bit(x))` packs `01 00 01 05`.

**Reference and placement rules** (loop 12). `SchemeOrder.validate` resolves references while it walks the fields, one scope at a time: the top level, each `repeat` or `times` round, each `list` or `dict` element, and each nested row (`group(get, set, ...)`), whose field ids number from 0 and see no id of the row around it (loop 16, AZ-2101: the nested ids are kept apart from the ids of the row in `seen`, so `u8 profile(0), group(g, u8 inner(0)), when(1, eq(0, 1), u8 shape)` with `profile` 0 packs `010001`, it packed `01000109`). A `when` body, a `flags` bit and an anchored `group` belong to the scope they stand in. A `when` condition or a borrowed count (`sized`, `bits`, `packed`, the count of `times`) may name only an integer or bool field read earlier in its own scope (C++ `is_count_source`); a later field, or an outer field named from inside a round or element, is an `IllegalArgumentException` that names both ids. Construction also refuses:
- a `boolField`, or a group with no fields, that is not a direct bit of `flags(...)` or `flagByte().bit(...)`
- `group(anchor)` with no fields wherever it stands, including as a flag bit: it has no accessor, so its bit could never be set

An empty nested row `group(get, set)` is allowed only as a flag bit and carries presence only: the bit is set when the member is present, and a set bit unpacks as an empty child row (`{g: {x: 1}}` comes back as `{g: {}}`). A non-empty nested row under `flags` sets its bit when its member is present, not when a field inside it is (`groupOn` in `Walker.java`).

**Typed nested rows** (loop 16, AZ-2101; `Packbin.java`, `Field.java`, `SchemeOrder.java`, `Walker.java`). `group(get, set, create, fields...)` takes a `Supplier` for the child row: unpack calls it whenever the member is `null`, in each round of a `repeat` or `times` and for each element of a `list` or `dict` that holds the group, reads the nested fields into it and sets it through `set` (`Walker.newRow`; before, the child of a typed row was a `HashMap` and unpack threw `ClassCastException`). `group(get, set, fields...)` is for `Map` rows only: `SchemeOrder.validate(fields, typedRow)` throws `IllegalArgumentException("nested group on a typed row needs a child factory")` for it on a scheme whose row class is not a `Map`, or below a nested row that has a factory, so a typed row with a `Map` member that used it passes `group(get, set, HashMap::new, ...)`. A factory also works on a `Map` row.

**Element groups on a typed row** (loop 16, AZ-2235; `SchemeOrder.requireElementFactory`). A `list` or `dict` whose element is `group(get, set, fields...)` gets a `HashMap` per item, so the same refusal applies to it, wherever the holding scope is typed (a typed row, a nested row with a factory, and inside a `repeat`, `when`, `flags`, flag bit or anchored group of one): `list element: nested group on a typed row needs a child factory` (`dict element: ...`; an inner list or dict names the container that holds the element). Pass `group(identity(), ignore(), Item::new, ...)`, or `HashMap::new` for `Map` items; the bytes are the same. A `Map` scheme whose nested row has a `Map` factory counts as typed by this rule (pass `HashMap::new` to the element group too). The residual cases are in §7.

**Missing nested values** (loop 16, AZ-2234; `Walker.packGroup`, `Containers.packList` and `packDict`). Pack throws `IllegalArgumentException` for a nested-row member that is `null` or absent, wherever pack reaches it outside `flags` and a flag-byte bit: `missing group` (also for each round of a `repeat` or `times` that has no row for it, a `null` entry included, and for a nested row whose body writes 0 bytes), `missing list element 1` for a `null` element of a list of nested-row groups, `missing dict element "b"` for a `null` value of a dict of them. It wrote nothing for them, and unpack read the same bytes as a different row. `{}`, `{g: null}` and `{g: []}` for a `repeat` of the row still pack `01`: no round is reached, so no row is missing. Under `flags` or a flag-byte bit a `null` member still clears the bit and writes nothing. `PackSession.pack` throws before the send counter moves.

**`u2` in a round** (loop 16, AZ-2234; `VarFields.packU2`). A `u2` inside a `repeat` or `times` round packs the item of each round for each slot (`repeat(0, u2(a, b))` with `{a: [1, 2], b: [3, 0]}` packs `01 0d 02`); it read the whole list and threw `0: expected 2-bit int`. A `u2` outside a round is unchanged.
**Nested rounds** (loop 16, AZ-2127; `Rounds.java`, `SchemeOrder.java`). A `repeat` or `times` inside a `repeat` or `times` round is no longer refused. An inner value field holds one list per outer round (`repeat(u8 n, times(1, 0, u8 v))` with `n = [1, 1]` and `v = [[5], [7]]` packs `01 01 05 01 07`), `null` for an outer round that skipped the group and `[]` for a group that read no round (`foldIntoOuterRound`, `entryCounts`). The inner rounds count against the same round and slot limits. A `repeat` has no end marker, so `packRepeat` keeps the repeats a call has written in `seen`, by field, and throws `IllegalArgumentException` (`<anchor>: a repeat has no end marker, so it can be written in one round only`) when the same inner `repeat` would be written a second time; an inner `times` is fine under any number of outer rounds.

**Times, longer list** (loop 16, AZ-2187; `Rounds.packTimes`). Pack throws `IllegalArgumentException` before the rounds are written when a body field's list is longer than the count (`1: list has 3 entries for a count of 2`; a member without a field id is named by its kind, `group: ...`). It dropped the extra entries.

**Strict pack** (loop 16, AZ-2190; `Scalars.java`). Pack writes an integer field only for a whole number inside its range and a float field only for a number, and every refusal is an `IllegalArgumentException` that names the field id: an integer out of range (it threw `ArithmeticException`), a `BigInteger` that wrapped (2^63 into `i64`), a fractional `BigDecimal` (1.5 was cut to 1), a string or boolean for an integer or float (a `ClassCastException` for a float), and a finite value too large for `f32` or `f64` (an `f32` wrote an infinity). Only a `Float` or `Double` that is itself infinite is an explicit infinity, and `NaN` and the infinities are written as given. A `Long` of -1 is still accepted for `u64`: it is the bit pattern, so unpack then repack works (an `Integer` of -1 is refused). The same checks run in `PackSession.pack`.

**Flag group presence** (loop 16, AZ-2128; `Walker.childOn`). A bit under `flags` is on when any value inside its member is present, at any depth: a `u2` slot, a nested `flags` and a group holding them count (they were dropped, `0100`), a split bit in a group counts, and a set group that cannot be written in full fails pack naming the missing value. A `when`, `times` or `repeat` member never sets a bit (held, see §7).

**Bool bit**: the bit is set only for `Boolean.TRUE`; `false`, an absent value and any other value (`1`, `"true"`) leave it clear. A set bit unpacks as `Boolean.TRUE` in both the combined (`flags`) and the split (`flagByte`) form; a clear bit stores nothing. A split bit inside a `when` that is not taken is still set from the row on pack, and unpack tests the `when` first and never reads it (shared `bitwhen` vector: `{k:0, v:5}` packs `010001` and unpacks as `{k:0}`; `{k:1, v:5}` packs `01010105`).

**Repeat and times rounds** (loop 12, `Rounds.java`). A round packs item i of every body field's list, and a flag bit in the round is decided from that item. The `repeat` round count is the longest list among the body's value fields, looking through `flags`, flag bits, `when` and anchored groups. Each round removes the body's values from the call's `seen` map, so a `when` or count never matches an earlier round's value. Unpack keeps one list entry per round for every value field of the body, `null` where the round skipped it, so packing the unpacked row gives the same bytes. The `null` padding is one store per round, linear in the packet length.

**Round limits** (loop 15, AZ-2218; `Scheme.java`, `Cursor.java`, `Rounds.java`). A `Scheme` carries `maxRounds` (default `Scheme.DEFAULT_MAX_ROUNDS`, 65,535) and `maxSlots` (default `DEFAULT_MAX_SLOTS`, 4,194,304). `scheme.withLimits(maxRounds, maxSlots)` returns a new scheme over the same fields; both values are taken every time, and the receiver is unchanged. A limit below 1 throws `IllegalArgumentException`; there is no unlimited value. A package-private `Cursor` replaces the `int[] offset` of every unpack method: it holds the position (`pos`) and the slots the rounds of the call have taken, shared by every field of the call, list and dict elements included. `Rounds.unpackRepeat` and `unpackTimes` call `cur.startRound(roundsStarted, slots)` before a round is read, where `slots` is the number of value fields of the body (`values(...)`). The round that would be the 65,536th of one field, or would take the slot total past `maxSlots`, returns `ShortPacket(field.label(), 0, left)` (the label is `"times"` for a `times`, the field id for a `repeat`): no row, no handler call. A `times` count is not refused up front, so a huge count over few bytes still ends in a short read.

**Breaking changes for callers** (loop 11; pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.

**Breaking changes for callers** (loop 12; no wire change for a scheme that round-tripped):
- A `when` or count naming a later field, or an outer field from inside a `repeat` or `times` round, built before. It is now refused at construction.
- A `boolField` or an empty group outside a flag bit, `group(anchor)` with no fields anywhere, and a `repeat` or `times` inside a round are refused at construction (the nested-round refusal is lifted in loop 16, see Nested rounds).
- Unpack of a `repeat` or `times` puts `null` in a body field's list for a round that skipped it (`[7, null, 9]`, was `[7, 9]`).
- A flag bit inside a `repeat` is decided from the round's value; it was decided from the whole list, so `repeat(flags(bool))` packed clear bits.

**Breaking changes for callers** (loop 15, AZ-2218; pack output and the bytes of every packet within the limits are unchanged):
- Unpack refuses a packet whose `repeat` or `times` starts more than 65,535 rounds, or whose rounds hold more than 4,194,304 slots together, until the scheme raises the limits with `withLimits`.

**Breaking changes for callers** (loop 16; the bytes of a row that packed before are unchanged except where noted):
- `group(get, set, create, fields...)` is new; the old `group(get, set, fields...)` on a typed row, or below a group that has a factory, throws `IllegalArgumentException` when the scheme is built (a typed row with a `Map` member that used it must pass `HashMap::new`).
- Field ids of a nested row live in a scope of their own (`010001`, was `01000109`), and under `flags` a nested row's presence is its member alone.
- A `repeat` or `times` inside a round builds and packs; the nested lists have one entry per outer round.
- `times` pack throws for a list longer than the count (the extra entries were dropped).
- Pack throws `IllegalArgumentException` naming the field id where it threw `ArithmeticException` or `ClassCastException`, or wrote wrong bytes (a wrapped `BigInteger`, a cut fraction, an `f32` infinity); code that caught `ArithmeticException` around `pack` must catch `IllegalArgumentException`.
- A `u2`, a nested `flags` and a group holding them under `flags` set the group's bit (they were dropped, `0100`).
- A bit inside a nested row whose only flag byte was read outside it fails when the scheme is built (AZ-2233); a byte read before a nested row is no longer visible inside it. Both built before and packed bytes that unpack read back as trailing bytes (`01 00 05`, or `01 01 05` for an identity member).
- Pack throws where it wrote bytes that unpack read as a different row (AZ-2234): `missing group` for a `null` or absent nested row, `missing list element 1` and `missing dict element "b"` for a `null` element. A `u2` in a round packs the item of each round (it threw).
- A `list` or `dict` of `group(get, set, fields...)` on a typed row, or below a group with a factory, fails when the scheme is built (AZ-2235); pass a factory (`group(identity(), ignore(), Item::new, ...)`).
- Split-form flag bits are numbered by their place in the scheme (AZ-2135), not by the order of the `.bit(...)` calls: a handle shared by two schemes packed `010305` for `[m, m.bit(x)]` with `x` = 5 in both and now packs `010105`, a flag byte read twice no longer shares the numbers of its first read, and the ninth bit of one read fails when the scheme is built.

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

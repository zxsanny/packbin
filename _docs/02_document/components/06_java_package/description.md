# Java package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for a Java program.

**Architectural Pattern**: stateless clear pack, plus frame mode (`FrameSession`), the one session, which the caller holds (ADR 008, ADR 009).

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's Java program. Kotlin is not this package.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme` | type number, row class, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, a flag bit whose flagByte is not read earlier in the same scope (a nested row is a scope of its own: a byte read inside it belongs to it, and one read outside it is not visible inside), a ninth bit in one read of a flagByte, a `when` or count that does not name an earlier integer or bool field in its scope, a `bool` or empty group that is not a direct flag bit, an empty `group(anchor)`, a nested `group(get, set, fields...)` on a typed row or below a nested row that has a child factory, also as the element of a `list` or `dict` there, a `when` whose `eq` value its integer source can never hold (loop 19, AZ-2338), or a member key set twice through `Access.set("x")` in one scope outside every `when` (see §7). Each is an `IllegalArgumentException` |
| `BinaryPacker.pack` | scheme, row | bytes | No | `IllegalArgumentException` naming the field id for an integer out of range, a `BigInteger` that would wrap, a fraction, a string or boolean for a number, a finite value too large for `f32` or `f64`, a `times` list longer than its count, an inner `repeat` written a second time in one call, a nested row that is `null` or absent (`missing group`) or a `null` element of a list or dict of nested rows (`missing list element 1`, `missing dict element "b"`), a set flags group that lacks a required value, a `times` count above `maxRounds`, a lone byte buffer in a round, a `times` count of 0 with a list of values and a body that a clear split flag bit would drop (loop 19; §7), a packet above `maxBytes`, a round that would pass `maxSlots` and a `repeat` list above `maxRounds` (loop 20, AZ-2354, AZ-2355), a combined `flags` `times` whose count was skipped while values are given (loop 20, AZ-2360), a `Long`, `BigInteger` or `BigDecimal` that a `u2`, `bits` or `packed` slot would cut, and a `u64` count above the `int` range for `sized` or `bits` (loop 20, AZ-2361) |
| `BinaryPacker.unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch, a `repeat` or `times` round past the scheme's limits; never throws on bytes (see §7) |
| `Scheme.withLimits`, `maxRounds()`, `maxSlots()`, `Scheme.DEFAULT_MAX_ROUNDS`, `DEFAULT_MAX_SLOTS` | `maxRounds` (int), `maxSlots` (long) | a new scheme with those limits (unpack and pack); `maxBytes` goes back to the default | No | `IllegalArgumentException` for a limit below 1 (§7) |
| `Scheme.withMaxBytes`, `maxBytes()`, `Scheme.DEFAULT_MAX_BYTES` | `maxBytes` (long) | a new scheme with that pack output budget, type byte included, and the same rounds and slots (loop 20) | No | `IllegalArgumentException` `maxBytes must be at least 1` |

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

### Interface: PackSession (removed in loop 74)

Retired (loop 74, AZ-3282, ADR 009): the stream session `PackSession` (`load` of a 32-byte seed, `start` and `join` with a 16-byte nonce, `pack` and `unpack` of payloads the length of clear pack, no tag) is removed with `PackSession.java`, `SessionTest.java` and `HostileSessionTest.java`; `javap -public` over `java/out/main` shows none of `PackSession`, `start(`, `join(`, the seed and nonce sizes. Frame mode (below) is the one session.

### Interface: Error correction (loop 38, ADR-007, `contracts/library/message-ecc.md`)

Optional parity bytes per scheme: `n` from 0 to 32, default 0, which keeps the bytes, the errors and the speed of an unprotected scheme. `n` is not on the wire. C++ is pending (AZ-2688).

| Name | Meaning |
|------|---------|
| `Scheme.withParity(int)` | a copy with `n` parity bytes, limits kept; `withLimits` and `withMaxBytes` keep the count. A value outside 0 to 32 throws `IllegalArgumentException`. `parity()` reads it |
| `BinaryPacker.unpackRepair(byte[], int limit, Scheme.Handler<?>...)` | repairs up to `limit` wrong bytes (0 to `n / 2`) before the type byte picks the handler; `unpack` is limit 0 and returns `null` when it reads. Another limit, or a mix of counts, throws `IllegalArgumentException` before any byte is read |
| `Packbin.Repaired` | returned by `unpackRepair` when the message reads; `count` is the bytes repaired (0 for an intact or unprotected message) |
| `Packbin.Uncorrectable` | returned when more bytes are wrong than `limit` allows; names no field |
| `Packbin.TooLong(length, limit)` | returned for a buffer above 254 bytes. A buffer shorter than `n` is `Packbin.ShortPacket("parity", n, present)` |

- **Pack**: a clear message above `254 - n` bytes throws `IllegalArgumentException` naming the length and the limit.
- **Dispatch**: all handlers of one call declare the same `n`; a mix throws, naming both counts. With one `n` the message is repaired first, then dispatched.
- **Session** (retired, loop 74, ADR 009): the stream session's protected payload (pad, then parity) went with `PackSession`; `message-ecc.md` 1.0.1 has no session row.
- **`t` and detection**: `t` defaults to 0 and then any corruption of up to `n` wrong bytes is detected. A `t` above 0 repairs up to `t` wrong bytes but gives up detection: corruption of `t + 1` to `n - t` bytes is still refused, a larger corruption may be repaired to a different message. The contract table lists the chance (`n` = 4: 1 in 4.29e+09 at `t` = 0, 1 in 990,537 at `t` = 1, 1 in 485 at `t` = 2). `t` above `n / 2` is an error before any byte is read.
- **Size and speed**: a message is at most 254 bytes, parity included; pack refuses a clear message above `254 - n` bytes and writes nothing. Unpack of hostile bytes does at most about 3 x 255 x 32 field operations beyond the unprotected walk and never throws or traps on them. Acceptance bound EC-13 (a bound, not a recorded measurement): 1,000 unpacks with correction of a 254-byte message with 16 parity bytes and 8 wrong bytes in 1 second; 1,000 packs of such blocks in 1 second.

### Interface: FrameSession (loop 71, AZ-3233; the only session since loop 74)

Public types (the D1 names, top-level since AZ-3290, loop 74): `FrameSession`, `FrameDirection` (an enum `UP`, `DOWN`, `GROUP`, wire byte 1, 2, 3; it replaced the `int` constants `FrameSession.UP`, `DOWN`, `GROUP`), `FrameSlot` (`CURRENT`, `PREVIOUS`), `FrameOpened`, `FrameSealed` (Java's seal result; `FrameSlot`, `FrameOpened` and `FrameSealed` were `FrameSession.Slot`, `Opened`, `Sealed`), `MsgContext`, `ReplayWindow`, `Freshness` (moved out of `ReplayWindow`), `MacKey`. Java has no `FrameConfig` and no `FrameDirections`: load takes the tag length and the directions as arguments.

| Name | Meaning |
|------|---------|
| `FrameSession.load(key, epoch, tagLen, FrameDirection... directions)` | a session, or `null` for a value out of range; a `null` direction is refused; `setPrevious(key, epoch)`, `clearPrevious()`, `close()` (wipes the keys; later calls give `BadValue`) |
| `seal(FrameDirection, MsgContext, ad, clear, plain, out)` (and an `outOffset` form) | a `FrameSealed` (with `length`) or an error object; writes nothing on a refusal; safe from many threads |
| `open(FrameDirection, MsgContext, ad, body, clearLength, ReplayWindow, counter, out)` (and a ranged form) | a `FrameOpened` (`slot`, `clearLength`, `plainLength`) or an error object; a null window skips the replay check; a direction the session did not load is `BadValue` |
| `ReplayWindow` | `check(counter)` (`Freshness.FRESH`, `DUPLICATE`, `TOO_OLD`), `commit(counter)`, `top()`, `bits()`; unsigned counters |
| `MacKey.derive(key, epoch, label)`, `tag(out, parts...)`, `verify(tag, parts...)`, `close()` | tags of 4, 8, 16 or 32 bytes |
| `Packbin.BadValue`, `BufferFull`, `TagMismatch`, `Duplicate`, `TooOld` | new nested error classes beside `Uncorrectable`; `TooLong` and `ShortPacket` are the existing ones |

Files: `java/src/main/java/packbin/FrameSession.java` (352 lines), `MacKey.java` (96), `ReplayWindow.java` (87), `FrameCrypto.java` (84), `MsgContext.java` (26); `SessionPad.java` gains overloads (`hkdfSha256` with an info argument, `hkdfExtract`, `hkdfExpand`, `hmac`, a ranged `xor`); since loop 74 it holds only these frame-mode primitives. Loop 74 (AZ-3290) adds `FrameDirection.java`, `FrameSlot.java`, `FrameOpened.java`, `FrameSealed.java` and `Freshness.java`, and `api-check.sh` lists them. `api-check.sh` reports no main-source API above Android API level 26; `java/test.sh` runs the new test classes (`CryptoVectorsTest`, `FrameVectorsTest`, `FrameTamperReplayTest`, `FrameMacRefusalsTest`, `FrameHostileTest`, `FrameLifecycleTest`, `FrameReadmeExample`).

- **Frame mode** (loop 71, contract `pack-session.md` 2.0.0, 3.0.0 since loop 74 with the frame text unchanged; ADR 008, ADR 009): a `FrameSession` (beside the stream session until loop 74, the only session since), a `ReplayWindow` the caller owns (64 messages; `check` never changes state, `commit` only after an `Ok` open) and a `MacKey` for the MAC-only call. Seal and open follow the contract's order (argument checks, then the replay check without any MAC for `Duplicate` and `TooOld`, then the tag with the current key and then the previous key, then decrypt and commit). The bytes equal the Rust ones: the package passes every row of `fixtures/frame/vectors.txt` (157 rows, E1 to E5 included) and the 27 rows of `fixtures/crypto/vectors.txt`. The platform HMAC cannot expose precomputed pad states, so a session holds the 32-byte MAC key per direction and a `MacKey` the 32-byte label key (the contract's 72-byte figure does not apply); the HMAC key schedule runs on each call. Keys are overwritten at Dispose / close (Swift also at deinit; C# and Java have no finalizer); the tag compare is the platform's fixed-time compare (C# on net10.0, Java `MessageDigest.isEqual`) or a fold of every byte with no early exit (C# netstandard2.0, Swift); both are best effort in a managed runtime (stated in the API docs). `open` reads the caller's body once (a copy of at most 255 bytes) in C# and Java. `setPrevious`, `clearPrevious` and `close` must not run beside `seal` or `open`. The `msg_id` uniqueness rule is in the docs of `seal` and of the message context. A test-only counter of MAC computations proves a duplicate or too-old frame costs none (the Rust figure of SHA-256 compressions has no equivalent here). The README example of the package is the code of its example test (`scripts/frame/readme-examples.sh`).
- **Loop 74** (AZ-3282, AZ-3290; ADR 009): the stream session is removed; the mixed files keep their non-session checks (`EccSchemeTest` 14 tests / 41 checks to 7 / 20, `EccDispatchOrderTest` 8 runs / 32 to 6 / 10, `MissingNestedValueTest` 10 / 72 to 9 / 68, `PackStrictTest` 11 / 139 to 10 / 130, `TimesLongerTest` 7 / 27 to 6 / 23); the duplicate-type-before-parity-mix check (AZ-2704 AC-3) runs on `BinaryPacker.unpackRepair`. `java/test.sh` runs 9,725 checks after AZ-3282 (9,815 before). The frame types are top-level with the D1 names and the frame bytes are unchanged (157 of 157 rows).

## 4. Data Access Patterns

No queries and no cache.

**Seed data**: the shared golden hex file.

**Rollback**: drop the Maven Central version from new consumers. Central does not delete a published version.

## 5. Implementation Details

**State Management**: clear pack is stateless. Unpack keeps the flag bytes it reads in the call's own map, keyed by flag group, so a scheme holds no per-call state and is shared by threads (two threads, 200 000 unpacks each, in the race test). Source layout: `Walker.java` walks fields, `Containers.java` holds `list` and `dict`, `VarFields.java` the counted fields and the `times` count, `Rounds.java` the `repeat` and `times` rounds (and since loop 19 the pack cap and the lone-value check; since loop 20 the `repeat` cap and `nameOf`, `roundName`), `ByteSink.java` (loop 20: the pack output with `maxBytes`, `maxSlots` and `maxRounds`; 93 lines changed, it grows in `long` arithmetic and stops at `MAX_ARRAY`, `Integer.MAX_VALUE - 8`; no new main file), `Presence.java` (new in loop 19, moved out of `Walker.java`: `childOn`, `isPresent`, `boolOn`, `conditionHolds` and the split-bit check `requireNothingDropped`; `Walker.java` 464 to 387 lines, `Presence.java` 141, AZ-2342), `Cursor.java` (loop 15) the read position and round budget of one unpack call, `Scalars.java` the numbers, `SchemeOrder.java` the construction checks (id order, references, bool and empty-group placement) and `SchemeOrder.bindFlagBits`, which checks the flag scope and numbers the split bits (loop 16), and `MemberNames.java` (AZ-2246, the member-name check, run last by the `Scheme` constructor; `Access.set(String)` returns the package-private `Access.KeySetter`, which holds its key). A `FrameSession` keeps only its keys; the replay window is the caller's (the stream session's counters went with it in loop 74, ADR 009).

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
- A count that names a bool is refused when the scheme is built since loop 18 (AZ-2126; `requireCount` in `SchemeOrder.java`: `times 1 takes its count from field 0, which is a bool; a count names an integer field`); it built before, then pack threw `IllegalStateException` and unpack returned a `ShortPacket`. A `when` names an integer field, a `u2` slot or a bool; `eq` of a bool against anything but `Boolean.TRUE` fails (`when 1 tests bool field 0 against false; a bool is compared only with true`), and a float, utf8, bytes, sized, bits or packed source is not a count source, so it fails as not an earlier integer field of its scope
- An anchored `group` or a `flags` element of a `list` or `dict` on a typed row (S4, S5) still unpacks into a `Map` (a new `HashMap`), and so does an element group of a `Map` scheme with no factory (S8), so typed accessors in them fail with `ClassCastException` at unpack. Construction cannot tell typed accessors from `Map` accessors, so AZ-2235 refuses only a nested-row element group `group(get, set, fields...)` that has no factory on a typed row (§7); the owner has options B to D for the rest. An anchored-group element of a typed list that itself holds a nested-row element group without a factory is not refused either (every element scope is checked as untyped)
- Only a setter made by `Access.set("x")` has a name (`Access.KeySetter`, `MemberNames`): a typed accessor (`Access.set(BiConsumer)`), a hand-written lambda, `identity()` and `ignore()` have none, so two of them on one key, or `u8 a` beside `group(identity(), ignore(), u8 a)`, still build; `group(g, u8 a)` beside `u8(0, "g")` builds, and a nested row's own key is not a name. The owner's options B (probe a recording `Map`, which runs caller code), C (add names to the API) and D (leave Java as is) are open (AZ-2246)
- A repeated key inside a nested row that itself sits under a `when` builds (`when(1, eq(0, 1), group(g, u8 a, u8 a))`): `MemberNames.walk` passes the under-a-`when` flag into a nested row, like the open item for two declarations in one `when` body, and TypeScript does the same for an unanchored group. A `list` or `dict` element restarts the check, also under a `when` (total review F1, fixed in loop 16).
- An inner `repeat` has no end marker, so pack refuses only the second write of the same inner `repeat` in one call. A `repeat` that one outer round reaches while later rounds follow, and a field written after an inner `repeat`, still pack bytes that read back differently (AZ-2127; owner call)
- A `when`, `times` or `repeat` as a `flags` member, as a flag-bit field, or in a group under them is written since loop 18 (AZ-2120, AZ-2128; `Walker.childOn`; see Flag group presence). Left as decided: a `when` with a false condition drops a given body silently, and a `times` whose count field was skipped drops its values silently in the combined `flags` form (Python and C++ refuse them since loop 19; not decided for Java). A split flag byte decides its `when` or `times` bit where the byte is read; since loop 19 (AZ-2331) pack throws when that leaves the bit clear while the body would be written (see Split bit with a dropped body). Sibling members of one `flags` are separate flag-byte scopes here, in C++, in TypeScript and, since loop 19, in Rust
- A lone dictionary for a `dict` name in a `repeat` or `times` round throws `IllegalArgumentException` naming the member since loop 18 (AZ-2308; `Rounds.java`: `d: a lone dictionary is not a list of rounds; give one dictionary per round in a list`); it was broadcast under `times` and read as one round under `repeat`. A lone `byte[]` for a `bytes` or `sized` name is refused since loop 19 (AZ-2332; `d: a lone byte buffer is not a list of rounds; give one buffer per round in a list`, also in a `times` under `flags` with a count of 0, review B4); a lone `Utf8` string is still broadcast, and a lone `bits` or `packed` list cannot be told from the list of rounds. Pack caps a `times` count at `maxRounds` since loop 19 (AZ-2329); a `repeat` given more entries than `maxRounds` still packs (unpack then refuses it) and `maxSlots` is not applied on pack
- A `BigDecimal` with a fraction, and a `Long` or `BigInteger` above the slot, in a `u2`, `bits` or `packed` slot is refused since loop 20 (AZ-2361; `0: expected 2-bit int`; `1.5` was cut to 1, `0.1` to 0 and 2^32 + 1 to 1), as a `Double` or `Float` there, whole or not, always was. A whole `Double` is refused for an `eq` value too (`5.0`; C# refuses it since loop 20, TypeScript accepts it). An enum is not a number in a slot or an integer field (`0: expected int, got Level`, AZ-2359 pin). A split-bit `times` whose count above 0 is written after the byte, with the body absent or `[]`, is refused here while TypeScript and Python pack a clear bit (review B2, a loop 21 question)

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

**Member names** (loop 16, AZ-2246; `MemberNames.validate`, `Access.KeySetter`). A row holds one value per member name, so a key written twice in one scope loses a value: `u8(0, "x"), u8(1, "x")` packed `01 05 05` and unpacked `01 07 08` to `{x=8}`, which repacked as `01 08 08`; a key outside and inside a `times` round unpacked to a list that could not be packed again, one outside and inside a `repeat` round to a list that failed on repack; `times` then an outer `x` repacked to different bytes without a word. `new Scheme<>(...)` throws `IllegalArgumentException` (`member x: declared twice in one scope; a row holds one value per name, so one would be lost`) when two fields whose setters are `Access.set("x")` sit in one scope outside every `when`. Fields carry no names, so the check reads the key from the setter (the setter is the name, not the getter: `get("a")` with `ignore()` or `set("b")` is a legal echo). The scope is the top level, one nested row or one `list` or `dict` element; rounds, `flags`, flag bits and anchored groups share the scope around them, a `u2` is named by each slot's setter, a `list` or `dict` by its own, and a nested row's own key is not a name. A declaration under a `when` is not counted, so the branches of a chain may share a key. The check runs last (`MemberNames.validate(this.fields)` after `SchemeOrder.validate` and `bindFlagBits`), so every earlier message keeps winning. `Access.set((String) null)` used twice is refused as `member null: ...` (the old lambda accepted a null key). `javap -public` of `Field`, `Scheme`, `Packbin`, `Access`, `PackSession` (retired in loop 74), `BinaryPacker`, `Getter` and `Setter` is unchanged.

**Element groups on a typed row** (loop 16, AZ-2235; `SchemeOrder.requireElementFactory`). A `list` or `dict` whose element is `group(get, set, fields...)` gets a `HashMap` per item, so the same refusal applies to it, wherever the holding scope is typed (a typed row, a nested row with a factory, and inside a `repeat`, `when`, `flags`, flag bit or anchored group of one): `list element: nested group on a typed row needs a child factory` (`dict element: ...`; an inner list or dict names the container that holds the element). Pass `group(identity(), ignore(), Item::new, ...)`, or `HashMap::new` for `Map` items; the bytes are the same. A `Map` scheme whose nested row has a `Map` factory counts as typed by this rule (pass `HashMap::new` to the element group too). The residual cases are in §7.

**Missing nested values** (loop 16, AZ-2234; `Walker.packGroup`, `Containers.packList` and `packDict`). Pack throws `IllegalArgumentException` for a nested-row member that is `null` or absent, wherever pack reaches it outside `flags` and a flag-byte bit: `missing group` (also for each round of a `repeat` or `times` that has no row for it, a `null` entry included, and for a nested row whose body writes 0 bytes), `missing list element 1` for a `null` element of a list of nested-row groups, `missing dict element "b"` for a `null` value of a dict of them. It wrote nothing for them, and unpack read the same bytes as a different row. `{}`, `{g: null}` and `{g: []}` for a `repeat` of the row still pack `01`: no round is reached, so no row is missing. Under `flags` or a flag-byte bit a `null` member still clears the bit and writes nothing. (`PackSession.pack` threw before the send counter moved; retired in loop 74.)

**`u2` in a round** (loop 16, AZ-2234; `VarFields.packU2`). A `u2` inside a `repeat` or `times` round packs the item of each round for each slot (`repeat(0, u2(a, b))` with `{a: [1, 2], b: [3, 0]}` packs `01 0d 02`); it read the whole list and threw `0: expected 2-bit int`. A `u2` outside a round is unchanged.
**Nested rounds** (loop 16, AZ-2127; `Rounds.java`, `SchemeOrder.java`). A `repeat` or `times` inside a `repeat` or `times` round is no longer refused. An inner value field holds one list per outer round (`repeat(u8 n, times(1, 0, u8 v))` with `n = [1, 1]` and `v = [[5], [7]]` packs `01 01 05 01 07`), `null` for an outer round that skipped the group and `[]` for a group that read no round (`foldIntoOuterRound`, `entryCounts`). The inner rounds count against the same round and slot limits. A `repeat` has no end marker, so `packRepeat` keeps the repeats a call has written in `seen`, by field, and throws `IllegalArgumentException` (`<anchor>: a repeat has no end marker, so it can be written in one round only`) when the same inner `repeat` would be written a second time; an inner `times` is fine under any number of outer rounds.

**Times, longer list** (loop 16, AZ-2187; `Rounds.packTimes`). Pack throws `IllegalArgumentException` before the rounds are written when a body field's list is longer than the count (`1: list has 3 entries for a count of 2`; a member without a field id is named by its kind, `group: ...`). It dropped the extra entries.

**Strict pack** (loop 16, AZ-2190; `Scalars.java`). Pack writes an integer field only for a whole number inside its range and a float field only for a number, and every refusal is an `IllegalArgumentException` that names the field id: an integer out of range (it threw `ArithmeticException`), a `BigInteger` that wrapped (2^63 into `i64`), a fractional `BigDecimal` (1.5 was cut to 1), a string or boolean for an integer or float (a `ClassCastException` for a float), and a finite value too large for `f32` or `f64` (an `f32` wrote an infinity). Only a `Float` or `Double` that is itself infinite is an explicit infinity, and `NaN` and the infinities are written as given. A `Long` of -1 is still accepted for `u64`: it is the bit pattern, so unpack then repack works (an `Integer` of -1 is refused). (The same checks ran in `PackSession.pack`, retired in loop 74.)

**Flag group presence** (loop 16, AZ-2128; `Walker.childOn`). A bit under `flags` is on when any value inside its member is present, at any depth: a `u2` slot, a nested `flags` and a group holding them count (they were dropped, `0100`), a split bit in a group counts, and a set group that cannot be written in full fails pack naming the missing value. Since loop 18 a `when` (its condition holds on what was written and its body has a value), a `times` (its count is above 0; a skipped count is no round; a count of 0 with a non-empty list throws `IllegalArgumentException` naming the value) and a `repeat` (a round has a value) count as members and set their bit: `u8 mode; flags(when(eq(0, 1), u8 speed), u16 heading)` with `mode` = 1, `speed` = 7 and `heading` = 90 packs `01 01 03 07 5a 00` (it packed `01 01 02 5a 00`), and a set bit that cannot be written in full fails pack naming the value.

**Bool bit**: the bit is set only for `Boolean.TRUE`; `false`, an absent value and any other value (`1`, `"true"`) leave it clear. A set bit unpacks as `Boolean.TRUE` in both the combined (`flags`) and the split (`flagByte`) form; a clear bit stores nothing. A split bit inside a `when` that is not taken is still set from the row on pack, and unpack tests the `when` first and never reads it (shared `bitwhen` vector: `{k:0, v:5}` packs `010001` and unpacks as `{k:0}`; `{k:1, v:5}` packs `01010105`).

**Repeat and times rounds** (loop 12, `Rounds.java`). A round packs item i of every body field's list, and a flag bit in the round is decided from that item. The `repeat` round count is the longest list among the body's value fields, looking through `flags`, flag bits, `when` and anchored groups. Each round removes the body's values from the call's `seen` map, so a `when` or count never matches an earlier round's value. Unpack keeps one list entry per round for every value field of the body, `null` where the round skipped it, so packing the unpacked row gives the same bytes. The `null` padding is one store per round, linear in the packet length.

**Round limits** (loop 15, AZ-2218; `Scheme.java`, `Cursor.java`, `Rounds.java`). A `Scheme` carries `maxRounds` (default `Scheme.DEFAULT_MAX_ROUNDS`, 65,535) and `maxSlots` (default `DEFAULT_MAX_SLOTS`, 1,048,576 since loop 22, 4,194,304 before). `scheme.withLimits(maxRounds, maxSlots)` returns a new scheme over the same fields; both values are taken every time, and the receiver is unchanged. A limit below 1 throws `IllegalArgumentException`; there is no unlimited value. A package-private `Cursor` replaces the `int[] offset` of every unpack method: it holds the position (`pos`) and the slots the rounds of the call have taken, shared by every field of the call, list and dict elements included. `Rounds.unpackRepeat` and `unpackTimes` call `cur.startRound(roundsStarted, slots)` before a round is read, where `slots` is the number of value fields of the body (`values(...)`). The round that would be the 65,536th of one field, or would take the slot total past `maxSlots`, returns `ShortPacket(field.label(), 0, left)` (the label is `"times"` for a `times`, the field id for a `repeat`): no row, no handler call. A `times` count is not refused up front, so a huge count over few bytes still ends in a short read.

**Pack round cap** (loop 19, AZ-2329; `Rounds.packTimes`, `ByteSink.maxRounds`, `VarFields.borrowedLong`). `BinaryPacker.pack` builds the `ByteSink` with the scheme's `maxRounds`, and `packTimes` throws `IllegalArgumentException` before any round is written when the count is above it (`times: count 65536 is above the limit of 65535 rounds`; `1_000_000` and `4_000_000_000` the same). The count is computed as a `long` (`borrowedLong`), so a `u32` or `u64` count above `Integer.MAX_VALUE` is refused by the cap, not truncated first (review B1: `4294967299L` used to pack three rounds under count bytes saying 2^32 + 3). `withLimits(70_000, ..)` packs 70 000 rounds. Tests: `RoundLimitsTest`.

**Split bit with a dropped body** (loop 19, AZ-2331; `Presence.requireNothingDropped`, `valuesWithoutCount`). When a split flag bit is clear, pack checks its member: if the bit would be on by now (`childOn`: a `when` whose condition holds on the values written since the byte, a `times` whose count is above 0), it throws `IllegalArgumentException` naming the first value (`speed: its flag bit was decided before the value its condition or count reads was written`); if a `times` holds values and its count was never written, it throws (`pt: values given, but the count of its times was never written`; the check looks through groups, `when`, `flags` and flag bits, review B9). A `when` whose condition is false stays silent, before or after the byte; the combined `flags` form is unchanged. Tests: `SplitFormLoudPackTest`; the loader of `HostileVectorTest` writes the flag byte before the `when` (the README shape, review C3).

**`Eq` value check** (loop 19, AZ-2338; `requireWhenSource` in `SchemeOrder.java`). The `eq` value of a `when` on an integer source is run through `Scalars.writeScalar` into a scratch buffer, so it is held to the same rule as a packed value: a string, a boolean, NaN, a fraction, a whole `Double` such as `5.0`, an `Integer` out of range, a `BigInteger` that would wrap are refused with `IllegalArgumentException` (`when 1 tests field 0 against 300, which that field can not hold (...)`). A `u2` slot holds 0..3 (`eq(u2Slot, 7)` is refused, review B3). A bool source keeps its rule. `SchemeOrder` now keeps the source `Field` (it kept its `Kind`) to know the width. Tests: `EqValueCheckedTest` and `ReferenceScopeTest`.

**Lone values and count 0** (loop 19, AZ-2332, AZ-2335; `Rounds.requireNoLone`). A lone dictionary or a lone `byte[]` for a `bytes` or `sized` name of a `repeat` or `times` round throws, also for a `times` of count 0 in `flags`. A `times` count of 0 with a list of values throws; a lone scalar with count 0 packs `0100`. Tests: `LoneBytesInRoundTest`, `TimesCountZeroTest`.

**Pack output budget** (loop 20, AZ-2354, AZ-2355, AZ-2361; `ByteSink.java`, `Rounds.java`, `Scheme.java`, `BinaryPacker.java`, `VarFields.java`). `Scheme` carries `maxBytes` (default `Scheme.DEFAULT_MAX_BYTES`, 16 777 216, type byte included), set by `withMaxBytes(long)`; `withLimits(int, long)` returns a scheme with the default `maxBytes` (the reference rule: a limit left out takes the default), and `withMaxBytes` keeps the rounds and slots. A value below 1 throws `IllegalArgumentException`. `BinaryPacker.pack` builds `new ByteSink(maxRounds, maxSlots, maxBytes)`; every write is refused before it is made: `IllegalArgumentException` `s: the packet would be 16777477 bytes, above the limit of 16777216 bytes` (`Rounds.nameOf`: the field, a `u2` by its first slot, a combined `flags` byte by the first value its members hold). The sink grows in `long` arithmetic, capped at `Math.min(maxBytes, MAX_ARRAY)` (F29: it overflowed at 2^30 and copied the buffer on every append after it). `sink.startRound(field, values, width)` charges `maxSlots` as each round starts, with the width `Rounds.width` gives (distinct member names; since loop 21, AZ-2382) that unpack charges, before the round's bytes: `k: the rounds would hold 1048580 slots, above the limit of 1048576 slots`. `Rounds.packRepeat` refuses a list above `maxRounds` before any round (`k: the repeat count is 65536, above the limit of 65535 rounds`). The `times` cap keeps its loop 19 text (`times: count 65536 is above the limit of 65535 rounds`). AC-1: out of memory at `-Xmx1g` with no member before; the first message above in 47 ms and 99.5 MB RSS after. `packSized` and `packBits` use `borrowedCount(field, seen, Integer.MAX_VALUE)`: a `u64` count of 4294967299 is refused (`1: count 4294967299 is above the limit of 2147483647 items`; F30). Tests: `PackBudgetTest`, `LoneUtf8Budget`, `RepeatRoundCapTest`, `CountsFractionsSinkTest`, `ParityPinsTest` (AZ-2356 and AZ-2360 rows); the check count of `PackbinTest` is 1952, 0 failures, api-check PASS.

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
- Unpack refuses a packet whose `repeat` or `times` starts more than 65,535 rounds, or whose rounds hold more than 1,048,576 slots together (4,194,304 before loop 22), until the scheme raises the limits with `withLimits`.

**Breaking changes for callers** (loop 16; the bytes of a row that packed before are unchanged except where noted):
- `group(get, set, create, fields...)` is new; the old `group(get, set, fields...)` on a typed row, or below a group that has a factory, throws `IllegalArgumentException` when the scheme is built (a typed row with a `Map` member that used it must pass `HashMap::new`).
- Field ids of a nested row live in a scope of their own (`010001`, was `01000109`), and under `flags` a nested row's presence is its member alone.
- A `repeat` or `times` inside a round builds and packs; the nested lists have one entry per outer round.
- `times` pack throws for a list longer than the count (the extra entries were dropped).
- Pack throws `IllegalArgumentException` naming the field id where it threw `ArithmeticException` or `ClassCastException`, or wrote wrong bytes (a wrapped `BigInteger`, a cut fraction, an `f32` infinity); code that caught `ArithmeticException` around `pack` must catch `IllegalArgumentException`.
- A `u2`, a nested `flags` and a group holding them under `flags` set the group's bit (they were dropped, `0100`).
- A key written twice through `Access.set("x")` in one scope fails at construction (AZ-2246), unless one of the two sits under a `when`; typed accessors and lambdas are not checked.
- A bit inside a nested row whose only flag byte was read outside it fails when the scheme is built (AZ-2233); a byte read before a nested row is no longer visible inside it. Both built before and packed bytes that unpack read back as trailing bytes (`01 00 05`, or `01 01 05` for an identity member).
- Pack throws where it wrote bytes that unpack read as a different row (AZ-2234): `missing group` for a `null` or absent nested row, `missing list element 1` and `missing dict element "b"` for a `null` element. A `u2` in a round packs the item of each round (it threw).
- A `list` or `dict` of `group(get, set, fields...)` on a typed row, or below a group with a factory, fails when the scheme is built (AZ-2235); pass a factory (`group(identity(), ignore(), Item::new, ...)`).
- Split-form flag bits are numbered by their place in the scheme (AZ-2135), not by the order of the `.bit(...)` calls: a handle shared by two schemes packed `010305` for `[m, m.bit(x)]` with `x` = 5 in both and now packs `010105`, a flag byte read twice no longer shares the numbers of its first read, and the ninth bit of one read fails when the scheme is built.

**Breaking changes for callers** (loop 18; golden and route bytes are unchanged; unpack of older packets is unchanged):
- Construction: a count that names a bool (it built) and `eq` of a bool against anything but `true` now throw `IllegalArgumentException`; a `when` on a float, utf8, bytes, sized, bits or packed field fails as not an earlier integer field.
- Pack: a `when`, `times` or `repeat` as a `flags` member or flag-bit field is written and sets its bit (`01 01 02 5a 00` to `01 01 03 07 5a 00` for the pinned shape); a `times` count of 0 with a non-empty list throws; a row unpacked from an old packet (bit clear, count above 0) no longer repacks.
- Pack: a lone dictionary for a `dict` name in a round throws `IllegalArgumentException`.

**Breaking changes in loop 19** (golden and route bytes are unchanged; unpack of older packets is unchanged):
- Pack: a `times` count above `maxRounds` throws (65 536 and 1 000 000 rounds were written before; a `u64` count above 2^31 was truncated).
- Pack: a clear split flag bit whose body would be written throws; a false condition still packs silently.
- Pack: a lone `byte[]` in a `repeat` or `times` round throws (it was copied to every round); a `times` count of 0 with a list of values throws.
- Construction: an `eq` value its integer source cannot hold, or a whole `Double`, throws `IllegalArgumentException`.

**Breaking changes in loop 20** (golden and route bytes are unchanged; unpack of older packets is unchanged; bytes of every row that still packs are unchanged):
- Pack: a packet above `maxBytes` (16 MiB by default), a round that would pass `maxSlots` and a `repeat` list above `maxRounds` throw `IllegalArgumentException`.
- Pack: a combined `flags` `times` whose count was skipped, given values, throws (the values were dropped).
- Pack: a `BigDecimal` fraction and a `Long` or `BigInteger` above the slot in `u2`, `bits` or `packed` throw (they were cut); a `u64` count above the `int` range for `sized` or `bits` throws (it was cut to an `int`).
- API: `withLimits(int, long)` still resets `maxBytes` to the default; call `withMaxBytes` after it.

**Loop 21 changes** (AZ-2382, AZ-2383, AZ-2384, AZ-2386, AZ-2387, AZ-2390, AZ-2392; golden and route bytes are unchanged; 2153 checks).
- Slot width (AZ-2382; `Rounds.width`, used by `Rounds.pack*` and by unpack through `cur.startRound(i, width)`; `ByteSink.startRound(round, values, width)`): one slot per distinct member name (`Access.set("x")` key) the round holds; two `when` arms that write one key are one slot, and a member without a name (a typed accessor, a lambda) is a slot of its own. The difference left from TypeScript: a nested-row group (`group(get, set, ...)`, an empty one too) counts as one slot, its own name, where TypeScript counts the members of an unanchored group. Test: `RoundSlotWidthTest`.
- Empty round body (AZ-2390; the check in `SchemeOrder.java`, run when the scheme is built): `IllegalArgumentException` `repeat 0: the body holds no member; a round of it would charge no slot and write nothing`. Test: `EmptyRoundBodyTest`.
- Short optional list (AZ-2383; `Rounds.requireListPerRound` and `optionalValues`): `IllegalArgumentException` `v: 1 items, repeat count 2; give one entry per round, null where the member is absent`; `times` is unchanged. Test: `RepeatShortOptionalTest`.
- Split-bit `times` with an absent body (AZ-2384; `Presence.childOn(..., valuesOnly)`): a `times` bit is set only when its rounds hold a value, so a count above 0 written after the byte with no body or `[]` packs a clear bit (`0102025a00`); it was refused before. Count behind a clear `when` (AZ-2386; `Field.countSource`, set by `SchemeOrder.bind` through its `counts` map, and `Presence.requireCountWritten`): `pt: the count c is 1 in the row, but no field wrote it (the when that holds it is clear) ...`. A `bits`, `packed` or `sized` count behind a clear `when` throws `IllegalStateException` (`2: count 1 is missing`) when a value is given and packs a clear bit with no value (AZ-2387; open row). Tests: `ClearBitProbesTest`.
- Hostile loader (AZ-2392, AZ-2394): `HostileRefusals` names the exception class and the text each refused case must give, `HostileLoop21` builds the 15 new cases.

**Breaking changes for callers, loop 21** (golden and route bytes are unchanged; bytes of every row that still packs are unchanged):
- Construction: a `repeat` or `times` with no member in its body throws.
- Pack: a short non-empty list under `flags` or a flag bit in a `repeat` throws; a count above 0 that no field wrote, behind a clear `when`, in a split-bit or combined-`flags` `times` throws; a split-bit `times` with a count above 0 after the byte and no body now packs a clear bit.

**Potential race conditions**:
- None

**Performance bottlenecks**:
- The same AC-10 loop, on one core, in this language

**Loop 22 changes** (AZ-2410, AZ-2415, AZ-2417, AZ-2418; golden and route bytes are unchanged; 2252 checks, 2153 at loop 21).
- No-value count (AZ-2410, U11; `Presence.java`: `positive(value, bias)` compares the count after the `packed` bias and the count-written check now covers `BITS`, `PACKED` and `SIZED`; `SchemeOrder.java` gives those kinds their count source): a `bits`, `packed` or `sized` whose count the row holds above 0 (after the `packed` bias) and no field wrote, behind a clear `when`, with no value for the member, in a split bit or a combined `flags`, is refused (it packed a clear bit `01 00 00`); count 0, no count and a holding `when` pack as before. The text ends `so the member reads nothing; give the count 0, leave it out, or make the when hold`; the exception is the existing `IllegalStateException` of this check. Test: `ClearBitProbesTest.u11NoValueCountBehindAClearWhen`.
- Default `maxSlots` (AZ-2415, U17; `Scheme.DEFAULT_MAX_SLOTS`): 1 048 576, was 4 194 304. F10 packet at the default (refused at item 16 385): 317 MB peak at `-Xmx4g`, 960 MB before (273 MB and 824 MB at `-Xmx1g`). Tests: `RoundLimitsTest` (with `UnpackMemory.java`), `PackBudgetTest.rows2And3AnElementThatHoldsATimesUnderTheSlotsLimit`.
- Probes only (AZ-2413): a lone value and a `when` list in a `repeat` pack, a short required list is refused `expected int, got null`.
- Hostile loaders (AZ-2417, AZ-2418): `HostileVectorTest` with `HostileLoop22` and `HostileRefusals` replays the ten new cases (65 in all); `HostileRuleTableTest` (seven checks) feeds each loader table a wrong entry and expects a failure naming the case. The `construct_empty_*when*` loader entries pin the scope text.
- AZ-2410 note, U16 (README exception, no code): Java counts a nested-row group (a `group(get, set, ...)` row, an empty one too) as one slot where the other packages count the names inside it; the Go package copies TypeScript's count.

**Breaking changes for callers, loop 22** (golden and route bytes are unchanged; bytes of every row that still packs are unchanged):
- Pack: the no-value count row above throws.
- Unpack: a packet whose rounds hold more than 1 048 576 slots is refused until `withLimits` raises `maxSlots` (both values are taken every time); a round body wider than 16 names can no longer run 65 535 rounds at the default.

**Loop 23 changes** (AZ-2436 tests only; no source change; 2540 checks, 2252 at loop 22).
- U11 below the top level (AZ-2436, G3): `NoValueCountNestedTest` (run from `PackbinTest`) pins the refusal in an anchored group, a nested-row group (counting inside its own row), a bit holding an anchored group, an outer holding `when`, a bit holding a holding `when`, and `times`/`repeat` rounds, for three kinds x split bit and combined `flags`; count 0, a left-out count and a holding inner `when` pack the TypeScript hex. A nested-row group whose member counts by a field of the row around it is refused at construction (its ids start at 0 and see no id outside it): not spellable, pinned as observed. A member inside the clear `when` itself is the silent skip (`010100`).

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

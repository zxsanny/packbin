# Java refuses a flag bit whose flag byte lies outside its nested row

**Task**: AZ-2233_java_nested_row_orphan_bit_refused
**Name**: Java nested row: a flag bit with no flag byte inside the row is refused at construction
**Description**: `new Scheme<>(...)` throws `IllegalArgumentException` ("flag bit ... has no flagByte before it in the same scope") when a split-form flag bit stands inside a nested row (an accessor `group`) and the only read of its flag byte that the bit can see lies outside that row, instead of building a scheme that packs bytes its own unpack cannot read.
**Complexity**: 2 points
**Dependencies**: AZ-2135_split_bits_field_order (Java part: `SchemeOrder.bindFlagBits`, a bit binds to the latest read of its flag byte in the same container), AZ-2101_java_typed_nested_rows (nested rows, scope of their own)
**Component**: java
**Tracker**: AZ-2233
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment, Q4 (b) (first half), owner answer of 2026-10-06: "take all recommendations, implement everything now". Batch 2 review JA-F2 and batch 3 review JA-F1 (the opposite direction, fixed in batch 3) are the sources.

All probes below were run on Java at HEAD `2eb9875` (the working tree is identical for `java/`), JDK 21, on a scratch copy of `java/` and `fixtures/` after `bash java/test.sh` passed. Rows are `Map` rows; `m` is one flag byte handle; `x`, `a`, `k` are `u8` fields; `g` is a nested row `Packbin.group(Access.get("g"), Access.set("g"), ...)`.

- `SchemeOrder.bind` gives a nested row `new HashMap<>(visible)`: a copy of the flag bytes the row around it has read. So a bit inside the row can bind to a read of its byte that happens OUTSIDE the row (batch 3 made a byte read INSIDE a row invisible outside; this is the opposite direction).
- Pack cannot honour that binding. The flag byte is written by the row around, where it asks each bit's field for presence on that outer row. The bit's field belongs to the nested row, so the outer row does not hold it. The payload is then written inside the nested row, after the byte.
- Probe 1: scheme `[m, group(g, m.bit(u8 0 x))]` builds. `{g:{x:5}}` packs `01 00 05`. Unpack of `01 00 05` returns `TrailingBytes(left=1)`: the byte says "bit 0 clear", the 05 is never read. `{g:{}}` and `{}` pack `01 00` and unpack to `{g:{}}`.
- Probe 2: `[m, m.bit(u8 0 a), group(g, m.bit(u8 0 x))]` builds. `{a:1, g:{x:2}}` packs `01 01 01 02` and `{g:{x:2}}` packs `01 00 02`; both unpack to `TrailingBytes(left=1)`.
- Probe 3 (coincidence, still wrong): `[m, group(g, m.bit(u8 0 x))]` with the OUTER row holding an `x` too: `{x:7, g:{x:5}}` packs `01 01 05` and reads back as `{g:{x:5}}`; `{x:7, g:{}}` packs `01 01` and unpack gives `ShortPacket(field "0", needed 1, left 0)`. The bit follows the outer row's `x`, which the scheme never writes.
- Probe 4 (typed row): `Outer { Inner inner; Integer tail; }`, scheme `[m, group(get inner, set inner, Inner::new, m.bit(u8 0 x))]` on `Outer.class` builds; pack of `{inner: {x: 5}}` throws `ClassCastException: class Outer cannot be cast to class Inner` (the outer row is handed to the inner accessor).
- Shapes that already fail at HEAD, same message as the rule below: `[m, group(g, repeat(0, m.bit x))]`, `[m, list(l, group(identity, ignore, m.bit x))]` and `[m, repeat(0, group(g, m.bit x))]`: `flag bit U8 0 has no flagByte before it in the same scope` (a repeat, times, list or dict starts with no visible byte).
- Shapes that read correctly at HEAD and must stay: `[m, group(g, m, m.bit(u8 0 x))]` packs `{g:{x:5}}` as `01 00 01 05` and unpacks it; the README example `[m, m.bit(u8 0 a), group(g, m, m.bit(u8 0 x)), m.bit(u8 1 b)]` with `{a:1, g:{x:2}, b:3}` packs `01 03 01 01 02 03`; an anchored (flat) group `[m, group(0, m.bit(u8 0 x))]` with `{x:5}` packs `01 01 05` and unpacks it.
- One existing test pins the behaviour as intended: `SplitBitOrderTest.ac1NestedRowReadsStayInsideTheRow` asserts "a byte read outside a nested row stays visible inside it" for `[outside, group(g, outside.bit(u8 0 x))]` (`java/src/test/java/packbin/SplitBitOrderTest.java`, the `seenInside` lines). The README Java upgrade note says the same ("a byte read before the row stays visible inside it").

## Outcome

- A bit inside a nested row binds only to a read of its flag byte that stands inside that same nested row, before the bit. When there is none, the scheme is refused at construction with the existing orphan message: `flag bit <kind> <id> has no flagByte before it in the same scope` (the same text and kind as every other orphan bit; the first orphan bit reached in scheme order is named).
- Nothing else changes: a bit that binds to a read inside its row, in an anchored group, `when`, `flags` child or at the top level keeps its number and its bytes; schemes already refused keep their error.

## Scope

### Included
- `SchemeOrder.bind`: a nested row starts with no visible flag byte (it binds only to reads inside it), at any depth of nested rows and when the nested row stands under a `when`, a `flags` child, a flag bit payload or another nested row.
- Test changes: the `seenInside` assertion of `SplitBitOrderTest` becomes a refusal; new tests for the ACs.
- Javadoc of `SchemeOrder.bindFlagBits` (it says a byte read inside a nested row is visible only there; add that a byte read outside is not visible inside) and, for the docs worker, the README Java sentence about a byte "read before the row stays visible inside it" (README upgrade note on split-form bits).

### Excluded
- The opposite direction (a byte read inside a row used outside): already refused since batch 3 (JA-F1).
- A flag byte read inside a nested row and its bits outside: unchanged (refused).
- Other packages: TypeScript, Rust, C++ and Python decide their own scope rules (ADR-001); this task changes Java only.
- Pack behaviour of nulls, absent rows and `u2` (AZ-2234) and typed element groups (AZ-2235).
- Error kind and label of existing errors (decision C15): the message text of the existing orphan error is reused unchanged.

## Acceptance Criteria

**AC-1: A bit whose only flag byte lies outside its nested row is refused**
Given `[m, group(g, m.bit(u8 0 x))]` (Probe 1)
When `new Scheme<>(...)` runs
Then `IllegalArgumentException` with the message `flag bit U8 0 has no flagByte before it in the same scope`, and no scheme is built (at HEAD it builds and packs `01 00 05` for `{g:{x:5}}`).

**AC-2: Every shape in which the only visible read is outside the row is refused**
Given each of these, with `m` a flag byte handle and `x`, `a`, `k` `u8` fields (nested rows number their ids from 0):
- `[m, m.bit(u8 0 a), group(g, m.bit(u8 0 x))]` (Probe 2)
- `[m, group(g, m.bit(u8 0 x), m)]` (the byte read after the bit)
- `[m, group(g, u8 0 k, when(1, eq(0, 1), m.bit(u8 1 x)))]` (bit inside a `when` inside the row)
- `[m, group(g1, group(g2, m.bit(u8 0 x)))]` and `[group(g1, m, group(g2, m.bit(u8 0 x)))]` (read outside the innermost row)
- `[m, u8 0 k, when(1, eq(0, 1), group(g, m.bit(u8 0 x)))]` (nested row under a `when`)
- `[m, m.bit(group(g, m.bit(u8 0 x)))]` (nested row as the payload of a bit of the same byte)
- `[m, flags(0, group(g, m.bit(u8 0 x)))]` (nested row under `flags`)
When each is built
Then each throws `IllegalArgumentException` `flag bit U8 <id> has no flagByte before it in the same scope`, where `<id>` is the id of the bit's field (1 for the third shape, 0 for the others). At HEAD all eight build.

**AC-3: Shapes that already fail keep their error**
Given `[m, group(g, repeat(0, m.bit(u8 0 x)))]`, `[m, list(l, group(identity, ignore, m.bit(u8 0 x)))]` and `[m, repeat(0, group(g, m.bit(u8 0 x)))]`
When each is built
Then each throws `flag bit U8 0 has no flagByte before it in the same scope`, as at HEAD.

**AC-4: A byte read inside the row, and the other readable shapes, are unchanged**
Given `[m, group(g, m, m.bit(u8 0 x))]`, `[m, group(g1, group(g2, m, m.bit(u8 0 x)))]`, `[list(l, group(identity, ignore, m, m.bit(u8 0 x)))]`, the anchored `[m, group(0, m.bit(u8 0 x))]` and the README shape `[m, m.bit(u8 0 a), group(g, m, m.bit(u8 0 x)), m.bit(u8 1 b)]`
When each is built, and `{g:{x:5}}`, `{x:5}` and `{a:1, g:{x:2}, b:3}` are packed with the first, fourth and fifth
Then all build, and the bytes are `01 00 01 05`, `01 01 05` and `01 03 01 01 02 03`, and each unpacks back to its row (`{g:{x:5}}`, `{x:5}`, `{a:1, b:3, g:{x:2}}`).

**AC-5: A typed row is refused the same way**
Given Probe 4: `Outer.class`, `[m, group(get inner, set inner, Inner::new, m.bit(u8 0 x))]`
When `new Scheme<>(...)` runs
Then `IllegalArgumentException` `flag bit U8 0 has no flagByte before it in the same scope` (at HEAD it builds and pack throws `ClassCastException`).

**AC-6: Schemes that build keep their bytes (differential)**
Given the golden fixture, the hostile fixtures, `java/test.sh` and a scratch differential run of random schemes (flag byte handles, bits, nested rows to depth 2, `when`, scalars; four random rows each) at HEAD and with the change
When both are compared
Then every scheme that still builds packs the same bytes and unpacks the same result for every row; the schemes that are newly refused are exactly those with a bit inside a nested row whose bound read is outside it.

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every scheme that builds are unchanged. No public API change. The only behaviour change is at construction, for schemes whose bytes were unreadable.
- Observed in a scratch trial (one-line change in `SchemeOrder.bind`, nested row gets an empty visible map): 20,000 random schemes: 3,698 build in both and are identical (bytes and unpack result for 4 rows each); 521 build at HEAD and are refused (520 of them gave at least one unreadable or throwing row among the four sampled rows; the 521st had all four sampled rows leave the nested payload out, so they read back); 151 more are refused in both and differ only in which orphan bit is named first. `bash java/test.sh` passes in the trial except the one assertion named above.

**Reliability**
- A scheme that builds never packs a flag byte computed from a row that does not hold the bit's field.

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test class |
|--------|-------------|-----------------|------------|
| AC-1 | `[m, group(g, m.bit(u8 0 x))]` | construction throws the orphan message; replaces the `seenInside` assertion | `SplitBitOrderTest` |
| AC-2 | the eight shapes, each its own `expectThrows` | message with the right bit id | `SplitBitOrderTest` |
| AC-3 | repeat, list element, repeat round | same message as before | `SplitBitOrderTest` |
| AC-4 | five readable shapes; pack and unpack | bytes `01 00 01 05`, `01 01 05`, `01 03 01 01 02 03`; round trip | `SplitBitOrderTest` |
| AC-5 | typed `Outer` / `Inner` scheme | construction throws the orphan message | `SplitBitOrderTest` |
| AC-6 | golden, hostile and the whole suite | unchanged | `java/test.sh` (all mains); the differential is a scratch run, reported in the batch report |

`SplitBitOrderTest.java` is 219 lines; adding the tests keeps it under 500. Register no new class (the file is already in `PackbinTest.main`).

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4, AC-6 | `fixtures/golden.hex`, `fixtures/hostile/*` | Java pack and unpack | identical to HEAD | Compatibility |
| AC-6 | `language-pair.sh` rings that include Java | producer and consumer | 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: Java only, no shared walker, no cross-package import.
- Files at or under 500 lines (`SchemeOrder.java` is 206).
- Error kind and label of existing errors unchanged (decision C15): the orphan message text is the existing one.
- The refusal is a property of the scheme, not of a row: it does not depend on the row class.
- Bytes in the ACs were reproduced on Java at HEAD; the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A scheme of this shape that a caller shipped now fails to build**
- *Risk*: a caller whose outer row happens to hold a field with the same key (Probe 3) saw readable bytes for some rows.
- *Mitigation*: the bytes were wrong for any row that holds the bit's field only inside the nested row; the message names the bit; the fix is to read the flag byte inside the row (`group(g, m, m.bit(x))`), which is AC-4. README upgrade note (docs worker).

**Risk 2: Over-refusal for a shape that could be made to work**
- *Risk*: none found; pack writes the byte from the row around the nested row, which cannot hold the bit's field, so no binding to an outside read can be correct.
- *Mitigation*: the differential in AC-6 shows no scheme that builds changes.

## Owner decision (2026-10-06)

DECIDED, assessment 16 Q4 first half, recommendation taken ("take all recommendations, implement everything now"): refuse at construction, with the existing orphan message, when the only flag byte a bit can see lies outside its nested row; schemes that pack readable bytes do not change (differential against HEAD). The inner `repeat` case of Q4 (a) stays documented and is not part of this task.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2), in one Java worker with AZ-2234 and AZ-2235. A nested row (`group(get, set, ...)`) is a scope of its own for flag bytes in both directions: a byte read inside it is not visible after it (as before), and a byte read outside it is no longer visible inside it. A bit inside a nested row whose only flag byte was read outside it fails when the scheme is built: `flag bit U8 0 has no flagByte before it in the same scope`. It used to build and pack bytes its own unpack could not read (`[m, group(g, m.bit x)]` with `{g: {x: 5}}` packed `01 00 05`; unpack gave `TrailingBytes(left=1)`; a typed row threw `ClassCastException` at pack).

What shipped: one token in `SchemeOrder.bind` (a nested row gets `new HashMap<>()`, not a copy of `visible`); the Javadoc of `bindFlagBits` and of `Field.bit` (`SchemeOrder.java` +26/-5 with the AZ-2235 check, `Field.java` +3/-2). `javap -public` is unchanged.

Tests (`SplitBitOrderTest`, +109/-6): `az2233Ac1OrphanBitInANestedRowIsRefused`; `az2233Ac2EveryShapeWithTheReadOutsideIsRefused` (eight shapes; the `when` shape names `U8 1`, the rest `U8 0`); `az2233Ac3ShapesRefusedBeforeKeepTheirError`; `az2233Ac4ReadsInsideTheRowStillBuild` (`01 00 01 05`, `01 01 05`, `01 03 01 01 02 03`, round trip, the two-deep and list-element shapes); `az2233Ac5TypedRowIsRefusedTheSameWay`. The `seenInside` lines of `ac1NestedRowReadsStayInsideTheRow` became `expectThrows` with the orphan message (sanctioned by the spec).

Evidence: differential of 280,000 random schemes (map and typed, clean and shared handles), about 1.5 M rows: 0 violations, 749,506 rows with identical bytes; 5,679 schemes that HEAD built and now refuse are exactly the bit-in-a-nested-row-with-read-outside shapes (a built-in reference binder predicted every refusal). Batch-3 `Gen` differential, 200,000 seeds: default mode identical (197,848 built); share mode HEAD built 186,400, now 165,399, every new refusal an orphan message. The reviewer's own differential ran 1.57 M rows, 0 byte differences. Mutation (nested row sees the outer reads again): the AZ-2233 tests fail.

Review finding F1 (low): a nested row whose member is the row around it, `[m, group(identity(), ignore(), m.bit(x))]`, packed `01 01 05` and read back at HEAD, and is refused now; the Javadoc sentence "the row around cannot write the byte" was not true for it. Fixed in text: the `bindFlagBits` and `Field.bit` Javadoc say the rule is by scope, and the README patch and the Java description name the shape and the workaround (`group(identity(), ignore(), m, m.bit(x))` packs `01 00 01 05`). No code change (owner decision A).

Discoveries (kept): schemes HEAD already refused can name another orphan bit first (254 per 280,000), and 325 that said `flags already has 8 bits` now say the orphan message, because bits of a nested row that bound to an outer read no longer count toward that read's eight. TypeScript has no equivalent rule (its unanchored group shares the scope and flattens its members into the row), so this is Java-specific.

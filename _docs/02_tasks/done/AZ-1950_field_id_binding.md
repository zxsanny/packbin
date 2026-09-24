---
loop: 4
branch: dev
---

# Field id binding

**Task**: AZ-1950
**Name**: Field id binding
**Description**: A scheme field binds to a row member by its order and an accessor. That order is the binding key. The row uses normal names for that language. The key is not a wire tag.
**Complexity**: 8 points
**Dependencies**: AZ-1949
**Component**: library
**Tracker**: AZ-1950
**Epic**: pending

## Problem

The scheme names and the row member names are the same string. A C# row cannot use `Lat` while the layout says `"lat"`. Flags, `when`, sized bytes, and bit counts find their siblings by that string too.

## Outcome

- A value-bearing field is `Field.I32(1, x => x.Lat)`. The number is that field's order among value-bearing fields of the same row type, starting at 0. Scheme build fails if the number is not the next order. The bytes stay that same order. The number is not written.
- C# takes one member lambda and derives the getter and the setter. A lambda that is not a member access fails at scheme build.
- `when`, sized, and bits name the other field by its id: `Condition.Eq(1, 1)`, `Field.Sized(2, x => x.Payload, 1)`, `Field.Bits(3, x => x.Segs, 1)`.
- Flags, groups, repeat, lists, and dictionaries are structural. They have accessors when they correspond to a member, and their children use ids of the child row type.
- The same shape exists in TypeScript, Python, Rust, C++, and Java. Rust and C++ pass a member pointer or a get/set pair. Java passes getter and setter. Python passes get and set callables.
- Flags, `when`, repeat, and group do not take an order number. Their children do, in source order. A list or dictionary element row starts again at 0.
- Marker bytes for type number `0x20`, sid `1`, lat, lon, and kind `1` stay the bytes those fields already produce. The row members are `Sid`, `Lat`, `Lon`, and `Kind`.

## API

```csharp
public sealed class MarkerRow
{
    public ushort Sid { get; set; }
    public int Lat { get; set; }
    public int Lon { get; set; }
    public byte Kind { get; set; }
    public ushort? KindId { get; set; }
    public ushort Title { get; set; }
    public bool? Hidden { get; set; }
    public bool? Delta { get; set; }
}

static readonly Scheme<MarkerRow> MarkerScheme = new(0x20,
    Field.U16(0, x => x.Sid),
    Field.I32(1, x => x.Lat),
    Field.I32(2, x => x.Lon),
    Field.U8(3, x => x.Kind),
    Field.When(Condition.Eq(3, (byte)1),
        Field.U16(4, x => x.KindId)),
    Field.U16(5, x => x.Title),
    Field.Flags(
        Field.Bool(6, x => x.Hidden),
        Field.Bool(7, x => x.Delta)));
```

The leading `0x20` is the scheme type number from `scheme_dispatch`. It is not field id 0 and it is not a row member.

## Scope

### Included

- Id plus accessor for every value-bearing kind: integers, floats, bool, bytes, utf-8, u2 slots, bits, sized.
- Structural nodes: flags, when, repeat, group, list, dictionary.
- The passed number must equal the field order. A gap, a duplicate, or a number that is not the next index fails at scheme build.
- All six languages.

### Excluded

- Writing the field id into the buffer.
- A global id registry across schemes.
- Binding through a string member name.

## Acceptance Criteria

**AC-1: Member names are not the wire names.**
Given `MarkerRow.Lat` as the second value-bearing field, order 1.
When packed and unpacked.
Then the row property is `Lat` and the bytes match the positional i32, with no name and no order number in the buffer.

**AC-2: Sibling references use the order.**
Given kind at order 3 and a `when` on order 3.
When kind is 1.
Then `KindId` is written. When kind is not 1, `KindId` is omitted.

**AC-3: Flags use child accessors.**
Given `Hidden` and `Delta` as flag bits.
When `Hidden` is true and `Delta` is null.
Then the flag byte has the hidden bit set and the delta payload is absent.

**AC-4: Nested row type has its own ids.**
Given a list field whose element type has its own field id 0.
When packed.
Then the element id 0 does not collide with the parent id 0, because the parent scheme's type number is not a field id.

**AC-5: Order must match the number.**
Given a field numbered 2 that is not the third value-bearing field.
When the scheme is built.
Then construction fails.

**AC-6: Six languages.**
AC-1 bytes match. Mismatched bytes: 0.

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | Lat at order 1 | pack and unpack | property Lat, positional i32 | Compatibility |
| AC-2 | kind 1 and kind 0 | when | KindId present only for kind 1 | — |
| AC-3 | Hidden true, Delta null | flags | one bit set, delta omitted | — |
| AC-4 | list of a row with id 0 | pack | builds | — |
| AC-5 | number 2 in the first slot | scheme build | fails | — |
| AC-6 | AC-1 in all six | compare | 0 mismatched bytes | Compatibility |

## Constraints

- The six packages stay peers.
- Field order is the wire and the binding key. The number is not a tag.
- C# setter is derived only from a member-access lambda.

## Risks & Mitigation

**Risk 1: The id is prefixed as a tag**
- *Risk*: a field id of 2 inserts a `02` before the i32
- *Mitigation*: AC-1 compares the positional payload only

---
loop: 3
branch: dev
---

# C# packs Archangel fixtures, TypeScript unpacks

**Task**: AZ-1948
**Name**: C# packs Archangel fixtures, TypeScript unpacks
**Description**: C# packs each Archangel live packet. TypeScript unpacks those exact bytes into a class.
**Complexity**: 5 points
**Dependencies**: AZ-1945
**Component**: library
**Tracker**: AZ-1948
**Epic**: pending

## Problem

A language matching `fixtures/golden.hex` can still disagree with its neighbor on a live packet: an empty flags group, a UTF-8 length, a 2-bit kind byte, or a trail that runs to the end of the buffer. That only shows up when C# writes the bytes and TypeScript reads them.

## Outcome

- C# `Pack` writes each file in `fixtures/archangel/`. TypeScript `unpack` of those bytes yields the fixture entity. Wrong fields: 0. Bytes left: 0. Hex matches the file.
- The row has no type member. The type byte is the scheme type number (AZ-1945).
- Drivers follow `.github/workflows/drivers/csharp/Handoff.cs` and `.github/workflows/drivers/handoff.ts`: C# prints hex, TypeScript unpacks that hex.
- Real `pack` and real `unpack`. No stub.

## Fixtures

Copied from Archangel live packets (`_docs/02_document/contracts/map/live-binary.md` in the Archangel repo) plus generated neighbors of those shapes. One JSON file per packet: `entity`, `hex`, `bytes`.

| File | Packet | Entity | Hex | Bytes |
|------|--------|--------|-----|------|
| `dict-uav.json` | Dict | `{ id: 1, text: "uav" }` | `1101000300756176` | 8 |
| `dict-empty.json` | Dict | `{ id: 1, text: "" }` | `1101000000` | 5 |
| `dict-ukrainian.json` | Dict | `{ id: 2, text: "важка" }` | `1102000a00d0b2d0b0d0b6d0bad0b0` | 15 |
| `marker-rest-id.json` | Marker | sid 1, lat 500000000, lon 300000000, kind 1, title 7, restId 40 | `2001000065cd1d00a3e111010700202800` | 17 |
| `marker-bearing.json` | Marker | same point, kind 2, title 7, bearing 90 | `2001000065cd1d00a3e111020700045a00` | 17 |
| `marker-hidden-delta.json` | Marker | same point, kind 1, title 7, hidden true, delta true | `2001000065cd1d00a3e11101070003` | 15 |
| `marker-author.json` | Marker | same point, kind 1, title 7, author `{ login: 1, created: 1750000000 }` | `2001000065cd1d00a3e11101070010010080e14e68` | 21 |
| `marker-stored-zero.json` | Marker | same point, kind 1, title 7, bearing 0 | `2001000065cd1d00a3e111010700040000` | 17 |
| `trip-full.json` | Trip | contract example (off route, manage, pos, leader, purpose; card route, vehicle, unit, cp, rest) | `30010003e91f10000f001100022a000065cd1d00a3e111070000001200` | 29 |
| `trip-position-only.json` | Trip | sid 1, status 3, pos only, lat/lon 50°/30° | `3001000320000065cd1d00a3e111` | 14 |
| `route-two-point.json` | Route | contract example, kinds start then end, one straight bit | `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` | 26 |
| `route-one-point.json` | Route | sid 16, name 21, restId 45, one via at 50°/30° | `3410001500042d0001000065cd1d00a3e111` | 17 |
| `route-four-point.json` | Route | sid 16, name 21, restId 45, four vias, one kind byte | generated: count `04`, one kind byte `00`, four lat/lon pairs | 1 + 4×8 + head |
| `route-five-point.json` | Route | sid 16, name 21, restId 45, five vias, two kind bytes | generated: count `05`, two kind bytes | 2 + 5×8 + head |
| `notice-body-coords.json` | Notice | id 100, title 26, body 27, 50°/30°, created 1750000000 | `3864000000061a0080e14e681b000065cd1d00a3e111` | 21 |
| `notice-unread-bare.json` | Notice | id 100, title 26, created 1750000000, no body, no coords | `3864000000001a0080e14e68` | 11 |
| `path-one.json` | MarkerPath | sid 1, one vertex 50°/30° | `2101000065cd1d00a3e111` | 11 |
| `path-several.json` | MarkerPath | sid 1, vertices 50°/30° then 50.001°/30.001° | `2101000065cd1d00a3e111108ccd1d10cae111` | 19 |
| `target-position.json` | Target | sid 1, lat 500000000, lon 300000000, profile 1, motion clear | `4001000065cd1d00a3e1110100` | 13 |

`route-four-point.json` and `route-five-point.json` hex is generated with the same scheme as `route-two-point.json` (type 52, u8 count, u2 kinds low bits first, i32 pairs). Record the hex in the file when the fixture is written. Do not invent a second layout.

A layout that cannot match these lengths is not a golden fixture. It is an AZ bug, not this task.

## Scope

### Included

- C# packs, TypeScript unpacks, for every file in the table
- The fixture files themselves under `fixtures/archangel/`
- The existing position record (also `fixtures/golden.hex`)

### Excluded

- Python, Rust, Java, C++
- A registry publish
- A map from type byte to scheme
- A stub in place of `pack` or `unpack`

## System Under Test Boundary

C# `Pack` in this repo. TypeScript `unpack` in this repo. The bytes between them are the only input.

## Acceptance Criteria

**AC-1: Dict UTF-8**
Given `dict-uav.json`, `dict-empty.json`, and `dict-ukrainian.json`
When C# packs each entity and TypeScript unpacks the bytes
Then hex matches that file, wrong fields are 0, and bytes left are 0

**AC-2: Marker empty group and author group**
Given `marker-rest-id.json`, `marker-bearing.json`, `marker-hidden-delta.json`, `marker-author.json`, and `marker-stored-zero.json`
When C# packs and TypeScript unpacks
Then hex matches that file, hidden and delta add 0 extra bytes, bearing `0` still sets its bit, author is login then created, wrong fields are 0, bytes left are 0

**AC-3: Trip card and motion flags**
Given `trip-full.json` and `trip-position-only.json`
When C# packs and TypeScript unpacks
Then hex matches that file (`30010003e91f…` and `3001000320000065cd1d00a3e111`), wrong fields are 0, bytes left are 0

**AC-4: Route u2 kinds**
Given `route-two-point.json`, `route-one-point.json`, `route-four-point.json`, and `route-five-point.json`
When C# packs and TypeScript unpacks
Then hex matches that file, kind bits are low-first four per byte, wrong fields are 0, bytes left are 0

**AC-5: Notice body and coordinates**
Given `notice-body-coords.json` and `notice-unread-bare.json`
When C# packs and TypeScript unpacks
Then hex matches that file, wrong fields are 0, bytes left are 0

**AC-6: Repeat trail**
Given `path-one.json` and `path-several.json`
When C# packs and TypeScript unpacks
Then hex matches that file, wrong fields are 0, bytes left are 0

**AC-7: Position record**
Given `target-position.json` / `fixtures/golden.hex`
When C# packs
Then the bytes are `4001000065cd1d00a3e1110100` and TypeScript unpacks sid 1, lat 500000000, lon 300000000, profile 1, no heading/speed/altitude

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | C# pack of `dict-uav.json` | hex `1101000300756176` |
| AC-2 | C# pack of `marker-hidden-delta.json` | 15 bytes, flags `03` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | three dict files | C# pack → TS unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-2 | five marker files | C# pack → TS unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-3 | two trip files | C# pack → TS unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-4 | four route files | C# pack → TS unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-5 | two notice files | C# pack → TS unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-6 | two path files | C# pack → TS unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-7 | position fixture | C# pack → TS unpack | 13-byte golden, 0 left | Compatibility |

## Non-Functional Requirements

**Compatibility**
- Producer hex equals the file. Consumer fields equal the file entity.

**Reliability**
- Bytes left after unpack are 0.

## Constraints

- The consumer uses the same scheme as the producer.
- No registry call.
- TypeScript unpack uses the class, not a dictionary.

## Risks & Mitigation

**Risk 1: Both sides compare only hex**
- *Risk*: they can both miss a field the same way
- *Mitigation*: TypeScript must unpack to the entity, not only match hex

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |

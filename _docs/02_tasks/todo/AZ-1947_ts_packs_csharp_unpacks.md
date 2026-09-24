---
loop: 3
branch: dev
---

# TypeScript packs Archangel fixtures, C# unpacks

**Task**: AZ-1947
**Name**: TypeScript packs Archangel fixtures, C# unpacks
**Description**: TypeScript packs each Archangel live packet. C# unpacks those exact bytes into a class.
**Complexity**: 5 points
**Dependencies**: AZ-1945, AZ-1948
**Component**: library
**Tracker**: AZ-1947
**Epic**: pending

## Problem

C# packing a fixture that TypeScript can read does not prove the other direction. A flags bit, a UTF-8 count, or a 2-bit kind can still be written wrong from the Vue side and only fail when C# unpacks.

## Outcome

- TypeScript `pack` writes each file in `fixtures/archangel/` (the same files as AZ-1948). C# `Unpack.Run<T>` yields that entity. Wrong fields: 0. Bytes left: 0. Hex matches the file.
- The row has no type member. The type byte is the scheme type number (AZ-1945).
- Drivers follow `.github/workflows/drivers/handoff.ts` and `.github/workflows/drivers/csharp/Handoff.cs`: TypeScript prints hex, C# unpacks that hex.
- Real `pack` and real `unpack`. No stub.

## Fixtures

Same table as AZ-1948. Do not add a second copy of the files.

| File | Packet | Hex |
|------|--------|-----|
| `dict-uav.json` | Dict | `1101000300756176` |
| `dict-empty.json` | Dict | `1101000000` |
| `dict-ukrainian.json` | Dict | `1102000a00d0b2d0b0d0b6d0bad0b0` |
| `marker-rest-id.json` | Marker | `2001000065cd1d00a3e111010700202800` |
| `marker-bearing.json` | Marker | `2001000065cd1d00a3e111020700045a00` |
| `marker-hidden-delta.json` | Marker | `2001000065cd1d00a3e11101070003` |
| `marker-author.json` | Marker | `2001000065cd1d00a3e11101070010010080e14e68` |
| `marker-stored-zero.json` | Marker | `2001000065cd1d00a3e111010700040000` |
| `trip-full.json` | Trip | `30010003e91f10000f001100022a000065cd1d00a3e111070000001200` |
| `trip-position-only.json` | Trip | `3001000320000065cd1d00a3e111` |
| `route-two-point.json` | Route | `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` |
| `route-one-point.json` | Route | `3410001500042d0001000065cd1d00a3e111` |
| `route-four-point.json` | Route | hex recorded in the file (AZ-1948) |
| `route-five-point.json` | Route | hex recorded in the file (AZ-1948) |
| `notice-body-coords.json` | Notice | `3864000000061a0080e14e681b000065cd1d00a3e111` |
| `notice-unread-bare.json` | Notice | `3864000000001a0080e14e68` |
| `path-one.json` | MarkerPath | `2101000065cd1d00a3e111` |
| `path-several.json` | MarkerPath | `2101000065cd1d00a3e111108ccd1d10cae111` |
| `target-position.json` | Target | `4001000065cd1d00a3e1110100` |

## Scope

### Included

- TypeScript packs, C# unpacks, for every file in the table
- C# bind to the class (`Unpack.Run<T>` / `Bound<T>`), not a dictionary

### Excluded

- Python, Rust, Java, C++
- A registry publish
- A map from type byte to scheme
- A stub in place of `pack` or `unpack`
- Rewriting the fixture files (AZ-1948 owns them)

## System Under Test Boundary

TypeScript `pack` in this repo. C# `Unpack` in this repo. The bytes between them are the only input.

## Acceptance Criteria

**AC-1: Dict UTF-8**
Given `dict-uav.json`, `dict-empty.json`, and `dict-ukrainian.json`
When TypeScript packs each entity and C# unpacks the bytes
Then hex matches that file, wrong fields are 0, and bytes left are 0

**AC-2: Marker empty group and author group**
Given `marker-rest-id.json`, `marker-bearing.json`, `marker-hidden-delta.json`, `marker-author.json`, and `marker-stored-zero.json`
When TypeScript packs and C# unpacks
Then hex matches that file, wrong fields are 0, bytes left are 0

**AC-3: Trip card and motion flags**
Given `trip-full.json` and `trip-position-only.json`
When TypeScript packs and C# unpacks
Then hex matches that file, wrong fields are 0, bytes left are 0

**AC-4: Route u2 kinds**
Given `route-two-point.json`, `route-one-point.json`, `route-four-point.json`, and `route-five-point.json`
When TypeScript packs and C# unpacks
Then hex matches that file, wrong fields are 0, bytes left are 0

**AC-5: Notice body and coordinates**
Given `notice-body-coords.json` and `notice-unread-bare.json`
When TypeScript packs and C# unpacks
Then hex matches that file, wrong fields are 0, bytes left are 0

**AC-6: Repeat trail**
Given `path-one.json` and `path-several.json`
When TypeScript packs and C# unpacks
Then hex matches that file, wrong fields are 0, bytes left are 0

**AC-7: Position record**
Given `target-position.json`
When TypeScript packs and C# unpacks
Then the bytes are `4001000065cd1d00a3e1110100`, sid 1, lat 500000000, lon 300000000, profile 1, heading/speed/altitude absent, bytes left 0

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | TS pack of `dict-uav.json` | hex `1101000300756176` |
| AC-7 | TS pack of `target-position.json` | hex `4001000065cd1d00a3e1110100` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | three dict files | TS pack → C# unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-2 | five marker files | TS pack → C# unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-3 | two trip files | TS pack → C# unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-4 | four route files | TS pack → C# unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-5 | two notice files | TS pack → C# unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-6 | two path files | TS pack → C# unpack | hex match, 0 wrong fields, 0 left | Compatibility, Reliability |
| AC-7 | position fixture | TS pack → C# unpack | 13-byte golden, 0 left | Compatibility |

## Non-Functional Requirements

**Compatibility**
- Producer hex equals the file. Consumer fields equal the file entity.

**Reliability**
- Bytes left after unpack are 0.

## Constraints

- The consumer uses the same scheme as the producer.
- No registry call.
- C# unpack uses `Unpack.Run<T>`, not a dictionary.

## Risks & Mitigation

**Risk 1: This task re-packs different bytes than AZ-1948**
- *Risk*: TypeScript could drift from the C# hex
- *Mitigation*: both tasks assert the same files; a mismatch fails both

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |

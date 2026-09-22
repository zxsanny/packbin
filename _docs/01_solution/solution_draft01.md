# Solution Draft

loop: research
draft: 01
replaces: nothing
existing `solution.md`, `schema.md`, and `languages.md` stay as they are.

## Product Solution Description

Two libraries walk a field list the caller already wrote. C# writes with `BinaryPrimitives` little-endian methods. TypeScript writes with `DataView` and `littleEndian = true`. The bytes are the fields, in order. A shared hex fixture is the check that the two walks still match.

```
caller field list
      │
      ├─ C# BinaryPrimitives  → bytes
      └─ TypeScript DataView  → the same bytes
```

Vue and React import the TypeScript library. There is no code generator in the first release.

## Existing/Competitor Solutions Analysis

Protobuf, MessagePack, FlatBuffers, CBOR, and Cap'n Proto add their own structure bytes. Protobuf's documentation says those bytes are not canonical across languages (Source #7). Kaitai Struct can describe a layout that adds nothing, and version 0.11 writes only Java and Python (Source #9, #10). A one-language layout helper still leaves a second list. A compiler from one schema file is deferred, matching the restriction that the first release has no generator.

## Architecture

### Component: Wire codec

| Solution | Tools | Pinned Mode/Config | Advantages | Limitations | Requirements | Security | Cost | API Capability Evidence | Fit |
|----------|-------|--------------------|-----------|-------------|-------------|----------|------|-------------------------|-----|
| Runtime primitive walk | `System.Buffers.Binary.BinaryPrimitives`; `DataView` | Little-endian fixed widths, field order is wire order, no tag byte | Meets 0 extra bytes and the golden hex | Each language writes the list by hand | .NET LTS and Node LTS at publish | No auth, no network | $0 | MVE: Fact #10; docs: Source #15, #16 | Selected |
| Protobuf | protobuf | Standard binary serialization | Many languages | Adds tags; bytes are not canonical | A .proto file | N/A | $0 | docs: Source #7 | Rejected |
| Kaitai Struct | kaitai-struct-compiler 0.11 | `--read-write` | One spec | Write is Java and Python; it is a generator | JVM compiler | N/A | $0 | docs: Source #9 | Rejected |
| Tagged serializers | MessagePack, FlatBuffers, CBOR, Cap'n Proto | Their standard encodings | Mature | Extra structure bytes | Their runtime | N/A | $0 | docs: Source #5, #7 | Rejected |

**Exact-fit evidence**:

- Project constraints checked: no tag bytes, C# and TypeScript both pack, 0 mismatches, short input returns 0 values, 100000 round trips ≤ 1 second
- Evidence: Fact #8, #9, #10
- Disqualifiers: none for the primitive walk
- Restrictions × Candidate-Modes sub-matrix: `06_component_fit_matrix.md` § Runtime primitive walk
- API capability gates: MVE saved and run

### Component: Distribution

| Solution | Tools | Pinned Mode/Config | Advantages | Limitations | Requirements | Security | Cost | API Capability Evidence | Fit |
|----------|-------|--------------------|-----------|-------------|-------------|----------|------|-------------------------|-----|
| Test workflow | GitHub Actions | `on: [push, pull_request]`, run the golden check | Matches AC-11 | Does not upload | The GitHub repo | CI has read access to the repo | $0 | MVE: Fact #10; docs: Source #14 | Selected |
| Tag upload | GitHub Actions | Tag runs `npm publish` and `dotnet nuget push` with secrets | Matches the written publish restriction | Not executed here | npm and NuGet accounts, secrets | Tokens in GitHub Actions secrets | $0 | docs: Source #12, #13 | Experimental only |

Trusted publishing (OIDC) is the path npm and NuGet document now. It was not selected. The confirmed restriction says registry credentials stay in the CI secret store.

## Testing Strategy

### Integration / Functional Tests

- Pack the position values and compare to `4001000065cd1d00a3e1110100`. Mismatched bytes: 0.
- Unpack that hex. Field mismatches: 0. Motion field count: 0.
- Run the same fixture in C# and TypeScript. Mismatched bytes: 0.
- Clear optional bit adds 0 bytes. Set bit adds the field width. A buffer that ends inside the field returns an error and 0 values.
- Conditional group adds 0 bytes or the group width.
- Repeated group rejects 1 leftover byte and returns 0 values.

### Non-Functional Tests

- 100000 pack-then-unpack round trips of the position fixture finish in ≤ 1 second on one core, in each first-release language.
- The golden check runs on every push and pull request. A mismatch fails the check.
- A version tag publishes only after that check passes. The upload itself is not yet demonstrated.

## References

See `_docs/00_research/01_source_registry.md`.

## Related Artifacts

- AC assessment: `_docs/00_research/00_ac_assessment.md`
- Fit matrix: `_docs/00_research/06_component_fit_matrix.md`
- MVE: `_docs/00_research/raw/mve/`
- Tech stack evaluation: not run (Phase 3 optional)
- Security analysis: not run (Phase 4 optional; security was marked out of scope)

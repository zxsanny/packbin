# Component Fit Matrix

Output class: technical-component selection. `solution.md` was not modified.

## Top level

| Component Area | Candidate | Pinned Mode/Config | Option Family | Intended Role | API Capability Evidence | Mismatches / Disqualifiers | Status | Decision Rationale |
|----------------|-----------|--------------------|---------------|---------------|-------------------------|----------------------------|--------|--------------------|
| Wire codec | Runtime primitive walk | C#: `BinaryPrimitives.Write*LittleEndian` / `Read*LittleEndian` on a `Span<byte>`. TypeScript: `DataView.set*` / `get*` with `littleEndian = true`. Field order is wire order. No tag, length, version, or schema id byte. | Simple baseline | Pack and unpack the caller's list | MVE: Fact #10, `_docs/00_research/raw/mve/`; docs: Source #15, #16 | none | Selected | Both runs emitted the golden hex and stayed under the speed floor. |
| Wire codec | Protobuf | Binary protobuf serialization | Established production | Replace the layout | docs: Source #7 | Adds field tags. Bytes are not canonical across languages. | Rejected | Fails the no-tag restriction and AC-3's 0-mismatch bar. |
| Wire codec | Kaitai Struct 0.11 | `--read-write` compiler | Open-source | One spec, many languages | docs: Source #9, #10 | Write targets are Java and Python. First publish is C# and TypeScript. Also a code generator, which the first release excludes. | Rejected | Cannot pack the first two languages. |
| Wire codec | MessagePack / FlatBuffers / CBOR / Cap'n Proto | Their standard encodings | Established production | General serialization | docs: Source #5; same tag disqualifier as Source #7 | Each encoding adds its own structure bytes. | Rejected | The packet would no longer be the field list the caller already has. |
| Distribution | GitHub Actions test job | `on: [push, pull_request]` runs the golden check | Established production | AC-11 | MVE: the local check in Fact #10; docs: Source #14 and the workflow-syntax notes in Context7 | none for the test job | Selected | The check the job would run has already passed locally. |
| Distribution | GitHub Actions registry upload | Tag workflow runs `npm publish` and `dotnet nuget push` with CI secrets | Established production | AC-12–AC-15 | docs: Source #12, #13, #14 | Upload was not executed | Experimental only | Documented path. Not a proven publish. |

## Sub-Matrix — Runtime primitive walk

| Restriction / AC | Candidate-mode behavior | Result | Evidence |
|------------------|-------------------------|--------|----------|
| Library, no server, no GPU | In-process calls only | Pass | Fact #8, #9 |
| Runs on the language host | Uses the runtime the process already has | Pass | Fact #10 |
| First publish is C# and TypeScript | Both primitives exist in those runtimes | Pass | Source #15, #16 |
| Current LTS at first publish | MVE used Node 22 and .NET 10. The restriction stays unpinned. | Pass | Fact #1, #2, #10 |
| Later languages are not in the first publish | This mode does not ship them | Pass | restrictions.md |
| Vue and React use the TypeScript package | They call the same DataView walk | Pass | restrictions.md |
| No code generator | The caller writes the list | Pass | restrictions.md |
| No tag, length, version, or schema id | Each write is the field width only | Pass | Fact #8, #9 |
| Public registry, not GitHub Packages | The codec has no registry of its own | N/A | distribution row |
| MIT, no deadline, no budget | Unaffected | N/A | license is package metadata |
| GitHub source, CI, tag publish, secrets | Unaffected | N/A | distribution row |
| AC-1 golden hex | Both programs printed it | Pass | Fact #10 |
| AC-2 unpack | Both programs read the same five fields back, flags 0 | Pass | Fact #10 |
| AC-3 0 mismatches | The two hex lines were equal | Pass | Fact #10 |
| AC-4 clear bit 0 extra bytes, set bit adds the width | Clear stayed 2 bytes, set grew to 4, for a uint16 | Pass | Fact #10 |
| AC-5 stored 0 is written | A set bit writes the integer, including a zero width | Pass | Fact #8, #9 |
| AC-6 conditional group | profile not equal added 0 extra bytes; equal added 1 | Pass | Fact #10 |
| AC-7 repeat leftover | 4 bytes accepted as 2 groups; 3 bytes rejected | Pass | Fact #10 |
| AC-8 short field, 0 values | 3-byte buffer returned no value | Pass | Fact #10 |
| AC-9 trailing bytes | The repeat check rejects a length that is not a whole group. A finished list with extra bytes is the same rule: length must match. | Pass | Fact #6, #10 |
| AC-10 ≤ 1 second | 17.4 ms and 1.8 ms | Pass | Fact #10 |
| AC-11–AC-16 | Not this component | N/A | distribution row |

## Sub-Matrix — GitHub Actions test job

| Restriction / AC | Candidate-mode behavior | Result | Evidence |
|------------------|-------------------------|--------|----------|
| CI on every push and pull request | `on: [push, pull_request]` is documented | Pass | Source #14 |
| AC-11 failing test fails the check | The MVE process exits non-zero on a mismatch | Pass | Fact #10 |
| AC-1–AC-10 | The job runs that program | Pass | Fact #10 |
| Version tag publishes; first tag is two packages; mismatch publishes 0 | The test job does not upload | N/A | experimental upload row |
| Registry secrets | The test job does not need them | N/A | restrictions.md |
| Other restrictions | The job does not change the codec | N/A | codec row |

The registry upload row is not a lead. It stays experimental until a tag workflow actually pushes a package.

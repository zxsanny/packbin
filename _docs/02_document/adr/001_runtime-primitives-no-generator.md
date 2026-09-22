# ADR-001: Walk field lists with runtime primitives

- **Status**: Accepted
- **Date**: 2026-09-22
- **Deciders**: project owner
- **Supersedes**: —
- **Superseded by**: —

## Context

The packet size is the caller's layout. A tagged serializer or a generator changes who owns that layout and can change the byte count.

- Acceptance criteria addressed: AC-1, AC-3, AC-8
- Restrictions addressed: R-07, R-08
- Risks addressed: R01
- Research source (if any): `_docs/01_solution/solution.md` § What was rejected

Six languages must emit one hex. The first release forbids a code generator. Each language still has to write integers, flags, and groups the same way.

## Decision

We will walk a caller-owned field list with little-endian runtime primitives in each language, and ship no code generator in the first release.

A field marked big-endian is the exception. `flags`, `when`, and `repeat` are helpers in that language, not a second schema. The shared golden hex is the check that the six hand-written lists still match.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Protobuf, FlatBuffers, MessagePack | They add their own bytes, so the size is no longer only the caller's fields (R-08, AC-1) |
| Kaitai Struct | Write support is Java and Python only, and it is a generator (R-07) |
| A YAML compiler on day one | The walker is the product. A compiler waits until the hand-written lists drift (R01) |

## Consequences

### Positive

- The wire size stays the sum of the present fields
- One golden hex fails the tag when any language drifts (AC-3, R01)

### Negative

- Six lists are maintained by hand. A width change is six edits
- There is no single schema file that generates the packages

### Neutral / Open

- A compiler remains a later option. It is not part of this decision

## Evidence

- `_docs/02_document/architecture.md` § Architecture Vision
- `_docs/02_document/architecture.md` § 8. Key Architectural Decisions
- `_docs/01_solution/solution.md` § What was rejected
- `_docs/00_problem/restrictions.md` § Software

## Notes

# ADR-006: Compact text is the one wire form of every string

- **Status**: Accepted
- **Date**: 2026-10-18
- **Deciders**: project owner
- **Supersedes**: —
- **Superseded by**: —

## Context

A string was a 2-byte count and its UTF-8 bytes: about 15 bits per Ukrainian character. The links this library serves (LoRa and similar) carry a few hundred bits per second, and the owner wants Ukrainian, Russian and English text, digits and coordinates in as few bytes as possible. A flipped bit on those links is real, so a scheme in which one wrong bit ruins the rest of a message was ruled out.

- Acceptance criteria addressed: CS-1 to CS-20 (`_docs/02_task_plans/compact-strings/acceptance_criteria.md`)
- Owner decisions (2026-10-18): D1 a table per language and a number mode; D2 a raw-UTF-8 fallback; D4 no built-in word dictionary in v1; D5 tables trained on sentences plus synthetic numbers and then frozen as part of the format; the wire break is accepted (no `v*` tag was ever published); only Raspberry Pi, Android and servers encode and decode strings (LoRa, ESP32 and Cortex-M4F devices only carry bytes); option D for C++
- Research source: `_docs/02_task_plans/compact-strings/research_report.md` and `research/`

ADR-001 (walk the field list with runtime primitives) is not changed: the compact text codec is one more runtime primitive that each package's walker calls for a string. ADR-002 to ADR-005 are not changed.

## Decision

Every string field, list element, dictionary key and dictionary value is written in the format of `_docs/02_document/contracts/library/compact-text.md`, version 1.0.0: a varint payload length, then a bit stream coded with a canonical Huffman table per mode (Ukrainian, Russian, English, number), a capital shift and lock, an escape to raw UTF-8, and a raw-UTF-8 payload when it is not larger. The code-length tables in `fixtures/text/tables.json` are part of the format and are frozen; the encoder is an optimal parse with a fixed tie-break so all eight packages write the same bytes.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Keep `utf8` and add a new compact kind | The owner wants every string compacted; two kinds double the surface and leave the old one in use |
| Unishox2 | 1.7 times larger on Ukrainian in the measurement (9.06 against 5.35 bits per character); its JavaScript port failed to decode 8 to 12 % of Cyrillic sentences; a C reference would add a dependency to the allocation-free core |
| Predictive bigram coding (about 20 % smaller) | One flipped bit ruins the rest of the string; tables of about 6,000 entries |
| Fixed 6-bit alphabet with bigram slots | 12 % larger; a simple lowercase-only design |
| A shared table for all languages (overlay) | 1 to 3 % larger; its only gain, a smaller table, no longer matters once the encoders and decoders are on Raspberry Pi, Android and servers |
| A version byte | The library adds no tag, length or version to the bytes beyond the fields |

## Consequences

### Positive

- 35 % of today's size for Ukrainian text, 34 % for Russian, 57 % for English, 51 % for coordinates and ids (held-out sentences; `fixtures/text/tables.report.md`)
- A field is never larger than today's
- A flipped bit costs about 7 to 9 % of the characters of its own string and does not reach the next field while the count is intact

### Negative

- Every packet with a string changes its bytes; there is no version marker, so an old packet reads as garbage or an error
- The tables come from literary sentences and synthetic numbers, not from real messages; retraining is another wire break
- Every package gains an encoder (about 150 lines) that must agree on ties; C++ strings are copies (`Text<N>`) and pack needs a scratch buffer

### Neutral / Open

- CRC for a whole message is a separate later task
- A caller-supplied dictionary of words is not in v1

# Rust core: compact text with caller scratch

**Task**: AZ-2754_rust_core_compact_text
**Name**: Rust core: compact text with caller scratch
**Description**: The compact string format in the heap-free core: the optimal parse runs in caller scratch words; text off forwards a payload unchanged.
**Complexity**: 5 points (plus dictionaries from AZ-2753, about 2 points: re-estimate at intake)
**Dependencies**: AZ-2753
**Component**: rust (core)
**Tracker**: AZ-2754
**Epic**: AZ-2750

## Problem

Strings in meshbell messages use the compact format. The std codec allocates; the C++ core runs the parse in caller scratch (3 words per code point) and refuses a string that does not fit.

## Outcome

- A `text` feature: string fields, list elements, dictionary keys and repeat strings encode and decode with the std codec's bytes, using caller scratch.
- Without `text`, a `Packed` member borrows the payload and forwards it; a string member is refused at validate.

## Scope

### Included
- The core codec (encoder in scratch, decoder), the shared generated tables, the `Scratch` shape, the `text` feature switch.
- Dictionaries (moved from AZ-2753 in loop 51): the `dict` kind (u16 entry count, then a string key and the element per entry, keys in the item rows as in lists), and the key order check (strictly ascending by the decoded UTF-8 bytes, a repeated key refused, on pack and unpack, as the std walker does). Every key is a string and the order is compared on decoded text (the C++ core decodes both payloads, `compare_payloads`), so the kind needs this slice's decoder.

### Excluded
- Retraining the tables (owner, CS-D5); a different encoding when scratch is short (never done).

## Acceptance Criteria

**AC-1: Same bytes as std**
Given `fixtures/text/vectors.txt` and the random strings of the std tests
When the core encodes and decodes with enough scratch
Then every encode row is byte-identical and every decode returns the text

**AC-2: Scratch too small (R6)**
Given a string longer than the scratch holds
When `pack` runs
Then `ScratchTooSmall` naming the field and the words needed; no other encoding is written

**AC-3: Text off (R7)**
Given a scheme with a `Packed` member and a scheme with a string member, built without `text`
When validate, pack and unpack run
Then the `Packed` payload is forwarded unchanged; the string member is refused at validate

**AC-5: Dictionaries (from AZ-2753 AC-3)**
Given the dictionary schemes of the std tests and the hostile `dict_keys_*` and `invalid_utf8_dict_key` packets
When the core packs and unpacks
Then the bytes equal the std bytes; keys not strictly ascending, or a repeated key, are refused on pack and unpack as std refuses them; the item storage limit is `TooMany` as for lists

**AC-4: Untrusted payloads**
Given a flipped bit in a payload, a payload cut short, an invalid code
When `unpack` runs
Then an error or a text that differs in that field only; the next field is intact while the count header is intact; no panic

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | vectors file and random strings, differential | equal |
| AC-2 | scratch one word short | `ScratchTooSmall` |
| AC-3 | no-text build cases | forward / refused |
| AC-4 | hostile payloads | bounded, no panic |
| AC-5 | dict differential, unordered and repeated keys | equal / refused |

## Constraints

- Wire bytes do not change (wire-stability policy); the std API and its tests are untouched.
- Fit decisions of `_docs/02_task_plans/rust-nostd-core/feature-description.md`: the caller's row is read and written through a `Row` trait by field id (card 1); a scheme is a plain `&[Field]` slice, so host tests can build it at runtime (card 2); any format change changes the std walker and the core walker in one task and the differential test covers both (card 4).
- No `unwrap`, `expect`, panicking index or unchecked arithmetic on a path reachable from untrusted bytes; lengths use checked or saturating operations.
- Source file length soft cap 500 lines; tests follow AAA; no verbose logs.


## Risks & Mitigation

**Risk 1: Flash and stack for the codec on Cortex-M4F**
- *Mitigation*: the text feature has its own size line in AZ-2751 and no hard limit until the owner sets one

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The first estimate of 5 points covered the whole feature; the slices sum to 34 points | owner (scope per loop) | accepted-risk | Medium |

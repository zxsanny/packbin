---
loop: 35
branch: dev
---

# Compact text: format spec, ADR 006, contract and frozen tables

**Task**: AZ-2646_compact_text_format_spec
**Name**: Compact text: format spec, ADR 006, contract and frozen tables
**Description**: Byte-exact format of a compact string, the contract and ADR, and the frozen code-length tables made by a reproducible training script.
**Complexity**: 5 points
**Dependencies**: None
**Component**: compact-text (all packages)
**Tracker**: AZ-2646
**Epic**: AZ-2645

## Problem

Strings cost a 2-byte count plus UTF-8: a 20-letter Ukrainian word is about 42 bytes. The research (`_docs/02_task_plans/compact-strings/research_report.md`) chose scheme B with a table per language and a number mode, but nothing yet fixes the bytes. Eight packages must write the same bytes, so the format, its tie-break rules and its tables need one frozen source.

## Outcome

- A specification that two people can implement and get the same bytes from.
- Frozen code-length tables for four modes, reproducible from a documented recipe.
- ADR 006 and the contract `compact-text.md` at version 1.0.0, frozen.

## Scope

### Included
- `_docs/02_document/contracts/library/compact-text.md`: count varint; payload prefix (3 pad bits, 3 start-mode bits: Ukrainian, Russian, English, number, raw UTF-8); the four tables (symbol order, canonical code assignment, lengths at most 16); control symbols (switch, CAP, LOCK, ESC); the raw fallback rule; the encoder rule (optimal parse over mode and caps-lock state, integer lengths, fixed tie-break); decoder rules (zero pad bits, refusals).
- `scripts/text/train_tables.py` and `fixtures/text/tables.json`: training on the Tatoeba sentence exports (recipe with URLs and the sha256 of the three files: ukr 882a6b39…53a7e, rus db438e85…2b92, eng ac9f0d48…cd96) plus synthetic number messages, seeded; the output is committed and a check proves a rerun gives the same bytes.
- ADR 006 `_docs/02_document/adr/006_compact-text-format.md` and the ADR README row.
- A worked example of 5 strings in the contract (bits written out).

### Excluded
- The reference codec and vectors file (AZ-2647); any package code; README (AZ-2658).
- A caller-supplied dictionary, Unicode normalization, a checksum.

## Acceptance Criteria

**AC-1: Grammar is complete**
Given the contract
When two readers follow it for `привіт`, `Привіт, Світе!`, `ПРИВІТ`, `привіт ok 48.46` and `привіт 😀`
Then each gets the bit string and bytes in the worked example, with the count header and the zero pad bits

**AC-2: Tables are frozen**
Given `fixtures/text/tables.json`
When each of the four tables is read
Then every code length is at most 16, the Kraft sum is exactly 1, and the symbol set matches the contract (letters of the language, space, digits, `, . - : !  ?`, 15 extra marks, switch, CAP, LOCK, ESC; the number mode holds digits, `. , - :` and space)

**AC-3: Tables are reproducible**
Given the recipe and the three corpus files with the recorded sha256
When `train_tables.py` is run twice
Then the output equals the committed `tables.json` byte for byte both times

**AC-4: Raw fallback and empty string**
Given the contract
When its rules are applied to the empty string and to a string where the compact form is larger
Then count 0 is the empty string (1 byte); start mode 4 (raw) is used when the compact payload is not smaller, so a field is never larger than 2 + the UTF-8 bytes (CS-13, CS-15)

**AC-5: Decoder refusals listed**
Given the contract
When a stream ends inside a code, has a non-zero pad bit, names an undefined symbol, carries an ESC cut short or invalid UTF-8
Then each case is listed as a refusal that names the field (CS-9, CS-16)

**AC-6: Size targets met**
Given the held-out Tatoeba sentences and the number messages
When the frozen tables are applied with the training script's own encoder
Then the sizes meet CS-1, CS-2 and CS-14 and the report is saved next to `tables.json`

**AC-7: ADR accepted**
Given ADR 006 and the ADR index
When the index is read
Then ADR 006 is `Accepted`, names the wire break and the tables as part of the format, and amends nothing of ADR 001 to 005

## Non-Functional Requirements

**Reproducibility**
- The training run takes no randomness except a fixed seed written in the recipe.

**Compatibility**
- Position record AC-1 (13 bytes) is untouched.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | worked example | every bit string and byte string recomputed by a small script matches the document |
| AC-2 | tables.json checks | code lengths, Kraft sum, symbol sets |
| AC-3 | rerun | byte-identical tables.json |
| AC-7 | ADR index | row present, status Accepted |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | held-out sentences + number messages | size table against CS-1, CS-2, CS-14 | bounds met | CS-1, CS-2, CS-14 |
| AC-3 | corpus files with recorded sha256 | train twice | identical output | — |

## Constraints

- The wire format is the one in `_docs/02_document/contracts/library/compact-text.md` (AZ-2646). A language never invents a choice the contract fixes (tie-breaks, table order, pad bits).
- The encoder works on the UTF-8 bytes this package already produces for a string today, so lone-surrogate and invalid-input behavior of the language does not change (fit decision, feature-description).
- Positions: a string field, a list element, a dictionary key, a dictionary value that is a list of strings, a string under `repeat`, `times` or `flags` (scenario S12). Dictionary pairs are still sorted by the key's UTF-8 bytes before the keys are encoded; a repeated decoded key is refused (S10).


## Contract

This task produces `_docs/02_document/contracts/library/compact-text.md` (draft exists; this task freezes it at 1.0.0). Consumers: AZ-2647 to AZ-2658.


## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Wire break: packets with strings written before this loop cannot be read | Owner accepted 2026-10-18 (no tag was ever published) | accepted-risk | Medium |
| The tables come from literary sentences and synthetic numbers, not the owner's real messages | Owner D5 2026-10-18: freeze; real messages may retrain before the freeze if supplied | open | Medium |

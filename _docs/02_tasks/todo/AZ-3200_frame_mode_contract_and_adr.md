---
loop: 69
branch: dev
---

# Frame mode: contract 2.0.0 and ADR 008

**Task**: AZ-3200_frame_mode_contract_and_adr
**Name**: Frame mode: contract and ADR (PB-01)
**Description**: The session contract gains a `mode` setting; `frame` mode and the MAC-only call are specified byte for byte, and ADR 008 records that authentication enters packbin's scope for frame mode only.
**Complexity**: 4 points
**Dependencies**: None
**Component**: library contracts and docs
**Tracker**: AZ-3200
**Epic**: AZ-3199

## Problem

The session contract (`pack-session.md` 1.0.0) defines a stream only: an implicit per-direction counter, keys from a seed and a 16-byte opener, no tag. The project says authentication is out of scope (acceptance criteria, `architecture.md` "Authentication: none inside the library", restriction R-08: no tag on the wire). A LoRa mesh cannot use that stream: frames are lost, reordered and duplicated, anyone with a radio can flip ciphertext bits, and there is no connection to hold a handshake. The owner decided on 2026-10-19 (route A) that the radio seal is a `frame` mode of the session. The normative text, with worked examples E1 to E5, is the hand-off spec PB-01 (`_docs/02_task_plans/rust-m33f-and-frame-mode/input/PB-01_frame_mode_contract_and_adr.md`).

## Outcome

- `pack-session.md` 2.0.0 with a Configuration section and a Frame mode section (key schedule, nonce, encryption, tag, body, seal, open order, replay window, error kinds, uniqueness rule); the MAC-only call in the same contract or in `frame-mac.md`. Stream text and bytes unchanged.
- ADR 008 "Authentication in frame mode" (truncated HMAC-SHA256 over Poly1305, encrypt-then-MAC, a caller nonce and no randomness; amends ADR 001's size rule for frame mode only; index updated).
- `_docs/00_problem/` files and the `architecture.md` authentication line say authentication is in scope for frame mode only; R-08 gains exactly one exception: a frame-mode body ends with its tag.
- README "Frame session" section with the uniqueness rule in bold; its Rust example arrives with the code (AZ-3204), because an example of an API that does not exist yet cannot compile.

## Scope

### Included
- `_docs/02_document/contracts/library/pack-session.md` (version bump, Change Log), ADR 008 and `adr/README.md`, `_docs/00_problem/` (acceptance criteria out-of-scope line, restrictions R-08), `_docs/02_document/architecture.md` (authentication line), the Rust README section.

### Excluded
- Any code, vectors (AZ-3201, AZ-3202, AZ-3203).
- Any change to stream-mode bytes, operations or results.
- C#, Java, Swift and the other packages.
- Scenario S10 (a caller reusing a `msg_id`): the library cannot check it; this task states the rule, in bold, with meshbell's `msg_id` as the example (AC-6).

## Acceptance Criteria

**AC-1: Every byte is determined**
Given the contract alone
When a reader implements seal, open, the replay window and the MAC-only call
Then every byte of keys, nonce, ciphertext, M, tag and body, and every result, is determined: 0 open choices

**AC-2: The worked examples follow from the contract**
Given the contract and an independent script written only from it
When E1 to E5 are recomputed
Then 5 of 5 match `input_data/expected_results/results_report.md`

**AC-3: Stream unchanged**
Given `mode = stream`
When the contract is compared with 1.0.0
Then 0 stream bytes, operations or results changed

**AC-4: Scope recorded**
Given ADR 008, the problem and restriction files and `architecture.md`
When they are read
Then frame mode authenticates, stream mode does not, R-08 has exactly 1 exception (the tag), and the reasons are stated

**AC-5: Open order and refusals**
Given the open procedure
When a reader checks it
Then no MAC runs for a duplicate or too-old counter, 0 plaintext bytes are written before the tag matched, and a failed open changes the window 0 times

**AC-6: Uniqueness rule**
Given the README and the contract
When they are read
Then the `msg_id` uniqueness rule is stated in bold, with meshbell's `msg_id` (source, id field, creation wave) as the example

## Unit Tests

None (documentation task). AC-2 is checked by an independent Python script from the contract text, kept in the scratchpad and re-run by AZ-3202 as `framefmt.py`.

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | contract text only | independent recomputation of E1 to E5 | 5 of 5 values equal | — |
| AC-1, AC-5, AC-6 | the contract | read-through against the PB-01 acceptance list | each item found, 0 choices left open | — |

## Constraints

- Language-neutral normative text: no Rust-only types.
- A new mode is a major version of the contract (2.0.0); contract Change Log entry; ADR numbering in `adr/`.
- Fit decision 1: authentication enters scope for frame mode only (owner route A, 2026-10-19); ADR 008 amends ADR 001's "the size is the sum of the fields" for frame mode.
- The error kinds `TagMismatch`, `Duplicate`, `TooOld` carry the same names in every package.

## Risks & Mitigation

**Risk 1: A caller reuses a `msg_id`**
- *Risk*: reuse breaks confidentiality of both messages.
- *Mitigation*: the rule in bold in the README and the contract; meshbell's ids are unique by construction.

**Risk 2: The 4-byte tag is judged too short later**
- *Mitigation*: `tag_len` 8 and 16 exist; fixed per loaded key, so a change is a new key or epoch.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The project said authentication is out of scope | owner route A, 2026-10-19; ADR 008 | resolved | High |
| PB-01 is 4 points here, 3 in the Jira table | owner | accepted-risk | Low |

## Contract

This task produces the contract at `_docs/02_document/contracts/library/pack-session.md` (2.0.0; MAC-only in the same file or `frame-mac.md`). Consumers (AZ-3202, AZ-3203, meshbell) read that file, not this spec.

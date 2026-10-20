# Autodev Loop Plan — Loop 52

loop: 52
kind: product
confirmed: true
branch: dev
ship: false

Intake: hopper hit on wave B of epic AZ-2750 (`handoff52.md`): AZ-2754 (compact text, `text` feature, plus dictionaries moved from AZ-2753) and AZ-2755 (ECC, `ecc` feature). Re-estimate at intake: AZ-2754 is 8 points (text 5, dicts 3); the slice is already decomposed (loop 50), so no `/decompose`. AZ-2756, AZ-2757 stay unclaimed (wave C, loop 53). All three batches write `rust/src/nostd/**`, so they run in sequence.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs already in `todo/` (decomposed in loop 50) |
| decompose-feature | 9.5 | Decompose Feature | no | done in loop 50 |
| implement | 10 | Implement | yes | batch 1 text (AZ-2754), batch 2 dictionaries (AZ-2754), batch 3 ECC (AZ-2755); one total review at the end (owner rule) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one run at HEAD: rust, rust-embedded, ring, scaffold, publish-gate |
| test-spec-sync | 12 | Test-Spec Sync | no | the ACs live in the task specs; product ACs do not change |
| update-docs | 13 | Update Docs | yes | public `nostd` API gains strings, dicts, scratch, parity |
| security | 14 | Security Audit | yes | the decoder of untrusted bytes grows (compact text, repair in place) |
| performance | 15 | Performance Test | no | no latency NFR; sizes are checked by the embedded stage |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | task complexity 8; loop 51 retro was the last (check interval) |
| local-deploy | — | Local deploy + open site | yes | none (library) |
| smoke | — | Smoke acceptance | yes | script in `smoke52.md` |

## Implementation

### Files that change
`rust/src/nostd/**` (`text/` module: tables, encoder, decoder; kinds `Utf8`, `Utf8Wire`, `Dict`; scratch through `Pack`; `ecc.rs`; parity on `Scheme`), `rust/src/walk/text_tables.rs` is read by `nostd` through `#[path]` (one generated file), `rust/src/ecc.rs` only if the shared algorithm needs a move, `rust/tests/nostd_*` and `nostd_support/**`, `rust/embedded/feature-sets.txt` and `limits.txt`, `.github/workflows/run-suite.sh` (feature runs), `_docs/**`.

### Order of work
1. Batch 1 (AZ-2754 text): const tables on Rust 1.79 (no `&mut` in const fn: by-value builders), UTF-8 check, count varint, decoder into a bounded sink, encoder in caller scratch (`pack_with`), `Utf8` (decoded copy through `Row::bytes` / `slots`) and `Utf8Wire` (payload as it is), list elements; `text` off refuses `Utf8` at validate and forwards `Utf8Wire`.
2. Batch 2 (AZ-2754 dicts): `dict` kind (key entry, element), ascending key order on pack (bytes) and unpack (decoded payloads compared without storage), `TooMany` at the item storage.
3. Batch 3 (AZ-2755 ECC): the std algorithm made shareable (no `Cow`/`Vec` in the shared part), `Scheme::with_parity`, `pack` appends parity, `unpack` detects, `unpack_repair` repairs in the caller's buffer, 254-byte limit, `ecc` off refuses parity.

### Proof
Differential test per kind (std bytes equal core bytes, std rows equal core rows) with strings and dicts in every presence context; text vectors file; hostile `dict_keys_*` and `invalid_utf8_dict_key`; ecc vectors with k wrong bytes; a scratch one word short; builds with and without each feature; the embedded stage sets `text` and `ecc` added to `feature-sets.txt` (flash and stack figures, no limit until the owner sets one).

### Risks
Flash and stack of the codec on Cortex-M4F (no limit yet). The decoder must keep to `get`, checked arithmetic and zipped copies (the panic-path link check). Const table build on Rust 1.79 (no `const_mut_refs`).

## Assessment rounds

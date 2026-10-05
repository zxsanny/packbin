---
loop: 12
---

# Rust and C++ pin a split bit inside an untaken `when` (`bitwhen` vector)

**Task**: AZ-2133_rust_cpp_bitwhen
**Name**: Rust and C++ bitwhen
**Description**: Rust and C++ tests pin the `bitwhen` bytes; both drivers join the `bitwhen` ring.
**Complexity**: 1 point
**Dependencies**: AZ-2082_rust_flag_bits_bool
**Component**: rust, cpp
**Tracker**: AZ-2133
**Epic**: AZ-2069

## Problem

Loop 12 feature assessment (`_docs/loops/loop12/assessment12.md` U4). Cross-language `bitwhen` vector (owner decision U4, 2026-10-05): scheme type 1 = `u8 k` (id 0), split flag byte `m`, `when(eq(k, 1), [m.bit(u8 v)])`. Row `{k:0, v:5}` packs `010001` (the bit is set from the row even though the `when` is not taken; unpack checks the `when` first and never reads it); row `{k:1, v:5}` packs `01010105`. Driver contract: `pack-bitwhen` prints the hex of `{k:0, v:5}`; `unpack-bitwhen <hex>` exits 0 only if unpack is ok, `k == 0` and `v` is absent.

## Owner decisions (2026-10-05)

U4: A — keep the bytes (all five packages agree), reword project AC-4 to "when its field is walked", pin them with one shared vector.

## Acceptance Criteria

**AC-1: Rust**
Given the `bitwhen` scheme (map API; the typed API has no flag-byte form)
When `{k:0, v:5}` and `{k:1, v:5}` are packed and unpacked
Then `010001` (unpack `k = 0`, no `v`) and `01010105` (round-trips); the Rust driver implements `pack-bitwhen` / `unpack-bitwhen`

**AC-2: C++**
Given the same scheme in C++ (`flag_byte` / `flag_bit`)
When the same rows are packed and unpacked
Then the same bytes; `handoff.cpp` implements `pack-bitwhen` / `unpack-bitwhen`

## Constraints

- ADR-001; files ≤ 500 lines; no wire change.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | — | — |

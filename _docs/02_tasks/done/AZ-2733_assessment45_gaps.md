---
loop: 45
branch: dev
---

# Loop 45 assessment gaps: the small items

**Task**: AZ-2733_assessment45_gaps
**Name**: Loop 45 assessment gaps (CS-D1, CS-D2, CS-D3, CS-D4, CS-D6, CS-D9, EC-D9, EC-D1)
**Description**: The clear and decided gaps of the loop 45 feature assessment that cost little: TypeScript module state, a C++ text test, stale documents, Go seeds, a size report, two speed bounds.
**Complexity**: 5 points
**Dependencies**: None
**Component**: TypeScript, C++, Go, Python packages; `_docs/` test specs, acceptance criteria and the C++ component description
**Tracker**: AZ-2733
**Epic**: AZ-2645

## Problem

`_docs/loops/loop45/assessment45.md` (verdict CLARIFY, round 1) found these open rows. The owner (2026-10-20) accepted all six recommended answers and chose "small items now, tests next loop". The remaining items are in `Excluded`.

## Outcome

- CS-D1: no module-level variable of `typescript/src/text.ts` holds the last text or field after a pack call returns.
- CS-D2: the C++ suite has a test of a `Text<N>` field under a flags bit, a `times` group and a `repeat`.
- CS-D3: the test-spec documents describe the compact string format and carry the CS, HD and RL ids.
- CS-D4: the Go fuzz seeds hold the compact-format string packets.
- CS-D9: the size report exists where AZ-2657 AC-5 said.
- EC-D9, EC-D1: the ECC acceptance criteria and the C++ component description state the numbers and the proof of today.
- CS-D6: the Python and TypeScript speed tests (40 s, 4 s) use the load-aware helper with a bound set from one measurement.

## Acceptance Criteria

**AC-1** (CS-D1, HD-1): After a TypeScript pack call of a 65,535-character text returns, no module-level variable of `typescript/src/text.ts` references the returned field bytes or the code points or costs of the text: `outBuf` is reset to an empty array and the used part of `scratchPoints` and `scratchCosts` is zeroed. A new test fails on the old code: it drops the result of a pack call, forces a collection and finds the weak reference to the field bytes empty, and a second check reads the scratch arrays zero (through a source check or an existing test seam; no new public API).
**AC-2** (CS-D1): the packed bytes of every `enc` row, the HD-2 case (65,535 characters, 200 rounds, 1 s) and the AC-8 speed test of TypeScript are unchanged and pass.
**AC-3** (CS-D2): a C++ test packs and unpacks a scheme with a `Text<N>` field (a) under a flags bit: bit clear, 0 bytes written and read; bit set with an empty text, 1 byte (count 0); (b) under `times` and under `repeat`: a text round-trips in every round. The C++ table cannot express the flags shape "bit clear, 0 bytes": a bound `Text<N>` under a flags bit is always written (`cpp/src/core/values.cpp:90`) and `Opt<Text<N>>` is `SchemeInvalid`. Owner decision 2026-10-20: that half is excluded (see Excluded); the tests added instead are bit set with an empty text is 1 byte (`01 01 00`), and unpacking a packet with the bit clear leaves the text empty. `times` and `repeat` are tested in full.
**AC-4** (CS-D3): in `_docs/02_document/tests/`, `test-data.md` FT-U-01 and FT-U-02 hold the compact bytes of `zxsanny` and of the empty string as the reference encoder `scripts/text/textfmt.py` gives them (`00` for the empty string); `blackbox-tests-02-strings-lists-dicts.md` no longer says "2-byte count"; every id CS-1 to CS-20, HD-1 to HD-5 and RL-1 to RL-4 appears in `traceability-matrix.md` with the test that covers it, named as in `assessment45.md` Part A.
**AC-5** (CS-D4): the Go seeds `hostile_invalid_utf8*`, `ring_user*` and `ring_nested*` in `go/testdata/fuzz/FuzzUnpack/` equal the compact-format packets of `fixtures/hostile/fuzz/corpus.txt`; `go test` in `golang:1.27` passes.
**AC-6** (CS-D9): `scripts/text/size_report.py` writes `_docs/02_task_plans/compact-strings/size_report.md` with the run date and the sha256 of the recipe files; CS-13 holds on every `enc` row. If the report needs a corpus that is not in the repository, the worker stops and reports it.
**AC-7** (EC-D9, EC-D1): in `_docs/02_task_plans/message-error-correction/acceptance_criteria.md`, EC-4 says a buffer above 254 bytes; EC-12 states the Cortex-M4F image as built now (7,920 B flash of 8,192, 504 B stack of 512, built with `PACKBIN_NO_ECC`) and that "a message packed on the ESP32 and Pico equals the vector bytes" is proven on the host, on QEMU Cortex-M3 and on s390x (owner decision 2026-10-20); EC-13 and results row 16 name the same block size; `_docs/02_document/components/05_cpp_package/description.md` lines 130-131 carry the same numbers.
**AC-8** (CS-D6): the Python AC-8 speed test calls `timing_support.assert_within` (it asserts a fixed `40.0` s today) and the TypeScript AC-8 test keeps `assertWithin` (it already uses `bound(4)`); both nominal bounds are 3 times the best measured time with the host load factor divided out (best of several runs), and the two measured figures replace "(P)" in CS-11 of `_docs/02_task_plans/compact-strings/acceptance_criteria.md` (the parent edits that file from the workers' figures).
**AC-9**: no file under `cpp/src` or `cpp/include` changes (the Cortex-M4F margins of `AGENT_GOTCHAS.md` stay); existing vectors, ring and golden packet are unchanged.

## Excluded

- CS-S3 concurrency tests in five to seven packages, CS-A5 and CS-A10 (criteria change to 3,000 / 30,000 and the missing random and hostile tests in Python, C# and Swift), CS-D7 (the 1 s repeated-text test in Java, C#, Rust, C++) and EC-D2 (one protected session payload in the session cross-language check): owner 2026-10-20, next loop, written to `_docs/loops/loop45/handoff46.md`.
- CS-D5 (retrain the tables on real messages): waits for the owner's 100 to 200 messages before the first `v*` tag.
- C++ absent optional text under a flags bit (the "bit clear = 0 bytes" half of AC-3(a)): not expressible in the C++ table today; excluded by the owner on 2026-10-20 (supporting it would change `cpp/src/core` and `table.hpp` and needs a flash saving first).
- CS-D8 and EC-D11: unchanged, owner-accepted.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The C++ field table cannot express an absent optional text under a flags bit (AC-3) | owner excluded it on 2026-10-20; `times` and `repeat` are tested | accepted-risk | Medium |
| Zeroing the TypeScript scratch arrays costs time on every text encode (AC-1, AC-2) | only the used prefix is cleared; AC-2 keeps the speed tests | open | Low |
| Python and TypeScript timing is measured on a host at load 15 to 25 (AC-8) | the helper's load factor is divided out; the figure is the best of several runs | open | Low |

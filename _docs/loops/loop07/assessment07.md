# Feature assessment — loop 7

loop: 7
feature: borrowed-count
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-09-26
**Implement pass**: batch 01, `_docs/03_implementation/batch_01_loop7_report.md`
**Verdict**: COMPLETE — 5 covered / 4 out-of-scope / 0 gap-clear / 0 gap-unclear

`scenarios.md` absent (pre-4.7 spec). Discoveries table on the batch report is `none`.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | Width-2 list of 0,1,2,3 is one byte `e4` and the count is not repeated | covered | AC-1; `BorrowedCountTests.Width2_FourValues_AreOneByte` and the same case in typescript, python, rust, java, cpp; `Walker.Counted.PackPacked` / `_write_packed` | spec |
| S2 | Width-1 bias −1 packs eight 1-bits as `ff`, and count 1 writes no bitset bytes | covered | AC-2; `Width1_BiasMinusOne_WritesEightBitsOrNone` and peers; `BorrowedCount` / `_borrowed` | spec |
| S3 | Counted group of two lat/lon pairs stops, then a following `u8` of 7 is read | covered | AC-3; `Times_StopsSoTheNextFieldIsRead` and peers; `PackTimes` / `UnpackTimes` | spec |
| S4 | One route scheme round-trips the fixture hex | covered | AC-4; `Route_MatchesFixtureAndRejectsAShortTail` and peers; scheme field list in each test | spec |
| S5 | Wrong list length fails and names the field; a short tail names field, needed, and left, and returns 0 values | covered | AC-5; length-mismatch and short-tail cases in each language; pack length check and `ShortPacket` | spec |
| S6 | Widths other than 1 and 2 | out-of-scope | spec `### Excluded`: "Widths other than 1 and 2." | spec |
| S7 | A bias other than 0 and −1 | out-of-scope | spec `### Excluded`: "A bias other than 0 and −1." | spec |
| S8 | Changing `repeat` or fixed-slot `u2` | out-of-scope | spec `### Excluded`: "Changing `repeat` or fixed-slot `u2`." | spec |
| S9 | A length prefix on the packed list or the counted group | out-of-scope | spec `### Excluded`: "A length prefix on the packed list or the counted group." | spec |

### Gaps that need a decision (gap-unclear)

None.

### Clear gaps to extend (gap-clear)

None.

## Not walked

None.

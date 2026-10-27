# Batch Report

**Batch**: 5 (feature assessment round 1 re-entry)
**Tasks**: AZ-3322_java_frame_config
**Date**: 2026-10-27

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3322_java_frame_config | Done | 3 new (`FrameConfig.java`, `FrameDirections.java`, `FrameConfigTest.java`), `FrameSession.java`, `FrameDirection.java`, `java/test.sh`, 8 test files; README Java example and 9 docs by the parent | `java/test.sh` exit 0 (rerun), `PackbinTest checks: 9725`, 12 test mains, `FrameConfigTest` 27 checks, `frame vectors: 157 rows checked, 0 mismatches`, api-check PASS | one speed check failed once under load 35 (see Discovered 3) |

Origin: feature assessment loop 74 round 1 row D6 (CLARIFY), owner answer "Add them (Recommended)", 2026-10-27. One worker (the AZ-3290 Java worker, resumed twice: the second time to correct my spec, see Discovered 1).

## Code Review Verdict: not run per batch

Owner preference (loop 16): one total review per loop (step 14).

## AC evidence

| AC | Evidence |
|----|----------|
| AC-1 | `javap -public java/out/main/packbin/*.class`: `FrameConfig` and `FrameDirections` present; the only `load` is `public static packbin.FrameSession load(byte[], int, packbin.FrameConfig);`; 0 varargs loads; 11 public frame types |
| AC-2 | `frame vectors: 157 rows checked, 0 mismatches`; `CryptoVectorsTest` asserts 27 rows |
| AC-3 | `FrameConfigTest`: null config, null set and tag length 5 give null; an empty set loads and every seal and open (UP, DOWN, GROUP; open with a valid up body) is `BadValue` and writes nothing; a session loaded with `of(UP)` refuses `seal(DOWN)` and `open(GROUP)`; a mutation check (empty-set refusal put back in a scratch copy) fails `FrameConfigTest` |
| AC-4 | `scripts/frame/readme-examples.sh`: PASS C#, Java, Swift, Rust |
| Android | `api-check PASS: no main-source API above Android API 26` (`FrameDirections` is a private bit mask, no `Set.of`, no `Record`) |
| Probe | main sources plus `fixtures/hostile/fuzz/java/packbin/*.java` compile, exit 0, 76 classes |

## Behavior of the other three packages for an empty set (checked before changing Java)

- C#: `csharp/FrameSession.cs:50` "With FrameDirections.None it returns a session that refuses every Seal and Open as BadValue"; test `FrameRefusalTests.Ac3_LoadWithNoDirectionGivesASessionThatRefusesEverySealAndOpen`.
- Rust: `load_frame_in_place` checks the epoch and that `tag_len` is 4, 8 or 16; `seal.rs:36` refuses a direction not in the set.
- Swift: the `FrameSession` init checks key size, epoch and tag length; `checkCall` refuses a direction not in the set.

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | Clarity |
|---|----------|---------|-------------------|---------|
| 1 | AZ-3322 AC-3 | The first spec text made an empty direction set refuse at load; Rust, C# and Swift load it | spec corrected by the parent, Java matches the three (decision by the parent as a correction of its own spec; the owner asked for the same shape everywhere) | clear |
| 2 | AZ-3322 | `FrameConfig` has no default directions in Java (Swift defaults to `.all`; C# and Rust have none) | one constructor `(tagLength, directions)`; a default is a one-line addition | clear |
| 3 | step 11 | `PackbinTest` AC-8 "100000 round trips: 2.262 s elapsed, nominal bound 1.000 s x load factor 1.31" failed once at host load 35.57; the rerun measured 0.483 s and passed | a load-sampling miss of the timing helper (the factor sampled 1.31 against a load of 35); not this change; step 11 on a quiet host | clear |
| 4 | docs | nine places said Java has no `FrameConfig` or `FrameDirections` (README x2, contract, architecture, module layout, the Java, C# and Swift component descriptions, system flows) | fixed by the parent in this commit | clear |

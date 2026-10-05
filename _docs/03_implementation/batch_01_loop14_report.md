# Batch Report

**Batch**: 1 (loop 14)
**Tasks**: AZ-2094_java_release_17
**Date**: 2026-10-06

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2094_java_release_17 | Done | 13 modified, 5 new | Java suite, `ApiSafeReplacementsTest`, `api-check`, `publish-gate.test.sh` all pass | None |

All six ACs have a test or a check; each was also proved to fail on a violating copy (no `--release 17`, a Java 21 call in a test compile, `Arrays.compareUnsigned` back in, a signed byte compare, a mutable child copy).

## Decisions

- API-level check (spec flagged concern): Animal Sniffer 1.28 `SignatureChecker` against the `android-api-level-26` 8.0.0_r2 signature, run on the compiled main classes inside `java/test.sh`. The jar, ASM 9.10.1 and the signature are pinned by version and SHA-256 and fetched by `java/tools/Fetch.java` (the `java` image has no curl). No hand-written denylist. Cost: a cold cache needs Maven Central; a hash mismatch fails closed. Chosen by the implementer as the spec's recommendation; the owner may veto.
- `List.of` / `List.copyOf` / `Map.of` are in scope (the rule is "no API above Android API 26"). They now go through `Field.immutableCopy` (null items rejected, unmodifiable) or `Collections.singletonList` / `emptyList` / `emptyMap` / `Arrays.asList`.
- `java/test.sh` removes only `out/main` and `out/test`, so the pinned tool cache in `java/out/api-tools` (gitignored) survives. JDK 11 candidates dropped: JDK 11 cannot compile `--release 17`.

## Code Review Verdict: PASS

`/code-review` medium over the full diff: no findings. Parent re-ran the Java suite (`docker compose -f docker-compose.test.yml run --rm java`) and `publish-gate.test.sh`: both exit 0.

CI-parity: PASS. Commands (no `Local pre-push checks` section exists, so inferred from `test.yml` `scaffold`): `docker compose -f docker-compose.test.yml run --rm java`, `bash .github/workflows/report-row.test.sh`, `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/publish-gate.test.sh`. The other five language suites and the `embedded` job read no changed path and run in Run Tests (step 11).

## Test Suite

- Java: all four classes print their pass line (the suite prints no counts); `api-check PASS`.
- Gate: 30 classes in the jar, 30 at major version 61.
- Smoke: main and test compiled with `--release 17`, `PackbinTest` run on `eclipse-temurin:17-jre`: passes, golden hex matches.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `Walker.java` `ByteBuffer.flip()` resolves to the Java 9 covariant override under `--release 17`; Android API 26 has no such method (`NoSuchMethodError`) | AZ-2094 AC-3 | Fixed: `((Buffer) buf).flip()`; the API check found it | clear |
| 2 | README has no Java section | AZ-2094 Scope | One line "Java: Java 17+, Android API 26+." added after the intro | clear |
| 3 | `language-pair.sh` compiles the Java handoff driver without `--release` | AZ-2094 Excluded | Left as is (drivers excluded) | clear |
| 4 | Release notes for the next tag should say older Central versions target JDK 26 | AZ-2094 Flagged concerns | Owner, at the tag | unclear |
| 5 | Spec line numbers had drifted (`Walker.java` 497 lines in the task, 375 now) | AZ-2094 | The API check output was the source of truth | clear |

## Commit

`[AZ-2094] Java jar targets Java 17 and Android API 26`. Body: one line + `Loop: 14`.

## Next Batch: AZ-2095_publish_after_tests

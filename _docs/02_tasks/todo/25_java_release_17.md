# Published Java jar targets Java 17 and Android API 26

**Task**: 25_java_release_17
**Name**: Java 17 / Android API 26 artifact
**Description**: The jar on Maven Central loads on Java 17 and on Android API 26, and the publish gate proves it on every build.
**Complexity**: 2 points
**Dependencies**: None (lands before 27_publish_build_before_upload, which moves the Java build into a build phase)
**Component**: java+publish
**Tracker**: pending
**Epic**: AZ-2069

## Problem

The Java artifact is built by whatever JDK the CI image has, and nothing checks the API level that Android, the named consumer (`_docs/01_solution/languages.md:17`), can use.

- `docker-compose.test.yml:68` runs the `java` service on `eclipse-temurin:26-jdk`. Publishing runs `publish-inside.sh java` inside that service (`publish-registries.sh:300-302` → `run_inside java`).
- `.github/workflows/publish-inside.sh:67` compiles with `javac -encoding UTF-8 -d "$classes" "${sources[@]}"` — **no `--release`**. Class files therefore get the JDK 26 format (major 70), and Java 17/21 JVMs reject the jar with `UnsupportedClassVersionError`. `:68` runs `javadoc` without `--release` either.
- `java/test.sh:46-47` compiles the suite the same way, so CI never compiles against the Java 17 API. A JDK 18+ method would pass the tests and break Java 17 consumers.
- The main sources call APIs above Android API 26 (`scan_csharp_java.md` L19, A14):
  - `Arrays.compareUnsigned(byte[], byte[])` (API 33) at `java/src/main/java/packbin/VarFields.java:342` (dict key ordering).
  - `List.of` / `List.copyOf` / `Map.of` (API 30) at:
    - `Field.java:68,75,159,186,231,235,246,258,272,294`
    - `Packbin.java:104`
    - `Scheme.java:20`
    - `VarFields.java:313,371,434,436,459`
- No test asserts the class-file version. `publish-gate.test.sh` `maven_bundle_checks` (`:179-236`) checks file names, signatures and the absence of `META-INF` only.

User decision (verbatim, 2026-10-05): "Published jar compiled with `--release 17`; no API above Android API 26 (replace `Arrays.compareUnsigned`)."

The decision names `Arrays.compareUnsigned` as the example. The rule "no API above Android API 26" also covers the `List.of`/`List.copyOf`/`Map.of` sites above, so they are in scope.

## Outcome

- Every class in the published jar has class-file major version 61 (Java 17).
- Main sources compile with `--release 17` in tests and in publish; the javadoc jar is built the same way.
- Main sources call no API above Android API 26, and a CI check enforces it.
- Dict key order, and all wire bytes, are unchanged (unsigned UTF-8 byte order, `strings-lists-dicts` restriction).

## Scope

### Included
- Publish build: `.github/workflows/publish-inside.sh` java branch (`:59-108`): `javac --release 17`, `javadoc --release 17`.
- Test build: `java/test.sh:46-47` compiles main sources with `--release 17`. Test sources may use `--release 17` too.
- Replace the API-30/33 calls listed above with API-26-safe equivalents with the same behavior: immutable copies stay immutable, unsigned byte comparison is unchanged.
- Class-version check: in `publish-gate.test.sh` `maven_bundle_checks`, after the container builds the bundle (`:191-196`, version `0.1.2`), run `javap -v` on every `.class` in `packbin-0.1.2.jar` inside the `java` service, which has a JDK. Fail unless every class reports `major version: 61`.
- API-level check: a CI check that fails when main sources reference an API above Android API 26. How it is done is decided at task start (see Flagged concerns). It runs in the CI test path, not only at publish.
- A one-line note in the README Java section and in `_docs/04_deploy/packages.md`: "Java 17+, Android API 26+".

### Excluded
- Changing the CI test image tag `eclipse-temurin:26-jdk`. The restriction "current stable toolchain" (`_docs/00_problem/restrictions.md:11`) stays; `--release` decouples the target from the JDK.
- The drivers (`.github/workflows/drivers/Handoff.java`, `Position.java`). They are not published and may use newer language features, compiled without `--release` as today.
- Typed nested-row fixes (task 32) and Java walker bug fixes (tasks 05, 08, 20).
- Gradle/Maven module metadata or a `pom.xml` (the POM stays generated, `publish-inside.sh:75-103`).

## Acceptance Criteria

**AC-1: Jar class files are Java 17**
Given the Maven bundle built by `publish-inside.sh java` for any version
When `javap -v` reads every class in `packbin-<version>.jar`
Then each reports `major version: 61`.

**AC-2: Main sources compile against the Java 17 API**
Given `java/test.sh` in the CI `java` service
When it compiles `java/src/main/java`
Then it uses `--release 17`, so a call to an API added after Java 17 fails the build.

**AC-3: No API above Android API 26**
Given main sources that call `Arrays.compareUnsigned`, `List.of`, `List.copyOf`, `Map.of` or any other API added after Android API 26
When the API-level check runs in CI
Then it fails and names the class, method and API. With the replacements in place it passes.

**AC-4: Dict order unchanged**
Given a dict with keys `"b"`, `"a"`, a key starting with byte `0xc3` and an ASCII key
When Java packs it
Then the keys are written in unsigned UTF-8 byte order, as before. The existing dict tests (`SchemeTest`, `PackbinTest`), the golden hex and the language-pair handoffs (user, nested) give identical bytes.

**AC-5: Immutability unchanged**
Given a `Field` or `Scheme` built from caller lists
When the caller changes its list afterwards, or code tries to modify the field's child list
Then the field keeps its original children, and a modification attempt throws `UnsupportedOperationException`, as `List.copyOf` did.

**AC-6: Javadoc built for 17**
Given the publish build
When `javadoc` runs
Then it uses `--release 17`, and the `-javadoc.jar` is still produced (bundle check `publish-gate.test.sh:220-235` still passes).

## Non-Functional Requirements

**Compatibility**
- Java 17, 21 and the CI JDK (26) load and run the jar. Android API 26+ without core-library desugaring.

**Performance**
- AC-10 (100 000 round trips ≤ 1 s) still holds in `PackbinTest`.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-4 | new test: unsigned key order with a non-ASCII leading byte (`0xc3…` after `"z"`) | same bytes as before the change (record the pre-change hex first) |
| AC-5 | field children copy: mutate the source list after construction; try `add` on the field's list | children unchanged; `UnsupportedOperationException` |
| AC-2 | `java/test.sh` compile line | contains `--release 17` and passes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `publish-gate.test.sh` maven bundle step (container build, version 0.1.2) | `javap -v` over every jar class | all `major version: 61`; any other value fails the test job | Compatibility |
| AC-3 | temp branch reintroducing `Arrays.compareUnsigned` | CI API-level check | check fails naming `VarFields` | Compatibility |
| AC-1 | the jar from the bundle check, run on `eclipse-temurin:17-jre` | `java -cp packbin-0.1.2.jar` + a one-class smoke that packs the golden row | prints `4001000065cd1d00a3e1110100` | Compatibility |

The last row is optional but recommended: it is the only direct "loads on 17" proof.

## Constraints

- Canonical path only: the jar is built by `publish-inside.sh` in the CI `java` service; no laptop build or upload (R-15). Verification runs in CI containers.
- Tokens only as CI secrets. The bundle check uses a throw-away GPG key, as it does today (`publish-gate.test.sh:197-219`).
- ADR-001: Java keeps its own walker; no byte change.
- `Walker.java` is at 497 lines. If a replacement helper is needed, place it so that no file goes over the 500-line soft cap (`quality-thresholds.md`).

## Risks & Mitigation

**Risk 1: Main sources use Java 18+ language or library features**
- *Risk*: `--release 17` fails to compile.
- *Mitigation*: Reading shows pattern-matching `instanceof` (Java 16) and `var` (Java 10), both fine for 17. Compile once with `--release 17` at the start of the task and fix only what fails.

**Risk 2: The API-level check needs a new tool**
- *Risk*: Animal Sniffer plus an Android signature artifact is a new dependency.
- *Mitigation*: Run the Complexity Budget Check before adding it (flagged below). Pin it by version and SHA-256 and run it in the `java` container.

**Risk 3: Replacement changes iteration order or mutability**
- *Mitigation*: AC-4/AC-5 tests, golden and language-pair tests.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| How to enforce Android API 26: (A) Animal Sniffer CLI with the `android-api-level-26` signature, pinned, in the `java` container — a real check, new tool; (B) a `javap -c` reference scan against a denylist of known API-27+ methods — no new tool, weak; (C) code review only. Choose A/B/C at task start (meta-rule Complexity Budget Check). Recommendation: A | user | open | Medium |
| `List.of`/`List.copyOf`/`Map.of` are in scope because of the "no API above Android API 26" wording, although the decision's parenthesis names only `Arrays.compareUnsigned` | user (confirm) | open | Low |
| Jars already on Maven Central (`0.1.x`) target JDK 26 and stay there; Central versions are immutable. Release notes for `0.2.0` should say older versions need Java 26 | release owner | open | Low |
| Whether `0.1.x` was actually built on JDK 26 is unverified: no `javap` was run on a published jar | release owner | open | Low |

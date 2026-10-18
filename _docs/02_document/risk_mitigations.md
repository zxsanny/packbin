# Risk Assessment — packbin — Iteration 01

## Risk Scoring Matrix

|  | Low Impact | Medium Impact | High Impact |
|--|------------|---------------|-------------|
| **High Probability** | Medium | High | Critical |
| **Medium Probability** | Low | Medium | High |
| **Low Probability** | Low | Low | Medium |

## Acceptance Criteria by Risk Level

| Level | Action Required |
|-------|----------------|
| Low | Accepted, monitored quarterly |
| Medium | Mitigation plan required before implementation |
| High | Mitigation + contingency plan required, reviewed weekly |
| Critical | Must be resolved before proceeding to next planning step |

## Risk Register

| ID | Risk | Category | Probability | Impact | Score | Mitigation | Owner | Status |
|----|------|----------|-------------|--------|-------|------------|-------|--------|
| R01 | Six hand-written field lists drift | Technical | Medium | High | High | Golden hex on every language. Mismatch count above 0 publishes 0 packages | all six packages | Mitigated |
| R02 | A pushed vcpkg port version stays | External | Low | Medium | Low | The tag pushes a public vcpkg git registry for `packbin`. Rollback is a later port version. A pull request to the curated microsoft/vcpkg registry is not the publish path | C++ package | Mitigated |
| R03 | A published Maven Central version cannot be deleted | External | Low | Medium | Low | The Java component records that rollback is "stop depending on that version" | Java package | Accepted |
| R04 | One language misses the 100000-round-trip bound | Technical | Low | Medium | Low | AC-10 is the same loop in each language. The research loop on C# and TypeScript finished far under 1 second | each package | Accepted |
| R05 | A published Go version cannot be deleted or moved | External | Low | Medium | Low | Go ships as the tag `go/vX.Y.Z` (ADR-004). The tag is pushed last, after the golden gate and every registry, never forced; a re-run finds it at the same commit and pushes nothing, at another commit it fails. `proxy.golang.org` and the checksum database remember the first content, so a bad version is marked `retract` in the `go.mod` of the next patch | Go package | Accepted |
| R06 | Correcting `t` bytes lowers guaranteed detection to `n - t` bytes, and garbage beyond that can be repaired to a wrong message | Technical | Medium | High | High | The default correction limit is 0 (detect only). A `t` above `n / 2` is refused before any byte is read. The contract (`message-ecc.md`) lists the chance that random bytes are accepted for every `n` and `t`, and the README and the component descriptions point to it | all eight packages with the feature | Mitigated by default, open for a caller who sets `t` above 0 |
| R07 | A protected message is at most 254 bytes, and a plain code would accept a lost last byte | Technical | Low | Medium | Low | Pack refuses a clear message above `254 - n` bytes with a typed error and writes nothing. The code covers the clear length as a first byte that is not sent, so a message with one byte more or less (a trailing `00`) fails the check | all seven packages with the feature (C++ pending) | Accepted (limit), Mitigated (length hole) |
| R08 | The Cortex-M4F image has 60 B of flash left, and the correction tables alone are 511 B, so the feature cannot ship on that target | Technical | High | Low | Medium | `PACKBIN_NO_ECC` removes the codec, its tables and `Result.repaired`; `cpp/embedded/arm.sh` builds the whole Cortex-M4F target with it, so flash (8,132 of 8,192 B) and stack (492 B) are unchanged. `parity(scheme, n)` with `n` above 0 is `SchemeInvalid` there, a compile error for a `constexpr` scheme. Cortex-M0+, M3 and ESP32 keep the feature | C++ package | Accepted |

## Detailed Risk Analysis

### R01: Six hand-written field lists drift

**Description**: Each language writes the field list by hand. A width or endian mistake in one language ships different bytes.

**Trigger conditions**: A field width, order, or endian differs and the golden check is skipped.

**Affected components**: all six language packages (Go, the seventh since loop 24, and Swift, the eighth since loop 26, are under the same golden check), GitHub Actions

**Mitigation strategy**:
1. One shared hex fixture is the pass condition for every language
2. A version tag publishes only when the mismatch count is 0

**Contingency plan**: The tag publishes nothing. The lists are corrected and the tag is cut again.

**Residual risk after mitigation**: Low

**Documents updated**: architecture.md ADR-001 and ADR-002, interaction-risks.md, acceptance_criteria.md AC-3 and AC-14

### R02: A pushed vcpkg port version stays

**Description**: AC-13 names vcpkg `packbin`. vcpkg has no upload API. A port version that the tag has pushed stays in the git registry.

**Trigger conditions**: A C++ port that fails the golden hex is pushed.

**Affected components**: C++ package, GitHub Actions

**Mitigation strategy**:
1. The golden check gates the tag before the registry push
2. The publish path is a public vcpkg git registry. A pull request to the curated microsoft/vcpkg registry is not used, because that merge is manual and the package would not exist when the tag is pushed
3. Rollback is a later port version. Callers stop depending on the bad one

**Contingency plan**: Publish a later port version. The other five packages still wait for the same tag. Nothing publishes from a laptop.

**Residual risk after mitigation**: Low

**Documents updated**: architecture.md external systems, components/05_cpp_package/description.md, packages.md, infra_topology.md, acceptance_criteria.md AC-13

### R03: A published Maven Central version cannot be deleted

**Description**: Central keeps a published version. A bad Java artifact cannot be unpublished the way an npm version can be deprecated.

**Trigger conditions**: A Java package that fails the golden hex is uploaded.

**Affected components**: Java package

**Mitigation strategy**:
1. The golden check gates the tag before any upload
2. The Java component states that rollback is to stop depending on that version

**Contingency plan**: Publish a later version. Callers stay on the last good version.

**Residual risk after mitigation**: Low

**Documents updated**: components/06_java_package/description.md, architecture.md external integrations

### R04: One language misses the speed bound

**Description**: AC-10 requires 100000 position round trips in 1 second on one core, in each language.

**Trigger conditions**: A language implementation adds allocation or copying inside the loop and the elapsed time exceeds 1 second.

**Affected components**: each language package

**Mitigation strategy**:
1. The same loop is a test in every language
2. The bound stays the written one. No tighter target is added

**Contingency plan**: The check fails and the tag does not publish.

**Residual risk after mitigation**: Low

**Documents updated**: each component description, performance-tests.md

### R05: A published Go version cannot be deleted or moved

**Description**: The Go module is fetched from the git tag `go/vX.Y.Z`. The Go module proxy caches the first content it sees and the checksum database records it, so a tag that is deleted or moved gives users a checksum error, and a version with a bug stays fetchable.

**Trigger conditions**: A Go version is tagged and then found wrong (a bug, or a tag at the wrong commit).

**Affected components**: Go package, GitHub Actions (`publish-go.sh`)

**Mitigation strategy**:
1. The Go tag is the last upload of a run, so a golden mismatch or a failed registry pushes none (`go-tag` is a `final` target)
2. `publish-go.sh` never forces a push; the same commit passes without a push, another commit fails naming both (tags never move)
3. A tag needs the owner's explicit go with the exact commit; none was pushed in loop 24

**Contingency plan**: Mark the version `retract vX.Y.Z` in the `go.mod` of the next version and ship that as the next patch (no `retract` line exists yet).

**Residual risk after mitigation**: Low

**Documents updated**: `adr/004_go-ships-as-a-git-tag.md`, `_docs/04_deploy/packages.md`, `components/07_go_package/description.md`

### R06: Correcting `t` bytes lowers guaranteed detection to `n - t` bytes

**Description**: With `n` parity bytes the code detects any corruption of up to `n` wrong bytes. If the receiver allows repair of `t` bytes (loop 38, ADR-007), corruption of `t + 1` to `n - t` bytes is still refused, but a larger corruption can land within `t` bytes of a different valid message and be repaired to it. The result is a wrong row with no error. Unpack cannot tell this from a true repair.

**Trigger conditions**: A caller passes a correction limit above 0, and the link delivers a buffer with more than `n - t` wrong bytes, or garbage. The chance that a random buffer of the 13-byte fixture plus `n` parity bytes is accepted (`message-ecc.md`):

| n | t | chance accepted | about 1 in |
|---|---|-----------------|------------|
| 1 | 0 | 3.906e-03 | 256 |
| 2 | 0 | 1.526e-05 | 65,536 |
| 2 | 1 | 5.838e-02 | 17 |
| 4 | 0 | 2.328e-10 | 4.29e+09 |
| 4 | 1 | 1.010e-06 | 990,537 |
| 4 | 2 | 2.060e-03 | 485 |
| 8 | 0 | 5.421e-20 | 1.84e+19 |
| 8 | 2 | 7.405e-13 | 1.35e+12 |
| 8 | 4 | 1.373e-06 | 728,310 |
| 16 | 0 | 2.939e-39 | 3.40e+38 |
| 16 | 4 | 2.953e-25 | 3.39e+24 |
| 16 | 8 | 2.258e-13 | 4.43e+12 |

The contract lists every `t` for `n` = 1, 2, 4, 8 and 16. Rows above are a selection.

**Affected components**: Python, TypeScript, C#, Rust, Java, Go, Swift and C++ packages, README, `message-ecc.md`

**Mitigation strategy**:
1. The default correction limit is 0: a caller who does nothing gets the full detection of `n` bytes
2. `t` is chosen at each unpack call, not stored in the scheme, and a `t` above `n / 2` is an error before any byte is read
3. The table is in the contract and is pointed to from the README, the glossary and every component description
4. A caller that must not accept a wrong message keeps `t` = 0 and asks the sender to resend, or picks `n` large enough that `n - t` covers the corruption it expects

**Contingency plan**: A caller that finds a wrong row set `t` to 0. A format change is not needed: `t` is not on the wire.

**Residual risk after mitigation**: Medium for a caller that sets `t` above 0 (the numbers above), Low at the default

**Documents updated**: `contracts/library/message-ecc.md`, `adr/007_message-error-correction.md`, README ("Error correction"), `glossary.md` (Correction limit), the eight component descriptions

### R07: The 254-byte message and the unsent length byte

**Description**: The code word is 255 bytes. Its first byte is the clear length, covered by the code and not sent, so a sent message is at most 254 bytes including parity (the clear message is at most `254 - n`). A longer message is not split into blocks in v1. A plain systematic code without the length byte accepts a message with one trailing `00` more or less (about 1 in 256 for a lost last byte); covering the length closes that hole.

**Trigger conditions**: A scheme can write a clear message above `254 - n` bytes (a long list, string or byte run), or the link drops or adds the last byte.

**Affected components**: all packages with the feature, `message-ecc.md`, ADR-007

**Mitigation strategy**:
1. Pack refuses a clear message above `254 - n` bytes with a typed error that names the clear length and the limit, and writes 0 bytes; unpack refuses a buffer above 254 bytes and a buffer shorter than `n`
2. The length byte is part of the code, so a lost or added last byte (including a trailing `00`) fails the check; EC-14 is the acceptance check for it in every package
3. Owner accepted the limit (ADR-007); splitting into blocks can be added later without changing the bytes of short messages

**Contingency plan**: A scheme that needs more than `254 - n` bytes uses `n` = 0 and its own check, or waits for block splitting (out of scope for loop 38).

**Residual risk after mitigation**: Low

**Documents updated**: `contracts/library/message-ecc.md`, `adr/007_message-error-correction.md`, README ("Error correction"), `glossary.md` (Parity bytes, Code word), the eight component descriptions

### R08: Message error correction does not fit the Cortex-M4F flash margin

**Description**: The Cortex-M4F image is 8,132 of 8,192 B, a margin of 60 B. The correction codec is about 2.2 KB of code and 511 B of tables when linked, so it cannot be added to that image.

**Trigger conditions**: A Cortex-M4F caller declares parity bytes in a scheme, or a change drops `PACKBIN_NO_ECC` from the Cortex-M4F stage of `cpp/embedded/arm.sh`.

**Affected components**: C++ package (`ecc.hpp`, `codec.hpp`, `session.hpp`, `cpp/embedded/arm.sh`), README ("Error correction"), `components/05_cpp_package/description.md`

**Mitigation strategy**:
1. The feature is compiled out with `PACKBIN_NO_ECC`; the Cortex-M4F target defines it for every object, and the build gate keeps the flash and stack numbers of the unprotected image
2. A scheme with `n` above 0 is refused with `SchemeInvalid`, at compile time when `constexpr`, so protected bytes are never silently dropped
3. The README and the C++ description state that the feature is off on that target

**Contingency plan**: A Cortex-M4F caller that needs protection checks its own message, or waits for a flash saving in the core that frees about 2.7 KB.

**Residual risk after mitigation**: Low

**Documents updated**: README ("Error correction"), `components/05_cpp_package/description.md`

## Architecture/Component Changes Applied

| Risk ID | Document Modified | Change Description |
|---------|------------------|--------------------|
| R01 | `architecture.md` ADR-001 | Little-endian writes in every language, still no generator |
| R01 | `interaction-risks.md` | The seam is all six packages against one hex |
| R02 | `architecture.md` external systems | C++ row is vcpkg, a git registry push |
| R02 | `components/05_cpp_package/description.md` | Rollback is a later port version |
| R03 | `components/06_java_package/description.md` | Rollback is to stop depending on that version |
| R04 | component descriptions | Each names the AC-10 loop on one core |
| R05 | `adr/004_go-ships-as-a-git-tag.md` | Go is a tag at the same commit, last upload, never moved |
| R06 | README, `glossary.md`, eight component descriptions | The default limit 0, the refusal above `n / 2` and the chance table are stated |
| R07 | README, `glossary.md`, eight component descriptions | The 254-byte limit and the unsent length byte are stated |
| R08 | README, `components/05_cpp_package/description.md` | The feature is off on the Cortex-M4F target (`PACKBIN_NO_ECC`) and the reason is stated |

## Summary

**Total risks identified**: 8
**Critical**: 0 | **High**: 2 | **Medium**: 1 | **Low**: 5
**Risks mitigated this iteration**: 4 (R05 accepted); loop 38 adds R06 (open for a caller that sets `t` above 0) R07 (limit accepted, length hole mitigated) and R08 (feature off on the Cortex-M4F, accepted)
**Risks requiring user decision**: none

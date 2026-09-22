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

## Detailed Risk Analysis

### R01: Six hand-written field lists drift

**Description**: Each language writes the field list by hand. A width or endian mistake in one language ships different bytes.

**Trigger conditions**: A field width, order, or endian differs and the golden check is skipped.

**Affected components**: all six language packages, GitHub Actions

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

## Architecture/Component Changes Applied

| Risk ID | Document Modified | Change Description |
|---------|------------------|--------------------|
| R01 | `architecture.md` ADR-001 | Little-endian writes in every language, still no generator |
| R01 | `interaction-risks.md` | The seam is all six packages against one hex |
| R02 | `architecture.md` external systems | C++ row is vcpkg, a git registry push |
| R02 | `components/05_cpp_package/description.md` | Rollback is a later port version |
| R03 | `components/06_java_package/description.md` | Rollback is to stop depending on that version |
| R04 | component descriptions | Each names the AC-10 loop on one core |

## Summary

**Total risks identified**: 4
**Critical**: 0 | **High**: 1 | **Medium**: 0 | **Low**: 3
**Risks mitigated this iteration**: 4
**Risks requiring user decision**: none

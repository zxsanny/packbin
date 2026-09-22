# ADR-003: Publish C++ through a vcpkg git registry

- **Status**: Accepted
- **Date**: 2026-09-22
- **Deciders**: project owner
- **Supersedes**: —
- **Superseded by**: —

## Context

AC-13 requires one C++ package on the first tag. The other five languages have an upload API. vcpkg does not.

- Acceptance criteria addressed: AC-12, AC-13, AC-14
- Restrictions addressed: R-09, R-15, R-16
- Risks addressed: R02
- Research source (if any): `_docs/04_deploy/packages.md` § Registries

The project owner named vcpkg as the C++ registry on 2026-09-22. A curated pull request into microsoft/vcpkg would not exist at tag time, and the merge is manual.

## Decision

We will publish the C++ package as port `packbin` by pushing a public vcpkg git registry from the version tag, after the golden bytes match.

Consumers install with `vcpkg install packbin`. The tag job does not open a pull request against the curated microsoft/vcpkg registry. A pushed port version stays. Rollback is a later port version.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Conan | Not the registry the project owner named |
| A pull request to the curated microsoft/vcpkg registry | The merge is manual, so the package is not published by the tag (AC-12, R-15) |
| Leave the host unnamed until the first tag | The project owner named vcpkg before planning continued |

## Consequences

### Positive

- AC-13 names a real install command
- The tag still publishes six packages with 0 manual uploads

### Negative

- vcpkg consumers must point at this git registry. `vcpkg install packbin` does not resolve from the curated registry alone
- A pushed port version cannot be deleted. Callers move forward (R02)

### Neutral / Open

- The other five registries stay HTTPS uploads, as in ADR 002

## Evidence

- `_docs/02_document/architecture.md` § 1. System Context
- `_docs/02_document/architecture.md` § 5. Integration Points
- `_docs/02_document/components/05_cpp_package/description.md` § 4. Data Access Patterns
- `_docs/04_deploy/packages.md` § Registries
- `_docs/00_problem/acceptance_criteria.md` § Release

## Notes

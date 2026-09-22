# ADR-002: Publish six packages from a version tag

- **Status**: Accepted
- **Date**: 2026-09-22
- **Deciders**: project owner
- **Supersedes**: —
- **Superseded by**: —

## Context

The packages must appear on public registries without a laptop upload. A golden mismatch must publish nothing.

- Acceptance criteria addressed: AC-11, AC-12, AC-13, AC-14, AC-16
- Restrictions addressed: R-09, R-14, R-15, R-16, R-19
- Risks addressed: R01, R03
- Research source (if any): `_docs/01_solution/solution_draft01.md` § publish credentials

GitHub is already the source remote. npm and NuGet document OIDC trusted publishing. That path was not selected: registry credentials stay in the CI secret store.

## Decision

We will publish from a GitHub Actions job on a version tag, after every language in that commit matches the golden hex, using registry credentials from the CI secret store.

The test job runs on every push and pull request and does not hold those secrets. A mismatch count above 0 publishes 0 packages. The first tag publishes npm `packbin`, NuGet `Packbin`, PyPI `packbin`, crates.io `packbin`, Maven Central `packbin`, and vcpkg `packbin` from that commit. Each archive declares MIT.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| GitHub Packages | A public install still asks for a token (R-09) |
| Trusted publishing (OIDC) | Documented by npm and NuGet, not selected. Credentials stay in the CI secret store (R-19) |
| A manual upload from a laptop | Forbidden. Publish is the tag job (R-15) |

## Consequences

### Positive

- One tag is the release. There is no deploy host
- A bad golden check cannot ship five languages and skip one

### Negative

- Maven Central and the vcpkg git registry keep a version that was pushed (R03, R02)
- Long-lived registry tokens sit in GitHub Actions secrets and must be rotated by hand

### Neutral / Open

- The C++ mechanism is ADR 003. This record only says the tag is the publisher

## Evidence

- `_docs/02_document/architecture.md` § 2. Technology Stack
- `_docs/02_document/architecture.md` § 5. Integration Points
- `_docs/02_document/architecture.md` § 8. Key Architectural Decisions
- `_docs/02_document/deployment/ci_cd_pipeline.md` § Publish
- `_docs/04_deploy/packages.md` § Publish

## Notes

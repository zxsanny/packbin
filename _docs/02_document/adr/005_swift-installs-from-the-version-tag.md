# ADR-005: Swift installs from the root Package.swift at the vX.Y.Z tag

- **Status**: Accepted
- **Date**: 2026-10-14
- **Deciders**: project owner
- **Supersedes**: —
- **Superseded by**: —

## Context

Loop 26 adds Swift as the eighth language (epic AZ-2223). Swift has no registry to upload to: Swift Package Manager fetches a package from its git repository by a version tag and reads the `Package.swift` at the root of that tag. ADR-002 publishes six registry packages from a version tag, after every language matches the golden hex, and a mismatch publishes 0 packages. ADR-004 adds the Go module as the tag `go/vX.Y.Z` at the same commit.

- Acceptance criteria addressed: AC-12, AC-14, AC-15, AC-16; SW-10 and SW-16 (`_docs/02_task_plans/swift-package/acceptance_criteria.md`)
- Owner decisions: S-1 (manifest at the root, no Swift tag), S-2 (one dependency, `swift-crypto`), S-3 (a consumer resolve and build in the publish workflow, no Swift Package Index listing), S-5 (no tag in loop 26), 2026-10-14
- Research source (if any): `_docs/02_task_plans/swift-package/problem.md`

This record amends nothing. ADR-002 and ADR-004 stay as written: the registry packages and the Go tag of a release are the same as before, and Swift adds no package and no tag to those counts.

## Decision

We will ship Swift as the root `Package.swift` of the repository at the `vX.Y.Z` tag that starts `publish.yml`. After the same all-or-nothing golden gate, the publish job proves that a new app can resolve and build that tag.

- **Install.** An app adds `.package(url: "https://github.com/zxsanny/packbin", from: "X.Y.Z")` and the product `Packbin`. SwiftPM reads the version from the tag `vX.Y.Z` (it drops the `v`). The manifest declares `// swift-tools-version: 5.9`, iOS 15 and macOS 12, and the library target lives in `swift/Sources/Packbin`.
- **There is no Swift tag.** The release is the `vX.Y.Z` tag itself, which the owner pushes. The workflow creates, moves and deletes no tag for Swift; there is no `swift/vX.Y.Z`.
- **Gate.** `publish-gate.sh` runs the Swift position program (`.github/workflows/drivers/handoff-swift`, product `position`) through `publish-position.sh swift` in the `swift` container of `docker-compose.publish.yml`, and sums the byte mismatch over every language present. A Swift mismatch, like any other, publishes 0 packages and 0 Go tags, and runs no Swift check. A tree without `Package.swift` or without `swift/` prints `absent swift`, plans no Swift check, and the other packages and the Go tag publish as before.
- **Check.** `swift-check` is a final target with no upload. The build phase records the tag and the commit of the checkout and checks the manifest, the license and the version (`publish-check.py swift-check`). It runs after every registry upload and after the Go tag. Then `publish-swift.sh` writes a throwaway consumer package that depends on `https://github.com/zxsanny/packbin` with `exact: "X.Y.Z"` and builds the Swift position program against `Packbin`. It runs `swift package resolve` and requires the pin of that URL to be version `X.Y.Z` at the commit of the checkout, then runs `swift build`. Each try starts from a fresh scratch, cache, configuration and security directory. A resolve or build that fails is retried for up to 30 minutes, then the step fails. A pin at another commit or version fails at once and names both commits. The check runs with the Swift on the runner (Linux).
- **Version.** Only a semantic version (semver.org 2.0.0) passes the build check, because an `exact:` or `from:` requirement can name nothing else.
- **License.** The root `LICENSE` is the MIT text, and the manifest and license carry no other license identifier. The build check fails otherwise.
- **Tags never move.** A re-run of the tag resolves the same commit and passes, and it only checks again. A tag that resolves to another commit fails the check. A bad version is fixed by the next patch version, never by moving or deleting its tag, because SwiftPM caches and fingerprints the first content it saw for a version.

### Tag protection

The `vX.Y.Z` tag is the Swift release. Nothing in the workflow guards it against a hand-moved tag. The tag ruleset on `v*` that ADR-004 recommends (security finding F44: creation limited to the maintainers, update and deletion blocked) is the only guard. It is a repository setting the owner applies before the first tag. As of 2026-10-14 this repository does not record that it exists.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| A `swift/vX.Y.Z` tag, as Go has | SwiftPM reads the manifest at the repository root and takes versions from plain semantic tags; a prefixed tag is not a version to it |
| A separate repository or mirror for Swift | It would need its own release and could drift from the other packages; the golden gate would no longer cover the Swift commit |
| A Swift Package Index listing | Not a registry upload and not needed to install; left out of loop 26 (S-3) |
| Skip the consumer check | A tag that SwiftPM cannot resolve or build is not a release; the check is the only evidence that `.package(url:from:)` works |

## Consequences

### Positive

- One tag is still the release; Swift needs no credential and no second tag
- A bad golden check cannot ship the other languages and skip Swift, or the reverse
- A re-run of the tag is safe: it finishes the registries and checks the consumer again

### Negative

- A Swift version cannot be undone. A bad one stays resolvable at its tag and is replaced by the next patch
- The tag exists before the check runs, so a failed check leaves a failed job with the tag in place (re-run to check again)
- The check proves Linux only; a macOS consumer build is not part of the publish job
- The publish job resolves `swift-crypto` and `swift-asn1` from github.com and builds them, which adds minutes

### Neutral / Open

- Counts after the Swift release are the six registry packages, one Go tag, and no Swift artifact
- In loop 26 no tag is pushed; SW-10 and SW-16 are proven by the publish tests against a local bare repository, one of them with the real `swift`

## Evidence

- `.github/workflows/publish-gate.sh`, `publish-position.sh`, `publish-build.sh`, `publish-check.py`, `publish-swift.sh`
- `.github/workflows/publish-swift.test.sh`, `publish-swift-gate.test.sh`
- `_docs/02_task_plans/swift-package/acceptance_criteria.md` SW-10, SW-16
- `_docs/02_document/adr/002_publish-from-version-tag.md`, `004_go-ships-as-a-git-tag.md`

## Notes

None.

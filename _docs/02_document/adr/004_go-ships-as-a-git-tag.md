# ADR-004: Go ships as a git tag from the same commit

- **Status**: Accepted
- **Date**: 2026-10-13
- **Deciders**: project owner
- **Supersedes**: —
- **Superseded by**: —

## Context

Loop 24 adds Go as the seventh language (epic AZ-2222). Go has no registry to upload to: `go get` fetches a module from the repository by a version tag, and `proxy.golang.org` caches what it finds there. ADR-002 publishes six registry packages from a version tag, after every language matches the golden hex, and a mismatch publishes 0 packages.

- Acceptance criteria addressed: AC-12, AC-14, AC-15, AC-16; GO-10 and GO-16 (`_docs/02_task_plans/go-package/acceptance_criteria.md`)
- Owner decisions: G-1 (module path and tag layout) and G-6 (release), 2026-10-13
- Research source (if any): `_docs/02_task_plans/go-package/problem.md`

ADR-002 is immutable. This record amends one thing in it: the count of six. The wording of ADR-002 and AC-13 stays as written. AC-13 counted the packages of the first tag, which is history. A tag after the Go release publishes the six registry packages plus one Go tag.

## Decision

We will ship Go as a git tag, `go/vX.Y.Z`, pushed by `publish.yml` at the same commit as the `vX.Y.Z` tag that started the run, after the same all-or-nothing golden gate.

- **Layout.** The module is `github.com/zxsanny/packbin/go` and lives in the `go/` folder. Go requires a module in a subdirectory to be tagged `<directory>/vX.Y.Z`, so the tag for `v1.2.3` is `go/v1.2.3`, next to `v1.2.3`.
- **Gate.** `publish-gate.sh` runs the Go position program (`.github/workflows/drivers/handoff-go/position`) with the other languages and sums the byte mismatch over every language present. A Go mismatch, like any other, publishes 0 packages and 0 Go tags. A tree without `go/` prints `absent go`, plans no Go tag, and the other packages publish as before.
- **Order.** The Go tag is the last upload of the run, after every required and optional registry target. A run that stopped on a registry failure pushes no Go tag.
- **Push.** The `publish` job already holds `contents: write`. `publish-go.sh` pushes the commit of the checkout to `refs/tags/go/vX.Y.Z` with that token, without force.
- **Version.** The module path has no `/v2` suffix, so Go serves only `0.x` and `1.x` versions of it. The build check (`publish-check.py go-tag`) refuses any other version (canonical semver, major 0 or 1, no build metadata) before anything is pushed. A major 2 or higher needs a new module path and a new ADR.
- **Proxy check.** After the push (and on every re-run) the job runs `go mod download -json github.com/zxsanny/packbin/go@vX.Y.Z` against `proxy.golang.org` (it fetches the zip and verifies it against `sum.golang.org`), requires the JSON to name that Path and Version, and retries for up to 30 minutes. If it never answers, the step fails; the tag stays, and running the tag again only repeats the check.
- **License.** `go/LICENSE` is the MIT text; the check fails the build phase otherwise.
- **Tags never move.** A re-run finds `go/vX.Y.Z` at the same commit and pushes nothing; at another commit it fails and names both commits. A published Go tag is never deleted or moved. A bad version is retracted in `go.mod` (`retract vX.Y.Z`) of the next version, which ships as the next patch.

### Tag protection

`go/v*` tags are the release. A tag pushed by hand skips the golden gate and the license check, and the Go proxy serves it forever. The repository should therefore have a tag ruleset on `go/v*` and `v*`: creation limited to the publish workflow's identity and the maintainers, update and deletion blocked. This is a repository setting the owner applies, not code; as of 2026-10-13 it is a recommendation, and this repository does not record that the ruleset exists (security finding F44, related to F14).

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| A separate repository for Go | A second repository would need its own release and could drift from the six packages; the golden gate would no longer cover the Go commit |
| A tag without the gate, or a Go tag in a later job | A tag after a mismatch would ship Go bytes the other six do not match; one gate with one verdict keeps ADR-002's rule |
| Delete and re-push a bad tag | `proxy.golang.org` and the checksum database remember the first content; a moved tag gives users a checksum error. Retraction is the Go-supported fix |
| Skip the proxy check | A tag the proxy cannot serve is not a release; the check is the only evidence that `go get` works |

## Consequences

### Positive

- One tag is still the release; Go follows it without a second credential
- A bad golden check cannot ship six languages and skip Go, or the reverse
- A re-run of the tag is safe: it finishes the registries and re-checks the proxy

### Negative

- A Go version cannot be undone. A bad one stays fetchable and is only marked retracted in the next version
- The tag is pushed before the proxy has seen it, so a slow proxy leaves a failed job with the tag in place (re-run to re-check)
- The publish job needs a Go toolchain (`setup-go`) for the proxy check

### Neutral / Open

- The ADR-002 sentence "the first tag publishes six packages" stays true for the first tag. Counts after the Go release are six registry packages plus one Go tag
- In loop 24 no tag is pushed; GO-10 is proven by the publish tests and a dry run

## Evidence

- `.github/workflows/publish-gate.sh`, `publish-position.sh`, `publish-go.sh`, `publish-registries.sh`
- `.github/workflows/publish-go.test.sh`
- `_docs/02_task_plans/go-package/acceptance_criteria.md` GO-10, GO-16
- `_docs/02_document/adr/002_publish-from-version-tag.md`

## Notes

None.

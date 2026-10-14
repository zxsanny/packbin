# Package distribution

**Path:** `_docs/04_deploy/packages.md`

packbin has no server and no deploy host. Distribution is the GitHub repository plus one public registry per language. Go is the exception since loop 24: it has no registry, and its release is a git tag of this repository (ADR-004). Swift, since loop 26, has neither a registry nor a tag of its own: Swift Package Manager resolves the root `Package.swift` at the `vX.Y.Z` tag (ADR-005).

## Source

| Remote | Role |
|--------|------|
| GitHub repository `packbin` | Source, issues, golden fixtures, tags |

The repository holds the eight language projects (C#, TypeScript, Python, Rust, C++, Java and, since loop 24, Go and, since loop 26, Swift) and the shared hex fixtures. Application packet lists do not live here.

License is MIT.

## Registries

| Registry | Package | Consumer command | When |
|----------|---------|------------------|------|
| npmjs.org | `packbin` | `npm install packbin` | First publish, with the TypeScript package |
| nuget.org | `Packbin` | `dotnet add package Packbin` | First publish, with the C# package |
| pypi.org | `packbin` | `pip install packbin` | First publish, with the Python package |
| crates.io | `packbin` | `cargo add packbin` | First publish, with the Rust package |
| Maven Central | `io.github.zxsanny:packbin` | Gradle / Maven coordinate | First publish, with the Java package |
| vcpkg | `packbin` | `vcpkg install packbin`, with this repository's `vcpkg` branch as a git registry in `vcpkg-configuration.json` (README); then `find_package(packbin CONFIG REQUIRED)` and `packbin::packbin`; Linux and macOS only (`supports` is `linux \| osx`) | First publish, with the C++ package |

The Java jar targets Java 17+, Android API 26+.

### Go (no registry)

The seventh package is the module `github.com/zxsanny/packbin/go` in the `go/` folder. Go has no upload: `go get github.com/zxsanny/packbin/go@vX.Y.Z` fetches the module from this repository by the tag `go/vX.Y.Z`, and `proxy.golang.org` caches what it finds there. Go requires a module in a subdirectory to be tagged `<directory>/vX.Y.Z`, so the tag for `v1.2.3` is `go/v1.2.3`, pushed at the commit of `v1.2.3`. The module needs Go 1.26 (`go.mod`); its one dependency is `golang.org/x/crypto` (the session's ChaCha20). Decision and alternatives: `_docs/02_document/adr/004_go-ships-as-a-git-tag.md`. `go/v*` tags are the release and a hand-pushed one skips the gate: a tag ruleset on `go/v*` and `v*` is recommended (ADR-004, section "Tag protection"; a repository setting for the owner, not yet recorded as applied). No Go tag has been pushed yet (loop 24 pushed none; a tag needs the owner's explicit go with the exact commit).

### Swift (no registry, no tag of its own)

The eighth package is the library product `Packbin` of the root `Package.swift` (target `swift/Sources/Packbin`, `swift-tools-version: 6.0`, iOS 15, macOS 12, Linux). An app adds `.package(url: "https://github.com/zxsanny/packbin", from: "X.Y.Z")`; SwiftPM reads the version from the existing tag `vX.Y.Z`, so there is no upload and no `swift/vX.Y.Z` tag. Its one dependency is `swift-crypto` (exactly 4.3.1; HKDF-SHA256 for the session), linked only off Apple platforms, where CryptoKit is used; SwiftPM still resolves and clones it, and `swift-asn1`, on Apple platforms. A tag run proves the release with `swift-check`, a throwaway consumer that resolves and builds the tag (above). Decision and alternatives: `_docs/02_document/adr/005_swift-installs-from-the-version-tag.md`. No tag with Swift in the tree has been pushed yet (loop 26 pushed none).

Public registries, not GitHub Packages. GitHub Packages asks for a token even for public installs, which fails the "install and import" path.

## Publish

A version tag on the GitHub repository builds each language in that commit and pushes the matching registry. The C++ publish is a git push of a public vcpkg registry. vcpkg has no upload API. The port vendors `CMakeLists.txt`, `LICENSE`, `include/packbin` and `src` and builds the static library with the vcpkg CMake helpers (AZ-2098); port versions pushed before that only hold headers and sources and do not link. The first tag published all six packages from the same commit, after the golden hex matched on every one of them (AC-13 is that history and does not change). Since the Go release (ADR-004) a tag publishes the six registry packages and one Go tag, `go/vX.Y.Z` at the same commit, after the golden hex matches on all seven languages; a Go mismatch publishes 0 packages and 0 Go tags. Since loop 26 the gate covers eight languages; a Swift mismatch publishes 0 packages and 0 Go tags, and a passing tag ends with the Swift consumer check, which publishes nothing (ADR-005).

The publish has two phases. The build phase builds every artifact for every planned target (nupkg, npm tarball with compiled `dist/` JavaScript and `.d.ts` files built from the committed lockfile, wheel and sdist, crate, vcpkg port and Arduino library as prepared local clones, PlatformIO and ESP-IDF archives, the signed Maven bundle zip) into `.github/workflows/out/artifacts/<target>/` and checks each one: it carries the tag version, declares MIT and holds its main payload (`publish-check.py`). The Go target has no archive: its build step records the commit of the checkout and the tag line in `artifacts/go-tag/tag.txt`, and `publish-check.py go-tag` checks the tag line, the commit, the module line and that `go/LICENSE` is the MIT text; the build phase refuses before any write for a license that is not MIT, a module path that is not ours, a local `v<version>` tag at another commit or a checkout without `.git`. The upload phase starts only when every planned target logged `build ok`, and it sends those files with the registry tools on the runner (`dotnet`, `npm`, `twine`, `cargo`, `curl`, `git`, `pio`, `compote`; `go` for the proxy check of the Go tag); `pio pkg publish` and `compote component upload --archive` take the prebuilt archive as is. The build containers see the repo read-only (`docker-compose.publish.yml`) and write only their own folder, mounted at `/out/artifacts/<lang>` with `PACKBIN_OUT=/out`; the C# pack runs from a copy, so no build step can change a script the host runs next with the credentials. A failed build or check therefore leaves every registry untouched. Cargo is the exception to "no second pack": `cargo publish --no-verify` re-archives the staged directory that `cargo package` already compiled. A dry run is `PACKBIN_BUILD_ONLY=1 PACKBIN_PUBLISH=1 bash .github/workflows/publish-registries.sh`: it unsets every credential, signs the Maven bundle with a throwaway key, writes to no registry and exits 0. It is for CI tests, not a way to publish.

### Required and optional registries

The target table is in `.github/workflows/publish-lib.sh`; the credential check and the upload loop both read it.

| Tier | Targets | Credential missing | Upload fails |
|------|---------|--------------------|--------------|
| Required | NuGet, npm, PyPI, crates.io, Maven Central, vcpkg | The run fails before anything is built or written, naming every missing variable | The run fails |
| Optional | PlatformIO, ESP-IDF component registry, Arduino | Skipped with a `::warning::` annotation and a line in the job summary naming the target and the variable | The run fails (the credential shows intent) |
| Final | `go-tag` (the tag `go/vX.Y.Z`; planned when `go/` is in the tree) | Needs `GITHUB_TOKEN` for a github.com remote only; a remote at another URL needs none. Missing: the run fails before anything is built | Uploaded after every required and optional target, so a failed registry means no Go tag; the run fails if the push or the proxy check fails |

Credentials: `NUGET_TOKEN`; `NPM_TOKEN` or the OIDC id-token; `PYPI_TOKEN` or the OIDC id-token; `CARGO_REGISTRY_TOKEN`; `MAVEN_CENTRAL_TOKEN` and `MAVEN_GPG_PRIVATE_KEY`; `GITHUB_TOKEN` for a vcpkg or Arduino registry on GitHub and for the Go tag push (a registry or remote at another URL needs none); `PLATFORMIO_AUTH_TOKEN`; `IDF_COMPONENT_API_TOKEN`. A language missing from the tag is not planned, so its targets are neither required nor warned about. A build-only run needs no credential and prints no warning.

### Re-running a tag

Re-run the tag's `publish.yml` run in Actions ("Re-run jobs") or start a new run for the same tag ref. Before each upload the upload phase asks the registry whether this version is already there and skips it with `already published <target> <version>`; the rest is uploaded, so a partial publish is finished without a new patch tag. A run whose registries all hold the version uploads nothing and exits 0. Two runs for one tag never overlap: `publish.yml` has a `concurrency` group keyed by the tag ref without cancel-in-progress, so the second waits.

| Target | "Already published" is |
|--------|------------------------|
| NuGet | `api.nuget.org/v3-flatcontainer/packbin/index.json` lists the version; `--skip-duplicate` stays as the race guard |
| npm | `registry.npmjs.org/packbin/<version>` answers 200 |
| PyPI | `pypi.org/pypi/packbin/<version>/json` answers 200 and lists both the wheel and the sdist; with one file missing the upload runs with `--skip-existing` |
| crates.io | `crates.io/api/v1/crates/packbin/<version>` answers 200 (a yanked version counts) |
| Maven Central | the Central Portal `publisher/published` endpoint (same token) answers `{"published":true}`; a deployment that Central marks FAILED with "already exists" counts too |
| vcpkg | the remote `vcpkg` branch is the commit the build prepared (no diff, nothing to push) |
| Arduino | the remote `arduino` branch and the tag `arduino-<version>` are the prepared commit; a tag that points elsewhere is not published, and the atomic push is refused |
| PlatformIO | `api.registry.platformio.org/v3/packages/<owner>/library/packbin` lists the version; the owner is the account of `PLATFORMIO_AUTH_TOKEN` (`pio account show`) |
| ESP-IDF | `components.espressif.com/api/components/zxsanny/packbin` lists the version; `compote component upload --allow-existing` stays as the race guard |
| Go | the remote tag `go/vX.Y.Z` (asked first, peeled): at the commit of `vX.Y.Z` nothing is pushed; at another commit the run fails naming both commits (a Go tag never moves and is never deleted); absent, it is pushed without force. The proxy check below runs on every run |

Every query has a 20 s timeout and 3 attempts on a transport error, 5xx or 429. A query that still fails, or answers something unexpected, fails the run with `cannot tell whether <target> <version> is published`; it is never read as "not published". Public queries send no token. Registries stay immutable: nothing is deleted, overwritten or force-pushed.

After the push, and on a re-run, the Go step asks the proxy for the module: `go mod download -json github.com/zxsanny/packbin/go@vX.Y.Z` (the JSON must name that Path and Version; only a major 0 or 1 version is built, ADR-004) with `GOPROXY=https://proxy.golang.org` (no fallback), `GOFLAGS=-mod=mod`, `GOWORK=off` and the exclusion variables unset, retried every `PACKBIN_GO_PROXY_PAUSE` (30 s) for up to `PACKBIN_GO_PROXY_WINDOW` (1800 s). If the proxy never answers the step fails, the tag stays, and running the tag again only repeats the check. A bad Go version cannot be deleted: it is marked `retract vX.Y.Z` in the `go.mod` of the next version, which ships as the next patch (no `retract` line exists yet). `publish-go.test.sh` proves this logic with real git on local repositories and a fake `go`; the live proxy answer is proven only by the first tag.

A language that is not in the tag's tree is not published (for Go the gate prints `absent go`, no Go tag is planned, and the other packages publish as before). Adding Python does not require a new major version of the C# package.

## What a consumer keeps

The installed package is the walker. The consumer's repository keeps their field lists next to the socket that uses them. Upgrading packbin does not change those lists.

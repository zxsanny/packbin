# Package distribution

**Path:** `_docs/04_deploy/packages.md`

packbin has no server and no deploy host. Distribution is the GitHub repository plus one public registry per language.

## Source

| Remote | Role |
|--------|------|
| GitHub repository `packbin` | Source, issues, golden fixtures, tags |

The repository holds the six language projects and the shared hex fixtures. Application packet lists do not live here.

License is MIT.

## Registries

| Registry | Package | Consumer command | When |
|----------|---------|------------------|------|
| npmjs.org | `packbin` | `npm install packbin` | First publish, with the TypeScript package |
| nuget.org | `Packbin` | `dotnet add package Packbin` | First publish, with the C# package |
| pypi.org | `packbin` | `pip install packbin` | First publish, with the Python package |
| crates.io | `packbin` | `cargo add packbin` | First publish, with the Rust package |
| Maven Central | `io.github.zxsanny:packbin` | Gradle / Maven coordinate | First publish, with the Java package |
| vcpkg | `packbin` | `vcpkg install packbin` | First publish, with the C++ package |

The Java jar targets Java 17+, Android API 26+.

Public registries, not GitHub Packages. GitHub Packages asks for a token even for public installs, which fails the "install and import" path.

## Publish

A version tag on the GitHub repository builds each language in that commit and pushes the matching registry. The C++ publish is a git push of a public vcpkg registry. vcpkg has no upload API. The first tag publishes all six packages from the same commit, after the golden hex matches on every one of them.

The publish has two phases. The build phase builds every artifact for every planned target (nupkg, npm tarball with compiled `dist/` JavaScript and `.d.ts` files built from the committed lockfile, wheel and sdist, crate, vcpkg port and Arduino library as prepared local clones, PlatformIO and ESP-IDF archives, the signed Maven bundle zip) into `.github/workflows/out/artifacts/<target>/` and checks each one: it carries the tag version, declares MIT and holds its main payload (`publish-check.py`). The upload phase starts only when every planned target logged `build ok`, and it sends those files with the registry tools on the runner (`dotnet`, `npm`, `twine`, `cargo`, `curl`, `git`, `pio`, `compote`); `pio pkg publish` and `compote component upload --archive` take the prebuilt archive as is. The build containers see the repo read-only (`docker-compose.publish.yml`) and write only their own folder, mounted at `/out/artifacts/<lang>` with `PACKBIN_OUT=/out`; the C# pack runs from a copy, so no build step can change a script the host runs next with the credentials. A failed build or check therefore leaves every registry untouched. Cargo is the exception to "no second pack": `cargo publish --no-verify` re-archives the staged directory that `cargo package` already compiled. A dry run is `PACKBIN_BUILD_ONLY=1 PACKBIN_PUBLISH=1 bash .github/workflows/publish-registries.sh`: it unsets every credential, signs the Maven bundle with a throwaway key, writes to no registry and exits 0. It is for CI tests, not a way to publish.

### Required and optional registries

The target table is in `.github/workflows/publish-lib.sh`; the credential check and the upload loop both read it.

| Tier | Targets | Credential missing | Upload fails |
|------|---------|--------------------|--------------|
| Required | NuGet, npm, PyPI, crates.io, Maven Central, vcpkg | The run fails before anything is built or written, naming every missing variable | The run fails |
| Optional | PlatformIO, ESP-IDF component registry, Arduino | Skipped with a `::warning::` annotation and a line in the job summary naming the target and the variable | The run fails (the credential shows intent) |

Credentials: `NUGET_TOKEN`; `NPM_TOKEN` or the OIDC id-token; `PYPI_TOKEN` or the OIDC id-token; `CARGO_REGISTRY_TOKEN`; `MAVEN_CENTRAL_TOKEN` and `MAVEN_GPG_PRIVATE_KEY`; `GITHUB_TOKEN` for a vcpkg or Arduino registry on GitHub (a registry at another URL needs none); `PLATFORMIO_AUTH_TOKEN`; `IDF_COMPONENT_API_TOKEN`. A language missing from the tag is not planned, so its targets are neither required nor warned about. A build-only run needs no credential and prints no warning.

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

Every query has a 20 s timeout and 3 attempts on a transport error, 5xx or 429. A query that still fails, or answers something unexpected, fails the run with `cannot tell whether <target> <version> is published`; it is never read as "not published". Public queries send no token. Registries stay immutable: nothing is deleted, overwritten or force-pushed.

A language that is not in the tag's tree is not published. Adding Python does not require a new major version of the C# package.

## What a consumer keeps

The installed package is the walker. The consumer's repository keeps their field lists next to the socket that uses them. Upgrading packbin does not change those lists.

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

The publish has two phases. The build phase builds every artifact for every planned target (nupkg, npm tarball, wheel and sdist, crate, vcpkg port and Arduino library as prepared local clones, PlatformIO and ESP-IDF archives, the signed Maven bundle zip) into `.github/workflows/out/artifacts/<target>/` and checks each one: it carries the tag version, declares MIT and holds its main payload (`publish-check.py`). The upload phase starts only when every planned target logged `build ok`, and it sends those files with the registry tools on the runner (`dotnet`, `npm`, `twine`, `cargo`, `curl`, `git`, `pio`, `compote`); `pio pkg publish` and `compote component upload --archive` take the prebuilt archive as is. A failed build or check therefore leaves every registry untouched. Cargo is the exception to "no second pack": `cargo publish --no-verify` re-archives the staged directory that `cargo package` already compiled. A dry run is `PACKBIN_BUILD_ONLY=1 PACKBIN_PUBLISH=1 bash .github/workflows/publish-registries.sh`: it unsets every credential, signs the Maven bundle with a throwaway key, writes to no registry and exits 0. It is for CI tests, not a way to publish.

A language that is not in the tag's tree is not published. Adding Python does not require a new major version of the C# package.

## What a consumer keeps

The installed package is the walker. The consumer's repository keeps their field lists next to the socket that uses them. Upgrading packbin does not change those lists.

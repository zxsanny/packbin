# Deployment procedures

## Release

1. Tests are green on the commit.
2. The C# bytes and the TypeScript bytes of each golden fixture match. Mismatch count is 0.
3. Push a version tag. Actions publishes npm `packbin`, NuGet `Packbin`, PyPI `packbin`, crates.io `packbin`, Maven Central `packbin`, and vcpkg `packbin`.

## Health check

There is no HTTP health endpoint. The check is FT-P-01: the position values pack to `4001000065cd1d00a3e1110100`.

## Rollback

Unlist the NuGet version and deprecate the npm version. Publish a new patch only after the golden hex matches again. Do not force-push the tag.

## Checklist

- All six packages declare MIT
- The archive contains 0 registry tokens
- Python, Rust, Java, and C++ are in the tag, so PyPI, crates.io, Maven Central, and vcpkg publish with npm and NuGet
- Kotlin is absent, so that registry receives 0 packages

# Release notes 0.5.1

Written in loop 109 from the loop records and the git log since `v0.5.0` (2026-11-11). The body between the two rules is the body of the GitHub release for the tag `v0.5.1`. The section after it is for the publisher.

---

## packbin 0.5.1

A small release after 0.5.0 (2026-11-11). **No packet changes:** every packet that 0.5.0 writes or reads is byte for byte the same in all nine packages; no peer needs to upgrade together with another. The one library change is an addition to the C# package.

### New

- **C#: a list or dictionary element can be a row of several required members, with no flag byte per element.** `f.List(x => x.Marks, e => [e.U8(0, m => m.Id), e.U8(1, m => m.N)])` (and `Dict`, and the static `Field.List` / `Field.Dict`) writes the members of each element one after another, the same bytes as the nested row of the TypeScript and Dart packages. A list of rows no longer costs a flag byte per element, and no wrapper property is needed. A flags element (which writes one flag byte per element) stays the form for a member that may be left out. The README C# List section shows the example and its bytes (`01 02 00 01 02 03 04`). Fixture tests in C#, TypeScript and Dart read the same hex.

### Install

| Language | How |
|----------|-----|
| C# | NuGet `Packbin` 0.5.1 |
| TypeScript | npm `packbin@0.5.1` |
| Python | PyPI `packbin==0.5.1` |
| Rust | crates.io `packbin` 0.5.1 |
| Java | Maven Central `io.github.zxsanny:packbin:0.5.1` |
| C++ | the vcpkg registry of this project (`packbin` port) |
| Go | `go get github.com/zxsanny/packbin/go@v0.5.1` (tag `go/v0.5.1`) |
| Swift | `.package(url: "https://github.com/zxsanny/packbin", from: "0.5.1")` |
| Dart | from the repository (README, section Dart); `dart pub add packbin` once the first version is on pub.dev |

Details: `_docs/04_deploy/packages.md`.

---

## For the publisher (not part of the release)

- **The version comes from the tag** (ADR-002, ADR-004): the manifests carry a placeholder, so there is no version file to edit. `v0.5.1` is an annotated tag on `9df1db7` (the close commit of loop 109; its `main` push run `43105138008` of `test.yml` is green, 20 of 20 jobs), so the tag run's precheck found a successful run and skipped its own test call.
- **Changes since `v0.5.0` that are not in the release body:** the tag run now puts the Maven signing public key on `keys.openpgp.org` itself before the Central upload when it is missing (AZ-4196; `publish-key` stays as the manual fallback); the embedded-arm image builds on the host network (AZ-4191); the manual workflow `diagnose-dns` (AZ-4198) exists for a runner name-lookup failure; loop records and a retrospective of loops 105 to 107.
- **The key upload of AZ-4196 did not run for real.** The tag run (`43106289000`, 2026-11-11 21:48 to 22:07 UTC, attempt 1) found the signing key already served (`signing key 3C51A862BEA87BC1BE7B0AB5AC576082216B95B9 is served by keys.openpgp.org`), so its send branch stayed unused; it still has a stub test only. If Maven Central ever says "Could not find a public key", run `publish-key` and re-run the failed job, as in 0.5.0.
- **Dart and pub.dev.** Still no package `packbin` on pub.dev: the optional `pubdev` target is skipped with a warning and the other eight publish. The owner's first `dart pub publish` is still pending (`packages.md` § Dart).
- **Go.** The step pushed `go/v0.5.1` at `9df1db7` (22:04:32) and the proxy answered on the first try; never ask `proxy.golang.org` about a `go/vX.Y.Z` yourself while a run is going.
- **Published 2026-11-11.** One attempt, no re-run: npm, PyPI, crates.io, NuGet, Maven Central (pom and `.asc`), the vcpkg branch (`version packbin 0.5.1`), `go/v0.5.1`, the Swift check; `pubdev` skipped with its warning. GitHub release: https://github.com/zxsanny/packbin/releases/tag/v0.5.1.
- **Rollback** is unlist or deprecate; never move or delete a tag; a Go version cannot be removed (`retract` in the next `go.mod`). A fix ships as 0.5.2.
- **Check before pasting.** The claims were read from the README, the task AZ-4199 and the loop records; the CI of the tagged commit is the proof, not this file.

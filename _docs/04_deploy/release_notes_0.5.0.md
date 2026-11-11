# Release notes 0.5.0

Written in loop 105 from the loop records and the README change history since `v0.4.0` (2026-10-31). The body between the two rules is the body of the GitHub release for the tag `v0.5.0`. The section after it is for the publisher.

---

## packbin 0.5.0

The first release since 0.4.0 (2026-10-31). Every packet that 0.4.0 writes for a valid string is unchanged: no peer needs to upgrade together with another. The release adds a parity percentage to message error correction, a ninth language (Dart), and closes one case where three packages wrote a dictionary that no reader accepted.

### New

- **Parity percentage (opt in, all eight registry languages).** A scheme can declare a percentage 0 to 100 of parity instead of a fixed count: the number of parity bytes follows the message length, `n = min(32, ceil(p × length / 100))`, so a short message carries few bytes and a long one more, up to the 32-byte cap. The count is not on the wire: the receiver finds it from the received length. `scheme.with_parity_percent(p)` (Rust), `scheme.WithParityPercent(p)` (C#), `scheme.withParityPercent(p)` (Java, Dart) and the matching call in TypeScript, Python, Go, Swift and C++. A fixed count (`with_parity(n)`) is unchanged; declaring both for one scheme, or handlers with different settings in one `unpack`, is refused (ADR-010).
- **A ninth language: Dart.** The package `packbin` in `dart/` (Dart 3.13 and newer, native targets, no dependency) writes and reads the same bytes as the other eight, with the compact text, error correction (count and percentage), frame mode and the shared hostile vectors. It is released from the repository: pub.dev gets its first version from the owner by hand, then every tag; until then add it as a git dependency (README, section Dart).

### Changes

- **Two dictionary keys that become one key are refused at pack in TypeScript, C# and Java.** An unpaired UTF-16 surrogate in a string or a key is written as U+FFFD, so the keys `U+D800` and `U+DC00` were one key on the wire, and the packet was refused by every reader. The packages now throw at pack, naming the dictionary (`RangeError` in TypeScript, `ArgumentException` in C#, `IllegalArgumentException` in Java), as Dart does. Python and Go already refuse such a string; Rust and Swift strings cannot hold one.
- **Java writes U+FFFD (`EF BF BD`) for an unpaired surrogate, not a `?`,** in a string and in a dictionary key, as TypeScript, C# and Dart do. A lone surrogate no longer merges with a real `?`. Only a string that holds a lone surrogate changes its bytes.

### Install

| Language | How |
|----------|-----|
| C# | NuGet `Packbin` 0.5.0 |
| TypeScript | npm `packbin@0.5.0` |
| Python | PyPI `packbin==0.5.0` |
| Rust | crates.io `packbin` 0.5.0 |
| Java | Maven Central `io.github.zxsanny:packbin:0.5.0` |
| C++ | the vcpkg registry of this project (`packbin` port) |
| Go | `go get github.com/zxsanny/packbin/go@v0.5.0` (tag `go/v0.5.0`) |
| Swift | `.package(url: "https://github.com/zxsanny/packbin", from: "0.5.0")` |
| Dart | from the repository (README, section Dart); `dart pub add packbin` once the first version is on pub.dev |

Details: `_docs/04_deploy/packages.md`.

---

## For the publisher (not part of the release)

- **The version comes from the tag** (ADR-002, ADR-004): the manifests carry a placeholder. `v0.5.0` is an annotated tag on `4e9110a` (the close commit of loop 103, whose `dev` and `main` push runs of `test.yml` are green: 43026701119 and 43026708169), so the tag run's precheck finds a successful run and skips its own test call. The commits after it change only documents.
- **Dart and pub.dev.** pub.dev has no package `packbin` (the API answers 404 on 2026-11-11), so the optional `pubdev` target is skipped with a warning and the other eight publish. The owner's steps for the first Dart version are in `packages.md` § Dart; the next tag after them publishes Dart automatically.
- **Go.** The step pushes `go/v0.5.0` and asks the proxy; never ask `proxy.golang.org` about `go/v0.5.0` yourself while the run is going (a request before the tag exists is cached as "not found").
- **Rollback** is unlist or deprecate; never move or delete a tag; a Go version cannot be removed (`retract` in the next `go.mod`). A fix ships as 0.5.1.
- **Check before pasting.** The claims were read from the README, the ADRs and the loop records; the CI of the tagged commit is the proof, not this file.

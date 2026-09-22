# Restrictions

## Hardware and environment

- packbin is a library. It has no server, no GPU requirement, and no deploy host.
- It runs on the operating system that hosts the language runtime.

## Software

- The first publish is C#, TypeScript, Python, Rust, C++, and Java.
- C# builds on the current .NET LTS, and TypeScript builds on the current Node LTS, at the time of that publish. Python, Rust, C++, and Java use the current stable toolchain for that language at the same time.
- Kotlin is not in the first publish.
- Vue and React import the TypeScript package. They do not get a separate package.
- The first release has no code generator. Each language writes the field list in that language.
- The bytes on the wire are only the fields. packbin does not add a tag, a length prefix, a version byte, or a schema id.
- Install is from the public registry for that language. GitHub Packages is not an install path.

## Operational

- License is MIT.
- There is no calendar deadline. The first publish happens when all six languages agree on the golden bytes.
- No budget figure is set.

## Continuous integration and publish

- Source is GitHub: `https://github.com/zxsanny/packbin`.
- CI runs the tests on every push and every pull request.
- A version tag publishes each language present in that commit to its public registry. Publish is not a manual upload from a laptop.
- The first tag publishes six packages from the same commit, after every one of those languages matches the golden bytes: npm `packbin`, NuGet `Packbin`, PyPI `packbin`, crates.io `packbin`, Maven Central `packbin` for Java, and vcpkg `packbin`.
- A language that is not in the tagged tree is not published.
- Registry credentials stay in the CI secret store.

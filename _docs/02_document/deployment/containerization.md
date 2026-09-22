# Containerization

The product is a library. It has no runtime container. Containers exist only so the tests run on the current .NET LTS SDK, the current Node LTS image, and the current stable images for Python, Rust, C++, and Java.

| Image | What it runs | Published ports |
|-------|----------------|-----------------|
| dotnet-sdk, current LTS | the C# suite | none |
| node, current LTS | the TypeScript suite | none |
| python, current stable | the Python suite | none |
| rust, current stable | the Rust suite | none |
| a current stable C++ image | the C++ suite | none |
| a current stable JDK | the Java suite | none |

`docker compose` for tests starts those six images, mounts the fixture file read-only, and writes `./test-results/report.csv`. No database service. No GPU.

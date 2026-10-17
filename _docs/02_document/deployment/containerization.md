# Containerization

The product is a library. It has no runtime container. Containers exist only so the tests run on the current .NET LTS SDK, the current Node LTS image, the current stable images for Python, Rust, C++, and Java, and two images for the C++ embedded targets.

| Image | What it runs | Published ports |
|-------|----------------|-----------------|
| dotnet-sdk, current LTS | the C# suite | none |
| node, current LTS | the TypeScript suite | none |
| python, current stable | the Python suite | none |
| rust, current stable | the Rust suite | none |
| a current stable C++ image | the C++ suite | none |
| a current stable JDK | the Java suite; it compiles with `--release 17` and, on a cold `java/out/api-tools` cache, fetches the pinned API-check jars from Maven Central | none |
| `golang:1.27` | the Go suite (`go` service) | none |
| `swift:6.3.3` | the Swift suite (`swift` service, loop 26; `run-suite.sh swift`) | none |
| `packbin-embedded:local`, built from `ubuntu:24.04` (`cpp/embedded/Dockerfile`) with arm-none-eabi GCC 13, newlib-nano, QEMU system and user mode, and the s390x cross g++ | the `cpp-embedded` service: Cortex-M0+, Cortex-M3 on QEMU, Cortex-M4F size and stack, s390x big-endian | none |
| `espressif/idf:v5.3.2` | the `cpp-embedded-esp` service: ESP32-S3 and ESP32-C3 builds and the packaged examples | none |

`docker compose` for tests starts the eight suite images (the `go` service runs `golang:1.27`, the `swift` service `swift:6.3.3`), mounts the fixture file read-only, and writes `./test-results/report.csv`. The two embedded services mount the repository and the `test-results` directory, and add one row per target to the same report; `cpp/embedded/run.sh` runs both (since loop 31 CI runs the arm stage and two parts of the ESP stage as three jobs: `run.sh host arm`, `host esp core`, `host esp packages`; the in-container ESP stage reads `PACKBIN_ESP_PART`). No database service. No GPU. The publish golden gate and the language builds run in the same eight services with `docker-compose.publish.yml` passed after `docker-compose.test.yml`: it mounts the repo at `/src` read-only and gives `/test-results` a tmpfs, and a build writes only its own `artifacts/<lang>` folder, mounted at `/out/artifacts/<lang>` (`ci_cd_pipeline.md`).

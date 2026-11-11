# Probes of loop 102

Sources only (no build output). Each reads the repository by absolute path (`/Users/zxsanny/dev/zxsanny/packbin`) and writes nothing into it; the smoke script of loop 102 (`_docs/loops/loop102/smoke102.md`) copies or builds each into a temp directory and checks one line of its output.

| package | files | run |
|---------|-------|-----|
| C# | `csharp/Probe102.csproj`, `Program.cs` | `env MSBUILDDISABLENODEREUSE=1 dotnet build -c Release -o OUT -p:BaseIntermediateOutputPath=OBJ/` then `dotnet OUT/Probe102.dll` |
| Java | `java/Probe102.java` (package `packbin`) | `javac -d OUT` over `java/src/main/java/**/*.java` plus this file, then `java -cp OUT packbin.Probe102` |
| Python | `python/probe.py`, `probe_tb.py` | `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=python/src /opt/homebrew/bin/python3.13 probe.py` |
| Go | `go/main.go`, `go.mod` | copy the folder, then `docker run --rm -v REPO:/src:ro -v COPY:/probe -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -w /probe -e GOFLAGS=-mod=mod golang:1.27 go run .` |
| Rust | `rust/` (`Cargo.toml`, `src/main.rs`, `compile_fail/`) | copy the folder, `CARGO_TARGET_DIR=OUT RUSTUP_TOOLCHAIN=1.98 cargo run --manifest-path COPY/Cargo.toml` |
| Swift | `swift/` (`Package.swift`, `Sources/swiftprobe/main.swift`, `compile_fail.swift`) | copy the folder, `swift build --scratch-path OUT`, run `OUT/debug/swiftprobe` |

State of the probes: they print the behaviour at loop 102 HEAD ec86364 (C# and Java write an unreadable packet). Since loop 103 (AZ-4169) the C# probe prints a thrown `ArgumentException` for cases A and B and the Java probe a thrown `IllegalArgumentException` for cases A and B and writes `EF BF BD` instead of `3F`; the smoke script of loop 102 (`_docs/loops/loop102/smoke102.md`) records the earlier state and is not expected to pass on a later HEAD.

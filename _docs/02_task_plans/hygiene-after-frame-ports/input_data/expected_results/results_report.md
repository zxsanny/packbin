# Expected results — loop 76

Figures are from runs on HEAD a50e750, 2026-10-27, Mac arm64, Cargo 1.79.0, dotnet 10, Java 21.0.2 (`--release 17`), Apple bash 3.2.57.

## C# probe project (H2, H6)

| Run | Today | Required |
|-----|-------|----------|
| build of `PackbinProbe.csproj` from a copy | 0 errors, 1 warning `CS7022` | 0 errors, 0 warnings `CS7022` |
| `PackbinProbe <repo> edges` | `System.FormatException` at `ns20/Program.cs:5`, exit 134 | runs |
| same, with `<Compile Remove="ns20/**" />` | 63 PASS, 1 FAIL (NFC/NFD), exit 1 | |
| same, plus keys NFD then NFC | 64 PASS, 0 FAIL, exit 0 | 64 PASS, 0 FAIL, exit 0 |

## Java probe (H6)

| Run | Today | Required |
|-----|-------|----------|
| `AuditProbe <repo> edges` | 64 PASS, 1 FAIL, exit 1 | |
| same, keys NFD (`041065cc81`) then NFC (`0310c3a9`) | 65 PASS, 0 FAIL, exit 0 | 65 PASS, 0 FAIL, exit 0 |

## Rust frame-only build (H3)

| Run | Today | Required |
|-----|-------|----------|
| `cargo test --no-default-features --features frame --no-run` (1.79) | exit 101: 6 errors in `lib test` (`sha256.rs:190,191`, `hkdf.rs:84,85,91,92`: `String`, `Vec`, `format!`) | exit 0 |

## Timing selftest (H1)

| Check | Today | Required |
|-------|-------|----------|
| `printf '%s\n' ... \| grep` pipelines in the file | 15 | 0 |
| old pattern, 3,000 trials, idle, bash 3.2.57 | 0 failures | not applicable (cause unproven) |
| old pattern, 3,000 trials, 12 burners (load 5 to 12) | 0 failures | not applicable |
| selftest, mutated `publish-timing.test.sh` (no alpha line) | not run | exit non-zero, `FAIL: alpha has no timing line` and the captured output |

## Names (H7)

| Search | Today | Required |
|--------|-------|----------|
| `git grep -n "TopRangeAndSessionTests\|EccSessionTextTests\|fuzz_ecc_session"` outside loop history | 10 lines in 10 files | 0 |

## Swift DocC (H4)

| Search | Today | Required |
|--------|-------|----------|
| the 10 public frame type names in `Packbin.md` | 0 of 10 | 10 of 10 |

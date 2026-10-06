# Loop 17 handoff — written 2026-10-06 while loop 16 was closing

This is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 16 = last closed once the close finishes). Read `_docs/loops/loop16/plan16.md` (what loop 16 did), `assessment16.md` (rounds 1 and 2) and `_docs/03_implementation/batch_05_loop16_report.md`, `batch_06_loop16_report.md` (the discovery tables) first.

## Owner working preferences (2026-10-06, memory `one-total-review-and-test`)

- No review and no Docker run per batch or per change. Workers run their own package suite; the loop ends with ONE total review and ONE total test run (step 11).
- Do not chain feature-assess rounds while `todo/` keeps growing: record the open angles here instead.
- Next session tackles all remaining todo specs, split into waves that do not overlap (below).

## Where things stand when loop 16 closes

- `todo/` holds 16 specs (the held list below); `done/` holds 148. Every spec in `done/` has its Jira task Done or In Testing (loop 16's last two batches are In Testing until the close reconciles them).
- Loop 16 commits on local `dev` (not pushed until the close pushes `dev`): 1075e1a, 48a2e17, 9cb36ee, 2eb9875, 35544ed, 4a605dc, plus the total-review fixes and the close commits. Loop end channel is `main` (`_docs/04_deploy/ci_cd_pipeline.md`); polling is `enabled: yes`. A tag push (`v0.2.3` or `v0.3.0`) needs the owner's explicit go with the exact commit.
- Loop 16 behavior changes are in the README upgrade notes (TypeScript, Python, Java, Rust, C++ vcpkg); counts at the end of loop 16: TypeScript 470, Python 492, Rust 360, Java all checks pass.
- Epics: AZ-2069 (cross-language bug fixes, the hopper below), AZ-2222 (Go package, the owner wants full parity: memory `go-package-next-loop`), AZ-2223 (Swift, no order set).

## Do not start before checking

1. **Uncommitted work in the tree that is not the agent's**: C# multi-target compatibility (`csharp/Compat.cs`, `csharp/tests/TargetParityTests.cs`, changes in `csharp/{PackSession,Packbin,SessionPad,Walker*}.cs`, both `.csproj`), plus owner hunks in `.github/workflows/{publish-check.py,publish-phases.test.sh,run-suite.sh}`, `README.md` (lines 17 to 26: the platform and C++ bullets), `_docs/02_document/epics.md`. Loop 16 left them untouched (a baseline of the diff is in the session scratchpad; the guard compared content after every commit). Every C# spec edits the same files, so **wave C1 and C2 start only after the owner has committed this work** (or says otherwise). Ask first.
2. Order of the two owner requests: this hopper, then the Go package (AZ-2222) and Swift (AZ-2223), or Go first. Ask which.
3. First CI run after the push of loop 16 decides the Linux-only parts: the new `ring` job (node 24, JDK 26, Python 3.14, gcc 16 wrapper), `npm ci --prefix` through a symlinked temp path, `lib.test.sh` under bash 5.x and mawk, vcpkg `x64-linux` dry-run and the second consumer, `GITHUB_ACTIONS=true` turning a missing tool into a failure. Read the run before planning.

## The hopper: 16 specs in `todo/`, split into waves (no two batches of one wave write the same path)

All 16 are verified and carry owner decisions (the C# ones wait for item 1 above). Points are the spec points of the part that is still open.

| Spec | Open part | Writes | Points |
|------|-----------|--------|--------|
| AZ-2092 C# typed binding per scope | all | `csharp/` | 5 |
| AZ-2093 C# honest AC-10 test | all (needs 2092) | `csharp/tests/` | 1 |
| AZ-2135 split bits by field order | C# (G4); C++ numbering is the follow-up below | `csharp/` | 2 |
| AZ-2128 flag group presence parity | C# part | `csharp/` | 1 |
| AZ-2180 C# scheme clones its flag-bit groups | all | `csharp/` | 2 |
| AZ-2181 C# count source is an integer field | all | `csharp/` | 2 |
| AZ-2182 C# lone value in a round | all | `csharp/` | 2 |
| AZ-2119 C# group as list or dict element | all | `csharp/` | 3 |
| AZ-2120 C# `when` under combined `flags`, pack | all | `csharp/` | 2 |
| AZ-2191 C# strict numeric pack for dictionary rows | all | `csharp/` | 1 |
| AZ-2114 hostile session tests | C# | `csharp/tests/` | 1 |
| AZ-2115 split-form reference bytes | C# | `csharp/tests/` | 1 |
| AZ-2121 flag-scope container tests | C# | `csharp/tests/` | 1 |
| AZ-2126 `eq` on a bool accepts only `true` | construction check in TypeScript, Python, Rust, Java, C++, and C#; the hostile vector `eq_bool_false` (+ README section) | each package; `fixtures/hostile/` | 3 |
| AZ-2194 hostile `pack` stage | all six loaders, `fixtures/hostile/`, `check-cases.sh` and its self-test (numbers are stale: 19 cases, stages `unpack`, `construct`, `limit`) | `fixtures/hostile/`, scaffold, all package vector tests | 2 |
| AZ-2068 C++ AVR build | all (optional stretch; depends on AZ-2066, done) | `cpp/`, `.github/workflows/test.yml` | 3 |

### Waves

**Wave 0 (owner, before anything):** commit or hand over the C# multi-target work (item 1); answer which of the open decisions below should become specs; confirm Go-first or hopper-first.

**Wave 1, parallel, disjoint directories (one worker per directory):**

- C1 `csharp/` (serial inside): AZ-2092, then AZ-2093, then AZ-2135 (C#), then AZ-2128 (C#). Binding and flag-group code: these share the walker.
- CPP `cpp/include`, `cpp/src`, `cpp/tests`: write and implement the C++ flag-scope parity spec (below), then AZ-2126 (C++ part). AZ-2068 (AVR, `cpp/CMakeLists.txt`, `.github/workflows/test.yml`) is a separate optional batch after CPP (same directory).
- TS `typescript/`, PY `python/`, RS `rust/`, JV `java/`: AZ-2126 construction check, one worker each (1 point each), without the vector.

**Wave 2 (after C1 merged; `csharp/` serial, plus the fixtures):** C2: AZ-2180, AZ-2181, AZ-2182, AZ-2119, AZ-2120, AZ-2191, then the C# parts of AZ-2114, AZ-2115, AZ-2121, then the C# part of AZ-2126 and the `eq_bool_false` vector with its README section (all six packages read `fixtures/hostile/cases.txt`, so the vector comes last and only when every package refuses it).

**Wave 3 (nothing else running):** AZ-2194, the `pack` stage, the six loaders and the scaffold job.

**Wave 4:** one total review, one total test run, docs delta, security audit, retrospective, close, push, CI watch.

Why these cuts: every C# spec writes the same walker files, so C# is one serial stream (two batches of at most 20 points); the vector file and the loaders are read by all six packages, so AZ-2126's vector and AZ-2194 go after every package change; the four non-C# package workers and CPP touch different directories and can run beside C1.

## Open decisions and gaps from loop 16 (not specs yet; each is in a batch report discovery table)

- `when`, `times` or `repeat` as a `flags` member or flag-bit field: dropped on pack in all packages (held for the loop that lands the C# work, decide all together with AZ-2120's C# change).
- C++: a flag byte inside a `flags` member or a flag-bit child stays visible to later bits, while Rust, TypeScript and Java treat all three as conditional scopes: write the follow-up spec (owner decision of round 1: follow-up spec).
- Java: names only `Access.set(String)` members for the duplicate-name rule (options: probe a recording `Map`, add names to the API, or leave); a repeated key in a nested row under a `when` builds (list and dict elements restart the check since the total review); typed-accessor element cases S4, S5, S8 fail on unpack (options B to D); the "typed row" wording; `missing group` has no round index.
- Python: an unplaced split bit leaves its bit clear without a message; names are accessor keys (`r.x` and `r["x"]` differ); `repeat` does not follow `times` for short lists; the identity accessor in an element group; the constructor `PackSession([7]*32)`; the owner knows AZ-2249 breaks pack-only callers with object elements.
- Rust: `repeat` refused although it round-tripped (one-line flip in `field/names.rs`); a flag-byte name equal to a data name builds; two declarations in one `when` body build in all packages; flat-scheme release cost (about 1.3x to 1.57x, optional: record only when the scheme has a `when` or a count); a multi-name `u2` in a map `times`.
- TypeScript: `SchemeHandler<object>` is invariant, so a typed row's handler needs `as SchemeHandler<any>` (README examples cast): a defect to spec; the constructor accepts a 5-byte key; `start`/`join` throw for a non-`Uint8Array` nonce; optional tamper-proof brand in `load`; multi-slot `u2` and `flagByte` as direct list elements fail late; `when` and `times` direct elements say "eq names field id N".
- Harness: the tag-time guard does not assert `supports` and its import regex counts comments and strings, misses `require` and undeclared bare imports; the guard for the Python wheel and the Java jar; the `gcc:16` wrapper hardening (after the first green `ring` run); the vcpkg gate is 19 s against 9 s at HEAD.
- Docs: the root `README.md` line 27 (C++ bullet) sits inside the owner's uncommitted block: suggested text "C++: C++17; CMake 3.16+ or vcpkg on Linux and macOS (Windows is not supported: the package is not built or tested there); 32-bit microcontrollers (ESP32, RP2040, nRF52, STM32) through PlatformIO, Arduino and ESP-IDF 5.1+."; `components/01_csharp_package/description.md` line 92 is stale until the C# work lands.
- After the hopper: the Go package (AZ-2222, full parity), Swift (AZ-2223), and a release (`v0.2.3` or `v0.3.0`) on the owner's go.

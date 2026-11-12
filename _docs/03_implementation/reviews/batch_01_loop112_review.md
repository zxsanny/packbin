# Code Review Report

**Batch**: 1, loop 112 (AZ-4206_repeat_followed_by_a_field) | **Date**: 2026-11-12 | **Verdict**: PASS_WITH_WARNINGS

One review for the loop. Scope: `scripts/probes/repeat-followed-by-field/**` (nine probes, the runner, the rule-count tool, 3,438 lines), the findings, the contract and the ten follow-up specs. Two read-only reviewers read the probes against the package sources (five packages and the tools; four packages); the parent ran the mechanical checks, checked the same class in the files the reviewers did not name, and wrote the verdict. No package source changed in this loop.

Mechanical checks (parent): no packet or verdict is a literal in any probe source (`grep` for the packets outside comments: 0 lines; every `same` / `differs` / `refused` comes from a comparison or a caught error); `bash -n` and `shellcheck` clean on the 11 scripts; no file above 500 lines (largest 399); nothing under `scripts/probes` is ignored by git; a run leaves `git status --porcelain --ignored` unchanged.

Claims the table rests on, confirmed in the package sources by the second reviewer: Rust map form refuses any group as a list or dict element (`rust/src/field/integrity.rs:168-181`); the Rust heap-free API the same (`rust/src/nostd/check.rs:141-143`, `:186-200`); a C++ list or dict bound to a member refuses a group element and the unbound form builds (`cpp/include/packbin/table.hpp:472-473`, `fields_counted.hpp:175-205`); every Rust map-form repeat reads and writes the one `__repeat__` key (`rust/src/walk/pack.rs:175`, `unpack.rs:110`, `:331`).

## Findings

| # | Severity | Category | File:Line | Title | Outcome |
|---|----------|----------|-----------|-------|---------|
| 1 | Medium | Bug | `go/main.go`, `swift/.../main.swift`, `typescript/probe.ts`, `python/probe.py`, `dart/probe.dart`, `java/RepeatProbe.java` | A correct read-back of zero rounds would print `differs`: the package returns no key for a repeat that read no round, the probe gave an empty list | fixed in all six (absent and empty compare equal for the rounds of a repeat; the `differs:` text is unchanged); the reviewers named Go and Swift, the sibling check found the other four; C#, C++ and Rust nostd already compared equal |
| 2 | Medium | Bug | `rust/src/map_form.rs` | `e-flags` could never print `same`: unpack returns the flags byte under its name, the given row had none | fixed (the row gives the byte) |
| 3 | Medium | Bug | `cpp/run.sh` | Any failure of the `constexpr` compile was printed as a package refusal, with a literal fallback text | fixed: a refusal only when the compiler's first error or its note is at a line of `cpp/include/packbin/` and names a non-constexpr call or a static assertion; anything else fails the script |
| 4 | Medium | Bug | `rule-count/run.sh` | The logging call ran before the constructor's last checks, so a scheme that never builds could be counted | fixed: the call is the constructor's last line; the count is the same four schemes, 77,266 built |
| 5 | Medium | Spec-Gap | `scripts/probes/` | The probes were untracked at review time (AC-1: committed probes) | resolved by the batch commit, which follows the review |
| 6 | Low | Bug | five probes | The final comparison and printing ran outside the per-shape guard | fixed (`threw: probe: ...` in TypeScript, C#, Java, Python, Dart; Rust and Go print `-`, go on and exit 1; Swift and C++ run a process per shape) |
| 7 | Low | Bug | `rule-count/repeat-last-probe.ts`, `rule-count/run.sh` | Refusals were de-duplicated per process only; built totals were written at exit and lost for a terminated worker | fixed (one line per scheme built; the pair of file and scheme counted once) |
| 8 | Low | Bug | `rule-count/run.sh` | A `grep` under `set -e` could end the script with no message | fixed |
| 9 | Low | Bug | `rule-count/repeat-last-probe.ts` | `1` and `1n` compared as different `eq` values (the `excused` label only) | fixed |
| 10 | Low | Bug | `csharp/Program.cs` | The stderr `-map` lines compared a typed row with a dictionary, so `same` could never appear | fixed: those lines print `read: <row>` with no verdict |
| 11 | Low | Maintainability | `csharp/Probe.csproj` | The package sources are compiled into the probe, so "public members only" is not enforced by the compiler | kept: a project reference compiles the generated files that earlier builds left under `csharp/obj` (a planted file failed the scratch build); `Program.cs` builds against a separately built `Packbin.dll` and prints the same lines, and the csproj says so |
| 12 | Low | Bug | `dart/run.sh` | A `'` in the checkout path gave invalid YAML on bash 3.2 | fixed |
| 13 | Low | Bug | `java/run.sh` | An empty source list failed as "unbound variable" on bash 3.2 | fixed |
| 14 | Low | Bug | `run.sh` | Any folder with a `run.sh` was taken as a package (`rule-count`) | fixed (the nine names only) |
| 15 | Low | Spec-Gap | `rust/src/map_form.rs` | An unreachable path printed a hand-written `n/a` in the pack column | fixed (`-`, the reason on stderr) |
| 16 | Low | Maintainability | `rust/src/nostd_form.rs` | `validate` ran outside the panic guard | fixed |
| 17 | Low | Bug | `cpp/run.sh` | A link failure inside a command substitution surfaced as "status 127"; the fallback line used the base shape name | fixed (both) |
| 18 | Low | Spec-Gap | `README.md` of the probes | It said C# typed rows go to stderr (they are stdout), left C# out of the packages that take rounds as rows, and did not say how `d` and the Rust map `f` differ per package, nor list `f-two-groups` or `threw:` in the build and pack columns | fixed |
| 19 | Low | Maintainability | `go/main.go` | `recover` does not catch a Go fatal error and all shapes share a process | kept: the run then exits non-zero and the runner says the probe did not run |
| 20 | Low | Style | `rust/src/main.rs` | A comment said "seven lines" | fixed |

No Critical or High finding. Security quick-scan: the scripts read the checkout and write only to a `mktemp -d` directory removed on exit; the Go probe mounts the repository read-only in its container; no secret, no network call of their own (SwiftPM and `dart pub get` resolve from their caches). Architecture: no package imports a probe and no probe is part of a suite or a CI job (ADR-001 holds: each probe is written by hand in its language).

After the fixes: one run of all nine, 85 lines, byte-identical to the run recorded in the findings; `rule-count/run.sh` 4 refused, 77,266 built.

# Probes: how deep may a scheme be (AZ-4291)

A Dart scheme of 5,000 nested `when`s dies with a raw `Stack Overflow` when it is built (found in loop 113). No package has a depth limit, and the other eight were never measured. These probes build a chain of nested `when`s and a chain of nested groups at three depths in all nine packages, pack one value and unpack its own bytes, and print what happens. They assert nothing and change no package.

## Run

```bash
bash scripts/probes/scheme-depth/run.sh              # all nine packages
bash scripts/probes/scheme-depth/run.sh dart go      # some of them
```

`run.sh` calls `<package>/run.sh`, which builds into a temporary directory outside the repository (nothing is written into the checkout) and runs every case as its own process through `case.sh` with a 60 second limit. A stack overflow, abort or hang therefore costs one line and never the run. Tools as for `scripts/probes/element-row/README.md`, plus the .NET 10 SDK and Dart 3 (`dart` on `PATH`); Go runs in `golang:1.27` when there is no `go` on `PATH`.

## Output

One line per package, shape and depth, five fields separated by a tab, the format of `scripts/probes/element-row/README.md`: `package`, `shape` (`when-1000`, `group-50000`, ...), `build`, `pack`, `unpack`.

| field | values |
|-------|--------|
| build | `built`, `refused: <the package's own message>`, `threw: <error type>` (a raw language stack error counts here, not as a refusal), `n/a: <why>` |
| pack | the packet in lowercase hex (long ones cut to 40 characters, `...`, total bytes), `refused: ...`, `threw: ...`, `-` |
| unpack | `same`, `differs: ...`, `refused: ...`, `threw: ...`, `-` |

When the process itself dies, `case.sh` prints `crashed: signal <n>`, `crashed: exit <n>` or `crashed: timeout` in the build field and `-` in the other two.

## Shapes

Depths 1,000, 5,000 and 50,000. Type number 1 everywhere. The probe builds the nesting with a loop, so only the library recurses.

| shape | scheme | values |
|-------|--------|--------|
| `when-D` | `u8 a` (id 0), then D nested `when(a == 1, ...)`, the innermost holding `u8 b` (id 1) | `{a: 1, b: 7}`, bytes `01 01 07` |
| `group-D` | D nested groups, the innermost holding `u8 b`; the form is the package's own (a group without an anchor where it exists, else the anchored group that shares the row); each probe names the form at the top of its source | `b` = 7 |

## Repeatability

Two runs print the same lines except at the edge of a package's limit: Java `group-5000` fails at build or at unpack depending on JIT state, and a case that sits near the 60 second limit (Swift `group-5000`, Rust `nostd` `when-5000`) can move either way on another host. Go ignores the alarm signal of `case.sh`, so its cases run under `timeout 55` and print `crashed: exit 124`. Rust and Swift build in release by default (`PROBE_PROFILE=debug` for a debug build, which overflows earlier).

## State

Written in loop 125 (2026-11-14). The findings are in `_docs/06_metrics/scheme-depth-probe_2026-11-14.md`. Loop 126 (AZ-4294 to AZ-4303) added the limit of 256 levels (`_docs/02_document/contracts/library/scheme-depth.md`): after it, the 1,000, 5,000 and 50,000 lines of every package are `refused` (Rust's heap-free API refuses at 50,000 by its own `MAX_FIELDS`).

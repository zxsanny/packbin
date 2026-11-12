# Probes: a repeat that is not the last thing a packet reads (AZ-4206)

A `repeat` has no count: unpack reads rounds until the buffer ends. So bytes written after a repeat, or a repeat inside a list or dict element that another element follows, are read as more rounds. These probes show, per package, whether such a scheme builds, what it packs and whether the package reads its own bytes. They assert nothing and change no package: they print what happens on the checkout they run in.

## Run

```bash
bash scripts/probes/repeat-followed-by-field/run.sh            # all nine packages
bash scripts/probes/repeat-followed-by-field/run.sh go swift   # some of them
```

`run.sh` calls `<package>/run.sh` for each package and prints their lines. Every build goes to a temporary directory outside the repository; nothing is written into the checkout. Tools: Node 22.18 or newer, .NET 10 SDK (`net10.0`), a JDK, Python 3.10 or newer (`PACKBIN_PROBE_PYTHON` picks one), Rust 1.98 (`RUSTUP_TOOLCHAIN`), a C++17 compiler (`PACKBIN_CXX_SYSROOT` on macOS when a system header is not found), Swift 6, Dart 3, and Go 1.27 or Docker (without a `go` on `PATH` the Go probe runs in `golang:1.27`, the image of `docker-compose.test.yml`). All nine take about half a minute on the project's Mac.

## Output

One line per shape on stdout, five fields separated by a tab:

| field | values |
|-------|--------|
| package | `typescript`, `csharp`, `python`, `rust`, `java`, `cpp`, `go`, `swift`, `dart` |
| shape | `control`, `a`, `b`, `c`, `d`, `e-when`, `e-flags`, `f` |
| build | `built`, or `refused: <the package's message>`, or `n/a: <why the package cannot write this shape>`, or `threw: <error>` (something that is not the package's own error) |
| pack | the packet in lowercase hex, or `refused: <message>`, or `threw: <error>`, or `-` when nothing was built |
| unpack | `same` (the values given come back), `differs: <the values that came back>`, `refused: <the error>`, `threw: <the exception>` (an unpack that does not return an error value), or `-` |

Messages are printed on one line, as the package gives them. Anything else a probe prints goes to stderr.

A package that has a second public way to write a scheme prints it under the shape name with a suffix when the outcome can differ: Rust prints every shape again for the heap-free API (`-nostd`) and one more line for the map form (`f-two-groups`, the rounds of the two repeats given one after the other), C++ prints `b-unbound` and `c-unbound` (a list or dict element that is not bound to a member), and TypeScript prints two schemes that read back in loop 112 although nothing guaranteed it, and that the rule refuses since loop 113 (`x-one-item`, `x-exclusive-when`). Second ways that give the same outcome go to stderr (Java typed rows, the C++ `constexpr` form: a variant is hidden only when its shape name ends in `-constexpr` and both lines are refused, which is why `b-unbound` and `c-unbound` print, the bound list refusing its row element and the unbound one refusing the repeat inside it) or were checked once in loop 112 and are in the findings (typed rows in Go, Swift and Dart, a Python class row). C# is the other way round: stdout is the typed form (a repeat bound to a collection of rows, the only form the public `Unpack` reads back), and the dictionary form goes to stderr with the suffix `-map`.

## Shapes

Type number 1 everywhere. Field ids follow each package's own numbering rule; the names and values are the same in every package.

| shape | scheme | values | TypeScript packs |
|-------|--------|--------|------------------|
| `control` | `u8 x`, `repeat(u8 v)` (the repeat is last) | `x = 9`, `v = [5, 6]` | `01 09 05 06`, reads back |
| `a` | `repeat(u8 v)`, `u8 x` at the top level | `v = [5, 6]`, `x = 9` | `01 05 06 09` |
| `b` | `list items` whose element is a row `(u8 mode, repeat(u8 v))` | two items: `{mode 1, v [5]}`, `{mode 2, v []}` | `01 02 00 01 05 02` |
| `c` | `dict d` whose element is a row `(u8 mode, repeat(u8 v))` | two entries: `"a": {mode 1, v [5]}`, `"b": {mode 2, v []}` | `01 02 00 02 10 61 01 05 02 10 62 02` |
| `d` | a nested row `m` (a group without an anchor, `Nested` in Go) that holds `repeat(u8 v)`, then `u8 x` | `m.v = [5, 6]`, `x = 9` | `01 05 06 09` |
| `e-when` | `u8 k`, `when(k == 1, repeat(u8 v))`, `u8 x` | `k = 1`, `v = [5, 6]`, `x = 9` | `01 01 05 06 09` |
| `e-flags` | `flags(repeat(u8 v))`, `u8 x` | `v = [5, 6]`, `x = 9` | `01 01 05 06 09` |
| `f` | `repeat(u8 v)`, `repeat(u8 w)` at the top level | `v = [5]`, `w = [6]` | `01 05 06`, and reads it back as `v = [5, 6]` with no `w` and no error |

Where the packages differ in how a shape is written:

- **Rounds.** C# (typed rows), Rust (both APIs) and C++ take the rounds of a repeat as rows, one row per round: round 0 has `v = 5`, round 1 has `v = 6`. The others take one list per name (`v = [5, 6]`).
- **`d`.** C#, Java, Go, Swift and Dart have a nested row: the values are `m = {v: [5, 6]}`. TypeScript flattens a group without an anchor into the row, Python has only an anchored group that shares the row, and so do both Rust APIs and C++: there the scheme is a group that holds the repeat, then `x`, and the values are flat (`v`, `x`).
- **`b` and `c`.** A list or dict element cannot be a row in Rust (either API) or in a C++ list or dict bound to a member; the line shows the package's refusal of the row.
- **`f` in the Rust map form.** All repeats of a scheme share the one `__repeat__` key, so `f` gives one round that holds both names (`{v: 5, w: 6}`); `f-two-groups` gives two rounds (`{v: 5}`, `{w: 6}`).

Where a package has more than one way to write a scheme (a typed row and a map row), the probe uses the one that can express the shape and says which in a comment; `n/a` is for a shape no public API of the package can write.

## Counting what a rule would refuse

```bash
bash scripts/probes/repeat-followed-by-field/rule-count/run.sh
```

It answers "which existing schemes would a build-time rule refuse" for TypeScript: it copies the checkout (the tracked files as they are on disk and the untracked files that git does not ignore) to a temporary directory, adds a logging call (`rule-count/repeat-last-probe.ts`) to the `Scheme` constructor of the copy, runs the whole TypeScript suite and loads the ring drivers, and prints one line per scheme the rule would refuse and the totals. It needs `typescript/node_modules` and takes about 20 s. Once the rule is in the package the count is 0 by construction and the tool has no use.

## State

Written in loop 112 (2026-11-12) on `9cfccda`: 85 lines, every `control` line `same`. The findings of that run are in `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md`. The probes print the behaviour of the checkout they run in, so after a rule for this class is implemented they print the refusals.

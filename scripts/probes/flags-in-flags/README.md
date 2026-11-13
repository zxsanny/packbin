# Probes: a `flags` that is a direct member of a `flags` (AZ-4251)

A `flags` writes one byte with a bit per member, then each member whose bit is set. When a member is itself a `flags`, its bit must be set when any member inside it holds a value; otherwise the inner value is dropped with no error (C# packed `0102` for `both` before loop 118). These probes show, per package, whether scheme `S` builds, what each shape packs and whether the package reads its own bytes. They assert nothing and change no package: they print what happens on the checkout they run in.

## Run

```bash
bash scripts/probes/flags-in-flags/run.sh             # all nine packages
bash scripts/probes/flags-in-flags/run.sh go swift    # some of them
```

`run.sh` calls `<package>/run.sh` for each package and prints their lines. Every build goes to a temporary directory outside the repository; nothing is written into the checkout. Exit 0 when every probe ran (whatever it found), 1 when one could not be built or run, 2 for an unknown package name. Tools: Node 22.18 or newer, .NET 10 SDK (`net10.0`), a JDK, Python 3.10 or newer (`PACKBIN_PROBE_PYTHON` picks one), Rust 1.98 (`RUSTUP_TOOLCHAIN`), a C++17 compiler (`PACKBIN_CXX_SYSROOT` on macOS when a system header is not found), Swift 6, Dart 3, and Go 1.27 or Docker (without a `go` on `PATH` the Go probe runs in `golang:1.27`, the image of `docker-compose.test.yml`). The probes share the build setup of `scripts/probes/repeat-followed-by-field/`.

## Output

One line per shape on stdout, five fields separated by a tab:

| field | values |
|-------|--------|
| package | `typescript`, `csharp`, `python`, `rust`, `java`, `cpp`, `go`, `swift`, `dart` |
| shape | `both`, `x-only`, `b-only`, `none` |
| build | `built`, or `refused: <the package's message>`, or `n/a: <why the package cannot write this shape>`, or `threw: <error>` (something that is not the package's own error) |
| pack | the packet in lowercase hex, or `refused: <message>`, or `threw: <error>`, or `-` when nothing was built |
| unpack | `same` (the values given come back), `differs: <the values that came back>`, `refused: <the error>`, `threw: <the exception>` (an unpack that does not return an error value), or `-` |

Messages are printed on one line, as the package gives them. Anything else a probe prints goes to stderr.

`same` compares the values `x` and `b` only. A member with no value (`null`, `None`, `nil`, an absent key, an empty `Opt`) is absent, and `b = false` counts as an absent `b`: both leave the bit clear and unpack gives `true` only for a set bit (see the root README, Bool). The Rust map form also returns each flag byte it read under the name of its `flags` (`f`, `g`); those names are left out of the comparison and printed after `differs:`.

A package that has a second public way to write the scheme prints it under the shape name with a suffix:

- **Rust** prints every shape again for the heap-free API (`-nostd`, on stdout, as in the repeat probe) and for the typed `Scheme<T>` (`-typed`: on stdout when its build, pack or unpack cell differs from the map-form line of the shape, else on stderr). The plain shape names are the map form (`MapScheme`).
- **Java** stdout is the `Map` row; the typed row (a class with `Integer x`, `Boolean b`) is `-typed`, on stdout when it differs from the `Map` line, else on stderr.
- **C++** stdout is the scheme built at run time; the constant form is `-constexpr`, printed when it differs, else on stderr (`cpp/run.sh`).
- **C#** is the other way round: stdout is the typed form (a row class with `byte? X` and `bool B`), and the dictionary form goes to stderr with the suffix `-map`. The package has no public call that reads a dictionary row, so a `-map` packet is read back with the typed `Unpack` and compared with the typed row that holds the same values.
- Python, Go, Swift and Dart are probed in their map-row form only (a dict, `map[string]any`, `[String: Any]`, `Map<String, Object?>`); their typed rows build the same nodes.

## Shapes

Scheme `S`, type number 1: an outer `flags` whose members are (1) an inner `flags` holding one member `u8 x`, and (2) `bool b`. Every package numbers the ids straight through: both `flags` and `x` are 0, `b` is 1 (the Rust map form names its fields and gives the anchors 0 and 1, the `bool` there being an empty `group`). The names are the same everywhere (`X` and `B` in C#).

| shape | values | TypeScript packs | read-back |
|-------|--------|------------------|-----------|
| `both` | `x = 9`, `b = true` | `01 03 01 09` | same |
| `x-only` | `x = 9` (no `b`, or `b = false` where the row has the member) | `01 01 01 09` | same |
| `b-only` | `b = true` (no `x`) | `01 02` | same |
| `none` | nothing | `01 00` | same |

The bytes: `01` is the type number; the outer flag byte has bit 0 for the inner `flags` and bit 1 for `b`; the inner flag byte has bit 0 for `x`; then `09` is `x`. A `bool` writes nothing after its bit.

How each package writes `S`:

| package | scheme |
|---------|--------|
| TypeScript | `flags(0, [flags(0, [u8(0, r => r.x)]), bool(1, r => r.b)])` |
| C# | `Field.Flags(0, Field.Flags(0, Field.U8<Row>(0, r => r.X)), Field.Bool<Row>(1, r => r.B))` |
| Python | `flags(0, flags(0, u8(0, lambda r: r["x"])), bool(1, lambda r: r["b"]))` |
| Rust map | `flags(0, "f", vec![flags(0, "g", vec![u8("x")]), group(1, "b", vec![])])` |
| Rust typed | `SchemeItem::flags(0, [SchemeItem::flags(0, [BoundField::opt_u8(0, ..)]), BoundField::bool_flag(1, ..)])` |
| Rust nostd | `[flags(0, 3), flags(0, 1), u8(0), boolean(1)]` |
| Java | `Packbin.flags(0, Packbin.flags(0, u8(0, ..)), Packbin.boolField(1, ..))` |
| C++ | `flags(0, flags(0, u8<&Row::x>(0)), boolean<&Row::b>(1))`, `x` an `Opt<std::uint8_t>` |
| Go | `Flags(0, Flags(0, U8(0, "x")), Bool(1, "b"))` |
| Swift | `.flags(0, .flags(0, .u8(0, "x")), .bool(1, "b"))` |
| Dart | `flags(0, [flags(0, [u8(0, 'x')]), flagBool(1, 'b')])` |

## State

Written in loop 118 (2026-11-13) on `d2ba83d` with the C# fix of AZ-4251 in progress. TypeScript, Python, Rust (all three forms), Java (both forms), C++ (both forms), Go, Swift and Dart print the TypeScript bytes and `same` for every shape. The C# lines are run at loop close; the findings are in `_docs/06_metrics/flags-in-flags-probe_2026-11-13.md`.

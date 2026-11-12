# Probes: a list or dict whose element is a row (AZ-4242)

An element row is a list or dict element that is a row of required members, written one after another with no flag byte per element (AZ-4199). In C# this form had three defects, fixed in loops 109 and 111 (AZ-4199, AZ-4205): some collection member types could not use it, a member declared for another row type built and then threw a raw cast exception out of pack and unpack, and `when` / `times` inside an element row had no test. These probes show, per package, whether the same class exists in TypeScript (the reference), Java, Go, Swift, Rust, Python and C++. They assert nothing and change no package: they print what happens on the checkout they run in. C# (fixed) and Dart (pins the AZ-4199 bytes since loop 109) are not probed.

## Run

```bash
bash scripts/probes/element-row/run.sh              # all seven packages
bash scripts/probes/element-row/run.sh go swift     # some of them
```

`run.sh` calls `<package>/run.sh` for each package and prints their lines. Every build goes to a temporary directory outside the repository; nothing is written into the checkout. Tools as for `scripts/probes/repeat-followed-by-field/README.md`: Node 22.18 or newer, a JDK, Python 3.10 or newer (`PACKBIN_PROBE_PYTHON` picks one), Rust 1.98 (`RUSTUP_TOOLCHAIN`), a C++17 compiler (`PACKBIN_CXX_SYSROOT` on macOS when a system header is not found), Swift 6, and Go 1.27 or Docker (without a `go` on `PATH` the Go probe runs in `golang:1.27`).

## Output

One line per shape on stdout, five fields separated by a tab:

| field | values |
|-------|--------|
| package | `typescript`, `java`, `go`, `swift`, `rust`, `python`, `cpp` |
| shape | a shape of the table below, with a suffix for a variant (`coll-array`, `list-3-nostd`, ...) |
| build | `built`, or `refused: <the package's message>`, or `n/a: <why the package cannot write this shape>` (also `n/a: does not compile: <message>` for a typed form the compiler rejects), or `threw: <error>` (something that is not the package's own error) |
| pack | the packet in lowercase hex, or `refused: <message>`, or `threw: <error>`, or `-` when nothing was built |
| unpack | `same` (the values given come back), `differs: <the values that came back>`, `refused: <the error>`, `threw: <the exception>` (an unpack that does not return the package's own error), or `-` |

Messages are printed on one line, as the package gives them. Anything else a probe prints goes to stderr. "Refused" is the package's own error type (an `Err`, an error value, the package's exception class, a documented `IllegalArgumentException` / `ArgumentException` / `ValueError` / `RangeError` raised by the package on purpose); "threw" is anything else, such as a `ClassCastException`, a Go panic, a Swift trap, a Python `AttributeError` or `TypeError` from inside the package, or a C++ crash.

## Shapes

Type number 1 everywhere. Field ids follow each package's own numbering rule; names and values are the same in every package. The element row of AZ-4199 is `Comment = (utf8 id, utf8 text, u32 authorId, utf8 author)`, ids 0 to 3, with `c1 = {c1, hi, 7, ann}`, `c2 = {c2, ok, 258, bo}`, `c3 = {c3, yes, 1, cy}`.

| shape | scheme | values | TypeScript packs |
|-------|--------|--------|------------------|
| `list-0` | `list items` of element row `Comment` | `[]` | `010000` |
| `list-1` | same | `[c1]` | `010100` `03106331` `022aaa` `07000000` `03c91980` |
| `list-3` | same | `[c1, c2, c3]` | `010300` + c1 + `03106332` `03106f6b` `02010000` `0310626f` + `03106333` `03cb2200` `01000000` `03106379` |
| `dict-2` | `dict map` of element row `Comment` | `{b: c2, a: c1}` | `010200` `021061` + c1 + `021062` + c2 |
| `coll-<type>` | `list-3` (or `dict-2`) with each other collection member type the package accepts for a list (dict) field | as `list-3` / `dict-2` | the same hex |
| `when` | element row `(u8 mode, when(mode == 1, u8 speed))` | `[{1, 7}, {0}]` | `010200010700`, reads back |
| `times` | element row `(u8 c, times(1, c, u8 v))` | `[{2, [5, 6]}, {0, []}]` | `01020002050600`, reads back |
| `other-row` | `list-3` scheme whose element members are declared for a row type other than the element's | `[c1]` | n/a (no row types) |
| `nested-other-row` | a nested row (a group without an anchor) whose member is declared for another row type | one row | n/a (no row types) |
| `null-member` | `list-1` scheme, `c1` with `text` missing (null / absent / `None`) | `[c1 without text]` | refused: `missing text` |
| `null-item` | `list-3` scheme, a list holding `c1` and a null element | `[c1, null]` | refused: `items: expected an object for each item` |

`same` compares the values given with the values that came back; a name whose list is empty may be absent on unpack (`times` of zero rounds), as in the repeat probe. `when`'s `{0}` comes back with `speed` absent, null or 0, whichever the package uses for a member a `when` did not write.

Where a package has more than one public way to write a scheme (a typed row and a map row; Rust's std and heap-free `nostd` APIs; a C++ list bound to a member and an unbound one), the probe prints the shape again with a suffix when the outcome can differ and says which form the plain shape name uses at the top of its source:

| package | plain name | suffixed lines |
|---------|-----------|----------------|
| Java | typed rows (classes) | `-map`: map rows |
| Go, Swift | typed rows (`Bind`, `.bind`) | `-map`: map rows; `other-row-whole`, `nested-other-row-whole`: every member of the row bound to a second row type (another check than one stray member) |
| Python | dict rows | `-typed`: a class row around the list or dict |
| Rust | the map API (`MapScheme`) | `-nostd`: the heap-free API |
| C++ | a list or dict bound to a member | `-unbound`: `list(element)` / `dict(element)` with no member; the `constexpr` form gives the same outcome and goes to stderr |

Swift's `Set` lines carry one item only: a `Set`'s order changes per process, so three items would give other bytes on each run.

## State

Written in loop 116 (2026-11-12). The findings are in `_docs/06_metrics/element-row-probe_2026-11-12.md`.

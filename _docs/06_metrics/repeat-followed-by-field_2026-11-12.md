# Findings: a repeat that is not the last thing a packet reads (AZ-4206)

Measured on 2026-11-12 in loop 112, package sources of `9cfccda`, on the project's Mac (arm64). One run of `bash scripts/probes/repeat-followed-by-field/run.sh`: 85 lines, exit 0, 31 s. Every cell below is copied from that run (appendix). Tools: Node 22.23.0, .NET SDK 10.0.103, Python 3.14.8, Rust 1.98.1, javac 21.0.2, Apple clang 21.0.0, Go 1.27.4 (in `golang:1.27`), Swift 6.4.2, Dart 3.13.5.

## What this is about

A `repeat` has no count on the wire. Unpack reads rounds until the buffer ends. So whatever a scheme writes after a repeat is read as more rounds of it. The README says so in one sentence ("A field after `repeat` is eaten as another point. Use `times` when something follows the group"), and the doc comments of Go and Swift say "nothing may follow it", but no package checks it: the scheme builds, pack writes the bytes, and the package's own unpack cannot read them.

## Result

`R` = the scheme builds, packs, and the package's own unpack refuses the bytes with an error value. `M` = it builds, packs, and unpack returns **other values with no error**. `ok` = the values come back. Ten columns: nine packages, Rust twice (the map form and the heap-free `nostd` API; the typed Rust `Scheme` has no `repeat`).

| shape | scheme | TypeScript | C# | Python | Rust map | Rust nostd | Java | C++ | Go | Swift | Dart |
|-------|--------|-----------|----|--------|----------|-----------|------|-----|----|-------|------|
| control | `u8 x`, `repeat(u8 v)` | ok | ok | ok | ok | ok | ok | ok | ok | ok | ok |
| a | `repeat(u8 v)`, `u8 x` | R | R | R | R | R | R | R | R | R | R |
| b | `list` of rows `(u8 mode, repeat(u8 v))` | R | R | R | cannot be written (1) | cannot be written (1) | R | cannot be written (2) | R | R | R |
| c | `dict` of rows `(u8 mode, repeat(u8 v))` | R | R | R | cannot be written (1) | cannot be written (1) | R | cannot be written (2) | R | R | R |
| d | nested row with `repeat(u8 v)`, then `u8 x` | R | R | R | R | R | R | R | R | R | R |
| e-when | `u8 k`, `when(k == 1, repeat(u8 v))`, `u8 x` | R | R | R | R | R | R | R | R | R | R |
| e-flags | `flags(repeat(u8 v))`, `u8 x` | R | R | R | R | R | R | R | R | R | R |
| f | `repeat(u8 v)`, `repeat(u8 w)` | **M** | **M** | **M** | **M** (3) | **M** | **M** | **M** | **M** | **M** | **M** |

1. Rust: a list or dict element is one value, never a row (`list "items" cannot carry element "item": an element is one integer, float, bytes, utf8, list or dict, or a u2 with one name`; the heap-free API answers `SchemeInvalid`). The refusal is for the row, not for the repeat.
2. C++: a list or dict bound to a member cannot have a row as its element either (`SchemeInvalid`, the same answer for a row without a repeat). The unbound form `list(element)` builds with the repeat inside, so the scheme check has no rule against it, but nothing can be packed from it (`BadValue`).
3. Rust map form: all repeats of a scheme share the one `__repeat__` key, so the rounds of two repeats cannot be given apart. Given as one round that holds both names it packs `01 05 06` and reads back two rounds of `v`; given as two rounds, pack refuses (`Missing("v")`).

No package refuses any of these schemes when it is built because of the repeat. No unpack threw: every `R` is an error value (a short packet naming the field after the repeat or the next element).

### The bytes

Every package that packs a shape writes the same bytes.

| shape | values | packet | what the package's own unpack does |
|-------|--------|--------|------------------------------------|
| control | `x = 9`, `v = [5, 6]` | `01 09 05 06` | reads it back |
| a | `v = [5, 6]`, `x = 9` | `01 05 06 09` | `09` is read as a third round, then `x` is missing: short packet at `x`, needed 1, left 0 |
| b | `{mode 1, v [5]}`, `{mode 2, v []}` | `01 02 00 01 05 02` | the second item's `02` is read as a round of the first item: short packet at `mode` |
| c | `"a": {mode 1, v [5]}`, `"b": {mode 2, v []}` | `01 02 00 02 10 61 01 05 02 10 62 02` | the second key is read as rounds of the first entry: short packet at `d` |
| d | `m.v = [5, 6]`, `x = 9` | `01 05 06 09` | as `a` |
| e-when | `k = 1`, `v = [5, 6]`, `x = 9` | `01 01 05 06 09` | as `a` |
| e-flags | `v = [5, 6]`, `x = 9` | `01 01 05 06 09` | as `a` |
| f | `v = [5]`, `w = [6]` | `01 05 06` | **no error**: `v = [5, 6]`, and `w` is absent (TypeScript, Python, Java, Go, Swift, Dart) or empty (C#, C++, Rust nostd) |

Shape `f` was not in the task. It was added during the loop because it is the same mistake with a worse outcome: the reader gets a row with wrong values and no error to notice it by. The same happens with a list of rows that end in a repeat, followed by a top-level repeat (TypeScript, scratch run: `rows = [{v: [5]}]`, `k = [3, 4]` packs `01 01 00 05 03 04` and reads back `rows = [{v: [5, 3, 4]}]` with no `k`).

### Schemes of this kind that do read back today

They work only for some rows, because the repeat happens to be the last thing that wrote a byte:

- a list with exactly one item whose row ends in a repeat, when the list is the last field (TypeScript `x-one-item`: `01 01 00 01 05 06`, the same; Go, scratch run);
- a field after the repeat that sits under a `when` that is not taken, or under a flag bit that is clear (Go and Rust, scratch runs: `01 00 09`);
- two `when`s on the same field with different values, the repeat in one and the other field in the other (TypeScript `x-exclusive-when`: `01 01 05 06`, the same). This one works for every row: the two can never be written together.

A repeat with zero rounds does not help: `repeat(u8 v), u8 x` with no rounds packs `01 09` and is still refused, `x` is read as a round (Go and Rust, scratch runs).

## Proposed rule

One rule for all nine packages, checked when the scheme is built:

> A `repeat` must be the last thing its packet reads. A scheme is refused when (1) any field that can write a byte stands after a repeat, in the repeat's own place or after a `when`, `flags`, group or nested row that holds it, up to the top level; or (2) a repeat sits inside a list or dict element.

The message names the repeat and the field that follows it and says what to use (`times`, which has a count). A second repeat is a field that follows (shape `f`). It costs one walk when the scheme is built and nothing per pack or unpack.

### What it would refuse today (measured)

`bash scripts/probes/repeat-followed-by-field/rule-count/run.sh` adds a logging call to the `Scheme` constructor in a temporary copy of TypeScript and runs the whole TypeScript suite (3,642 tests, the shared hostile cases of `fixtures/hostile/cases.txt` among them) and loads the ring drivers. Run of 2026-11-12: 77,266 schemes built (a scheme that does not build is not counted), 11 of them by the ring drivers.

| what | schemes the rule refuses |
|------|--------------------------|
| shared fixtures and golden vectors (`fixtures/golden.hex`, the hostile cases, the ring driver schemes) | **0** |
| TypeScript's own tests | **4**, in 3 files (below) |

| test file | scheme | why |
|-----------|--------|-----|
| `typescript/tests/nested-round.test.ts` | `repeat(u8 k, list rows of (repeat(u8 v)))` | a repeat inside a list element (packed with empty lists only) |
| `typescript/tests/nested-round.test.ts` | `list rows of (repeat(u8 v))`, `repeat(u8 k)` | the same (packed with an empty list only) |
| `typescript/tests/pack-repeat-round-cap.test.ts` | `list items of (repeat(u8 k))` | the same (a pack-limit test, one item) |
| `typescript/tests/round-values.test.ts` | `repeat(bytes v, size 0)`, `u8 tail` | a field after a repeat (the test of a round that reads nothing) |

These four tests would be rewritten with `times` or turned into tests of the refusal. Counting "any field" instead of "a field that can write a byte" gives the same four. No test scheme uses the two-exclusive-`when`s pattern.

Not measured: the same count in the test suites of the other eight packages (their tests are written by hand per package; the implementation task finds them when its check goes in), and any scheme outside this repository (Archangel uses the C# package).

### The other ways to answer it

| | rule | gain | cost |
|---|------|------|------|
| A (proposed) | refuse at scheme build, as above | the mistake is found once, when the scheme is written; no packet a reader cannot read, no silent wrong row | the schemes that work for some rows (one item, a `when` not taken, a clear flag bit, two exclusive `when`s) stop building; a sender that only packs for a reader of its own loses the scheme; a behaviour change in the next release |
| B | A, but a field after the repeat is allowed when it sits under a `when` on the same field with another value than the repeat's `when` | keeps "one body per kind byte" schemes, which are always readable | more code and tests in nine packages for a pattern no test or fixture uses today; it can be added later without breaking anything, the other direction cannot |
| C | refuse at pack, when a byte is written after a repeat was reached | refuses only rows that cannot be read; every scheme that works today keeps working | found at run time, per row, on the sender; a check on every pack; a scheme that fails only for some rows is harder to test |
| D | keep it as it is (the README sentence) | nothing changes | all nine keep writing packets they refuse, and shape `f` keeps reading back wrong values with no error |

Recommended: A. It is the smallest rule, it refuses nothing in the shared fixtures, and B stays open as a later relaxation.

## Second ways of writing the same schemes

Checked by the probes or by scratch runs of the workers; they give the same outcome unless noted.

- Typed rows: C# (the committed probe uses them: a repeat bound to a collection of rows is the only form the public `Unpack` reads back), Java (`-typed` lines on stderr), Go (`Bind`), Swift (`bind(get:set:)`), Dart (`rowScheme`; for `f` it returns `w = []` and not an absent `w`), a Python class row.
- An anchored group in place of the nested row for `d`: Go, Swift, Dart, C++ (C++ has no group without an anchor): the same bytes, only the id of `x` differs.
- C++ `constexpr` schemes: the same cells; `b` and `c` do not compile (`constexpr variable 's' must be initialized by a constant expression`).
- C# dictionary row over an unbound `Field.Repeat`: builds and packs the same bytes; it cannot show a read-back at all, because C# has no public call that reads a dictionary row (a known gap, not this class: even the control comes back as `ShortPacket(Field="V", Needed=0, Left=0)`).
- A fixed-size row changes the error of `a`: with room for exactly the rounds given, the Rust heap-free API and C++ (`Array<Round, 2>`) answer `TooMany` instead of a short packet. The probes use a larger row.

## Appendix: the run

`package`, `shape`, `build`, `pack`, `unpack`, as printed (2026-11-12 11:27).

| package | shape | build | pack | unpack |
|---------|-------|-------|------|--------|
| typescript | control | `built` | `01090506` | `same` |
| typescript | a | `built` | `01050609` | `refused: {"field":"x","left":0,"needed":1,"ok":false}` |
| typescript | b | `built` | `010200010502` | `refused: {"field":"mode","left":0,"needed":1,"ok":false}` |
| typescript | c | `built` | `010200021061010502106202` | `refused: {"field":"d","left":0,"needed":1,"ok":false}` |
| typescript | d | `built` | `01050609` | `refused: {"field":"x","left":0,"needed":1,"ok":false}` |
| typescript | e-when | `built` | `0101050609` | `refused: {"field":"x","left":0,"needed":1,"ok":false}` |
| typescript | e-flags | `built` | `0101050609` | `refused: {"field":"x","left":0,"needed":1,"ok":false}` |
| typescript | f | `built` | `010506` | `differs: {"v":[5,6]}` |
| typescript | x-one-item | `built` | `010100010506` | `same` |
| typescript | x-exclusive-when | `built` | `01010506` | `same` |
| csharp | control | `built` | `01090506` | `same` |
| csharp | a | `built` | `01050609` | `refused: ShortPacket(Field="X", Needed=1, Left=0)` |
| csharp | b | `built` | `010200010502` | `refused: ShortPacket(Field="Mode", Needed=1, Left=0)` |
| csharp | c | `built` | `010200021061010502106202` | `refused: ShortPacket(Field="D", Needed=1, Left=0)` |
| csharp | d | `built` | `01050609` | `refused: ShortPacket(Field="X", Needed=1, Left=0)` |
| csharp | e-when | `built` | `0101050609` | `refused: ShortPacket(Field="X", Needed=1, Left=0)` |
| csharp | e-flags | `built` | `0101050609` | `refused: ShortPacket(Field="X", Needed=1, Left=0)` |
| csharp | f | `built` | `010506` | `differs: {"RoundsV":[{"V":5},{"V":6}],"RoundsW":[]}` |
| python | control | `built` | `01090506` | `same` |
| python | a | `built` | `01050609` | `refused: ShortPacket(field='1', needed=1, left=0)` |
| python | b | `built` | `010200010502` | `refused: ShortPacket(field='0', needed=1, left=0)` |
| python | c | `built` | `010200021061010502106202` | `refused: ShortPacket(field='', needed=1, left=0)` |
| python | d | `built` | `01050609` | `refused: ShortPacket(field='1', needed=1, left=0)` |
| python | e-when | `built` | `0101050609` | `refused: ShortPacket(field='2', needed=1, left=0)` |
| python | e-flags | `built` | `0101050609` | `refused: ShortPacket(field='1', needed=1, left=0)` |
| python | f | `built` | `010506` | `differs: {"v":[5,6]}` |
| rust | control | `built` | `01090506` | `same` |
| rust | a | `built` | `01050609` | `refused: Short(ShortPacket { field: "x", needed: 1, left: 0 })` |
| rust | b | `refused: panic: list "items" cannot carry element "item": an element is one integer, float, bytes, utf8, list or dict, or a u2 with one name` | - | - |
| rust | c | `refused: panic: dict "d" cannot carry element "item": an element is one integer, float, bytes, utf8, list or dict, or a u2 with one name` | - | - |
| rust | d | `built` | `01050609` | `refused: Short(ShortPacket { field: "x", needed: 1, left: 0 })` |
| rust | e-when | `built` | `0101050609` | `refused: Short(ShortPacket { field: "x", needed: 1, left: 0 })` |
| rust | e-flags | `built` | `0101050609` | `refused: Short(ShortPacket { field: "x", needed: 1, left: 0 })` |
| rust | f | `built` | `010506` | `differs: {"__repeat__":[{"v":5},{"v":6}]}` |
| rust | f-two-groups | `built` | `refused: Missing("v")` | - |
| rust | control-nostd | `built` | `01090506` | `same` |
| rust | a-nostd | `built` | `01050609` | `refused: Fault { error: ShortPacket, offset: 4, field: 1, needed: 1 }` |
| rust | b-nostd | `refused: Fault { error: SchemeInvalid, offset: 0, field: 0, needed: 0 }` | - | - |
| rust | c-nostd | `refused: Fault { error: SchemeInvalid, offset: 0, field: 0, needed: 0 }` | - | - |
| rust | d-nostd | `built` | `01050609` | `refused: Fault { error: ShortPacket, offset: 4, field: 1, needed: 1 }` |
| rust | e-when-nostd | `built` | `0101050609` | `refused: Fault { error: ShortPacket, offset: 5, field: 2, needed: 1 }` |
| rust | e-flags-nostd | `built` | `0101050609` | `refused: Fault { error: ShortPacket, offset: 5, field: 1, needed: 1 }` |
| rust | f-nostd | `built` | `010506` | `differs: {0: [{0: U8(5)}, {0: U8(6)}], 1: []}` |
| java | control | `built` | `01090506` | `same` |
| java | a | `built` | `01050609` | `refused: ShortPacket(field="1", needed=1, left=0)` |
| java | b | `built` | `010200010502` | `refused: ShortPacket(field="0", needed=1, left=0)` |
| java | c | `built` | `010200021061010502106202` | `refused: ShortPacket(field="", needed=1, left=0)` |
| java | d | `built` | `01050609` | `refused: ShortPacket(field="0", needed=1, left=0)` |
| java | e-when | `built` | `0101050609` | `refused: ShortPacket(field="2", needed=1, left=0)` |
| java | e-flags | `built` | `0101050609` | `refused: ShortPacket(field="1", needed=1, left=0)` |
| java | f | `built` | `010506` | `differs: {"v":[5,6]}` |
| cpp | control | `built` | `01090506` | `same` |
| cpp | a | `built` | `01050609` | `refused: {"error":"ShortPacket","field":1,"needed":1,"offset":4}` |
| cpp | b | `refused: {"error":"SchemeInvalid","field":0,"needed":0,"offset":0}` | - | - |
| cpp | b-unbound | `built` | `refused: {"error":"BadValue","field":-1,"needed":0,"offset":1}` | - |
| cpp | c | `refused: {"error":"SchemeInvalid","field":0,"needed":0,"offset":0}` | - | - |
| cpp | c-unbound | `built` | `refused: {"error":"BadValue","field":-1,"needed":0,"offset":1}` | - |
| cpp | d | `built` | `01050609` | `refused: {"error":"ShortPacket","field":1,"needed":1,"offset":4}` |
| cpp | e-when | `built` | `0101050609` | `refused: {"error":"ShortPacket","field":2,"needed":1,"offset":5}` |
| cpp | e-flags | `built` | `0101050609` | `refused: {"error":"ShortPacket","field":1,"needed":1,"offset":5}` |
| cpp | f | `built` | `010506` | `differs: {"v":[5,6],"w":[]}` |
| go | control | `built` | `01090506` | `same` |
| go | a | `built` | `01050609` | `refused: packbin: short packet at field 1 (x): needed 1, left 0` |
| go | b | `built` | `010200010502` | `refused: packbin: short packet at field 0 (mode): needed 1, left 0` |
| go | c | `built` | `010200021061010502106202` | `refused: packbin: short packet at d: needed 1, left 0` |
| go | d | `built` | `01050609` | `refused: packbin: short packet at field 0 (x): needed 1, left 0` |
| go | e-when | `built` | `0101050609` | `refused: packbin: short packet at field 2 (x): needed 1, left 0` |
| go | e-flags | `built` | `0101050609` | `refused: packbin: short packet at field 1 (x): needed 1, left 0` |
| go | f | `built` | `010506` | `differs: {"v":[5,6]}` |
| swift | control | `built` | `01090506` | `same` |
| swift | a | `built` | `01050609` | `refused: packbin: short packet at field 1 (x): needed 1, left 0` |
| swift | b | `built` | `010200010502` | `refused: packbin: short packet at field 0 (mode): needed 1, left 0` |
| swift | c | `built` | `010200021061010502106202` | `refused: packbin: short packet at d: needed 1, left 0` |
| swift | d | `built` | `01050609` | `refused: packbin: short packet at field 0 (x): needed 1, left 0` |
| swift | e-when | `built` | `0101050609` | `refused: packbin: short packet at field 2 (x): needed 1, left 0` |
| swift | e-flags | `built` | `0101050609` | `refused: packbin: short packet at field 1 (x): needed 1, left 0` |
| swift | f | `built` | `010506` | `differs: {"v":[5,6]}` |
| dart | control | `built` | `01090506` | `same` |
| dart | a | `built` | `01050609` | `refused: packbin: short packet at field 1 (x): needed 1, left 0` |
| dart | b | `built` | `010200010502` | `refused: packbin: short packet at field 0 (mode): needed 1, left 0` |
| dart | c | `built` | `010200021061010502106202` | `refused: packbin: short packet at d: needed 1, left 0` |
| dart | d | `built` | `01050609` | `refused: packbin: short packet at field 0 (x): needed 1, left 0` |
| dart | e-when | `built` | `0101050609` | `refused: packbin: short packet at field 2 (x): needed 1, left 0` |
| dart | e-flags | `built` | `0101050609` | `refused: packbin: short packet at field 1 (x): needed 1, left 0` |
| dart | f | `built` | `010506` | `differs: {"v":[5,6]}` |

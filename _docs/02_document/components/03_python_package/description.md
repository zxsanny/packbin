# Python package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for tools and scripts.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's Python program.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme` | type number, row class, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, a `bool` that is not a direct child of `flags` or of a flag-byte bit, a `group(anchor)` with no fields, a `when` or count that names a later field, an id that does not exist or a field of another scope, a split flag bit before its flag byte or in another scope, a ninth bit of one read of a flag byte, a `repeat` or `times` inside a `repeat` or `times` round, a member name declared twice in one scope outside every `when`, or an attribute accessor in a `list` or `dict` element group (see §7). Each is a `ValueError` naming the id or the member; a ninth `flags` child already fails at `flags(...)` |
| `Scheme.with_limits`, `max_rounds`, `max_slots`, `Scheme.DEFAULT_MAX_ROUNDS`, `Scheme.DEFAULT_MAX_SLOTS` | `max_rounds`, `max_slots` (whole numbers) | a new scheme with those unpack limits | No | `ValueError` for a limit below 1 or not a whole number (§7) |
| `BinaryPacker.pack` | scheme, row | bytes | No | integer does not fit; `TypeError` for a float field given anything but an `int` or a `float`; `OverflowError` for a finite value too large for `f32`; `ValueError` for a `times` list longer than its count (§7) |
| `BinaryPacker.unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch, a `repeat` or `times` round past the scheme's limits; never raises on bytes (see §7) |

**Input DTOs**:

```
Value:
  fields: name to number, string, list, dictionary, or absence (required) — absence omits the field
```

**Output DTOs**:

```
Bytes:
  length: number — sum of present field widths
ShortPacket:
  field: string
  needed: number
  left: number
```

### Interface: PackSession

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `PackSession(seed)` | 32 bytes | a session | No | length other than 32 raises `ValueError` |
| `load` | `bytes`, `bytearray` or `memoryview` of 32 bytes | a session, or `None` | No | anything else returns `None` and raises nothing: a length other than 32, an `int`, a list, a `str`, `None`, a released memoryview (loop 16, AZ-2231) |
| `start` | none, or `bytes`, `bytearray` or `memoryview` of 16 bytes | 16 bytes, or `None` | No | anything else returns `None`, leaves the session closed and raises nothing: a length other than 16, an `int`, a list, a `str`, a released memoryview (AZ-2244); `start()` and `start(None)` draw the nonce |
| `join` | `bytes`, `bytearray` or `memoryview` of 16 bytes | `True`, or `False` | No | anything else returns `False`, leaves the session closed and raises nothing, `None` included (AZ-2244) |
| `pack` | scheme, row | payload the same length as clear pack | No | pack before start or join produces 0 payloads |
| `unpack` | payload, scheme | the row, or the clear-unpack error | No | — |

## 4. Data Access Patterns

No queries and no cache.

**Seed data**: the shared golden hex file.

**Rollback**: yank the PyPI version.

## 5. Implementation Details

**State Management**: clear pack is stateless. A session keeps one send counter and one receive counter. Source layout (`python/src/packbin/`): `_nodes.py` the field builders and nodes (since AZ-2245 every accessor pair carries an `access` mark, `("attr", key)` or `("item", key)`, set by `_marked`; the identity has none; since AZ-2248 a `times` node holds its `optional` leaf ids, `_optional_leaves`), `_validate.py` the construction checks (`_validate_order` for ids, references and bool placement, `_validate_round_nesting`; new in loop 16, `_validate_order` moved out of `_nodes.py`; `_validate_names` for a name declared twice, AZ-2245; `_validate_element_accessors` for attribute accessors in element groups, AZ-2249; `Scheme.__init__` runs both last), `_flag_scope.py` the split flag bit check and numbering (`_bind_flag_bits`; new in loop 16, AZ-2230, it replaced `_validate_flag_bits` and `_check_flag_scopes` of `_validate.py`), `_pack.py` and `_unpack.py` the walkers, `_scheme.py` `Scheme`, `BinaryPacker` and the round limits, `_session.py` (`_exact_bytes` is the one check of a seed or nonce, shared by `load`, `start` and `join`, AZ-2244) and `_session_pad.py` the session, `_errors.py` the result types.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime writes little-endian fields |

**Error Handling Strategy**:
- A short field returns an error and zero values
- Hostile bytes return `UnpackResult(ok=False)`, never an exception (§7)
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator
- A `repeat` whose lists differ in length raises `ValueError` (`repeat fields must have equal lengths`), where TypeScript, C# and Java let the longest list set the round count; a `times` list shorter than its count raises a bare `IndexError` for a plain member or a member under `when`; for a member under `flags` or a flag bit a short or empty list means absent (AZ-2248), where `repeat` is unchanged: its lists still need equal lengths and an empty one raises `IndexError`, while TypeScript and Java pack these rows (the owner decides whether `repeat` follows `times`)
- A `when`, `repeat` or `times` as a member of `flags` or as the field of a flag bit never sets its bit and is not written, with no error (`_child_on` in `_pack.py`). The owner holds it for the loop that lands the C# work, so the six packages are decided together (AZ-2128, AZ-2120)
- `PackSession(seed)` takes any 32-item sequence of byte values, so `PackSession([7] * 32)` builds a session; `load`, `start` and `join` are the strict entry points (bytes, bytearray or memoryview only). Open for the owner (AZ-2231, AZ-2244)
- A name is the accessor key, so `row.x` and `row["x"]` in one scheme count as different names and build (AZ-2245; the owner may want a match by key only); keys compare by `==` (`r[0]` and `r[False]` clash); two declarations inside one `when` body build, as in TypeScript. An identity accessor in a `list` or `dict` element group builds, fails at pack with `TypeError: 0: expected int, got dict` and loses the value on unpack (AZ-2249, owner option B would refuse it); an attribute accessor on the list itself (`lambda row: row.pts`) is allowed, a top-level `dict` row with attribute accessors or a class row with key accessors raises `AttributeError` on unpack
- A bit made by `.bit(...)` that the scheme does not place leaves its bit clear, with no error. A flag byte listed without all its bits was refused before AZ-2230 (`flag byte: bit 1 is not in the scheme`); the owner has not confirmed that the silence is wanted
- A float field takes only an `int` or a `float`: a numpy `float32` or integer is refused (a numpy `float64` is a `float`), and an `int` too large for `f64` (`10**400`) raises an unnamed `OverflowError`

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time bound set by the input length and, for rounds, a memory bound set by the scheme's round limits (below). It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In Python it is `ShortPacket(field, needed=0, left)` built by `_bad_value` in `_unpack.py`. A count error is labelled with the counted field's id, a `times` error with its anchor id, and a zero-width list or dict element or an invalid dictionary key with `""`. Session unpack removes the pad and then runs the same clear unpack.

**Round limits** (loop 16, owner decision after the review of AZ-2134; `_scheme.py`, `_unpack.py`). Before this, Python had no limit because it listed only the rounds that read a name (loop 15, AZ-2220). Since AZ-2134 every name a round can hold keeps one list entry per round, so memory grows with names times rounds and Python needs the same limits as C#, TypeScript, Java and Rust. A `Scheme` carries `max_rounds` (default `Scheme.DEFAULT_MAX_ROUNDS`, 65,535) and `max_slots` (default `Scheme.DEFAULT_MAX_SLOTS`, 4,194,304), read through `scheme.max_rounds` and `scheme.max_slots`. `scheme.with_limits(max_rounds=..., max_slots=...)` returns a copy of the scheme with the new limits and the same fields; an omitted argument is the default, not the receiver's value, so give both in one call. A value below 1, a `bool` or anything that is not an `int` raises `ValueError`; there is no unlimited value. `BinaryPacker._unpack_fields` builds a `_Budget` for the call and `unpack_nodes` passes it to every `repeat`, `times`, `list` and `dict`. `_Budget.refuses(started, width)` runs as each round starts, before the round is read: `width` is the number of value-holding nodes of the body (`leaves`; a `u2` counts each slot), a round costs `width` slots, and the first round of a run costs `width * 9` (eight more per node for the list that holds the run's entries), so a short run in each of many `list` or `dict` elements pays for its own lists. The round that would be the 65,536th of one field, or would take the slot total past `max_slots`, returns `ShortPacket(field=<anchor id>, needed=0, left=<bytes left>)` (the interim bad-value error): no row, no handler call. A `times` count is not refused up front. Memory at the defaults (Python 3.14, macOS arm64, resident set above the idle interpreter), 1 MiB packet of one-byte rounds, a `repeat` with a 36-name `when` body: refused at round 65,536 after about 39 MiB in 0.27 s (about 390 MiB unlimited); the same body in 65,535 `list` elements is refused after about 53 MiB in 0.3 s.

**Construction rule** (loop 16, AZ-2100, AZ-2230; `_bind_flag_bits` in `_flag_scope.py`, called by `Scheme(...)`): a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body, a `flags` member and a flag bit see the flag bytes read before them but leave theirs behind. A violation is a `ValueError` (`flag bit 0: its flag byte is not read earlier in the same scope`). A flag byte takes no field id: each bit takes the id where it stands. `flag_byte()` and `.bit(...)` build in a `Scheme`, unpack reads a bit's field like any other field, and a `bool` under a bit round-trips.

**Bit numbers** (loop 16, AZ-2230; `_flag_scope.py`). Each read of a flag byte becomes a `_FlagByte` of its own in the scheme's copy of the fields (`Scheme._fields` holds the bound nodes, not the caller's), and each bit is numbered by its place among the bits that follow that read: bit 0 is the first, as in the combined form and in TypeScript, Java, Rust and C++, and a bit nested in another bit's field comes after the outer one. The `flag_byte()` handle and the bits `.bit(...)` returns hold no number (index -1), so a handle can be shared by any number of schemes and be read more than once: `[m, m.bit(a), m, m.bit(b)]` with only `b` set packs `01 00 01 09`; a bit made early and placed late takes its place (`[m, mid, early, late]`, only `late` set: `01 02 01 09`). The ninth bit of one read raises `ValueError` (`flags already has 8 bits`) when the `Scheme` is built, not when `.bit(...)` is called. A bit the scheme does not place has no number and stays clear (see §7).

**Reference scope** (loop 16, AZ-2113; `_validate_order`). Every `eq` field id, and the count id of `sized`, `bits`, `packed` and `times`, must name a value field declared earlier in the same scope: the top level, a `repeat` or `times` body, or a `list` or `dict` element (ids restart at 0 in an element). `flags`, flag bits, `when` and `group` share the scope around them; a Python `group` has no scope of its own. A later field, an id that does not exist, an outer field from inside a body and a field inside an earlier body are a `ValueError` (`when 1: eq names field id 2 is allowed only if declared earlier in the same scope`, `sized 0: count field id 5 is allowed only if declared earlier in the same scope`). The count is not checked for its kind, and `eq` may name any value field.

**Rounds** (loop 16, AZ-2134; `_unpack.py`, `_pack.py`, `_validate.py`). Every node of a `repeat` or `times` body that holds a value (`leaves`, found once at construction through `flags`, `when`, groups, flag bits and `u2` slots by `_round_leaves` in `_nodes.py`) gets one list for the run, with one entry per round and `None` where the round skipped it (`_align_lists`). The lists are stored on the row when the run ends (`_store_lists`), so a default the row class carries, a number or a list its class shares, is never part of them (before, a class-level list was appended to in place). Two nodes that bind one member, the arms of two `when`s, share one list. Pack reads the lists by round index (`_at_round`), so `flags`, `when` and groups inside a round pack, and a `bool` under `flags` inside a `times` reads its own round. A `repeat` takes its round count from its lists, which must be equally long. A `times` list longer than the count raises `ValueError` before any round is written (`_check_round_lists`: `1: 3 items, times count is 2`), for every kind of member, `bool` and `u2` included. A `repeat` or `times` inside a `repeat` or `times` round, directly or under `when`, `flags`, a flag bit or a group, raises `ValueError` at construction (`_validate_round_nesting`: `repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times`); a `list` or `dict` element starts outside any round, so a round inside an element of a round is allowed.

**Member names** (loop 16, AZ-2245; `_validate_names`, `_declare_name`, `_marked`). A row holds one value per accessor name, so a name declared twice in one scope loses a value: `u8 x` twice unpacked `01 07 08` to `{x: 8}` and packed that as `01 08 08`; `u8 x` beside a `times` holding `u8 x` unpacked to `{x: [7, 8]}` and could not be packed again. `Scheme(...)` raises `ValueError` (`member x: declared twice in one scope; a row holds one value per name, so one would be lost`, the accessor key named) for the same name twice at one level, outside and inside a `times` or `repeat` round, in two rounds, under `flags`, in a group or a flag bit, for every kind of field including a `u2` slot, `be()` and a `list` or `dict` accessor. The scope is the top level or one `list` or `dict` element (an element may reuse a row's names); `repeat`, `times`, `flags`, `when`, `group` and a flag bit share the scope around them, and a flag byte holds no name. A declaration under a `when` is not counted, so the branches of a chain may share a member. The check runs after every earlier one, so the older messages keep winning, and before the element accessor check. `_pair` marks both closures of an accessor with `(kind, key)`; `be()`, flag bits and `with_limits` reuse the closures, so the mark survives.

**Element accessors** (loop 16, AZ-2249; `_validate_element_accessors`). A `list` or `dict` element that is not a leaf is unpacked into a plain `dict`, so a member that reads and writes an attribute (`lambda p: p.x`) could pack objects but never unpack a value (`AttributeError` out of `BinaryPacker.unpack` on a valid packet). `Scheme(...)` raises `ValueError` (`list element: field 0 uses the attribute accessor 'x'; an element row is a dict, so use a key accessor, row['x']`; `dict element:` for a dict; `a nested list` or `a nested dict` for a container member) for such a member at any depth of the element: in a group, `flags`, `u2`, a `when`, `times` or `repeat` body, a flag bit or a nested container. Key accessors, a leaf element, an inner container that is itself an element (its own accessor is never called) and the identity accessor are unchanged. A scheme whose element members are all optional is refused too, by scheme and not by value.

**Short `times` lists** (loop 16, AZ-2248; `_optional_leaves` in `_nodes.py`, `_at_round` in `_pack.py`, bound again in `_flag_scope.py`). The ids of the leaves of a `times` body that a flag bit can leave absent (reached through `flags` or a flag bit, also through `when` and groups below them) are computed once at construction. `_at_round(row, i, optional)` returns `None` past the end of a list only for those leaves, so `{"c": 2, "on": [True]}` packs `01 02 01 00` and `{"c": 2, "v": [5]}` packs `01 02 01 05 00`, as in TypeScript and Java. A set `u2` or group that lacks a sibling still fails (`ValueError: 2: expected 2-bit int`, `TypeError: 2: expected int, got NoneType`); a plain member and a member under `when` keep `IndexError`; a longer list is still refused; unpack returns full lists with `None` and `repeat` is untouched.

**Float pack** (loop 16, AZ-2192; `_require_int` and `_write_scalar` in `_pack.py`). An `f32` or `f64` field takes only an `int` or a `float`. A `bool`, string, bytes, `Decimal` or `Fraction` raises `TypeError` naming the field (`0: expected number, got str`; a `bool` used to pack as 1.0 and a string raised an unnamed `ValueError`), and a finite value too large for `f32` raises `OverflowError` (`0: 1e+39 does not fit in f32`). `nan` and the infinities are written as given.

**Star import** (loop 16, AZ-2104; `__init__.py`). `__all__` leaves out `bool`, `bytes`, `dict` and `list`, so `from packbin import *` no longer replaces the builtins with field builders; they stay importable by name (`from packbin import dict as map_field`). `PackSession(seed)` raises `ValueError` unless the seed is 32 bytes.

**Bool rule** (loop 12, `_validate_order` in `_validate.py` since loop 16): a `bool` stands only as a direct child of `flags(...)` or as the field of a flag-byte bit. Anywhere else (top level, inside any `group`, also one under `flags`, inside `when`, `repeat` or `times`, or as a `list` or `dict` element) `Scheme(...)` raises `ValueError` naming its id. A `group(anchor)` with no fields has no accessor, so it can never carry `true`; `Scheme(...)` refuses it wherever it stands, inside `flags` too. `flags(...)` with a ninth child raises `ValueError` naming the anchor when it is declared. The bit is set only for `True`; `False`, a missing value and any other value (`1`, `"yes"`) leave it clear, and unpack gives `True` only when the bit is set.

**Breaking changes for callers** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.
- A `bool` outside `flags` (its value never reached the wire) and a `group(anchor)` with no fields now fail at construction (loop 12).
- A ninth `flags` child now fails at `flags(...)`, instead of at pack only when its value was present (loop 12).

**Breaking changes for callers, loop 16** (the bytes of a row that packed before are unchanged except where noted):
- `PackSession(seed)` raises `ValueError` unless the seed is 32 bytes (`load` still returns `None`). `load` returns `None` for anything that is not `bytes`, `bytearray` or `memoryview` of 32 bytes: `load(32)` opened a session keyed by 32 zero bytes (`bytes(32)`), `load` of a list of 32 ints and of an `array.array` did too (AZ-2231).
- `from packbin import *` no longer imports `bool`, `bytes`, `dict` and `list`; import them by name.
- `PackSession.start(nonce)` and `join(nonce)` follow the `load` rule (AZ-2244): `start` returns `None` and `join` `False`, raising nothing, for anything that is not `bytes`, `bytearray` or `memoryview` of 16 bytes. `start(16)`, a list of 16 ints, an `array.array` and a ctypes array opened a session (`start(16)` used 16 zero bytes), and a `str`, a float, a released memoryview and `join(None)` raised.
- A member name declared twice in one scope fails at construction (AZ-2245), unless one of the two sits under a `when`.
- A `times` list that is shorter than the count, or empty, packs for a member under `flags` or a flag bit, a missing entry meaning absent (AZ-2248); it raised `IndexError`.
- A `list` or `dict` element group with an attribute accessor fails at construction (AZ-2249). This breaks schemes that only pack, with object elements: `Row.pts = [Pt(1), Pt(2)]` packed to `01 02 00 01 02` and no longer builds; pack `dict` elements instead (`[{"x": 1}, {"x": 2}]` packs the same bytes). The owner confirmed it.
- `Scheme(...)` refuses a `when` or count that names a later field, an id that does not exist or a field of another scope, split flag bits outside their scope, and a `repeat` or `times` inside a `repeat` or `times` round. `flag_byte()` and `.bit(...)` now build.
- Pack refuses a `times` list longer than the count and a float field given anything but an `int` or a `float` (a `bool` packed as 1.0); a flags group holding only a `u2` or a nested `flags` now sets its bit (`{p:1, q:2}` packs `010109`, it packed `0100`).
- Unpack of a `repeat` or `times` gives every name one list entry per round, `None` where the round skipped it, and no longer appends to a list the row class carries; `flags`, `when` and groups inside a round pack, and a `bool` under `flags` in a `times` reads its own round (`{a:2, on:[True,False]}` packs `01020100`, it packed `01020000`).
- Unpack refuses a packet whose `repeat` or `times` starts more than 65,535 rounds, or whose rounds hold more than 4,194,304 slots together, until the scheme raises the limits with `with_limits`.
- Split-form flag bits are numbered by their place in the scheme (AZ-2230), as in TypeScript, Java, Rust and C++: a handle shared by two schemes no longer fails the one that places only some of its bits, a bit made early and placed late takes its place, and a second read of a flag byte starts its own bits (`01 00 01 09` above; the bit number followed the `.bit(...)` calls before). The ninth bit of one read raises when the scheme is built. A flag byte listed with a bit the scheme leaves out builds (it raised `flag byte: bit 1 is not in the scheme`).

**Potential race conditions**:
- None

**Performance bottlenecks**:
- The same AC-10 loop, on one core, in this language. Python's bound is 2 seconds.

## 8. Dependency Graph

**Must be implemented after**: the golden fixture file

**Can be implemented in parallel with**: the other five language packages

**Blocks**: the first version tag, together with the other five language packages

## 9. Logging Strategy

| Log Level | When | Example |
|-----------|------|---------|
| none | the library returns the error | the caller logs the three error fields |

**Log format**: none inside the package

**Log storage**: none

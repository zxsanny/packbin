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
| `Scheme` | type number, row class, fields by order id | scheme | No | a gap, a repeated id, an anchor that is not the next value id, a `bool` that is not a direct child of `flags` or of a flag-byte bit, a `group(anchor)` with no fields, a `when` or count that names a later field, an id that does not exist or a field of another scope, a split flag bit before its flag byte or in another scope, a ninth bit of one read of a flag byte, a `repeat` or `times` inside a `repeat` or `times` round, a member name declared twice in one scope outside every `when`, an attribute accessor in a `list` or `dict` element group, or an `eq` value that its integer source can never hold (loop 19, AZ-2338; see §7). Each is a `ValueError` naming the id or the member; a ninth `flags` child already fails at `flags(...)` |
| `Scheme.with_limits`, `max_rounds`, `max_slots`, `max_bytes`, `Scheme.DEFAULT_MAX_ROUNDS`, `Scheme.DEFAULT_MAX_SLOTS`, `Scheme.DEFAULT_MAX_BYTES` | `max_rounds`, `max_slots`, `max_bytes` (whole numbers) | a new scheme with those limits (rounds and slots on unpack and pack, bytes on pack) | No | `ValueError` for a limit below 1 or not a whole number (§7) |
| `BinaryPacker.pack` | scheme, row | bytes | No | integer does not fit; `TypeError` for a float field given anything but an `int` or a `float`; `OverflowError` for a finite value too large for `f32`; `ValueError` for a `times` list longer or shorter than its count, for a `times` count above `max_rounds`, for a value given to a split flag bit that stays clear while its body would be written and for a `times` count of 0 with a list of values (loop 19), for a packet above `max_bytes`, a round that would pass `max_slots` and a `repeat` list above `max_rounds` (loop 20, AZ-2354, AZ-2355), and for a combined `flags` `times` whose count was skipped while values are given (loop 20, AZ-2360), `KeyError` `'missing field w'` for a required value with an empty list beside a longer one in a `repeat` (loop 20, review B1), `TypeError` for a lone byte buffer in a round (§7) |
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

### Interface: Error correction (loop 38, ADR-007, `contracts/library/message-ecc.md`)

Optional parity bytes per scheme: `n` from 0 to 32, default 0, which keeps the bytes, the errors and the speed of an unprotected scheme. `n` is not on the wire. C++ is pending (AZ-2688).

| Name | Meaning |
|------|---------|
| `Scheme.with_limits(..., parity=n)` | sets `n`; `parity` left out keeps this scheme's count (a limit left out is still the default). A value that is not a whole number of 0 to 32 raises `ValueError` naming `n` and 32 |
| `Scheme.parity` | the count |
| `BinaryPacker.unpack(data, *handlers, limit=t)` | repairs up to `t` wrong bytes (0 to `n / 2`, default 0); another `limit` raises `ValueError` before any byte is read |
| `UnpackResult.repaired` | the number of bytes repaired, 0 for an intact or unprotected message |
| `Uncorrectable()` | in `UnpackResult.error` when more bytes are wrong than `t` allows; names no field, `value` is `None` |
| `TooLong(length, limit)` | in `UnpackResult.error` for a buffer above 254 bytes. A buffer shorter than `n` is `ShortPacket(field="parity", needed=n, left=...)` |

- **Pack**: a clear message above `254 - n` bytes raises `ValueError` naming the length and the limit.
- **Dispatch**: all handlers of one `unpack` call declare the same `n`; a mix raises `ValueError` naming both counts. With one `n` the message is repaired first, then the type byte picks the handler.
- **Session**: `PackSession.pack` pads the clear message, then appends the parity of the padded bytes (payload = clear length + `n`). `PackSession.unpack(..., limit=t)` repairs, drops the parity, removes the pad, then reads. The receive index advances for every payload that passes the checks of the call, a refused one included; a bad `limit` or a mix raises before it moves. With `n` = 0 the payload has the length of clear pack.
- **`t` and detection**: `t` defaults to 0 and then any corruption of up to `n` wrong bytes is detected. A `t` above 0 repairs up to `t` wrong bytes but gives up detection: corruption of `t + 1` to `n - t` bytes is still refused, a larger corruption may be repaired to a different message. The contract table lists the chance (`n` = 4: 1 in 4.29e+09 at `t` = 0, 1 in 990,537 at `t` = 1, 1 in 485 at `t` = 2). `t` above `n / 2` is an error before any byte is read.
- **Size and speed**: a message is at most 254 bytes, parity included; pack refuses a clear message above `254 - n` bytes and writes nothing. Unpack of hostile bytes does at most 255 x 32 field operations beyond the unprotected walk and never throws or traps on them. Acceptance bound EC-13 (a bound, not a recorded measurement): 1,000 unpacks with correction of a 254-byte message with 16 parity bytes and 8 wrong bytes in 5 seconds in Python (the bound for this package); 1,000 packs of such blocks in 1 second.

## 4. Data Access Patterns

No queries and no cache.

**Seed data**: the shared golden hex file.

**Rollback**: yank the PyPI version.

## 5. Implementation Details

**State Management**: clear pack is stateless. A session keeps one send counter and one receive counter. Source layout (`python/src/packbin/`): `_nodes.py` the field builders and nodes (since AZ-2245 every accessor pair carries an `access` mark, `("attr", key)` or `("item", key)`, set by `_marked`; the identity has none; since AZ-2248 a `times` node holds its `optional` leaf ids, `_optional_leaves`), `_validate.py` the construction checks (`_validate_order` for ids, references and bool placement, `_validate_round_nesting`; new in loop 16, `_validate_order` moved out of `_nodes.py`; `_validate_names` for a name declared twice, AZ-2245; `_validate_element_accessors` for attribute accessors in element groups, AZ-2249; `Scheme.__init__` runs both last), `_flag_scope.py` the split flag bit check and numbering (`_bind_flag_bits`; new in loop 16, AZ-2230, it replaced `_validate_flag_bits` and `_check_flag_scopes` of `_validate.py`), `_pack.py` and `_unpack.py` the walkers, `_scheme.py` `Scheme`, `BinaryPacker` and the round limits (since loop 19 `BinaryPacker.pack` passes the scheme's `max_rounds` to `pack_nodes`; since loop 20 it builds a `_PackBudget` of `max_rounds`, `max_slots` and `max_bytes`). Loop 20: `_pack_limits.py` (81 lines, new: `_PackBudget`, `round_member`, `flags_member`) and `_pack_rounds.py` (91 lines, new: the round lists, `_at_round`, `_refuse_repeat_over_limit`), both moved or written out of `_pack.py` (447 lines), `_session.py` (`_exact_bytes` is the one check of a seed or nonce, shared by `load`, `start` and `join`, AZ-2244) and `_session_pad.py` the session, `_errors.py` the result types.

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
- Before loop 22 a `repeat` whose lists differ in length raised `ValueError` (`repeat fields must have equal lengths`; the rule is gone, see Loop 22 changes), where TypeScript, C# and Java let the longest list set the round count; a `times` list shorter than its count raises a `ValueError` that names the member since loop 19 (AZ-2336; `1: 1 items, times count is 2`, it was a bare `IndexError`) for a plain member or a member under `when`; for a member under `flags` or a flag bit a short or empty list means absent (AZ-2248), where `repeat` is unchanged: its lists still need equal lengths and an empty one raises a bare `IndexError`, while TypeScript and Java pack a lone value and a `when` list shorter than the longest (since loop 21 they, and C#, refuse a short list under `flags` in a `repeat`; the equal-length rule of Python stayed until loop 22 (AZ-2413))
- A `when`, `repeat` or `times` as a member of `flags`, as the field of a flag bit, or in a group under them is written since loop 18 (AZ-2120, AZ-2128; `_child_on` in `_pack.py`; see Flag members below). Left as decided: a `when` with a false condition drops a given body silently. A `times` whose count field was skipped and whose values are given raises `ValueError` since loop 19, in the combined `flags` form too (it dropped them; C#, TypeScript, Java and Rust still drop them, not decided). A split flag byte decides its `when` or `times` bit where the byte is read; since loop 19 (AZ-2331) pack raises when that leaves the bit clear while the body would be written (see Split bit with a dropped body). A short `times` list is a named `ValueError` for every member since loop 19 (AZ-2336)
- A `repeat` or `times` round starts with a fresh scope since loop 19 (AZ-2330, see Round scope), as TypeScript and C# do. `eq(intField, True)` is a construction error since loop 19 (AZ-2338; it matched 1 by `==`, review T8). A lone byte buffer for a `bytes` or `sized` name in a round raises `TypeError` since loop 19 (AZ-2332), as in the other packages. Pack caps a `times` count and a `repeat` list at `max_rounds`, charges `max_slots` per round and refuses a packet above `max_bytes` (loops 19 and 20). Unpack charges 8 more slots per name for the first round of each run (`_Budget.refuses`, `width * 9`) and pack does not, so a packet written at exactly `max_slots` is refused by Python's own unpack: align Python unpack or keep it is a loop 21 decision
- Python accepts an `IntEnum` member in a `u2`, `bits` or `packed` slot (an `int` subclass) and refuses every fraction and the whole floats `3.0` and `1.0` there; C# and Java refuse enums, a Rust enum is not a value; a TypeScript numeric enum is a number as well; a plain `enum.Enum` is refused here naming the field (AZ-2359, pinned by `test_loop20_parity_pins.py`)
- `PackSession(seed)` takes any 32-item sequence of byte values, so `PackSession([7] * 32)` builds a session; `load`, `start` and `join` are the strict entry points (bytes, bytearray or memoryview only). Open for the owner (AZ-2231, AZ-2244)
- A name is the accessor key, so `row.x` and `row["x"]` in one scheme count as different names and build (AZ-2245; the owner may want a match by key only); keys compare by `==` (`r[0]` and `r[False]` clash); two declarations inside one `when` body build, as in TypeScript. An identity accessor in a `list` or `dict` element group builds, fails at pack with `TypeError: 0: expected int, got dict` and loses the value on unpack (AZ-2249, owner option B would refuse it); an attribute accessor on the list itself (`lambda row: row.pts`) is allowed, a top-level `dict` row with attribute accessors or a class row with key accessors raises `AttributeError` on unpack
- A bit made by `.bit(...)` that the scheme does not place leaves its bit clear, with no error. A flag byte listed without all its bits was refused before AZ-2230 (`flag byte: bit 1 is not in the scheme`); the owner has not confirmed that the silence is wanted
- A float field takes only an `int` or a `float`: a numpy `float32` or integer is refused (a numpy `float64` is a `float`), and an `int` too large for `f64` (`10**400`) raises an unnamed `OverflowError`

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time bound set by the input length and, for rounds, a memory bound set by the scheme's round limits (below). It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In Python it is `ShortPacket(field, needed=0, left)` built by `_bad_value` in `_unpack.py`. A count error is labelled with the counted field's id, a `times` error with its anchor id, and a zero-width list or dict element or an invalid dictionary key with `""`. Session unpack removes the pad and then runs the same clear unpack.

**Round limits** (loop 16, owner decision after the review of AZ-2134; `_scheme.py`, `_unpack.py`). Before this, Python had no limit because it listed only the rounds that read a name (loop 15, AZ-2220). Since AZ-2134 every name a round can hold keeps one list entry per round, so memory grows with names times rounds and Python needs the same limits as C#, TypeScript, Java and Rust. A `Scheme` carries `max_rounds` (default `Scheme.DEFAULT_MAX_ROUNDS`, 65,535) and `max_slots` (default `Scheme.DEFAULT_MAX_SLOTS`, 1,048,576 since loop 22, 4,194,304 before), read through `scheme.max_rounds` and `scheme.max_slots`. `scheme.with_limits(max_rounds=..., max_slots=...)` returns a copy of the scheme with the new limits and the same fields; an omitted argument is the default, not the receiver's value, so give both in one call. A value below 1, a `bool` or anything that is not an `int` raises `ValueError`; there is no unlimited value. `BinaryPacker._unpack_fields` builds a `_Budget` for the call and `unpack_nodes` passes it to every `repeat`, `times`, `list` and `dict`. `_Budget.refuses(started, width)` runs as each round starts, before the round is read: `width` is `node.width`, the number of distinct names of the body (`_round_width` in `_nodes.py`, since loop 21, AZ-2381: the same rule as TypeScript and as pack; a `u2` counts each slot), and a round costs `width` slots. Until loop 21 `width` was the number of value-holding nodes and the first round of a run cost `width * 9` (eight more per node for the list that holds the run's entries), so a packet that pack wrote at exactly `max_slots` was refused by Python's own unpack; that charge is gone. The round that would be the 65,536th of one field, or would take the slot total past `max_slots`, returns `ShortPacket(field=<anchor id>, needed=0, left=<bytes left>)` (the interim bad-value error): no row, no handler call. A `times` count is not refused up front. Memory at the defaults (Python 3.14, macOS arm64, resident set above the idle interpreter), 1 MiB packet of one-byte rounds, a `repeat` with a 36-name `when` body: refused at round 65,536 after about 39 MiB in 0.27 s (about 390 MiB unlimited); the same body in 65,535 `list` elements is refused after about 53 MiB in 0.3 s.

**Construction rule** (loop 16, AZ-2100, AZ-2230; `_bind_flag_bits` in `_flag_scope.py`, called by `Scheme(...)`): a split-form flag bit must follow its flag byte, read earlier in the same scope. A scope is the top level, one `repeat` or `times` round, or one `list` or `dict` element. A `when` body, a `flags` member and a flag bit see the flag bytes read before them but leave theirs behind. A violation is a `ValueError` (`flag bit 0: its flag byte is not read earlier in the same scope`). A flag byte takes no field id: each bit takes the id where it stands. `flag_byte()` and `.bit(...)` build in a `Scheme`, unpack reads a bit's field like any other field, and a `bool` under a bit round-trips.

**Bit numbers** (loop 16, AZ-2230; `_flag_scope.py`). Each read of a flag byte becomes a `_FlagByte` of its own in the scheme's copy of the fields (`Scheme._fields` holds the bound nodes, not the caller's), and each bit is numbered by its place among the bits that follow that read: bit 0 is the first, as in the combined form and in TypeScript, Java, Rust and C++, and a bit nested in another bit's field comes after the outer one. The `flag_byte()` handle and the bits `.bit(...)` returns hold no number (index -1), so a handle can be shared by any number of schemes and be read more than once: `[m, m.bit(a), m, m.bit(b)]` with only `b` set packs `01 00 01 09`; a bit made early and placed late takes its place (`[m, mid, early, late]`, only `late` set: `01 02 01 09`). The ninth bit of one read raises `ValueError` (`flags already has 8 bits`) when the `Scheme` is built, not when `.bit(...)` is called. A bit the scheme does not place has no number and stays clear (see §7).

**Reference scope** (loop 16, AZ-2113; `_validate_order`). Every `eq` field id, and the count id of `sized`, `bits`, `packed` and `times`, must name a value field declared earlier in the same scope: the top level, a `repeat` or `times` body, or a `list` or `dict` element (ids restart at 0 in an element). `flags`, flag bits, `when` and `group` share the scope around them; a Python `group` has no scope of its own. A later field, an id that does not exist, an outer field from inside a body and a field inside an earlier body are a `ValueError` (`when 1: eq names field id 2 is allowed only if declared earlier in the same scope`, `sized 0: count field id 5 is allowed only if declared earlier in the same scope`). Since loop 18 (AZ-2126) a count must name an integer field or a `u2` slot (`sized 1: count names field 0, which is a utf8; a count names an integer ...`), and `eq` must name an integer field, a `u2` slot or a bool: `eq` against a bool with anything but `True` is a `ValueError` (`when 1: eq tests bool field 0 against False; a bool is compared only with true`), and a float, utf8, bytes, sized, bits or packed source is a `ValueError` (`eq names field 0, which is a utf8; a when names an integer or a bool field`). The error text shows a value only for a plain scalar and the type name for anything else (`_shown` in `_validate.py`), so an arbitrary `__repr__` never runs.

**Rounds** (loop 16, AZ-2134; `_unpack.py`, `_pack.py`, `_validate.py`). Every node of a `repeat` or `times` body that holds a value (`leaves`, found once at construction through `flags`, `when`, groups, flag bits and `u2` slots by `_round_leaves` in `_nodes.py`) gets one list for the run, with one entry per round and `None` where the round skipped it (`_align_lists`). The lists are stored on the row when the run ends (`_store_lists`), so a default the row class carries, a number or a list its class shares, is never part of them (before, a class-level list was appended to in place). Two nodes that bind one member, the arms of two `when`s, share one list. Pack reads the lists by round index (`_at_round`), so `flags`, `when` and groups inside a round pack, and a `bool` under `flags` inside a `times` reads its own round. A `repeat` takes its round count from its lists, which must be equally long. A `times` list longer than the count raises `ValueError` before any round is written (`_check_round_lists`: `1: 3 items, times count is 2`), for every kind of member, `bool` and `u2` included. A `repeat` or `times` inside a `repeat` or `times` round, directly or under `when`, `flags`, a flag bit or a group, raises `ValueError` at construction (`_validate_round_nesting`: `repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times`); a `list` or `dict` element starts outside any round, so a round inside an element of a round is allowed.

**Member names** (loop 16, AZ-2245; `_validate_names`, `_declare_name`, `_marked`). A row holds one value per accessor name, so a name declared twice in one scope loses a value: `u8 x` twice unpacked `01 07 08` to `{x: 8}` and packed that as `01 08 08`; `u8 x` beside a `times` holding `u8 x` unpacked to `{x: [7, 8]}` and could not be packed again. `Scheme(...)` raises `ValueError` (`member x: declared twice in one scope; a row holds one value per name, so one would be lost`, the accessor key named) for the same name twice at one level, outside and inside a `times` or `repeat` round, in two rounds, under `flags`, in a group or a flag bit, for every kind of field including a `u2` slot, `be()` and a `list` or `dict` accessor. The scope is the top level or one `list` or `dict` element (an element may reuse a row's names); `repeat`, `times`, `flags`, `when`, `group` and a flag bit share the scope around them, and a flag byte holds no name. A declaration under a `when` is not counted, so the branches of a chain may share a member. The check runs after every earlier one, so the older messages keep winning, and before the element accessor check. `_pair` marks both closures of an accessor with `(kind, key)`; `be()`, flag bits and `with_limits` reuse the closures, so the mark survives.

**Element accessors** (loop 16, AZ-2249; `_validate_element_accessors`). A `list` or `dict` element that is not a leaf is unpacked into a plain `dict`, so a member that reads and writes an attribute (`lambda p: p.x`) could pack objects but never unpack a value (`AttributeError` out of `BinaryPacker.unpack` on a valid packet). `Scheme(...)` raises `ValueError` (`list element: field 0 uses the attribute accessor 'x'; an element row is a dict, so use a key accessor, row['x']`; `dict element:` for a dict; `a nested list` or `a nested dict` for a container member) for such a member at any depth of the element: in a group, `flags`, `u2`, a `when`, `times` or `repeat` body, a flag bit or a nested container. Key accessors, a leaf element, an inner container that is itself an element (its own accessor is never called) and the identity accessor are unchanged. A scheme whose element members are all optional is refused too, by scheme and not by value.

**Short `times` lists** (loop 16, AZ-2248; `_optional_leaves` in `_nodes.py`, `_at_round` in `_pack.py`, bound again in `_flag_scope.py`). The ids of the leaves of a `times` body that a flag bit can leave absent (reached through `flags` or a flag bit, also through `when` and groups below them) are computed once at construction. `_at_round(row, i, optional)` returns `None` past the end of a list only for those leaves, so `{"c": 2, "on": [True]}` packs `01 02 01 00` and `{"c": 2, "v": [5]}` packs `01 02 01 05 00`, as in TypeScript and Java. A set `u2` or group that lacks a sibling still fails (`ValueError: 2: expected 2-bit int`, `TypeError: 2: expected int, got NoneType`); a plain member and a member under `when` keep `IndexError`; a longer list is still refused; unpack returns full lists with `None` and `repeat` is untouched.

**Float pack** (loop 16, AZ-2192; `_require_int` and `_write_scalar` in `_pack.py`). An `f32` or `f64` field takes only an `int` or a `float`. A `bool`, string, bytes, `Decimal` or `Fraction` raises `TypeError` naming the field (`0: expected number, got str`; a `bool` used to pack as 1.0 and a string raised an unnamed `ValueError`), and a finite value too large for `f32` raises `OverflowError` (`0: 1e+39 does not fit in f32`). `nan` and the infinities are written as given.

**Star import** (loop 16, AZ-2104; `__init__.py`). `__all__` leaves out `bool`, `bytes`, `dict` and `list`, so `from packbin import *` no longer replaces the builtins with field builders; they stay importable by name (`from packbin import dict as map_field`). `PackSession(seed)` raises `ValueError` unless the seed is 32 bytes.

**Bool rule** (loop 12, `_validate_order` in `_validate.py` since loop 16): a `bool` stands only as a direct child of `flags(...)` or as the field of a flag-byte bit. Anywhere else (top level, inside any `group`, also one under `flags`, inside `when`, `repeat` or `times`, or as a `list` or `dict` element) `Scheme(...)` raises `ValueError` naming its id. A `group(anchor)` with no fields has no accessor, so it can never carry `true`; `Scheme(...)` refuses it wherever it stands, inside `flags` too. `flags(...)` with a ninth child raises `ValueError` naming the anchor when it is declared. The bit is set only for `True`; `False`, a missing value and any other value (`1`, `"yes"`) leave it clear, and unpack gives `True` only when the bit is set.

**Pack output budget** (loop 20, AZ-2354, AZ-2355; `_pack_limits.py`, `_pack_rounds.py`, `_pack.py`, `_scheme.py`). A `Scheme` carries `max_bytes` (default `Scheme.DEFAULT_MAX_BYTES`, 16 777 216, type byte included), read through `scheme.max_bytes`; `with_limits(max_rounds=..., max_slots=..., max_bytes=...)` returns a copy and an omitted argument is the default. A limit that is not a positive whole number raises `ValueError`. `BinaryPacker.pack` builds a `_PackBudget` and every write goes through it before the bytes are appended: `ValueError` `s: the packet would be 16777477 bytes, above the limit of 16777216 bytes`. Slots are charged as each round starts with the width unpack charges (without its surcharge), one counter per pack call (`k: the rounds would hold 1048580 slots, above the limit of 1048576 slots`), before the round's bytes. `_refuse_repeat_over_limit` refuses the first list of a `repeat` above `max_rounds` before any round (`k: the repeat count is 65536, above the limit of 65535 rounds`); the `times` cap now has the reference text too (`x: the times count is 65536, above the limit of 65535 rounds`, was `times 1: 65536 rounds, the limit is 65535`). AC-1 (a 65 535-character `utf8` under a `times` of 65 535): about 7.3 GB before (spec figure); the first message above in 4 ms and 42.8 MB RSS after. The suite is about 20 s slower (25.7 s). Tests: `test_pack_output_budget.py`, `test_pack_repeat_round_cap.py`.

**Parity pins and fixes** (loop 20, AZ-2356, AZ-2359, AZ-2360, AZ-2362 and review B1, B3; `_pack_rounds.py`, `_pack.py`). A split `times` count of 0 written after the byte now packs a lone scalar as `01 00 00` (it was refused) and still refuses a list. A combined `flags` `times` whose count was skipped, given values, raises `ValueError` naming the first held member (`pt: a value is given, but the count of its times is not written, so its bit is clear; write the count before the times`; it named `times 1`). A `repeat` with an empty list as a `flags` member leaves the bit clear instead of a bare `IndexError` (`repeat { u8 w; flags { u8 v } }` with `w` = [1, 2], `v` = [] packs `01 01 00 02 00`), and a required value with an empty list beside a longer one raises `KeyError` `'missing field w'`; every list empty still packs no rounds. An `IntEnum` packs as its integer, a plain `Enum` is refused. Tests: `test_loop20_parity_pins.py`, `test_split_form_pack_fails_loudly.py`.

**Breaking changes for callers** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.
- A `bool` outside `flags` (its value never reached the wire) and a `group(anchor)` with no fields now fail at construction (loop 12).
- A ninth `flags` child now fails at `flags(...)`, instead of at pack only when its value was present (loop 12).

**Round scope** (loop 19, AZ-2330; `unpack_nodes` in `_unpack.py`, `pack_nodes` in `_pack.py`). Each round of a `repeat` or `times` is packed and unpacked with an empty `seen` (`{}`), where the round reused the scope around it: a `when` in a later round could see a value that an earlier round skipped. `u8 a; times(a, u8 k, when(k == 1, u8 v), when(v == 5, u8 w))` with `a` = 2, `k` = [1, 0], `v` = [5] and `w` = [7] packs `010201050700` like TypeScript (Python raised `TypeError`: the shared scope matched `v == 5` in round 2). The bytes and the unpacked row change for a round whose `when` names a value an earlier round skipped. Tests: `test_round_fresh_scope.py`.

**Pack round cap** (loop 19, AZ-2329; `pack_nodes(..., max_rounds=)` in `_pack.py`, `BinaryPacker.pack` in `_scheme.py`). A `times` count above the scheme's `max_rounds` raises `ValueError` before any round is written (`times 1: 65536 rounds, the limit is 65535`; 4 000 000 000 behaves the same), also in a round, a group, `flags` and a list or dict element. `with_limits(max_rounds=70_000)` packs 70 000 rounds. Tests: `test_pack_round_count_cap.py`.

**Split bit with a dropped body** (loop 19, AZ-2331; `_unwritten_sources`, `_refuse_late_body` and `_times_on` in `_pack.py`). For a split flag bit that comes out clear, `_refuse_late_body` re-checks every `when` under the bit whose source had no value at the byte (`_unwritten_sources`, all of them since review B5): when the source is written later and its value now matches, and `_child_on` says the bit would be on, pack raises `ValueError` (`when 1: a body value is given, but condition field 0 is written after the flag byte that decides this bit`). A false condition stays silent. `_times_on` raises when values are given and the count was skipped or is written after the byte (`times 1: body values are given, but count field 0 has no value (it was skipped, or is written after the flag byte that decides this bit)`), in the combined `flags` form too, and for a count of 0 with a list of values. Tests: `test_split_form_pack_fails_loudly.py`.

**`Eq` value check** (loop 19, AZ-2338; `_require_eq_value` in `_validate.py`). An `eq` on an integer source (`u8` to `i64`, a `u2` slot as 0..3) must hold an `int` that is not a `bool` and lies in the source's range, else `ValueError` at construction (`when 1: eq tests u8 field 0 against 300, which is outside 0..255`). `5.0` is refused (Python refuses whole floats), `0`, `5` and `255` build. Tests: `test_eq_value_checked.py`; `test_bool_placement.py` and `test_flags_round_member.py` changed.

**Lone buffers and count 0** (loop 19, AZ-2332, AZ-2335). A lone `bytes`, `bytearray` or `memoryview` for a `bytes` or `sized` name in a `times`, `sized` or `repeat` round raises `TypeError` naming the member; a list with one buffer per round packs. A `times` count of 0 with a list of values raises `ValueError`; a lone scalar with count 0 packs `0100` (also inside `flags`). Tests: `test_lone_bytes_in_round_refused.py`, `test_times_count_zero_with_values.py`, `test_times_longer_list.py` and `test_times_short_list.py` changed.

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
- Unpack refuses a packet whose `repeat` or `times` starts more than 65,535 rounds, or whose rounds hold more than 1,048,576 slots together (4,194,304 before loop 22), until the scheme raises the limits with `with_limits`.
- Split-form flag bits are numbered by their place in the scheme (AZ-2230), as in TypeScript, Java, Rust and C++: a handle shared by two schemes no longer fails the one that places only some of its bits, a bit made early and placed late takes its place, and a second read of a flag byte starts its own bits (`01 00 01 09` above; the bit number followed the `.bit(...)` calls before). The ninth bit of one read raises when the scheme is built. A flag byte listed with a bit the scheme leaves out builds (it raised `flag byte: bit 1 is not in the scheme`).

**Flag members** (loop 18, AZ-2120 and AZ-2128; `_child_on`, `_times_on` in `_pack.py`). Pack decides each member of `flags` in order against `seen`, the values written so far in the scope: a `when` is on when its condition holds and its body has a value, a `times` when its count is above 0 (a skipped count is no round; a count of 0 with a non-empty list raises `ValueError` naming the value), a `repeat` when a round has a value, and a group counts the same three. `u8 mode; flags(when(eq(0, 1), u8 speed), u16 heading)` with `mode` = 1, `speed` = 7 and `heading` = 90 packs `01 01 03 07 5a 00` (it packed `01 01 02 5a 00`). A set bit that cannot be written in full raises `ValueError` and names the value. A lone dictionary for a `dict` name in a `repeat` or `times` round raises `TypeError` naming the member, also with a `times` count of 0 (it was broadcast under `times`, read as one round or a `ValueError` for unequal lengths under `repeat`); a list with one dictionary per round packs as before.

**Breaking changes for callers, loop 18** (golden and route bytes are unchanged; unpack of older packets is unchanged):
- Construction: `eq` of a bool with anything but `True`, a `when` on a float, utf8, bytes, sized, bits or packed field, and a count on a non-integer field raise `ValueError` when the scheme is built (Python took any value field for `eq` and did not check the kind of a count).
- Pack: a `when`, `repeat` or `times` as a member of `flags`, of a flag bit, or in a group under them is written and sets its bit (`01 01 02 5a 00` to `01 01 03 07 5a 00` for the pinned shape); a `times` count of 0 with a non-empty list raises `ValueError`; a row unpacked from an old packet (bit clear, count above 0) no longer repacks.
- Pack: a lone dictionary for a `dict` name in a round raises `TypeError`.

**Breaking changes for callers, loop 19** (golden and route bytes are unchanged; unpack of older packets is unchanged except the round scope below):
- Rounds: a `when` in a `repeat` or `times` round no longer sees a value that an earlier round skipped, in pack and in unpack; the bytes of such a scheme change.
- Pack: a `times` count above `max_rounds` raises `ValueError` (65 536 rounds were written before); a split flag bit that would drop its body raises `ValueError`; a `times` count of 0 with a list raises; a skipped count with values raises in `flags` too; a lone byte buffer in a round raises `TypeError` (it was broadcast).
- Pack: a `times` list shorter than the count is a `ValueError` that names the member (`IndexError` before), for a plain member and a member under `when`.
- Construction: an `eq` value that its integer source can never hold raises `ValueError` (a `bool`, a float including `5.0`, a number out of range, a string, `None`, a list).

**Breaking changes for callers, loop 20** (golden and route bytes are unchanged; unpack of older packets is unchanged; bytes of every row that still packs are unchanged; 846 tests):
- Pack: a packet above `max_bytes` (16 MiB by default), a round that would pass `max_slots` and a `repeat` list above `max_rounds` raise `ValueError`.
- Pack: a combined `flags` `times` whose count was skipped, given values, raises (it packed `01 00`); the message names the member.
- Pack: a split `times` count of 0 after the byte with a lone scalar packs `01 00 00` (it raised).
- Pack: the `times` cap message changed to `x: the times count is 65536, above the limit of 65535 rounds`; test for the failure, not the text.

**Loop 21 changes** (AZ-2381, AZ-2382, AZ-2383, AZ-2386, AZ-2387, AZ-2390, AZ-2392; golden and route bytes are unchanged; 1003 tests).
- Slot width (AZ-2381, AZ-2382; `_round_width` and `_finish_round` in `_nodes.py`, `_Budget.refuses` in `_unpack.py`, `_PackBudget.start_round` in `_pack_limits.py`): a round costs one slot per distinct name its body can hold, an empty group's name included and a name that two `when` arms both write counted once (`node.width`, computed once when the scheme is built); a node with no member access, such as the identity accessor, is a slot of its own. Pack and unpack charge `node.width` alike, so a packet written at exactly `max_slots` unpacks and the round after it is refused by both. The first-round surcharge of loop 16 (`LIST_SLOTS`) is removed. Memory per slot is one list entry of the round's list, so `max_slots` also bounds that memory; the figures in `README.md` were measured before this change and are not re-measured (review finding 2).
- Empty round body (AZ-2390; `_validate_round_bodies` in `_validate.py`, run by `Scheme.__init__`): `ValueError` `repeat 0: the body holds no member; a round of it would charge no slot and write nothing` at construction, looking through `when`, groups, flag bits and `list`/`dict` elements; a zero-width `bytes`, a flag byte and a member-less `flags` build. Test: `test_empty_round_body.py`.
- Short optional list (AZ-2383; `_refuse_short_optional` in `_pack_rounds.py`, `node.optional` set by `_finish_round`): a non-empty list under `flags` or a flag bit shorter than the rounds raises `ValueError` `v: 1 items, repeat count 2; give one entry per round, None where the member is absent`; `times` is unchanged. Python keeps its equal-length rule for every other `repeat` list. Test: `test_repeat_short_optional.py`.
- Count behind a clear `when` (AZ-2386; `_refuse_unwritten_count` in `_pack.py`, `_Times.count_source`, the node of the count): a `times` whose count the row holds above 0 while no field wrote it raises `ValueError` where the bit is found clear (split bit and combined `flags`); Python changed here, it packed a clear bit. A `bits`, `packed` or `sized` count behind a clear `when` raises `RuntimeError` (`2: count 1 is missing`) when a value is given; with no value it packs a clear bit (open row). A split-bit `times` with the count after the byte and no body packs a clear bit (AZ-2384, pinned). Test: `test_loop21_parity_probes.py`.
- Hostile loader (AZ-2392, AZ-2394): `hostile_refusals.py` names the exception type and the whole message each refused `pack` case and each `construct` case must give, and `hostile_loop21_support.py` builds the 15 new cases.

**Breaking changes for callers, loop 21** (golden and route bytes are unchanged; bytes of every row that still packs are unchanged):
- Unpack: a packet that the first-round surcharge refused now unpacks (a short run in each of many `list` elements, for example); more memory per packet is possible.
- Construction: a `repeat` or `times` with no member in its body raises `ValueError`.
- Pack: a short non-empty list under `flags` or a flag bit in a `repeat` raises (it packed `01 01 01 05 02 00`); a count above 0 that no field wrote, behind a clear `when`, in a split-bit or combined-`flags` `times` raises (it packed a clear bit).

**Potential race conditions**:
- None

**Performance bottlenecks**:
- The same AC-10 loop, on one core, in this language. Python's bound is 2 seconds.

**Loop 22 changes** (AZ-2410, AZ-2413, AZ-2415, AZ-2417, AZ-2418; golden and route bytes are unchanged; 1099 tests, 1003 at loop 21).
- No-value count (AZ-2410, U11; `_unwritten_sources` and `_refuse_unwritten_count` in `_pack.py`, `count_source` kept by `_Sized`, `_Bits`, `_Packed` in `_nodes.py` and set by `_validate.py`): a `bits`, `packed` or `sized` whose count the row holds above 0 (after the `packed` bias) and no field wrote, behind a clear `when`, with no value for the member, in a split bit or a combined `flags`, is refused (it packed a clear bit `01 00 00`); count 0, no count and a holding `when` pack as before. The `ValueError` reads `v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold`. Two schemes that share one counted node each keep their own count source: `_bind` in `_flag_scope.py` copies the leaf (review22 4, commit `1dceae6`; test `test_shared_count_node.py`). Test: `test_loop22_parity.py`.
- `repeat` lists of any length (AZ-2413, U14; the equal-length check is removed from the `repeat` path of `_pack.py`): the round count is the longest list, a lone value goes to every round, and a `when` list outside `flags` may be shorter (`repeat { u8 a; u8 b }` with `a = [1, 2]`, `b = 7` packs `0101070207`; `repeat { u8 k; when k == 1 { u8 v } }` with `k = [1, 2]`, `v = [9]` packs `01010902`, bytes as TypeScript). A required member whose list has run out is still refused naming it (`KeyError 'missing field b'`). Each round is still charged to `maxSlots` and `maxBytes`, and a list past `maxRounds` is refused before any round, so no input allocates more than the limits allow. A lone dictionary or `bytes` in a round is refused as before. Unpack of the new shapes gives one entry per round (`None` padding) and repacks to the same bytes. Tests: `test_loop22_parity.py`, `test_repeat_short_optional.py` (the two equal-length pins became `test_row30_a_lone_value_goes_to_every_round` and `test_row38_a_short_list_under_a_when_outside_flags_packs`), `test_round_lists.py`.
- Default `max_slots` (AZ-2415, U17; `DEFAULT_MAX_SLOTS` in `_unpack.py`, re-exported by `_scheme.py` and `_pack_limits.py`): 1 048 576, was 4 194 304. F10 packet at the default: 162 MB peak, 550 MB before. Tests: `test_round_limits.py`, `test_loop22_parity.py::test_az2415_ac2_*`, `test_pack_output_budget.py`.
- Hostile loaders (AZ-2417, AZ-2418): `test_hostile_vectors.py` with `hostile_loop22_support.py` and `hostile_refusals.py` replays the ten new cases (65 in all); four tests build a wrong rule entry and expect the loader to fail naming the case. The `construct_empty_*when*` cases are refused by the scope rule before the empty-body rule; a separate test checks `Scheme` refuses them.

**Breaking changes for callers, loop 22** (golden and route bytes are unchanged; bytes of every row that still packs are unchanged):
- Pack: the no-value count row above raises `ValueError`. A `repeat` row with a lone value or a short `when` list that raised `ValueError` before now packs.
- Unpack: a packet whose rounds hold more than 1 048 576 slots is refused until `with_limits` raises `max_slots`; a round body wider than 16 names can no longer run 65 535 rounds at the default.

**Loop 23 changes** (AZ-2437, AZ-2435 and AZ-2436 tests; golden and route bytes are unchanged; bytes of every row that still packs are unchanged; 1476 tests, 1099 at loop 22).
- Short count list in a round (AZ-2437, found in the loop 23 batch; `_RoundValues.unwritten_count` in `_pack_rounds.py`, read by `count_of` into `_refuse_unwritten_count` and `_refuse_late_body` in `_pack.py`): in the U11 check a missing round entry reads as an absent count, so `times(n) { u8 mode; when(mode == 1) { u8 c }; flags { bits v (count c) } }` with `n = 2`, `mode = [1, 0]`, `c = [3]` packs `01020103000000` and the same body in a `repeat` packs `010103000000`, as TypeScript, Java and C# (loop 22 raised `ValueError: 2: 1 items, times count is 2` / `KeyError: missing field c`; the `times` row packed at `88c063f`, so this was a loop 22 regression). A round whose `when` holds still needs its entry. `_RoundValues.__call__` is the old `_at_round` closure line for line. Tests: `test_no_value_count_nested.py::test_az2437_*`.
- Raised `max_slots` (AZ-2435, G1, tests only): the F10 packet unpacks with `max_slots=4_194_304` to the rows at HEAD and packs back to the same packet; the default refuses it (`ShortPacket`, `left` 3 194 814). Test: `test_raised_max_slots.py` (4 to 6 s, no slow marker).
- U11 below the top level (AZ-2436, G3, tests only): six nested positions x three kinds x split bit and combined `flags`. Test: `test_no_value_count_nested.py`.
- Closed in loop 25 (AZ-2474, Low-1 A): a value given for a `bits`, `packed`, `sized` or `times` whose count no field wrote raises `ValueError` (`3: count 2 was not written`), the text TypeScript uses in its `RangeError`; `_borrowed` in `_pack_rounds.py` takes the count id and separates "not written" from a non-integer raw value; no wire change.

**Breaking changes for callers, loop 23**:
- None: the short count list rows above, which raised, now pack.

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

# Rust package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for a native node.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds.

**Upstream dependencies**: none inside the repo.

**Downstream consumers**: the caller's Rust program.

## 2. Internal Interfaces

### Interface: packbin

| Method | Input | Output | Async | Error Types |
|--------|-------|--------|-------|-------------|
| `Scheme` | type number, fields by order id | scheme | No | a gap, a repeated id, a bad anchor, a reference to an id not yet walked, a flag-bit reference to an id outside the enclosing `repeat` or `times` body, a `when` or a count (`sized`, `bits`, `packed`, `times`) that names a field its own scope did not declare earlier (outside the body, inside an earlier body, declared later or never declared, by name or by number), a flag bit whose flag byte is not read earlier in the same scope, a 9th member in one `flags` or a 9th bit in one flag-byte read, a bool (an empty `group`) not directly inside `flags` or under a flag bit, a `repeat` inside a `repeat` or `times` round, a `times` inside a `times` round, a `when` on a float, bytes, utf8, `sized`, `bits`, `packed`, `list` or `dict` source or with an `eq` value that is not an integer, or a `list` or `dict` element that is a group, flags, `when`, `repeat`, `times`, flag byte or bit, `sized`, `bits`, `packed` or a `u2` with several names (see §7). Construction failures are panics that name the field |
| `SchemeItem::times` | anchor, count id, `get` (`&T` to `&[E]`), `set` (`&mut T`, `Vec<E>`), element items on `E` | scheme item | No | the construction panics above, raised in `Scheme::new`; an element that holds a `times` or names an id outside the element |
| `MapScheme::with_limits`, `Scheme::with_limits`, `max_rounds()`, `max_slots()`, `DEFAULT_MAX_ROUNDS`, `DEFAULT_MAX_SLOTS` | `max_rounds`, `max_slots` (`usize`) | the scheme with those unpack limits | No | a panic naming the limit when either is 0 (§7) |
| `BinaryPacker::pack` | scheme, row | bytes | No | integer does not fit; `PackError::Type` naming the `times` when its count differs from its `Vec` length, or `<label>: item count out of range` for a `packed` or `times` count of 2^63 or more; `PackError::Missing` naming a required value of a set flags group |
| `BinaryPacker::unpack` | scheme, bytes | row or error | No | short packet, trailing bytes, type mismatch, a `repeat` or `times` round past the scheme's limits; never panics on bytes (see §7) |
| `BinaryPacker::unpack_with` | bytes, handlers | row or error | No | unknown leading byte |
| `pack` | `MapScheme`, values by field name | bytes | No | `PackError::Missing` for a written field with no value; `PackError::Type` for a value that does not fit, a bool value other than 0 or 1, a `"__repeat__"` or `"__times_<anchor>"` value that is not `Value::Groups`, a `times` whose rounds are not as many as its count, a list kept beside the rounds that disagrees with them, a non-empty list or a single value kept under a `times` member below a `flags` or `when` when no `"__times_<anchor>"` rounds are given, or a `packed` or `times` count of 2^63 or more; `PackError::Missing` also names a required value of a set flags group |
| `unpack` | `MapScheme`, bytes | values by field name, or error | No | `UnpackError::Type` (another type number), `Short` (also a `repeat` or `times` round past the scheme's limits), `Trailing`; never panics on bytes (see §7) |

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
| `load` | 32 bytes | a session, or nothing | No | length other than 32 creates 0 sessions |
| `start` / `start_with` | none, or 16 bytes | 16 bytes | No | a nonce length other than 16 opens 0 sessions |
| `join` | 16 bytes | the waiter | No | length other than 16 joins 0 sessions |
| `pack` | scheme, row | `Result<Vec<u8>, SessionPackError>`: a payload the same length as clear pack | No | `SessionPackError::NotOpen` before start or join (0 payloads); `SessionPackError::Pack(PackError)` when the row cannot be packed, with the same `PackError` as clear pack and no pad position used |
| `unpack` | payload, scheme | the row, or the clear-unpack error | No | — |

## 4. Data Access Patterns

No queries and no cache.

**Seed data**: the shared golden hex file.

**Rollback**: yank the crates.io version.

## 5. Implementation Details

**State Management**: clear pack is stateless. A session keeps one send counter and one receive counter. A `FlagByte` handle holds only its name: `MapScheme::new` gives each flag-byte read a slot and numbers its bits by field order, so one handle can build any number of schemes. The typed `Scheme` names what it generates, `__flags_N` for a `flags` and `__bound_N` for a bound `list`, `dict` or `list_u16` (loop 13), from one counter that every `times` element shares with the row, so two unnamed containers, or one in a `times` element, never get the same name. Before, the container constructors hard-coded `__list` and `__dict`, and a second bound list overwrote the first.

**Key Dependencies**:

| Library | Version | Purpose |
|---------|---------|---------|
| none | — | the runtime writes little-endian fields |

**Error Handling Strategy**:
- A short field returns an error and zero values
- Hostile bytes return `Err`, never a panic (§7)
- No retry

## 6. Extensions and Helpers

| Helper | Purpose | Used By |
|--------|---------|---------|
| golden fixture | the shared hex | this package and the other five |

## 7. Caveats & Edge Cases

**Known limitations**:
- The first release has no code generator
- A `list` or `dict` element must be one integer, float, bytes, utf8, list or dict, or a `u2` with one name; any composite element panics at construction instead of losing data (loop 13). The typed API still binds only those: `list_u16` keeps an `element_id` argument that must be 0 (C18)
- The typed API has no flag-byte, `repeat` or `u2` form and no generic `list` or `dict` binder (C18); a split flag byte or a `repeat` is built with the map API (`MapScheme`, `pack`, `unpack`) or a raw `SchemeItem::Field`. A raw `SchemeItem::Field(repeat/when/flags ...)` in a typed scheme packs nothing and drops on unpack
- Map API: a `times` or `when` (and a `repeat`) as a `flags` member or flag-bit field never sets its bit and is never written, with no error (`member_on` in `walk/pack.rs`). The owner holds it for the loop that lands the C# work, so the six packages are decided together (AZ-2128, AZ-2120)
- Map API: a hand-built `times` fed per-name lists only (no `"__times_<anchor>"` key) slices direct children only (`slice_times`), so a non-empty list or a single value kept under a member below a `flags`, `when` or a group below them is refused with a `PackError::Type` naming it (AZ-2189); an empty list still packs. A list longer than the count is refused with a `PackError::Type` before any round is written (`{"0": 2, "1": [1, 2, 3]}`: `times at id 1: '1' has 3 items, count is 2`; `check_longer` in `walk/times.rs`, loop 16, AZ-2237), as TypeScript, Python, Java and C# do; it checks the data members of the round (a direct field or the field of a flag bit), not the names of a `flags`, a flag byte or a `group`, and a longer list is reported before any item error. A `times` inside a `repeat` round stays allowed, where Java, C# and TypeScript refuse it (AZ-2127). A map scheme that reuses one member name in two `times` cannot repack unedited values (it fails loudly)
- A multi-name `u2` in a map `times` fed per-name lists is not sliced past its first slot (`slice_times`, `check_longer`): it fails with `PackError::Missing("2")`, as before loop 16 (open)
- Pack records each field it writes in a per-scope map (`Written` in `walk/pack.rs`), so a flat scheme packs about 1.5 times slower in release than before (12 `u8` fields, 300k packs: 89 ms, now 140 ms; a 60k-element list, 1.0 times). Skipping the record for a scheme with no `when` or count would remove it; not done (open, Low)
- Typed `times`: `PackSession::pack` of a row whose count and `Vec` length differ returns `Err(SessionPackError::Pack(PackError::Type(..)))` (AZ-2105). Unpack keeps one `Values` per round, about 300 to 500 MB of peak memory for 1 MB of one-byte rounds without a limit (the count is never pre-allocated); capped by the round limits since loop 15

**Hostile input** (loop 11). Unpack of untrusted bytes returns an error value and no row, within a time bound set by the input length and, for rounds, a memory bound set by the scheme's round limits (below). It does not throw and does not loop on input it cannot consume. The cases:
- a `repeat` round that reads 0 bytes ends the repeat; the bytes left come back as trailing bytes
- a `times` round, or a `list` or `dict` element, that reads 0 bytes is an error, even for a small count (a few bytes could otherwise ask for 65 535 empty items)
- a negative count, a count larger than the bytes left, invalid UTF-8 in a string or a dictionary key, and a count whose source field is absent (it sat behind a clear flag bit)

The error shape is interim: a short-packet-style value. Its kind, label, `needed` and `left` are decided under C15, so no new public error type was added. In Rust it is `UnpackError::Short` with `needed` 0. A zero-width `times` round is labelled `"times"`; the `repeat` case is `UnpackError::Trailing`. A `packed` count goes through checked arithmetic (`packed_layout` in `walk/unpack.rs`), so a count of 2^63 or more, or one that overflows a 32-bit `usize`, is an error, not a wrap. `walk/element.rs` reads one `list` or `dict` element and rejects a zero-width one.

**Construction rules** (`field/order.rs` for ids and scope, then `check_shape` in `field/shape.rs` for flag bits, bools and rounds, then `check_integrity` in `field/integrity.rs` for `when` and elements; `MapScheme::new` runs all three, also for the typed `Scheme::new`):
- a `when`, a `sized`, `bits`, `packed` or `times` count, or a flag bit may only name an id inside its own `repeat` or `times` body, because each round reads into its own values
- a `when` or a count (`sized`, `bits`, `packed`, `times`) must also name a field that its own scope declared earlier, by name as well as by numeric id (`declared_integer` in `field/integrity.rs`, loop 16, AZ-2117): a name outside the body, inside an earlier `repeat`, `times`, `list` or `dict` body, declared later or never declared is refused, and so is a numeric id whose slot carries a non-numeric name (it never matched). The panic names the owner and the field: `when at id 2 names field "1", which is not in the same scope (...)`, `times at id 2 names field ...`, `the count of "2" names field ...`
- a split-form flag bit binds to the latest read of its flag byte that it can see, earlier in the same scope; a flag byte read inside a `when`, a `flags` member or a flag bit is not visible after it, and one outside a `repeat`, `times`, `list` or `dict` body is not visible inside
- a bit's position is its order among the bits of that read, not the order of `bit()` calls; a second read of the same flag byte starts its own bits (as C++)
- one `flags` holds at most 8 members and one flag-byte read at most 8 bits (a bit inside a `when` counts against the same read); the 9th panics naming that field
- a bool (an empty `group`, typed `BoundField::bool_flag`) stands only directly inside `flags` or under a flag bit; at the top level, inside `when`, `repeat`, `times`, a plain group (also one under `flags`) or as a `list` or `dict` element it panics naming its id
- no `repeat` inside a `repeat` or `times` round and no `times` inside a `times` round, at any depth (also through `when`, `group`, `flags` or a flag bit); a `times` inside a `repeat` round stays allowed, and a `list` or `dict` element starts outside any round
- a `when` tests an integer or bool field (an empty group counts) against an integer `eq` value; a float, bytes, utf8, `sized`, `bits`, `packed`, `list` or `dict` source, or a float, text or other non-integer `eq`, panics naming the `when` (a `when` on a utf8, bytes or f32 source with a same-type `eq` built before). The check applies to a tested name that scope declared before the `when`
- a `list` or `dict` element is one integer, float, bytes, utf8, list or dict, or a `u2` with one name; the walker keeps one value per element, so a group, flags, `when`, `repeat`, `times`, flag byte or bit, `sized`, `bits`, `packed` or a `u2` with several names would lose values, and panics naming the owner and the element

**Round limits** (loop 15, AZ-2219; `field/map_scheme.rs`, `scheme/mod.rs`, `walk/unpack.rs`). A scheme carries `max_rounds` (default `DEFAULT_MAX_ROUNDS`, 65,535, exported at the crate root) and `max_slots` (default `DEFAULT_MAX_SLOTS`, 4,194,304). `MapScheme::with_limits(self, max_rounds, max_slots)` and `Scheme<T>::with_limits` (which delegates to its layout) take the scheme and return it with the new limits (clone first to keep the original); `max_rounds()` and `max_slots()` read them. A zero limit panics naming it, unlike the typed errors of C#, TypeScript and Java; `usize::MAX` is valid and lifts the default. `repeat` and `times` store `slots`, the count of the names a round can hold (`count_fields`: value fields, `flags` and group names, the names of nested `when`, `repeat` and `times` bodies), computed once at construction. The per-call `Cursor` carries the limits and a slot counter, and `start_round(field, started, slots)` runs as each round starts, before its `Values` is built. The round that would be the 65,536th of one field, or would take the slot total past `max_slots`, returns `UnpackError::Short` with the field `"repeat"` or `"times"` and `needed` 0; no new error variant. Rounds of a `times` inside a `repeat` count their own `max_rounds` afresh per walk and add to the shared slot total. A typed `Scheme` refuses the same way and its handler is not called. A `times` count is not refused up front.

**Bool** (loop 12): the bit is set only for true (typed `Some(true)`, map value `1`); `0` or no value leaves it clear, and a map value other than 0 or 1 fails pack with `PackError::Type`. A set bit unpacks as `Value::U8(1)` (typed `Some(true)`), under `flags` and under a flag-byte bit alike; a clear one is absent (`None`).

**Flag group presence** (loop 16, AZ-2128; `group_on`, `any_member_on` and `member_on` in `walk/flag_bits.rs`, which also holds `collect_flag_bits`, moved out of `walk/pack.rs` in AZ-2237). A group under `flags` or a flag bit is on when its own name has a value, or any value inside it, at any depth, is present: an integer, float, bytes, utf8, list, dict, `sized`, `bits`, `packed`, a `u2` name, a nested group or a nested `flags` (its own name or any member). A flag byte inside is skipped (its value comes from its bits), and a `when`, `repeat` or `times` does not count (held, see §7). A group whose bit is on is written in full, so a required value that is missing fails pack with `PackError::Missing` naming it.

**Written values** (loop 16, AZ-2237; `walk/pack.rs`). Pack decides every `when` and takes every count from what it wrote in the same scope, as unpack does from what it read (map form and typed `Scheme<T>`). `Written` holds the fields written in one scope (the top level, one round of a `repeat` or `times`, one `list` or `dict` element; a list or dict element uses `Written::unread()`, which stores nothing, because elements cannot hold a `when` or count). A field behind an untaken `when` or a clear bit is not written, so a `when` on it does not match and a count that names it returns `PackError::Missing` naming the count's field. A `flags` byte or flag byte is recorded as the byte pack wrote, and a set bool as `1`, so a `when` or count that names one does not read a value kept in the row. A `times` leaves one list under each name its rounds wrote in the scope around it (`RoundLists`; a name written twice in one round keeps the later value, as unpack builds it), so a `when` or count on such a name finds a list; a `repeat` does not. A map `times` without rounds checks first that no list is longer than the count (`check_longer` in `walk/times.rs`).

**Session pack** (loop 16, AZ-2105; `session/mod.rs`). `SessionPackError { NotOpen, Pack(PackError) }` is exported at the crate root. `PackSession::pack` returns `Err(NotOpen)` before `start` or `join` and `Err(Pack(e))` with the error of `BinaryPacker::pack`, and the send counter moves only when the pack succeeds, so a failed pack leaves the next payload readable by the waiter.

**Checked count** (loop 16, AZ-2118; `borrowed_count` in `walk/pack.rs`). The count of a `packed` field or a `times` goes through `i64::try_from` and `checked_add`: a count that does not fit (2^63 or more) or whose bias overflows returns `PackError::Type("<label>: item count out of range")` in debug and release; a negative result keeps `<label>: item count N`.

**Typed `times`** (loop 13, `scheme/times.rs`). `SchemeItem::times(anchor, count_id, get, set, members)` binds a `Vec<E>` with `E: Default + 'static`: `get` lends `&[E]`, `set` takes the `Vec<E>`, and `members` are items on `E`, numbered from `anchor` on like the items of a `when`. A reference among them names an id of the same element. It replaces the three-argument form and the `SchemeItem::Times` struct variant. The element items compile lazily, inside `Scheme::new`, with the scheme's name counter, so an element panic fires there and no element reuses a generated name. The rounds travel as `Value::Groups` under `"__times_<anchor>"`, built by `read_values` and read back by `build_row` in `scheme/mod.rs`. Pack fails with `PackError::Type` (`times at id N: count C, R rounds`) when the count differs from the `Vec` length. Unpack makes one `E::default()` per round and sets the `Vec`, also for count 0 (it replaces a non-empty default). A `times` inside a `times` element is refused at construction. The README times and route vectors pack the same bytes as the other five packages.

**Integer `when`** (loop 13, `value.rs`). `when_matches` takes the members when `eq` and the source are integers of the same number, whatever their width or sign, so `Value::U16(1)` matches a `u8` source and a `u64` above `i64::MAX` matches by value. It replaced `values_eq`, which was true only for the same variant, so such a `when` never fired and dropped its group without an error. `same_value` (floats by bits, so NaN equals itself) compares the rounds with the lists beside them.

**Map `pack` / `unpack`** (public since loop 12, `walk/mod.rs`): values are keyed by field name. A `flags` byte or flag byte is computed from its fields on pack and returned under its own name on unpack as `Value::U8` of the byte read. `repeat` rounds are `Value::Groups` under `"__repeat__"` (no value packs no rounds). A `times` unpacks to one `Value::List` per name (an item for every round that read it) and also to its rounds as `Value::Groups` under `"__times_<anchor>"`, one `Values` per round, always present and empty for count 0 (`walk/times.rs`, `times_name` in `field/mod.rs`). Pack takes the Groups when the key is there: as many as the count, else `PackError::Type`, and a member under `flags`, `when` or a group stays in its round. Without the key each direct field takes a `Value::List` with one item per round (`slice_times`), and a non-empty list or a single value kept under a member below a `flags` or `when` is a `PackError::Type` naming it and the `"__times_<anchor>"` key to use (`check_aligned` in `walk/times.rs`, loop 16, AZ-2189; an empty list still packs, because it holds nothing to drop); a list longer than the count is a `PackError::Type` too (`check_longer`, AZ-2237, see §7). With both, a value kept for a name of the rounds (a non-list counts as a list of one item) must equal what the rounds hold, else `PackError::Type` (`times at id N: list for 'x' disagrees with its rounds`). To change a value after `unpack`, edit the rounds and drop or rewrite the lists, or edit the lists and drop the `"__times_<anchor>"` key (not for a member below a `flags` or `when`: edit its rounds); leaving both and changing one is an error. A flag bit inside a `when` that is not taken still sets its bit on pack; unpack checks the `when` first and never reads the field (`bitwhen` vector: `{k:0, v:5}` packs `010001`, `{k:1, v:5}` packs `01010105`).

**Breaking changes for callers** (pack output is unchanged):
- A flag byte read in one `when` with its bit in another `when` worked before. It is now refused at construction.
- A flag byte outside a `list`, `repeat` or `times` body with its bit inside that body is refused at construction.
- A `times`, `list` or `dict` element that reads nothing is now an error instead of an empty item.

**Breaking changes in loop 12** (bytes of valid schemes are unchanged except where noted):
- A `FlagByte` handle no longer counts bits across schemes, and a second read of a flag byte no longer shares the first read's bits. A handle reused for a second scheme used to shift that scheme's bits.
- A map bool value `0` now leaves its bit clear (it set it before); a bool value other than 0 or 1, or a `"__repeat__"` value that is not `Value::Groups` (before: no rounds), fails pack with `PackError::Type`.
- A bool or empty group outside `flags` or a flag bit (it packed nothing and came back missing), a 9th `flags` member or flag-byte bit (a shift panic in debug, an aliased bit in release), a `repeat` inside a `repeat` or `times` round and a `times` inside a `times` round now fail at construction.
- A bool under a flag-byte bit now unpacks as set (it was missing).

**Breaking changes in loop 13** (wire bytes of valid schemes are unchanged):
- `SchemeItem::times` has a new signature (above) and the `SchemeItem::Times` struct variant is gone. The old form shipped in `v0.2.1` and never worked past a count of 1. Its construction panics moved from the call to `Scheme::new`.
- A `when` on a utf8, bytes, f32 or other non-integer source, or with a non-integer `eq`, now panics at construction. A list or dict whose element is a group, flags, `when`, `repeat`, `times`, flag byte or bit, `sized`, `bits`, `packed` or a multi-name `u2` now panics at construction (it lost values or failed at run time).
- A `when` matches by integer value at any width (it needed the same variant); two or more bound lists, dicts or `list_u16` fields keep their own members (they overwrote each other).
- Map `unpack` of a `times` also returns `"__times_<anchor>"` Groups, and map `pack` with both the Groups and a list that disagrees fails with `PackError::Type`. Before, the lists were the only form.
- Unpack keeps one `Values` per `times` round, about eight times the memory it used (312 MB peak for 1 MB of one-byte rounds, 37 MB before).

**Breaking changes in loop 15** (AZ-2219; wire bytes and the result for a packet within the limits are unchanged):
- Unpack of a map scheme or a typed scheme refuses a packet whose `repeat` or `times` starts more than 65,535 rounds, or whose rounds hold more than 4,194,304 slots together, until the scheme raises the limits with `with_limits`. A refused 1 MiB packet peaks at 20 to 57 MB, against 0.3 to 1.2 GB before.

**Breaking changes in loop 16** (wire bytes of valid schemes and rows that packed before are unchanged except where noted):
- `PackSession::pack` returns `Result<Vec<u8>, SessionPackError>` instead of `Option<Vec<u8>>`; code that matched `Some` and `None` does not compile.
- A `when` or count naming a field outside its own scope, by name or by numeric id, now panics when the scheme is built (a name outside the body, inside an earlier body or never declared used to build and never fire).
- A `packed` or `times` count of 2^63 or more returns `PackError::Type("<label>: item count out of range")`; it reported a negative count (`item count -2`), and a debug build panicked at 2^63 with bias -1.
- A map `times` packed from per-name lists returns `PackError::Type` when a non-empty list or a single value is kept under a member below a `flags` or `when` (it was dropped); the empty list still packs.
- A flags group holding `u2`, `sized`, `bits`, `packed`, a nested group or a nested `flags` is on when any value inside is present and is written in full (its values were dropped, `0100`); a required value that is missing fails with `PackError::Missing`.
- Pack decides every `when` and takes every count from the fields it wrote in the same scope, as unpack does (AZ-2237). A `when` on a field that an earlier `when` or a clear flag bit skipped no longer matches (`u8 "0"; when(1, eq("0", 1), [u8 "1"]); when(2, eq("1", 4), [u8 "2"])` with `{"0": 0, "1": 4, "2": 9}` packed `010009`, now `0100`), `eq` of a bool against 0 on a clear bit does not write its body (it packed `010005`), and a count that names a skipped field returns `PackError::Missing(<count>)`. A `when` or count that names a `flags` byte or a split flag byte reads the byte pack wrote. After a `times` the names its rounds wrote are lists in the scope around it, so a `when` on one does not match.
- A map `times` without rounds returns `PackError::Type` (`times at id 1: '1' has 3 items, count is 2`) for a list longer than the count; it dropped the extra entries (`01020102`).

**Potential race conditions**:
- None

**Performance bottlenecks**:
- The same AC-10 loop, on one core, in this language

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

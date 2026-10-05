# Discovery scan — Rust and C++ packages

**Run**: `02-whole-project-assessment` (Quick Assessment, Phase 1, read-only)
**Tree**: `loop/10-cpp-microcontroller` @ `d108141`
**Scope**: `rust/Cargo.toml`, `rust/src/**` (incl. `*_tests.rs`), `rust/tests/**`; `cpp/include/packbin/**`, `cpp/src/**`, `cpp/tests/**`, `cpp/Makefile`, `cpp/CMakeLists.txt`, `cpp/library.json`, `cpp/idf_component.yml`, `cpp/arduino/**` (examples glanced; `cpp/embedded/` out of scope).
**Method**: file-by-file read of every scoped file; lizard 1.24 (`-C 10 -L 50`) on `rust/src` and `cpp/{include,src,tests}`; grep scans listed per inventory; behaviour probes run on copies outside the tree (Rust: in-crate `#[cfg(test)]` probes in a scratch copy of `rust/`, `cargo 1.79`, debug and `--release`; C++: one probe linked against `cpp/src/core/*.cpp` with `-fno-exceptions -fno-rtti`, Apple clang 21, outside `cpp/build`). No source file, build dir or tracker was touched.
**Component notes**: [`components/04_rust.md`](components/04_rust.md), [`components/05_cpp.md`](components/05_cpp.md).

Probe ids used below: Rust **R-P1…R-P12**, C++ **C-P1…C-P4**.

## (a) Smell table S01–S32

| ID | Smell | Result | Evidence | Change / deferral |
|----|-------|--------|----------|-------------------|
| S01 | Long method | found | Rust `walk/unpack.rs:93 unpack_one` 325 NLOC, `walk/pack.rs:154 pack_one` 212, `scheme/mod.rs:86 compile_items` 88, `field/order.rs:50 check_one` 71, `scheme/bound.rs:454 dict_list_dict_utf8` 60, `session/sha256.rs:18 compress` 55 (algorithm, code-ok); test `counted_tests.rs:192 dictionary_field` 241. C++: no function > 50 NLOC (largest `unpack_one` 49) | C10, C11; sha256 code-ok |
| S02 | Large file | found | `rust/src/scheme/bound.rs` **514** lines (> 500 cap); near cap: `field/mod.rs` 494, `walk/unpack.rs` 449, `counted_tests.rs` 443, `packbin_tests.rs` 430. C++ max `table.hpp` 367 | C11 (bound.rs); C10 (unpack.rs) |
| S03 | Long parameter list | found | Rust `unpack_fields/unpack_one(field, cur, values, flag_bits, groups)` — 4 walk-state params travel together through every recursive call; C++ `hkdf_sha256` 8 params (RFC shape, code-ok) | C10 (walk-state struct like C++ `Walk`) |
| S04 | Primitive obsession | found | Rust order ids are strings: `id_name(id)` → `"3"`, parsed back by `order.rs:24 parse_id`; field identity is `Rc<str>` in a `HashMap`; C++ uses `int16` ids | deferral (representation change too wide for a quick win); symptoms fixed by C3, C14 |
| S05 | Data clumps | found | Rust `(flag_bits, groups)` pair; `UnpackError::Short(ShortPacket{field, needed: 0, left})` built at 15 sites (`unpack.rs:191-409`, `session/mod.rs:79`) | C8, C10 |
| S06 | Duplicated code | found | Rust: 14 copies of `if let Value::X(x) = v { Some(*x) } else { None }` (`bound.rs:62-258`); 4 copies of the count lookup + error (`unpack.rs:190-304`); `Bits` ≡ `Packed` width 1 bias 0 (pack.rs:257-297, unpack.rs:218-286); `as_u2`/`as_bit` ≡ `as_packed(v, 3/1)` (`value.rs:174-231`); anchor/"not yet walked" checks in `compile_items` (`scheme/mod.rs:125-161`) repeat `order.rs` and run again in `MapScheme::new`; `parse_hex` in 6 test files. C++: `visit_integer`/`visit_number` (`values.hpp:21-98`) intentional (keeps FP code out of counts) | C10, C11, C15; C++ code-ok; test `parse_hex` deferral |
| S07 | Dead code | found | Rust public surface with no external use: `MapScheme` (no public pack/unpack since loop 4's `pack_map`/`unpack_map` were dropped), `Values`, `insert`, `motion_field_count`, `Value::Groups`; `BoundField::list_u16(…, element_id)` must be 0 (`scheme/mod.rs:102`); C++ `bind_small_numbers<M, T>` unused `T` (`fields_counted.hpp:37`) | C13; C++ trivial (fold into C16) |
| S08 | Speculative generality | found (NOTE) | Rust `FieldKey` for `String`/`u32`/`i32` (`field/mod.rs:219-245`; `i32` wraps negatives to `u32`), `list_u16` element-id parameter | C13 |
| S09 | Lazy class | found (NOTE) | `rust/src/walk/mod.rs` (13 lines, forwards only); C++ `validate()` returns the stored status (required by restrictions, keep) | deferral (harmless) |
| S10 | Data class | n/a | C++ `Field` is a POD table entry by design (flash table, walkers own behaviour); Rust `Value` is a value enum | — |
| S11 | Feature envy | not_found | `pack.rs:111 group_on` re-lists named kinds instead of `field_name` (minor, folded into C10) | — |
| S12 | Inappropriate intimacy | found | C++ public `packbin` namespace exports table internals: `Field`, `Kind`, `Node`, `Access`, `Item`, `Count`, `flag::*`, `check_table`, `put_num/get_num/...` (`table.hpp:12-153`, `order.hpp:186`); a user `struct Item` is ambiguous under `using namespace packbin` (C-P1 build error), and the README example uses that directive | C16 |
| S13 | Message chains | not_found | — | — |
| S14 | Middle man | found (NOTE) | `rust/src/walk/mod.rs` | same as S09 |
| S15 | Divergent change | found | `rust/src/value.rs` mixes the value model, number coercions, and test/report helpers (`to_hex`, `mismatched_bytes`, `motion_field_count`) | C13 |
| S16 | Shotgun surgery | found | Adding a field kind edits 6 Rust files / 7 `match FieldKind` sites and 6 C++ files; C++ test `session_host_tests.cpp ac3_no_os_in_core` hard-codes 6 header names (misses `fields_grouped.hpp`, `fields_counted.hpp`) | inherent to the table/walker design — deferral; C20 for the test list |
| S17 | Switch / type soup | found | Rust: 7 exhaustive matches over 19 `FieldKind`s (`count_fields`, `field_name`, `check_one`, `pack_one`, `unpack_one`, `collect_flag_bits`, `group_on`); C++: `Kind` switches in `pack_one`, `unpack_one`, `check_subtree`, `holds`, `present`, `visit_*` | closed kind set — keep the switch; C10 shrinks the Rust arms |
| S18 | Temporary field | found (NOTE) | C++ `Field::size` = bytes length / capacity / flag-byte number; `ref_id`/`ref` = when source / count source / flag byte; `eq`, `width`, `bias`, `bit` per kind (`table.hpp:120-144`) | code-ok (compact flash table, AC-5 budget) |
| S19 | Parallel inheritance | found | Rust map constructors `field::u8("n")…` vs `BoundField::u8(id, get, set)…` vs `Value` variants vs `IntKind`; the typed side lags the map side (no typed u2, group, flag byte, repeat, generic list/dict, 8 of 10 `opt_` scalars) | C11, C12 |
| S20 | Magic number / string | found | Rust `65535` ×4 (`pack.rs:313,325,342,350`), `"times"` ×3 (`pack.rs:301`, `unpack.rs:293,300`), `""` type field (`unpack.rs:424`), `expected: 0` for unknown type (`scheme/mod.rs:272`), `"u2"` (`unpack.rs:211`), reserved `"__repeat__"`, `"__flags_n"`, `"__list"`, `"__dict"`, `"__row"`; C++ `raw[16]` = 64 u2 children (`pack.cpp:155`), `SIZE_MAX`/`SIZE_MAX-1` sentinels (`pack.cpp:192,245`, `unpack.cpp:161-164,255`), `65535` ×4 | C2, C7, C8, C10, C13 |
| S21 | Hardcoded configuration | found (inventory) | 27 rows below; 1 `business` (domain field catalog in library), 1 `uncertain`, rest `code-ok`/`system` | C13, C7 (§ b) |
| S22 | String SQL | not_found | 0 hits (§ b) | — |
| S23 | Stringly-typed APIs | found | Rust `PackError::Type(String)` carries free text (`"int"`, `"float"`, `"times: item count -1"`); `UnpackError::Short.field: String`; order ids as strings (S04) | C8; id representation deferred |
| S24 | Mutable shared state | found (NOTE) | Rust `FlagByte { next_bit: Rc<RefCell<u8>> }` (`field/mod.rs:120-155`): bit numbers depend on call order of `.bit()` and keep counting when one handle builds a second scheme. C++: no mutable static state (grep) | C14 |
| S25 | Silent failure swallow | found | Rust `PackSession::pack` `BinaryPacker::pack(...).ok()?` (`session/mod.rs:65`) collapses `PackError` into "not open"; `bound.rs` `set` closures ignore a wrong `Value` variant (`:30-34`, list `filter_map`s `:372-449`) — this is how typed `times` silently drops data (R-P12); `fill_random` drops the I/O error (`session/mod.rs:117-120`, returns typed `false`, acceptable); C++ unbound `dict` skips the duplicate-key check (`unpack.cpp:145`) | C4, C9; C++ deferral (needs storage) |
| S26 | Circular dependency | not_found | Rust module graph acyclic; C++ include graph acyclic (`fields.hpp` includes `fields_grouped/counted.hpp` at the end, both include only `table.hpp`) | — |
| S27 | Framework leak | n/a | no framework | — |
| S28 | Secret in source | not_found | `grep -rniE "token|secret|password|api[_-]?key|BEGIN (RSA|EC|PRIVATE)"` over scope: 0; session seeds in tests are published vectors | — |
| S29 | Cognitive / cyclomatic complexity | found | Rust `pack_one` CCN 72, `unpack_one` 66, `compile_items` 15; C++ `pack_one` 23, `unpack_one` 22, `clear_scope` 18, `check_subtree` 14, `bind_element` 13, `item_count` 13, `holds` 12, `visit_number` 12 | C10 (Rust); C++ deferral (flat switch dispatch, already split in loop 10) |
| S30 | Shotgun resources | n/a | library; no upload dirs, caches or tunable limits besides protocol limits | — |
| S31 | Embedded HTML | not_found | 0 hits (§ b) | — |
| S32 | Hidden domain rule | found | Rust: a **numeric** field name is order-checked, any other name is not (`order.rs:24-34`); repeat groups ride in the reserved `"__repeat__"` key; `when` matches only when `eq`'s `Value` variant equals the field's (`value.rs:133-157`: `eq(3, Value::U16(1))` on a `u8` field never matches, no build error); flag bit = order of `.bit()` calls. C++: `boolean`/empty `group` outside `flags` always unpacks `true` (C-P2); flag-byte values kept per *number* in unpack but per *entry* in pack (C-P1); u2 ≤ 64 children only at run time; dict pack requires presorted keys (README says so, header comment says the opposite) | C1, C5, C6, C7, C14, C17, C21 |

Counts: **found 23** (S01–S09, S12, S14–S21, S23–S25, S29, S32; of them NOTE-level: S08, S09, S14, S18, S24), **not_found 6** (S11, S13, S22, S26, S28, S31), **n/a 3** (S10, S27, S30).

## (b) Inventories

### S21 — config-in-code

Scan: `grep -rnE "[0-9]{3,}|\"[a-z_/\.]+\"" rust/src rust/Cargo.toml cpp/include cpp/src cpp/Makefile cpp/CMakeLists.txt cpp/library.json cpp/idf_component.yml cpp/arduino` filtered by hand, plus a full read of every scoped file; publish-time rewrites checked in `.github/workflows/publish-inside.sh:50-56`, `publish-embedded.sh:21-34`, `stage-arduino.sh:15`.

| # | File | Line | Symbol / preview | Classification | Notes | Change / deferral |
|---|------|------|------------------|----------------|-------|-------------------|
| 1 | `rust/Cargo.toml` | 3 | `version = "0.1.0"` | system | rewritten from the tag by `publish-inside.sh` | code-ok |
| 2 | `rust/Cargo.toml` | 5-7 | `license`, `description`, `readme` | code-ok | package metadata; no `repository` key | C22 (add repository) |
| 3 | `rust/src/session/mod.rs` | 9-10 | `SEED_SIZE = 32`, `NONCE_SIZE = 16` | code-ok | pack-session contract | — |
| 4 | `rust/src/session/mod.rs` | 98 | `b"packbin"` HKDF info | code-ok | contract constant | — |
| 5 | `rust/src/session/mod.rs` | 117 | `"/dev/urandom"` | system | OS random source; no Windows source (`start_with` exists) | deferral (no AC for Windows) |
| 6 | `rust/src/session/{sha256,hkdf,pad}.rs` | sha256:1-12, hkdf:14-15, pad:18-21 | SHA-256 `K`, HMAC pads, ChaCha constants | code-ok | algorithm constants | — |
| 7 | `rust/src/field/mod.rs` | 201 | type number `0..=255` | code-ok | wire byte | — |
| 8 | `rust/src/walk/pack.rs` | 313, 325, 342, 350 | `65535` count limit | code-ok | strings-lists-dicts restriction; name it (S20) | C10 |
| 9 | `rust/src/value.rs` | 127 | `motion_field_count`: `["heading","speed","altitude","frequency"]` | **business** | application field names of one product record inside the library's public API; test-only use | C13 (move to tests) |
| 10 | `rust/src/walk/pack.rs` / `unpack.rs` | 223 / 446 | `"__repeat__"` | code-ok (hidden convention) | reserved key; collides with a user field of that name | C5 / C13 |
| 11 | `rust/src/scheme/mod.rs` | 142 | `"__flags_{n}"` | code-ok | internal name | — |
| 12 | `rust/src/scheme/bound.rs` | 365, 393, 418, 461-462 | `"__list_{id}"`, `"__list"`, `"__dict"`, `"__row"` | code-ok | internal names — cause of the collision bug | C3 |
| 13 | `rust/src/packbin_tests.rs` | 160, 168 | `100_000` iterations, `<= 1.0` s | code-ok | AC-10, test | — |
| 14 | `rust/src/packbin_tests.rs` / `cpp/tests/core/host_tests.cpp` | 259-273 / 78-87 | GPU library names list | code-ok | test-only | — |
| 15 | `cpp/library.json` | 3 | `"version": "0.1.0"` | system | rewritten by `publish-embedded.sh` | code-ok |
| 16 | `cpp/idf_component.yml` | 1, 7 | `version: "0.1.0"`, `idf: ">=5.1"` | system | version rewritten at publish; IDF floor = restrictions | code-ok |
| 17 | `cpp/arduino/library.properties` | 2-4 | `version=0.1.0`, author, maintainer | system | version rewritten by `stage-arduino.sh` | code-ok |
| 18 | `cpp/library.json` | 18 | `"flags": ["-std=gnu++17"]` | system | build flag | code-ok |
| 19 | `cpp/Makefile` | 2, 7, 15 | `CXXFLAGS`, `CORE_FLAGS`, `TEST_BIN := build/packbin_tests` | system | one `build/` for host and container toolchains | C19 |
| 20 | `cpp/CMakeLists.txt` | 23 | `option(PACKBIN_OS_RANDOM … ON)` | system | host adapter switch | code-ok |
| 21 | `cpp/include/packbin/session.hpp` / `src/core/session.cpp` | 21-22 / 10-22, 153-154 | `SeedSize`, `NonceSize`, `kInfo`, `kRound`, `0x36`/`0x5c` | code-ok | contract + algorithm | — |
| 22 | `cpp/include/packbin/table.hpp` | 70, 77, 85 | `N <= 65535` for `Text`/`Blob`/`Array` | code-ok | wire u16 count | — |
| 23 | `cpp/src/core/pack.cpp` | 104 | `len > 65535` | code-ok | wire u16 count | — |
| 24 | `cpp/src/core/pack.cpp` | 155 | `std::uint8_t raw[16]` → u2 ≤ 64 children | **uncertain** | undocumented limit, run-time `BadValue` | C7 (build-time check) |
| 25 | `cpp/include/packbin/codec.hpp` | 36, 76 | `255` (id report range, type number) | code-ok | wire byte | — |
| 26 | `cpp/include/packbin/fields_grouped.hpp` | 45, 54 | flag-byte number `0..7` | code-ok | design limit (8 slots) | — |
| 27 | `cpp/src/os_random.cpp` / `cpp/tests/core/check.hpp` | 37 / 23 | `"/dev/urandom"`, `kMaxSites = 1024` | system / code-ok | host fallback; test harness | — |

Totals: 27 rows — business 1, uncertain 1, system 10, code-ok 15. Escalate row 24 (`uncertain`) in the Phase 1 gate.

### S22 — string SQL

Scan: `grep -rniE "select |insert into|update [a-z_]+ set|delete from|execute\(|sqlite|postgres|\bsql\b" rust/src rust/tests rust/Cargo.toml cpp/include cpp/src cpp/tests cpp/arduino cpp/Makefile cpp/CMakeLists.txt cpp/library.json cpp/idf_component.yml` → **0 hits**. The packages have no database (architecture § 2).

| File | Line | API | sql_preview | Change |
|------|------|-----|-------------|--------|
| — | — | — | 0 hits | — |

### S31 — embedded HTML

Scan: `grep -rniE "<html|<!doctype|<body|<div|<span|text/html|<script"` over the same paths → **0 hits**. Libraries with no UI.

| File | Line | kind | served_as | Change |
|------|------|------|-----------|--------|
| — | — | — | 0 hits | — |

## (c) Logical flow findings

### Logic bugs

| # | Where | Finding | Evidence | Change |
|---|-------|---------|----------|--------|
| LB1 | Rust `field/order.rs:36-42`, `walk/unpack.rs:159-185, 287-327` | A `when` (or count) inside `repeat`/`times` that names an **outer** field passes construction, but the walker evaluates it against the fresh per-group `Values`, so it never matches. A repeat body that is only that `when` consumes 0 bytes and `while cur.left() > 0` never ends: **unpack hangs** with unbounded memory growth on any packet with ≥ 1 byte after the fixed fields. In `times` the same body loops `count` times (count read from the packet, up to 2⁶⁴). Reachable through the public API (`SchemeItem::Field(repeat(…))`). C++ rejects the same scheme (`SchemeInvalid`, field 1 — C-P4). | R-P5: "unpack did not return within 3 s"; C-P4 | C1 |
| LB2 | Rust `walk/pack.rs:182,187,97,204`, `unpack.rs:128,155`; `field/mod.rs:144` | `flags` with > 8 members and a `flag_byte` with > 8 `.bit()` fields are accepted. Debug: panic `attempt to shift left with overflow` (pack.rs:182 / :97). Release: bit k aliases bit k mod 8 — a 9th member sets bit 0 and packs member 0 (here `Missing("0")`; with member 0 present: wrong bytes). C++ rejects at build (`flags_overflow.cpp`, `fields_grouped.hpp:45`, `order.hpp:151`). | R-P2, R-P8 (debug panic; release `Err(Missing("0"))`) | C2 |
| LB3 | Rust `scheme/bound.rs:365,393,418,461`; `scheme/mod.rs:229-233, 239-243` | Every `list_utf8` binds the name `"__list"`, every `dict_*` `"__dict"`, every `list_u16` `"__list_0"` (element id must be 0). Two such fields in one scheme overwrite each other in `Values`: both are packed from the **second** member and both unpack into the same value. Silent data corruption. | R-P1: rows `a=["x"]`, `b=["yy","zz"]` pack to `01 0200 0200 7979 0200 7a7a 0200 0200 7979 0200 7a7a` (b twice) | C3 |
| LB4 | Rust `scheme/mod.rs:73-83, 148-165`; `walk/pack.rs:33-52, 298-309`; `walk/unpack.rs:287-327` | Typed `SchemeItem::times` binds children to scalar members: pack fails `Missing` for count ≥ 2 (only index 0 has a value), and unpack produces `Value::List` that the scalar binder ignores — the value is **silently dropped** even for count 1. No test uses it. | R-P12: n=2 → `Err(Missing("1"))`; unpack `01 01 09` → `Ok`, row `x: 0` | C4 |
| LB5 | Rust `walk/pack.rs:323-363, 33-52`; `walk/unpack.rs:171-185, 306-327, 341-367` | Composite children lose data silently: `list(flags…)` packs flag byte 0 and unpacks only the flag byte (member value gone); `list(group…)` fails with `Short{needed: 0}`; a `flags` member inside `times` is never packed and unpacks misaligned (per-name lists of different lengths); a `repeat` inside `repeat` drops the inner groups (`nested_groups` discarded). strings-lists-dicts restriction says list/dict elements "may be any existing field". | R-P3 (`list(flags)` unpack → `xs: [U8(1)]`, member 9 lost), R-P10, R-P6 (repack drops `a=9`), R-P11 (inner `5, 6` dropped) | C5 (fail closed); full support → C12 |
| LB6 | C++ `src/core/unpack.cpp:16, 232-236` vs `pack.cpp:74-83`; `order.hpp:112-126` | Unpack stores flag-byte values in `Walk::flag_bytes[number]`; pack and `resolve` bind each `flag_bit` to a specific flag-byte **entry**. A container whose items have their own `flag_byte(0)` overwrites slot 0, so an outer `flag_bit(0, …)` after the container reads the item's byte. The packet pack wrote does not unpack (`TrailingBytes`) or decodes wrong fields. | C-P1: pack `01 01 01 00 0203` ok; unpack → `TrailingBytes` at offset 4, `tail.has = 0` | C6 |
| LB7 | C++ `unpack.cpp:220-222, 237-241`, `pack.cpp:217-218`, `order.hpp:170-181` | `boolean<…>` or empty `group<…>` outside `flags` packs 0 bytes and unpacks as `true` every time; scheme check allows it. Rust's `bool_flag` outside flags stays absent — cross-language difference on the same scheme. | C-P2: unpack `01 07` → `b = 1`; pack `b=false` → `0107` | C7 |
| LB8 | Rust `field/mod.rs:120-155` | `FlagByte` numbers bits with a shared counter: bit = how many `.bit()` calls came before on that handle. Building a second scheme (or calling a helper twice) with the same handle continues at bit 3, 4… → different wire bytes for the same field list, no error. (by inspection) | code | C14 |
| LB9 | Rust `value.rs:133-157`, `walk/pack.rs:215-219`, `unpack.rs:165-169` | `when` compares `Value` variants: `eq(3, Value::U16(1))` on a `u8` field never matches (no build error), so the group is silently omitted on pack and skipped on unpack. C++ compares as `int64`. (by inspection) | code | C21 |

### Panic / hang paths on untrusted input (Rust)

| Path | Trigger | Mode |
|------|---------|------|
| `unpack.rs:172` repeat loop | scheme with a zero-width repeat body (LB1) + any trailing byte | hang / OOM |
| `unpack.rs:307` times loop | zero-width times body + large count from the packet | effective hang |
| `pack.rs:182/187/97/204`, `unpack.rs:128/155` | scheme with > 8 flag members / bits (LB2) | debug panic; release corruption |
| `.unwrap()` / `.expect()` in `rust/src` non-test code | 2 sites: `session/mod.rs:96` (guarded by `is_none` check), `scheme/mod.rs:112` (construction) | none on input |
| Index / arithmetic on input | `le_buf`, u2/bits/packed indexing, `Packed` `n * width` (n ≤ i64::MAX after the bias check) | checked — no panic found |

C++: no exceptions or aborts on input; the only non-terminating case is an **unbound** `repeat` whose body is a zero-width `boolean`/empty `group` (degenerate scheme; closed by C7).

### Performance waste

| # | Where | Finding | Action |
|---|-------|---------|--------|
| PW1 | Rust `walk/pack.rs:331-334, 356-358`, `BinaryPacker::pack` | Each pack builds a `HashMap<Rc<str>, …>` of cloned values; each list/dict item is cloned into a one-entry `Values` | none — AC-10 met; folded into C10 only if it falls out |
| PW2 | Rust `Scheme::new` | order check runs twice (compile_items + MapScheme::new) | C15 (construction-time only) |
| PW3 | C++ `codec.hpp:159-160`, `pack.cpp:77` | O(h²) handler-uniqueness check per packet; flag byte scans to table end | none — h and table sizes are small; AC-10 13 ms |

### Design contradictions

| # | Finding | Evidence | Change |
|---|---------|----------|--------|
| DC1 | Typed Rust scheme narrower than the map scheme and the spec (LESSONS 2026-09-24): no `opt_` for u32/u64/i8–i64/f32/f64, no typed u2, non-empty group, flag byte/bit, repeat, generic list/dict (4 hard-coded shapes). The golden position row's optional `altitude: i16` cannot be bound — all Rust tests and both CI drivers use an unbound raw `flags(4, "motion", …)`. Raw `SchemeItem::Field` values are never bound (pack `Missing` for required kinds; unpack discards). | `bound.rs`; `.github/workflows/drivers/rust/src/main.rs:38-42`; `tests/session_tests.rs:41` | C11 (scalars), C12 (decision) |
| DC2 | `MapScheme` and its constructors/values are public but have no public pack/unpack (dead half-API). | `lib.rs:11-27`, `walk` private | C13 |
| DC3 | Cross-language: when/count referencing an outer field inside a container — Rust accepts, C++ rejects. | LB1, C-P4 | C1 (align Rust with C++; other four languages to be checked by their scan) |
| DC4 | Cross-language: `bool`/empty group outside flags — C++ `true`, Rust absent. | LB7 | C7 |
| DC5 | Rust reports bad values as `ShortPacket { needed: 0 }` (invalid UTF-8, duplicate dict key, missing/negative count, list element missing, session not open) and unknown type as `Type { expected: 0 }`; C++ has `BadValue`. AC-8's ShortPacket is meant to name needed/left bytes. | `unpack.rs:191-409`, `scheme/mod.rs:271-274`, `session/mod.rs:79-83` | C8 |
| DC6 | C++ unpack keeps fields read before a failure (feature scenario S5, `codec.hpp:104-105`) vs project AC-8 / component `tests.md` ST-01 "0 values; any field value returned = fail". Decided in the feature, not reconciled in the project docs. The `on()` path does hold back the handler. | `codec.hpp:104`, `05_cpp_package/tests.md:274-284` | C17 (docs) — confirm with user |
| DC7 | Invalid UTF-8: Rust unpack rejects; C++ borrows the bytes unchecked (zero-copy, embedded profile). No AC covers it. | `unpack.rs:332`, `unpack.cpp:44-64` | none — report to the cross-language gate |
| DC8 | Dict key order: both packages enforce ascending order on pack (Rust by `BTreeMap`, C++ `keys_ascending` → `BadValue`) and accept any order on unpack (R-P7, C-P3). Consistent here. | probes | none — compare with the other four packages |
| DC9 | Rust `Scheme`/`MapScheme`/`Field` are `!Send + !Sync` (`Rc`, `RefCell`, `Box<dyn Fn>`), so a native node cannot keep one scheme in a `static` or share it across threads. | compile error in R-P5 setup | deferral (no AC; revisit with C14) |
| DC10 | Session random source: Rust only `/dev/urandom`, C++ Apple/Linux/`/dev/urandom` — `start()` fails on Windows hosts; `start_with`/`start(nonce)` remain. | `session/mod.rs:116-121`, `os_random.cpp` | deferral (no Windows AC) |

### Documentation drift

| # | Doc | Drift | Change |
|---|-----|-------|--------|
| DD1 | `_docs/02_document/components/05_cpp_package/description.md` | Still the 0.1.x dynamic API: `BinaryPacker::pack/unpack`, `ShortPacket` DTO, map `Value` input DTO, `load` "a session or nothing", `start` "none or 16 bytes", "pack before start produces 0 payloads". Missing: `Error`/`Result`, caller buffers, `Opt`/`View`/`Text`/`Blob`/`Array`/`Entry`, `constexpr` order check + `validate`, `on()` dispatch, `RandomFn` + host `os_random`, no-heap/no-exception profile, flash/stack budget, PlatformIO/Arduino/ESP-IDF publish and their rollback | C17 |
| DD2 | `05_cpp_package/tests.md` IT-08/ST-01 | "0 values" vs partial row (DC6) | C17 |
| DD3 | `cpp/include/packbin/fields_counted.hpp:186` | "keys keep the caller's order on pack" — pack rejects non-ascending keys (`pack.cpp:168-206`); README `:292` says "keys in unsigned byte order" | C17 |
| DD4 | `README.md:354` migration row | lists `Field` as removed; `packbin::Field` is still public | C16 / C17 |
| DD5 | `_docs/02_document/architecture.md` §1 external systems, §2 stack; `module-layout.md` C++ entry | no PlatformIO / Arduino / ESP-IDF registries; C++ public entries `cpp/arduino/packbin.h`, host-only `src/os_random.cpp`, `examples/`, `embedded/` not listed | C17 |
| DD6 | `_docs/02_document/components/04_rust_package/description.md` | lists `BinaryPacker::unpack(scheme, bytes)` (private); scheme errors described as returned (they panic); map `Value` input DTO (public API is typed rows); misses `DuplicateType`, `unpack_with` unknown-type shape; session `unpack` takes handlers, `pack` returns `None` on any pack error; no note on typed-kind coverage | C18 |
| DD7 | `cpp/tests/core/session_host_tests.cpp` `ac3_no_os_in_core` | claims "0 OS random references in the core" but scans 6 of 8 core headers (misses `fields_grouped.hpp`, `fields_counted.hpp`) | C20 |

### Test gaps noticed (no separate change unless listed)

- Rust: no test for typed `times`, two bound lists in one scheme, flags > 8, `when` inside `repeat`; the compile-fail test (`scheme_tests.rs:320`) accepts any compile error (C++'s checks the message). Covered by C1–C5 acceptance tests.
- C++: no vector with a reused flag-byte number inside a container (C6), no test for `boolean` outside `flags` (C7).
- Coverage is not measured for either package (baseline finding, project-wide).

## (d) Candidate changes

Points: 1 / 2 / 3 / 5. Ordered by severity.

### C1: Rust — reject outer references inside containers; stop zero-progress repeat
- **File(s)**: `rust/src/field/order.rs`, `rust/src/walk/unpack.rs`
- **Problem**: `when`/count/flag-bit sources inside `repeat`/`times` may name an outer field; construction passes, the walker cannot see outer values, and a zero-width repeat body hangs unpack (LB1, R-P5).
- **Change**: make the "not yet walked" check scope-aware (a reference inside a container must resolve inside that container, as C++ `find_ref`/`find_flag_byte` do); construction fails naming the id. Add a guard: a `repeat` iteration that consumes 0 bytes returns an error instead of looping.
- **Rationale**: removes a hang on untrusted input and a cross-language difference (DC3).
- **Constraint Fit**: scheme-field-order AC-4 ("a `when` … that names an id not yet walked fails construction") is tightened, not changed; no wire byte changes; existing tests use no outer references.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 2

### C2: Rust — enforce the 8-bit limit of `flags` and `flag_byte`
- **File(s)**: `rust/src/field/order.rs`, `rust/src/field/mod.rs`
- **Problem**: > 8 members / bits accepted; debug panic or release bit aliasing (LB2).
- **Change**: construction fails when a `flags` has more than 8 members or a flag byte gets a 9th bit.
- **Rationale**: same rule as C++ (`flags_overflow` compile-fail); removes a panic and silent corruption.
- **Constraint Fit**: schema.md "flags: one u8 … bit 0 is the first field"; no byte changes.
- **Risk**: low
- **Dependencies**: None (C14 touches the same `FlagByte`)
- **Complexity**: 1

### C3: Rust — unique binder names for bound lists and dicts
- **File(s)**: `rust/src/scheme/bound.rs`, `rust/src/scheme/mod.rs`
- **Problem**: all `list_utf8`/`dict_*` share `"__list"`/`"__dict"`, all `list_u16` `"__list_0"`; two in one scheme corrupt each other (LB3, R-P1).
- **Change**: give each bound list/dict a unique internal name when the scheme is compiled (like `__flags_{n}`), and drop the always-0 `element_id` parameter of `list_u16` (or document it).
- **Rationale**: silent data corruption on a public API.
- **Constraint Fit**: names are not on the wire; F-AC-1 bytes unchanged.
- **Risk**: low (`list_u16` signature change is public — coordinate with C13)
- **Dependencies**: None
- **Complexity**: 2

### C4: Rust — make typed `times` correct or remove it
- **File(s)**: `rust/src/scheme/mod.rs`, `rust/src/scheme/bound.rs`, `rust/src/walk/{pack,unpack}.rs`
- **Problem**: `SchemeItem::times` children bind scalar members; pack fails for count ≥ 2, unpack drops the values (LB4, R-P12); untested.
- **Change**: either (A) bind `times` to a `Vec<E>` member whose element binders read/write each `E` (the C++ shape `times<&Row::items>(…)`), or (B) remove `SchemeItem::times` from the public API until (A) is scheduled.
- **Rationale**: "correct solution only" — a public constructor that drops data must not ship in `v0.2.0`.
- **Constraint Fit**: borrowed-count criteria (times) stay covered by the map-walker tests; the route fixture bytes unchanged.
- **Risk**: medium (public API)
- **Dependencies**: C12 decides (A) vs (B)
- **Complexity**: 3 for (A), 1 for (B)

### C5: Rust — fail closed for composite children the map walker cannot carry
- **File(s)**: `rust/src/field/order.rs` (or `field/mod.rs` constructors), `rust/src/walk/{pack,unpack}.rs`
- **Problem**: `list`/`dict` of `flags`/`group`/`when`/`times`, `flags` inside `times`, `repeat` inside `repeat`/`times` lose data silently (LB5).
- **Change**: construction fails for those shapes with a message naming the field, until a typed binding supports them (C12). Repeat groups stop using the reserved `"__repeat__"` user-visible key if C13 removes the map API.
- **Rationale**: silent loss → explicit refusal; no wire change.
- **Constraint Fit**: strings-lists-dicts restriction says elements "may be any existing field" — this narrows it for Rust until C12; record as a known gap or get user approval.
- **Risk**: medium (spec narrowing)
- **Dependencies**: C12 (decision)
- **Complexity**: 2

### C6: C++ — keep flag-byte values per scope during unpack
- **File(s)**: `cpp/src/core/unpack.cpp`, `cpp/tests/core/grouped_tests.cpp` (new vector)
- **Problem**: `Walk::flag_bytes[number]` is shared across nesting levels; an inner flag byte with the same number overwrites the outer one (LB6, C-P1).
- **Change**: save the 8 slots before a container's items and restore them after (8 bytes of stack per nesting level), or key the value by the resolved table entry; add the C-P1 vector to the shared tests so the firmware runner covers it.
- **Rationale**: a packet the core packs must unpack (AC-3 for the target).
- **Constraint Fit**: no heap; stack budget AC-5 (≤ 512 B) — +8 B per container level; re-measure in the embedded job.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 2

### C7: C++ (and Rust) — refuse zero-width presence fields outside `flags`; u2 limit at build
- **File(s)**: `cpp/include/packbin/order.hpp`, `cpp/include/packbin/fields_counted.hpp`, `cpp/src/core/pack.cpp`; `rust/src/field/order.rs`
- **Problem**: `boolean`/empty `group` outside `flags` always unpacks `true` in C++ and absent in Rust (LB7); u2 > 64 children is a run-time `BadValue` (S21 row 24).
- **Change**: `check_shape` returns `SchemeInvalid` for `Bool`/empty `Group` whose parent is not `Flags` (Rust: same rule for empty `group`); `u2(…)` `static_assert`s ≤ 64 children.
- **Rationale**: removes a hidden rule and a cross-language difference.
- **Constraint Fit**: AC-7 (scheme check without throwing) — same mechanism; no byte changes.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 1

### C8: Rust — truthful unpack errors
- **File(s)**: `rust/src/value.rs`, `rust/src/walk/unpack.rs`, `rust/src/scheme/mod.rs`, `rust/src/session/mod.rs`
- **Problem**: 15 sites report bad values as `ShortPacket { needed: 0 }`; unknown type is `Type { expected: 0 }` (DC5, S05, S20).
- **Change**: add `UnpackError::BadValue { field }` (invalid UTF-8, duplicate key, missing/negative count, missing element), `UnknownType { actual }`, and a not-open session error; keep `Short` for real short reads.
- **Rationale**: AC-8's short-packet fields stay meaningful; mirrors C++ `BadValue`/`TypeMismatch`.
- **Constraint Fit**: F-AC-8/F-AC-9 still "an error and 0 values"; enum change is breaking — acceptable before the `v0.2.0` tag only with user approval.
- **Risk**: medium (public enum)
- **Dependencies**: None
- **Complexity**: 2

### C9: Rust — `PackSession::pack` returns the pack error
- **File(s)**: `rust/src/session/mod.rs`, `rust/tests/session_tests.rs`, README Rust session snippet
- **Problem**: `.ok()?` collapses `PackError` into the same `None` as "not open" (S25).
- **Change**: return `Result<Vec<u8>, SessionError>` (not open | pack error).
- **Rationale**: no silent swallow; pack-session AC-7 still observable.
- **Constraint Fit**: contract "pack before start or join produces 0 payloads" kept.
- **Risk**: medium (public signature)
- **Dependencies**: C8 (shared error style)
- **Complexity**: 1

### C10: Rust — split the walkers by kind
- **File(s)**: `rust/src/walk/pack.rs`, `rust/src/walk/unpack.rs`, `rust/src/value.rs`
- **Problem**: `pack_one` CCN 72 / 212 NLOC, `unpack_one` CCN 66 / 325 NLOC; 4 copied count lookups; Bits duplicates Packed; walk state passed as 4 params (S01, S03, S06, S29).
- **Change**: per-kind helpers (scalars, text, small numbers with Bits = Packed width 1, containers), one `count_of()` lookup, a walk-state struct; `as_u2`/`as_bit` via `as_packed`; named constant for the u16 limit. Same behaviour, golden vectors unchanged.
- **Rationale**: C++ did the same split in loop 10 (CCN ≤ 23); makes C1/C5/C8 local edits.
- **Constraint Fit**: ADR-001 (each language walks its own list) kept — no shared walker; AC-10 re-measured.
- **Risk**: low (52 tests + golden + language pairs)
- **Dependencies**: C1, C2, C5, C8 land first (or together)
- **Complexity**: 3

### C11: Rust — generate scalar `BoundField` constructors, add every `opt_` scalar
- **File(s)**: `rust/src/scheme/bound.rs`
- **Problem**: 514 lines (cap 500); 14 copies of the same extractor; `opt_` only for u8/u16, so the golden position row's optional `i16 altitude` cannot be bound (DC1, S02, S06, S19).
- **Change**: one `macro_rules!` for required + optional scalar pairs covering u8…u64, i8…i64, f32, f64; keep the container constructors.
- **Rationale**: size cap, duplication, and the missing kinds the LESSONS entry asked for.
- **Constraint Fit**: additive API; bytes unchanged; drivers can then bind motion fields.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 2

### C12: Rust — typed-scheme parity decision (needs user)
- **File(s)**: `rust/src/scheme/{mod,bound}.rs`, `rust/src/walk/*`
- **Problem**: typed scheme lacks u2, non-empty group, flag byte/bit, repeat, generic list/dict elements; raw `SchemeItem::Field` is never bound (DC1, S19). LESSONS 2026-09-24: "same value kinds as the map scheme … or the spec must exclude them."
- **Change**: choose (A) generic typed bindings (`Vec<E>` for repeat/times/list, `BTreeMap<String, E>` for dict, nested element binders, typed u2/group/flag byte), split into ≤ 3-point tasks; or (B) spec exclusion recorded in `languages.md`/README with C4(B) and C5.
- **Rationale**: the public Rust API cannot express several schema.md kinds; today they fail silently.
- **Constraint Fit**: languages.md "same surface everywhere" favours (A); (B) needs explicit user approval.
- **Risk**: medium–high for (A)
- **Dependencies**: C3, C4, C5, C11
- **Complexity**: 5 for (A) (split before scheduling); 1 for (B)

### C13: Rust — trim the public API to what callers can use
- **File(s)**: `rust/src/lib.rs`, `rust/src/value.rs`, `rust/src/*_tests.rs`, `rust/tests/*.rs`
- **Problem**: `MapScheme`, `Values`, `insert`, `Value::Groups`, `motion_field_count` (domain field names — S21 row 9), `mismatched_bytes` are public with no public pack/unpack or no external caller (DC2, S07, S15).
- **Change**: move test helpers into test code; either make the map layer crate-private (field constructors stay public as raw items, or become `pub(crate)` after C12) or re-export map pack/unpack deliberately. Keep `to_hex` only if the drivers still need it.
- **Rationale**: dead public surface and a product catalog inside the library.
- **Constraint Fit**: module-layout "public API is the file named"; breaking for 0.1.x users of the unusable map API only.
- **Risk**: medium (public API)
- **Dependencies**: C12 decision
- **Complexity**: 2

### C14: Rust — flag-bit positions from field order
- **File(s)**: `rust/src/field/mod.rs`, `rust/src/field/order.rs`, `rust/src/walk/pack.rs`
- **Problem**: bit number comes from a shared `Rc<RefCell<u8>>` counter; reuse of a handle shifts bits silently (LB8, S24, S32).
- **Change**: `FlagByte::bit` records only the flag name; `MapScheme::new` assigns positions in field order (as C++ `bit_position`) and enforces C2's limit.
- **Rationale**: deterministic bytes from the field list alone; removes shared mutable builder state (also one step toward `Send`, DC9).
- **Constraint Fit**: schema.md split form "motion.bit(…)" order unchanged; golden split-form vector unchanged.
- **Risk**: low
- **Dependencies**: C2
- **Complexity**: 2

### C15: Rust — one order check per typed scheme
- **File(s)**: `rust/src/scheme/mod.rs`
- **Problem**: `compile_items` repeats anchor/"not yet walked" checks that `MapScheme::new → check_order` runs again (S06, PW2); `compile_items` CCN 15.
- **Change**: keep only the list/dict element-id check in `compile_items`; rely on `check_order` for the rest (panic messages already identical).
- **Rationale**: one owner for the order rule.
- **Constraint Fit**: scheme-field-order AC-4 tests (`field_id_ac5_order_must_match`, `packbin_tests` build failures) must stay green.
- **Risk**: low
- **Dependencies**: C1 (scope rule lives in `check_order`)
- **Complexity**: 1

### C16: C++ — move table internals out of the public namespace
- **File(s)**: `cpp/include/packbin/{table,order,codec,fields*}.hpp`, `cpp/src/core/*`, tests
- **Problem**: `Field`, `Kind`, `Node`, `Access`, `Item`, `Count`, `flag::*`, `check_table` are in `packbin::` (S12); clashes with user types under `using namespace packbin`; README says `Field` was removed.
- **Change**: move them to `packbin::detail` (keep `Scheme`, builders, `Opt`, `View`, `Text`, `Blob`, `Array`, `Entry`, `Error`, `Result`, `Writer`/`Reader` and the codec functions public); drop the unused `T` of `bind_small_numbers`.
- **Rationale**: smaller public surface, matches the README migration table.
- **Constraint Fit**: no byte changes; embedded profile unchanged; examples unaffected (they use builders only).
- **Risk**: medium (public names; 0.2.0 is already a breaking C++ release)
- **Dependencies**: None
- **Complexity**: 2

### C17: C++ — documentation refresh
- **File(s)**: `_docs/02_document/components/05_cpp_package/description.md`, `…/tests.md`, `cpp/include/packbin/fields_counted.hpp:186`, `README.md:354`, `_docs/02_document/architecture.md` §1–2, `_docs/02_document/module-layout.md` (C++ entry)
- **Problem**: DD1–DD5; DC6 unreconciled.
- **Change**: document the core API, error model, storage types, compile-time check, `RandomFn`/`os_random`, embedded registries and rollback; reconcile "0 values" with the partial-row rule (user confirms S5 wording); fix the dict-order comment and the `Field` row.
- **Rationale**: docs are the cross-language contract readers use.
- **Constraint Fit**: Architecture Vision principles untouched (only the integration table and component docs).
- **Risk**: low
- **Dependencies**: C16 (Field row)
- **Complexity**: 2

### C18: Rust — documentation refresh
- **File(s)**: `_docs/02_document/components/04_rust_package/description.md`
- **Problem**: DD6.
- **Change**: document the typed API actually exported, panics on construction, `unpack_with`/`On`, error variants, session signatures, typed-kind coverage (after C12).
- **Rationale**: drift.
- **Constraint Fit**: docs only.
- **Risk**: low
- **Dependencies**: C8, C9, C12, C13
- **Complexity**: 1

### C19: C++ — per-toolchain build directory
- **File(s)**: `cpp/Makefile`, `cpp/tests/compile-fail/expect-fail.sh`
- **Problem**: host and container builds share `cpp/build/`, so `make` can run a binary from the other OS (LESSONS 2026-09-29; baseline observation 4).
- **Change**: `BUILD ?= build/$(shell $(CXX) -dumpmachine)` and pass it to `expect-fail.sh`.
- **Rationale**: removes a manual "delete cpp/build" step.
- **Constraint Fit**: CI commands unchanged (`make test`); `.gitignore` already covers `build/`.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 1

### C20: C++ — core OS-reference scan covers every core header
- **File(s)**: `cpp/tests/core/session_host_tests.cpp`
- **Problem**: `ac3_no_os_in_core` lists 6 headers by name; `fields_grouped.hpp`, `fields_counted.hpp` are not scanned (DD7, S16).
- **Change**: scan `include/packbin/*.hpp` except `os_random.hpp`.
- **Rationale**: the AC-10 (feature) claim must cover the whole core.
- **Constraint Fit**: test-only.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 1

### C21: Rust — `when` compares numbers, not `Value` variants
- **File(s)**: `rust/src/value.rs`, `rust/src/walk/{pack,unpack}.rs` (or `field/order.rs` for a build check)
- **Problem**: `eq` with a different integer variant than the field never matches, silently (LB9, S32).
- **Change**: compare integer values numerically (as C++ does with `int64`), or reject a mismatched variant at construction.
- **Rationale**: hidden rule; cross-language behaviour.
- **Constraint Fit**: AC-6 unchanged for matching variants.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 1

### C22: Rust — `repository` in `Cargo.toml`
- **File(s)**: `rust/Cargo.toml`
- **Problem**: crates.io page has no repository link; languages.md "Done for a language" asks the registry page to link the GitHub tree (C++ manifests have it).
- **Change**: add `repository = "https://github.com/zxsanny/packbin"`.
- **Rationale**: registry metadata parity.
- **Constraint Fit**: AC-16 unaffected; publish gate greps license/readme only.
- **Risk**: low
- **Dependencies**: None
- **Complexity**: 1

### Rejected or deferred ideas

| Idea | Reason |
|------|--------|
| Share one walker / crypto code between Rust and C++ (or with other packages) | ADR-001 and LESSONS 2026-09-23: packages stay peers with zero imports |
| Replace hand-written SHA-256/HKDF/ChaCha20 with crates/libraries | Rust has zero dependencies, C++ core is header-restricted; vectors already pinned by RFC tests |
| Collapse C++ `visit_integer` into `visit_number` | intentional: counts and `when` must not pull floating-point code into firmware (`values.hpp:19-20`) |
| Split C++ `pack_one`/`unpack_one` further | CCN 22–23 flat switch dispatch, already split in loop 10; low value |
| C++ dict pack auto-sorting | the row is `const` caller storage with no heap; README documents caller-sorted keys — fix the comment only (C17) |
| Duplicate-key check for an unbound (skipped) C++ dict | needs key storage or a second pass over the input; document as a limitation in C17 |
| UTF-8 validation in the C++ core | zero-copy borrowed views on firmware; no AC — raise in the cross-language gate (DC7) |
| Make Rust schemes `Send + Sync` now | no AC or consumer need yet (DC9); C14 removes one blocker |
| Windows random source for both packages | no Windows AC; `start_with` / `start(nonce)` exist (DC10) |
| Change Rust order ids from strings to integers (S04) | touches every module and the map API; revisit only if C12 (A) rewrites the typed layer |
| Shared `parse_hex` helper for Rust test files | integration tests would need a `tests/common` module; cosmetic |

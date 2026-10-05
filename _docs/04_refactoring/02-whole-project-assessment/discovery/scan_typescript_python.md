# Discovery scan — TypeScript and Python packages

**Run**: `02-whole-project-assessment` (Quick Assessment, Phase 1, read-only) · **Tree**: `d108141` · **Date**: 2026-10-05
**Scope**: `typescript/src` (5 files, 1494 lines), `typescript/tests` (6 suites + compile-fail fixture), `typescript/package.json`; `python/src/packbin` (8 files, 1450 lines), `python/tests` (6 files), `python/pyproject.toml`. `node_modules` and the CI drivers are excluded.
**Method**: read every file in full; lizard 1.24 (`/private/tmp/claude-501/lizard-venv/bin/lizard -l typescript -l python …`) plus a manual branch count where lizard misparses TS; grep counts (commands below); behavior probes run from the scratchpad against the repo sources (no repo files changed). Probes: `probe_ts.ts`, `probe_ts_split.ts`, `probe_ts_hang.ts`, `probe_py.py`, `probe_py_hang.py`, and a scratch `node_modules/packbin` consumer. `node --test tests/*.ts` passes 44/44 locally. Python tests were not run on the host (no pytest); the baseline records 44 passing in the CI container.
**Components**: [`components/02_typescript.md`](components/02_typescript.md), [`components/03_python.md`](components/03_python.md)

---

## (a) Smell table S01–S32

| ID | Smell | Result | Evidence (file:line, counts, top offenders) | Change / deferral |
|----|-------|--------|---------------------------------------------|-------------------|
| S01 | Long method | found | TS `walker.ts:223` `unpackFields` 216 lines (missed by lizard); `walker.ts:62` `packFields` 115 NLOC; Py `_unpack.py:189` `unpack_nodes` 171 NLOC; `_pack.py:165` `pack_nodes` 117 NLOC | B18, B19 |
| S02 | Large class / god module | not_found | No file over 500 lines. Largest: `walker.ts` 458, `fields.ts` 426, `_nodes.py` 424. `walker.ts` holds both directions (pack + unpack); `fields.ts` mixes builders, validation, name lookup and value flattening | B18 splits walker as a side effect; no standalone change |
| S03 | Long parameter list | found | TS `unpackFields(fields, allFields, cur, values, flagBytes, repeating)` 6 params; `packFields` 5. Py `unpack_nodes` 7 (`data, offset, nodes, row, seen, as_list, flag_state`); `pack_nodes` 5 | B18, B19 (a walk context object) |
| S04 | Primitive obsession | found (minor) | Py `_Scalar.kind: str` ("u8"…"f64") drives `_require_int` (`_pack.py:109` `field.kind in ("f32","f64")`); TS error kinds told apart by sentinel numbers (`needed: 0`) instead of a discriminant | B16 (TS errors); Py kind string deferred: internal only, low value |
| S05 | Data clumps | found | `(allFields, flagBytes, values)` travels through every TS walker call; Py `(data, offset, seen, flag_state)`; Py `field_id, get, set` repeated in 10 node dataclasses (`_nodes.py:64-210`) | B18, B19 |
| S06 | Duplicated code | found | TS: `if (repeating) appendRepeat(...) else values[...] = ...` **11×** (`walker.ts`); slice builder for repeat/times 2× (`walker.ts:127-136`, `163-172`); u16 count write + `> 65535` check 3× (`kinds.ts:280-281`, `walker.ts:182-183`, `205-206`); Uint8Array/ArrayBuffer coercion 2× (`walker.ts:84-89`, `kinds.ts:182-187`) and `toBuf` 2× (`index.ts:98`, `177`); width→max/shift/per 2× (`kinds.ts:137-139`, `160-162`). Py: `_unpack_leaf` re-implements scalar/bytes/utf8 (`_unpack.py:90-124` vs `205-341`); `_is_leaf` 2× (`_pack.py:123`, `_unpack.py:73`); `_builtin_*` aliases in 4 modules; repeat/times `at` closure 2× (`_pack.py:243`, `277`); utf8 prefix write 2× (`_pack.py:158-161`, `287-290`). Cross-package ChaCha20/HKDF duplication is intended by ADR-001 | B18, B19; cross-package: rejected R1 |
| S07 | Dead code | found | TS: `case "flags"` in `packFields` (`walker.ts:216`) and `unpackFields` (`423`) never runs, because `scheme()` and `list()`/`dict()` flatten every `flags` (and if reached it would make a fresh `Symbol` that never matches); no-op branch `walker.ts:315` (both arms `return err`); exported types `UnpackOk`/`UnpackResult` (`index.ts:123-124`) are never returned; `TypeMismatchErr.expected` never set (`kinds.ts:5`); `xorWithNonce` exported but only used internally. Py: `u2` branch accepting a prebuilt `_U2Slot` (`_nodes.py:352`) has no public way to make one; `_read_u2` fallback label `"0"` (`_unpack.py:288`) is unreachable (`u2` requires slots); `_unpack_leaf`'s `seen` argument is always `{}`; split-form `flag_byte` is unusable (B10) | B20 (TS); Py dead items folded into B19; B10 |
| S08 | Speculative generality | not_found | `group` overloads (TS) and `u2` slot tuples (Py) serve current callers; only the `_U2Slot` branch is speculative (listed under S07) | — |
| S09 | Lazy class | not_found | `_Node` marker base, `_Eq`, `_Handler`, TS `Scheme` are thin but are real value types | — |
| S10 | Data class | found (accepted) | Py node dataclasses / TS `Field` union carry no behavior; all logic sits in the walkers. That is the interpreter design and is not a defect | No change |
| S11 | Feature envy | not_found | The walkers read node fields by design. `kinds.ts` / `_pack.py` helpers own their encodings | — |
| S12 | Inappropriate intimacy | found (minor) | Py `_scheme.py:49,80` and `_session.py:8` reach `scheme._type_number`, `scheme._fields`, and the private `_Handler`, all inside the same package | Deferred: package-internal, no cycle |
| S13 | Message chains | not_found | Deepest chain is `f.field.fields` (`walker.ts:106`), which is shallow | — |
| S14 | Middle man | not_found | `BinaryPacker.unpack` → `unpackDispatch` / `_unpack_dispatch` is a thin facade that is intended | — |
| S15 | Divergent change | found (expected) | `walker.ts`, `_pack.py`, `_unpack.py` change for every new kind (git: `index.ts` 15 commits, `kinds.ts` 8, `__init__.py` 12) | B18, B19 (per-kind functions localize change) |
| S16 | Shotgun surgery | found | Adding one kind in TS touches 8 places: `Field` union, builder, `flatten`, `fieldName`, `findNameById`, `validateFieldIds`, `scalarChildNames`, `packFields`, `unpackFields`. Five of them repeat their own "leaf kinds" list (`fields.ts:294`, `324`, `358`, `kinds.ts:31`, plus the walker). Py: about 10 places (`_nodes` class + builder, `_validate_order`, `_child_on`, `_is_leaf`×2, `pack_nodes`, `unpack_nodes`, `_unpack_leaf`, `__init__` + `__all__`) | B18, B19 (one kind table per package) |
| S17 | Switch / type soup | found | TS `switch (f.kind)` with 19 cases in `packFields` and in `unpackFields`, 13 in `findNameById`, 17 in `validateFieldIds`; Py `isinstance` chains with 16 branches in `pack_nodes` / `unpack_nodes` and 7 in `_validate_order` | B18, B19 |
| S18 | Temporary field | found (minor) | Py `_Scalar.min_v/max_v` are ±inf and `signed=True` for floats (`_nodes.py:280,285`); TS `group.anchor?` decides two id regimes; `TypeMismatchErr.expected?` never set | B19 / B20 |
| S19 | Parallel inheritance / near-duplicate types | found (minor) | TS `Cursor` vs `ViewCursor` (`kinds.ts:7`, `251`) | B18 |
| S20 | Magic number / string | found | `65535` 3× TS, 2× Py (+ utf8); `field: ""` sentinel 4× TS (`index.ts:113`, `176`, `walker.ts:455`; flag byte name `""` in `fields.ts:107`) and 7× Py (`_unpack.py:148,165,172,177,184,225,248`, `_scheme.py:87`, `_session.py:64`); `needed: 0` as "trailing"/"duplicate key"; Py `TypeMismatch(expected=-1)` (`_scheme.py:91`); ChaCha20 sigma words inline in TS (`session-pad.ts:39-42`, named `_CONSTANTS` in Py) | B16 (sentinels), B19/B18 (`MAX_COUNT` constant); RFC constants: code-ok |
| S21 | Hardcoded configuration | not_found (inventory below) | 21 protocol/contract constants. All `code-ok`: 0 business, 0 system, 0 uncertain | — |
| S22 | String SQL | not_found (inventory below) | 0 hits | — |
| S23 | Stringly-typed APIs | found (minor) | Py `_Scalar.kind` strings; Py short-packet `field` carries `str(field_id)`; TS `kind` strings are a typed discriminated union (fine) | B9 (Py field naming) |
| S24 | Mutable global SoT | not_found | No module-level mutable state. Builder state is mutable but per instance: TS `flagByte` closure counter (`fields.ts:131`), Py `_FlagByte.bits` (`_nodes.py:105`); re-using one handle in two schemes would share the counter | Note only |
| S25 | Silent failure swallow | found (no empty `catch`; silent defaults) | No `catch` in TS `src`. Py has one `except Exception` that re-raises (`_nodes.py:42`, not silent). Silent paths: TS `writeInt` wraps out-of-range values (B1); `flagBytes.get(id) ?? 0` makes a bit before its flag byte silently absent (`walker.ts:103`, `270`; Py raises `RuntimeError`); `be()` returns non-numeric fields unchanged (`fields.ts:100`; Py raises `TypeError`); `collectFlagBits` skips groups → dropped field (B3); unpack `bits` with an absent count reads `[]` (`walker.ts:345`, `Number(undefined)` = NaN); Py `getattr(row, key, None)` makes a misspelled optional member silently absent (`_nodes.py:51`) | B1, B3, B17; accessor default: deferred (by design, documented absence) |
| S26 | Circular dependency | not_found | TS: `index → fields/walker/kinds/session-pad`, `walker → fields/kinds`, `fields → kinds`. Py: `_scheme → _nodes/_pack/_unpack`, `_session → _scheme`. No cycles (traced imports) | — |
| S27 | Framework leak | n/a | No framework; library only | — |
| S28 | Secret in source | not_found | `grep -rniE "password|secret|token|api[_-]?key|bearer|BEGIN (RSA|PRIVATE)"` → only `import secrets` / `secrets.token_bytes` (`_session.py:3,38`). Test seeds are generated by functions (`session.test.ts:48`, `test_session.py:32`) | — |
| S29 | High cognitive / cyclomatic complexity | found | TS `unpackFields` ~70 (manual), `packFields` 43, `validateFieldIds` ~26 (manual), `findNameById` ~20 (manual), `writePacked` 12; Py `unpack_nodes` 57, `pack_nodes` 48, `_validate_order` 12, `_write_packed` 11. **Baseline caveat:** lizard misparses TS. It drops `unpackFields`/`unpackBody` after `packFields`, and reports `fields.ts` as one 420-NLOC `memberName` because of the regex at `fields.ts:35`. The baseline TS row undercounts | B18, B19 |
| S30 | Shotgun resources | n/a | No uploads, caches or resource policies. The 65535 count limit is one wire rule, listed under S06/S20 | — |
| S31 | Embedded HTML | not_found (inventory below) | 0 hits | — |
| S32 | Hidden domain rule | found | (1) TS field names come from `Function.prototype.toString` of the accessor (`fields.ts:32-45`); the identity accessor becomes `"$"`. (2) TS `flattenValues` merges nested objects into one namespace, and inner names silently overwrite outer ones (B5). (3) TS error kinds are told apart by sentinel values (`needed:0` = trailing / duplicate key; `{"",1,0}` = empty buffer *or* session not open) (B16). (4) Py errors name `str(field_id)` instead of the member (B9). (5) TS `bool` presence = not null, so `false` sets the bit (B2). (6) TS flag-byte value leaks into the row under its name, `""` for short form (B6). (7) TS `when` uses `===`, so 64-bit `bigint` never equals a `number` literal (B7). (8) Py `__all__` exports `bool/bytes/dict/list`, shadowing builtins on `import *` (B22). (9) TS unpack hands a plain object typed as `T` (no class instance, groups flattened); Py constructs `row_type()`, which must be no-arg constructible | B2, B5, B6, B7, B9, B16, B22; (1) and (9) → doc only (B24) |

**Totals:** **found = 18** (S01, S03, S04, S05, S06, S07, S10, S12, S15, S16, S17, S18, S19, S20, S23, S25, S29, S32); **not_found = 12** (S02, S08, S09, S11, S13, S14, S21, S22, S24, S26, S28, S31); **n/a = 2** (S27, S30).

---

## (b) INV inventories

### S21 — config in code

Scan method: read every source file in full; `grep -rnE "^[A-Z_]+ *= |static readonly|^const [A-Z_]+ *=" typescript/src python/src`; plus a manual pass for literals in predicates (`65535`, `255`, `0xff`, widths, biases). Manifests are included.

| # | File | Line / symbol | Value | Classification | Notes | Change / deferral |
|---|------|---------------|-------|----------------|-------|-------------------|
| 1 | `typescript/src/index.ts` | 74 `scheme` | type number `0..255` | code-ok | one wire byte | — |
| 2 | `typescript/src/index.ts` | 126 `SESSION_INFO` | `"packbin"` | code-ok | HKDF info fixed by `contracts/library/pack-session.md` | — |
| 3 | `typescript/src/index.ts` | 129-130 `SeedSize`, `NonceSize` | 32, 16 | code-ok | contract sizes | — |
| 4 | `typescript/src/session-pad.ts` | 39-42 | ChaCha20 sigma words | code-ok | RFC 8439 (unnamed inline, S20 note) | B18 may name them; not required |
| 5 | `typescript/src/session-pad.ts` | 52, 82, 69 | 10 double rounds, 64-byte block, 12-byte nonce | code-ok | RFC 8439 | — |
| 6 | `typescript/src/kinds.ts` | 280 `writeUtf8` | 65535 | code-ok | strings-lists-dicts restriction; duplicated (S06) | B18 |
| 7 | `typescript/src/walker.ts` | 182, 205 | 65535 | code-ok | same rule, list/dict | B18 |
| 8 | `typescript/src/walker.ts` | 195-204 | dict key order = unsigned UTF-8 bytes | code-ok | wire contract | — |
| 9 | `typescript/src/fields.ts` | 220-224 `packed` | width ∈ {1,2}, bias ∈ {0,−1} | code-ok | schema rule | — |
| 10 | `typescript/src/fields.ts` | 38-42 `memberName` | accessor regexes | code-ok | parser, not policy (S32 noted) | B24 doc |
| 11 | `typescript/src/kinds.ts` | 56-62, 99, 143 | u2 0..3, bit 0/1, packed 0..max | code-ok | wire widths | — |
| 12 | `typescript/package.json` | `engines.node` | `>=22` | code-ok (packaging) | Node 22.0–22.17 cannot load the `.ts` entry without a flag; moot once B15 ships JS | B15 |
| 13 | `typescript/package.json` | `dependencies` | `@noble/hashes` `2.4.0` pinned | code-ok | lockfile-pinned dependency | — |
| 14 | `python/src/packbin/_scheme.py` | 20 | type number `0..255` | code-ok | wire byte | — |
| 15 | `python/src/packbin/_scheme.py` | 91 | `expected=-1` | code-ok (magic) | sentinel; S20 | B16 |
| 16 | `python/src/packbin/_session.py` | 13-14 `SEED_SIZE`, `NONCE_SIZE` | 32, 16 | code-ok | contract | — |
| 17 | `python/src/packbin/_session_pad.py` | 7-8 `_INFO`, `_CONSTANTS` | `b"packbin"`, sigma | code-ok | contract / RFC | — |
| 18 | `python/src/packbin/_nodes.py` | 240-285 | per-kind min/max, `struct` formats | code-ok | IEEE / two's complement ranges | — |
| 19 | `python/src/packbin/_nodes.py` | 103 `_FlagByte.bit` | 8 bits | code-ok | one flag byte (TS lacks it, B4) | B4 |
| 20 | `python/src/packbin/_pack.py` | 37, 141, 152 | 65535 | code-ok | wire rule; duplicated | B19 |
| 21 | `python/pyproject.toml` | `requires-python`, `version` | `>=3.10`, `0.1.0` (rewritten at publish) | code-ok (packaging) | `dataclass(slots=True)` and `zip(strict=True)` need 3.10 | — |

Business: 0 · System: 0 · Code-ok: 21 · Uncertain: 0. The library loads no configuration (module-layout "Shared / Cross-Cutting").

### S22 — string SQL

Scan method: `grep -rniE "\b(select|insert|update|delete)\b.+\b(from|into|set|where)\b|execute\(|executescript|cursor|sqlite|\.query\(" typescript/src typescript/tests python/src python/tests typescript/package.json python/pyproject.toml`. The only hits are the TS byte-cursor types `Cursor` / `ViewCursor` (`kinds.ts:7,70,108,152,196,251,254,286,301`; `walker.ts:29`), which are not SQL.

| File | Line | API | sql_preview | Change / deferral |
|------|------|-----|-------------|-------------------|
| — | — | — | **0 hits** | — |

### S31 — embedded HTML

Scan method: `grep -rniE "<!doctype|<html|<body|<div|<span|<script|text/html|innerHTML" typescript/src typescript/tests python/src python/tests` → no output.

| File | Line | Kind | Served as | Change / deferral |
|------|------|------|-----------|-------------------|
| — | — | — | **0 hits** | — |

---

## (c) Logical flow findings

Each item was confirmed by a probe unless marked "by reading".

### Logic bugs

| # | Pkg | Finding | Evidence | Severity |
|---|-----|---------|----------|----------|
| L1 | TS | Pack silently wraps out-of-range or fractional integers: `u8` 300 → `2c`, −1 → `ff`, 1.7 → `01`; `i8` 200 → `c8`; `i32` 3e9 → `005ed0b2`; `u64` −1n → `ff×8`. `f32` overflow becomes `Infinity` and `Number("abc")` becomes NaN, both silently | `kinds.ts:216-249`, `walker.ts:73,78`; probe | **High**: silent data corruption on the wire; contradicts architecture §4 and the component doc |
| L2 | TS (C# too, out of scope) | `bool` `false` counts as present: the bit is set and unpack returns `true`. A top-level `bool` always unpacks `true`. Python treats `False` as absent, so the same row `{on:false}` packs `0101` in TS and `0100` in Python (AC-3 risk) | `fields.ts:281`, `kinds.ts:9-11`, `walker.ts:257-260`; probe. C# `Walker.cs:39` uses the same `is not null` rule | **High** (cross-language byte disagreement; needs the parent to confirm C#/Rust/Java/C++ behavior) |
| L3 | TS | Flags inside a nested `group` are dropped on pack: `collectFlagBits` does not descend into `group`, so the flag byte is `00` and the child is not written | `fields.ts:263-275`; probe `flags in nested group` → `01010200` with `c=3` lost | **High** (silent loss) |
| L4 | TS, Py | More than 8 flag bits. TS accepts them and writes a byte its own unpack rejects (`010007` → trailing error). Py `flags()` accepts them and fails at pack with `byte must be in range(0, 256)` | `fields.ts:125,136`; `_nodes.py:318`; probe | Medium |
| L5 | TS | A nested group's member names overwrite parent names (`{sid:1, g:{sid:2}}` packs `sid` 2) | `fields.ts:416-426`; probe | Medium (silent) |
| L6 | TS | Id lookups for `when` / `sized` / `bits` / `packed` / `times` search the whole scheme from the top (`nameById(allFields, id)`), so inside an unanchored group (ids restart at 0) they bind to the outer field. `===` also fails between a `bigint` (64-bit unpack) and a `number` (pack): pack writes the group, unpack skips it, and the result is a trailing error | `walker.ts:113,143,152,297,328,345`, `fields.ts:314`; probes | Medium |
| L7 | TS | A list or dict whose element is a `group` (allowed: "any existing field except repeat", strings-lists-dicts restrictions) fails. Pack reads group children from the top-level values and throws `missing a`; unpack pushes `one[groupName]`, which is `undefined` | `walker.ts:179-214`, `382-422`; probe | Medium (feature gap against the spec) |
| L8 | TS, Py | A `repeat` whose body can read 0 bytes (e.g. only a non-matching `when`) loops forever on unpack, and the trigger is wire data | `walker.ts:311-318`, `_unpack.py:269-275`; both probes killed by a 5 s alarm | Medium (hang / DoS on the receiver for such schemes) |
| L9 | Py | Split-form `flag_byte` can never be used in a `Scheme`: `_validate_order` validates the bit fields under `_FlagByte.bits` and again at each `_FlagBit` | `_nodes.py:416-419`; probe `field id 1 is not the next order 2` | Medium (exported feature is dead) |
| L10 | Py | `repeat` / `times` on a row type with non-`None` defaults merge the default into the list (`lat=[0, 10, 30]`) | `_unpack.py:77-87`; probe with a dataclass | Medium (silent corruption) |
| L11 | Py | `repeat` containing `flags` / `when` / `group` crashes on pack (`'_Flags' object has no attribute 'get'`). In `times`, flag presence reads the whole list, not item `i` | `_pack.py:262-283`, `_child_on` `57-66`; probe | Medium |
| L12 | Py | A list or dict element `group` with attribute accessors fails on unpack: the child row is always `dict`, so `setattr` raises. Item accessors work | `_unpack.py:136-140`; probe | Low (documented use is item accessors) |
| L13 | TS | The flag byte's raw value is written into the unpacked row: key `""` for short form, the flag name (`"motion"`) for split form | `walker.ts:266`; probes | Low |
| L14 | TS, Py | Unpack throws instead of returning an error on wire-dependent input: invalid UTF-8 (`TypeError` / `UnicodeDecodeError`), or a count field absent because its flag bit is clear (`RangeError` / `RuntimeError`). TS `bits` with an absent count silently returns `[]` | `kinds.ts:297`, `walker.ts:38-53,345`; `_unpack.py:119,178,279-321`; probes | Low–Medium (contract says unpack returns an error) |
| L15 | Py | `PackSession(seed)` is public and skips the 32-byte rule that `load` enforces (`PackSession(b"abc").start()` opens) | `_session.py:20`; probe | Low |

### Performance waste

| # | Pkg | Finding | Evidence | Verdict |
|---|-----|---------|----------|---------|
| P1 | TS | `repeat`/`times`/`list`/`dict` copy the whole value map for every item (`{...values}`); dict sort encodes each key on every comparison; `TextEncoder`/`TextDecoder` are created per call | `walker.ts:128,164,186,194-204,211`; `kinds.ts:279,297` | 20 000-item repeat packs in 19 ms; no AC pressure → no change (R5) |
| P2 | TS | `nameById` does a depth-first search of the scheme on every count / `when` lookup during each pack and unpack | `walker.ts:45,113,143,152,297,328,345` | Folded into B7 (resolve once at construction) |
| P3 | Py | Pure-Python ChaCha20 with a per-byte XOR loop | `_session_pad.py:61-71` | Session is outside AC-10; no change (R2) |

### Design contradictions

| # | Finding | Evidence |
|---|---------|----------|
| C1 | Error model drift. TS reports trailing bytes as `ShortErr{field:"",needed:0}`, while C#/Rust/Java/Python have a separate `TrailingBytes`. Session-not-open is reported as an empty-buffer short packet in both TS and Py; the contract lists no error for it | `walker.ts:455`, `index.ts:176`; `_session.py:64`; `csharp/Packbin.cs:85`, `rust/src/value.rs:36` |
| C2 | Short-packet `field` differs by language for the same scheme: TS `"lon"`, C# `"Lon"`, Py `"8"`. Py list/dict/flags errors give `""` | `_unpack.py:68,103,148-184,225,248`; `python/tests/test_borrowed_count.py:119` vs `typescript/tests/borrowed-count.test.ts:162` vs `csharp/tests/BorrowedCountTests.cs:145` |
| C3 | `group` means different things. TS: a nested object with its own id space (unanchored) or continuing ids (anchored); unpack flattens members into the parent. Py: always continuing ids, no nested object. "A nested group still starts at 0" (schema.md, README) is true only for TS | `fields.ts:166-187,391-400`; `_nodes.py:338` |
| C4 | `Scheme<T>` in TS promises a `T`, but the handler receives a plain flat object (no class instance, groups flattened). Py constructs `row_type()` | `index.ts:119` cast `as object` |
| C5 | `be()` on a non-numeric field: TS returns it unchanged; Py raises `TypeError` | `fields.ts:93-101`; `_nodes.py:300-302` |
| C6 | The npm package exports raw `.ts`, so Node consumers fail at import (`ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING`, reproduced) while the docs list Node as a consumer | `package.json` `exports`; `.github/workflows/publish-inside.sh:23-29` (no build) |

### Documentation drift

| # | Doc | Drift |
|---|-----|-------|
| D1 | `_docs/02_document/components/02_typescript_package/description.md` §5 | Lists Key Dependencies as "none". Actual: `@noble/hashes` 2.4.0 since `1a15ce3` |
| D2 | Both component descriptions §2 | `BinaryPacker.unpack` is documented as "scheme, bytes → row or error". Actual: `(bytes, ...handlers)` → dispatch result, with the row passed to the handler. TS error types list "trailing bytes", which TS does not have (C1) |
| D3 | `_docs/01_solution/schema.md` | The TS snippets use a removed API: `packet([...])`, `u8("type")` string names, `flags([...])` without an anchor, a free `pack(target, …)`. `scheme.test.ts:84-88` asserts that `Packet` and `export function pack` do not exist. The type table omits `bool`, `group`, `sized`, `u2`, `bits`, `utf8`, `list`, `dict`. "Optional fields use `undefined` in TypeScript": TS treats `null` as absent too, and the README uses `null` |
| D4 | `_docs/02_document/architecture.md` §4 "pack refuses an integer that does not fit" | TS does not (L1) |
| D5 | README "Repeat"/"Sized" sections ("names the field"), `languages.md` ("a short-packet error names the same field") | Python names the id (C2) |
| D6 | README "Bool" ("A `bool` inside `flags` sets its bit") | TS and C# also set the bit for `false` (L2) |
| D7 | `_docs/02_document/contracts/library/pack-session.md` Unpack failure "—" | Both packages return a fake `ShortPacket("",1,0)` before open (C1) |
| D8 | Component test specs "Read the golden fixture file. Do not copy the hex into a second list" | `packbin.test.ts:23`, `scheme.test.ts:21` and the Python position tests hardcode `4001000065cd1d00a3e1110100` next to the fixture read |
| D9 | `baseline_metrics.md` TS complexity row | Undercounts: lizard misparses `walker.ts` / `fields.ts` (S29) |

---

## (d) Candidate changes

Local ids B1…; the parent assigns the final C-ids. Points: 1/2/3/5.

### B1: TS pack rejects values that do not fit the field
- **File(s)**: `typescript/src/kinds.ts`, `typescript/src/walker.ts`, `typescript/tests/packbin.test.ts`
- **Problem**: `writeInt` writes through `DataView`, which wraps modulo 2^n and truncates fractions. `writeFloat` turns f32 overflow into `Infinity`. `Number(...)` turns non-numbers into NaN. All of this happens silently (L1).
- **Change**: Before writing, require an integer (or `bigint` for 64-bit) inside the kind's range; otherwise throw `RangeError` naming the field, as Python already does. Floats must be `number`, not coerced strings.
- **Rationale**: Silent corruption of coordinates is the failure the problem statement is about ("the map applies a shifted coordinate").
- **Constraint Fit**: Restores architecture §4. AC-1..3 golden bytes are unchanged (in-range values). Pack throws before writing, as it does for a missing field.
- **Risk**: low (callers relying on wrap start getting errors, which is intended)
- **Dependencies**: None · **Points**: 2

### B2: One `bool` presence rule across languages (TS first)
- **File(s)**: `typescript/src/fields.ts` (`bitOn`), `typescript/src/kinds.ts` (`present`), `typescript/src/walker.ts` (`bool` cases), `typescript/src/fields.ts` (`validateFieldIds`); tests
- **Problem**: TS sets the bit for `false` and always unpacks `true` (L2). Python packs `false` as absent. Same row, different bytes.
- **Change**: A `bool` bit is set only for `true`. Unpack sets `true` only when the bit is set. A `bool` outside a flag bit is rejected at construction, because it carries no bytes.
- **Rationale**: AC-3 (identical bytes); the README Bool section.
- **Constraint Fit**: Needs a **user decision**: C# (`Walker.cs:39`) behaves like TS, so this is a cross-language contract choice and should be fixed in all packages from one decision. Position golden is unaffected.
- **Risk**: medium (wire behavior change for `false` rows)
- **Dependencies**: None · **Points**: 2 (TS part)

### B3: TS flag bits inside groups are found
- **File(s)**: `typescript/src/fields.ts` (`collectFlagBits`), tests
- **Problem**: `collectFlagBits` does not recurse into `group`, so a flag byte inside a nested group is written `00` and its fields are dropped (L3).
- **Change**: Collect bits wherever the flag byte's bits can sit (group, when, repeat, times), or record each byte's bits on the handle at `flatten` time so no search is needed.
- **Rationale**: Silent data loss.
- **Constraint Fit**: Same bytes for every currently-working scheme.
- **Risk**: low · **Dependencies**: None · **Points**: 1

### B4: Reject a ninth flag bit at construction (TS and Py)
- **File(s)**: `typescript/src/fields.ts` (`flags`, `flagByte.bit`), `python/src/packbin/_nodes.py` (`flags`)
- **Problem**: TS accepts 9+ bits and writes undecodable bytes. Py `flags()` fails only at pack, with a cryptic message (L4).
- **Change**: `flags`/`flagByte.bit` with more than 8 children fails at declaration, naming the anchor. Py `flag_byte.bit` already does this.
- **Rationale**: Schema: a flags field is one `u8`.
- **Constraint Fit**: Construction errors match the scheme-field-order AC style. No byte change.
- **Risk**: low · **Dependencies**: None · **Points**: 1

### B5: TS rejects ambiguous member names at scheme construction
- **File(s)**: `typescript/src/index.ts` (`scheme`), `typescript/src/fields.ts`
- **Problem**: Values are one flat namespace. A nested group member with the same name as a parent field silently overwrites it on pack and unpack (L5, S32).
- **Change**: `scheme()` fails when two value fields in the same flattened namespace share a name, and states the rule in the README.
- **Rationale**: Turns a hidden convention into an explicit construction error.
- **Constraint Fit**: Keeps the tested flattening ("flattens a nested group"). No byte change.
- **Risk**: low (rejects only schemes that already corrupt data)
- **Dependencies**: None · **Points**: 1

### B6: TS keeps flag-byte values out of the unpacked row
- **File(s)**: `typescript/src/walker.ts` (`flagByte` case)
- **Problem**: The unpacked row gets a `""` (or `"motion"`) key holding the raw flag byte (L13).
- **Change**: Keep the flag value only in the walk's flag map.
- **Rationale**: AC-2 says the result holds the fields. Other packages do not expose it.
- **Constraint Fit**: No byte change. Confirm no caller reads `row.motion` (no test does).
- **Risk**: low · **Dependencies**: None · **Points**: 1

### B7: TS resolves count and `when` references once, in their own id scope
- **File(s)**: `typescript/src/fields.ts`, `typescript/src/walker.ts`
- **Problem**: `nameById(allFields, id)` runs a depth-first search on every call and binds to the first id match from the top of the scheme, which is wrong inside unanchored groups. `===` fails between `bigint` and `number` (L6, P2).
- **Change**: At `scheme()` time, resolve each `eq`/count id to the field in the same id scope that precedes it, and fail if it is not earlier ("tests a field already read", as Python's `seen` does). Compare 64-bit values numerically.
- **Rationale**: Correctness of `when`/`times`/`packed` in nested scopes; also removes per-call searches.
- **Constraint Fit**: The route fixture and existing tests keep their bytes. The construction error for a forward reference matches the schema ("tests a field already read").
- **Risk**: medium · **Dependencies**: None · **Points**: 3

### B8: `repeat` stops when an iteration reads nothing (TS and Py)
- **File(s)**: `typescript/src/walker.ts:310-320`, `python/src/packbin/_unpack.py:269-275`
- **Problem**: A body that reads 0 bytes loops forever, and wire data decides when that happens (L8).
- **Change**: Reject at construction a `repeat` whose body can be zero-width, or end the loop with an error when an iteration does not advance the offset. The parent should pick one rule for all six languages.
- **Rationale**: Removes a receiver hang.
- **Constraint Fit**: AC-7 unchanged.
- **Risk**: low · **Dependencies**: None · **Points**: 2

### B9: Python errors name the member, like the other languages
- **File(s)**: `python/src/packbin/_nodes.py` (`_pair` keeps `_Hit.key`; nodes get a `name`), `_unpack.py`, `_pack.py`, tests asserting `"1"`, `"8"`, …
- **Problem**: `ShortPacket.field` is `str(field_id)`, and `""` for list, dict and flags (C2, D5).
- **Change**: Store the accessor's member key on each node and use it in `ShortPacket.field` and in pack error messages. A list/dict error names the list/dict member.
- **Rationale**: `languages.md` ("a short-packet error names the same field"), AC-8, README.
- **Constraint Fit**: Public error value changes before the `v0.2.0` tag. **User confirmation** needed for the exact string (TS uses camelCase member, C# PascalCase; Python would give the snake_case member).
- **Risk**: medium (callers matching `"1"`) · **Dependencies**: None · **Points**: 2

### B10: Python split-form `flag_byte` works in a Scheme
- **File(s)**: `python/src/packbin/_nodes.py:416-419` (`_validate_order`), new tests
- **Problem**: Bit fields are counted twice, so every split-form scheme fails construction (L9). There are no tests.
- **Change**: `_FlagByte` takes no id; each `_FlagBit` validates its field at its own position, as TS does.
- **Rationale**: Exported, documented feature (schema.md "Split form") that cannot be used.
- **Constraint Fit**: Ids still follow the schema order rule.
- **Risk**: low · **Dependencies**: None · **Points**: 1

### B11: Python repeat/times lists start empty
- **File(s)**: `python/src/packbin/_unpack.py` (`_append`, `_Repeat`, `_Times`)
- **Problem**: A row default (`lat = 0`) becomes the first list item (L10).
- **Change**: The first value a repeat or times run writes replaces whatever the fresh row held, so the result has exactly one item per group.
- **Rationale**: AC-7 ("one value per complete group").
- **Constraint Fit**: No byte change.
- **Risk**: low · **Dependencies**: None · **Points**: 1

### B12: Python repeat/times handle container children per item
- **File(s)**: `python/src/packbin/_pack.py` (`_Repeat`, `_Times`, `_child_on`)
- **Problem**: `repeat` calls `.get` on `_Flags`/`_When`/`_Group` and crashes. Flag presence inside `times` ignores the item index (L11).
- **Change**: Resolve every leaf, including leaves under flags, groups and when, through the per-item value, then compute flag bits from those values.
- **Rationale**: The schema allows any fields inside repeat/times; TS already does this per item.
- **Constraint Fit**: Route fixture unchanged.
- **Risk**: medium · **Dependencies**: B19 if done after the split; otherwise None · **Points**: 2

### B13: TS list/dict elements of kind `group`/`flags`
- **File(s)**: `typescript/src/walker.ts` (`list`, `dict` cases)
- **Problem**: Group elements read from and write to the parent value map, so pack throws and unpack yields `undefined` (L7).
- **Change**: Pack each element against the item's own value map (`flattenValues(item)`), and return the element's value map (or a scalar for leaf elements) on unpack, as Python does.
- **Rationale**: strings-lists-dicts restriction: elements may be any field except `repeat`.
- **Constraint Fit**: Existing list/dict fixtures (handoff `user`, `nested`) keep their bytes.
- **Risk**: medium · **Dependencies**: B7 (id scope) · **Points**: 3

### B14: Python list/dict element rows match the declared accessor style
- **File(s)**: `python/src/packbin/_unpack.py:136-140`, README
- **Problem**: Element rows are always `dict`, so attribute-accessor elements fail on unpack (L12).
- **Change**: Either document "element rows are dicts; use item accessors" and reject attribute accessors in element groups at construction, or accept an element row type. **User decision**.
- **Rationale**: Today the failure is an `AttributeError` from deep inside unpack.
- **Constraint Fit**: No byte change.
- **Risk**: low · **Dependencies**: None · **Points**: 1 (doc + construction check)

### B15: npm package ships JavaScript and type declarations
- **File(s)**: `typescript/package.json`, a new `typescript/tsconfig.json`; `.github/workflows/publish-inside.sh` and `publish-gate.test.sh` (CI scope; coordinate with that scanner)
- **Problem**: The package exports `./src/index.ts`. Plain Node refuses type stripping under `node_modules` (reproduced). `tsc` consumers need `allowImportingTsExtensions`. Only bundlers such as Vite work (C6).
- **Change**: Compile `src` to `dist/*.js` + `*.d.ts` in the publish path and point `exports`/`types` at them. Keep the tests on the sources.
- **Rationale**: The component doc and README name Node as a consumer.
- **Constraint Fit**: AC-12/13 (publish from tag, same commit) unchanged. Adds a dev-time build but no runtime dependency. Browser safety unchanged.
- **Risk**: medium (publish pipeline) · **Dependencies**: None · **Points**: 3

### B16: TS error results carry their kind; sentinels go away (TS and Py)
- **File(s)**: `typescript/src/kinds.ts`, `walker.ts`, `index.ts`; `python/src/packbin/_scheme.py`, `_session.py`, `_unpack.py`
- **Problem**: Trailing bytes, an empty buffer, a duplicate dict key and session-not-open are told apart by sentinel values (`field:""`, `needed:0`). Py uses `TypeMismatch(expected=-1)` (C1, S20, S32).
- **Change**: TS gets a `TrailingErr` (or a `kind` discriminant) like the other five languages. The session-not-open and duplicate-key cases get named results (or the contract names the reused error). Drop `expected=-1` or make it optional.
- **Rationale**: Callers cannot tell the errors apart without reading the code.
- **Constraint Fit**: AC-8/9 still met. Public API change before `v0.2.0`. **User approval** needed, ideally decided for all six packages at once.
- **Risk**: medium · **Dependencies**: None · **Points**: 2

### B17: Unpack returns errors for malformed wire data instead of throwing (TS and Py)
- **File(s)**: `typescript/src/kinds.ts:285-298`, `walker.ts:38-53,345`; `python/src/packbin/_unpack.py:119,178,277-321`
- **Problem**: Invalid UTF-8 and an absent borrowed count throw from unpack. TS `bits` silently yields `[]` (L14).
- **Change**: Return an unpack error naming the field, with no row. Use one rule for an absent count (error) in pack and unpack.
- **Rationale**: "Unpack returns an error and 0 values" (AC-8 pattern). A receiver should not need `try` around `unpack`.
- **Constraint Fit**: Needs the error shape from B16.
- **Risk**: low · **Dependencies**: B16 · **Points**: 2

### B18: Split the TS walker into per-kind functions with one kind table
- **File(s)**: `typescript/src/walker.ts`, `typescript/src/fields.ts`, `typescript/src/kinds.ts`
- **Problem**: `unpackFields` (~70 CCN, 216 lines) and `packFields` (43) are single switches. The leaf-kind lists repeat in 5 places (S16). `appendRepeat` appears 11×, slice builders 2×, count-prefix writes 3×. Dead `flags` cases (S01, S03, S05, S06, S17, S29).
- **Change**: One pack function and one unpack function per kind, dispatched from a table keyed by `kind`, plus a walk-context object for `(allFields, flagBytes, values/cursor)`. Shared helpers for "store value" and "u16 count". Same behavior. This mirrors what C++ did this loop (CCN ≤ 23).
- **Rationale**: Each new kind currently touches 8 places. Every bug above sits in this switch.
- **Constraint Fit**: Per-package only (ADR-001 kept: no shared walker). Golden, handoff and session bytes are unchanged; the existing 44 tests are the guard.
- **Risk**: medium · **Dependencies**: do after B1–B7 and B13 (bug fixes land with tests first) · **Points**: 5 (split into pack 3 + unpack 3 if the parent prefers ≤3-point tasks)

### B19: Split the Python walker into per-node functions and remove its duplication
- **File(s)**: `python/src/packbin/_pack.py`, `_unpack.py`, `_nodes.py`
- **Problem**: `unpack_nodes` CCN 57, `pack_nodes` 48. `_unpack_leaf` duplicates the leaf branches. `_is_leaf` 2×, `_builtin_*` 4×, `at` closures 2×. Mixed exception types (S01, S06, S17, S29, S18).
- **Change**: Dispatch by node type to small per-node pack/unpack functions (or methods on the node classes), with one leaf reader used by both the walker and list/dict elements, and one `MAX_COUNT`. Same behavior.
- **Rationale**: Same as B18. AC-10 Python ≤ 2 s must still hold (keep the dispatch cheap).
- **Constraint Fit**: ADR-001 (per package). Bytes unchanged; tests are the guard; re-run the NFR test.
- **Risk**: medium · **Dependencies**: after B9–B12 · **Points**: 5 (or pack 3 + unpack 3)

### B20: Remove TS dead code
- **File(s)**: `typescript/src/walker.ts:216-218,315,423-434`, `typescript/src/index.ts:123-124`, `typescript/src/kinds.ts:5`, `typescript/src/session-pad.ts:76` (make it module-private)
- **Problem**: Unreachable `flags` cases (wrong if reached), a no-op branch, and stale public types `UnpackOk`/`UnpackResult` that nothing returns (S07).
- **Change**: Delete them, after checking that README and drivers do not import `UnpackOk`/`UnpackResult` (grep: README mentions `UnpackResult` only in the C++ mapping table).
- **Rationale**: Dead code, and misleading public types.
- **Constraint Fit**: The public type removal is part of the `v0.2.0` API; no runtime change.
- **Risk**: low · **Dependencies**: None (or folded into B18) · **Points**: 1

### B21: Python `PackSession` cannot be built around a wrong-size seed
- **File(s)**: `python/src/packbin/_session.py:20-32`
- **Problem**: The public `__init__` skips the 32-byte rule (L15).
- **Change**: Validate in `__init__` (raise), or make construction go only through `load`.
- **Rationale**: Contract: "length other than 32 creates 0 sessions".
- **Constraint Fit**: Session bytes unchanged.
- **Risk**: low · **Dependencies**: None · **Points**: 1

### B22: Python star-import does not shadow builtins
- **File(s)**: `python/src/packbin/__init__.py:36-71`
- **Problem**: `__all__` exports `bool`, `bytes`, `dict`, `list`, so `from packbin import *` replaces the caller's builtins (S32).
- **Change**: Keep the attributes (`packbin.dict`, `from packbin import dict as map_field` as the README does) but leave these four out of `__all__`. Renaming them is a bigger API decision and is not proposed.
- **Rationale**: A hidden hazard for script users.
- **Constraint Fit**: Explicit imports and the README examples are unchanged.
- **Risk**: low · **Dependencies**: None · **Points**: 1

### B23: Tests for the gaps the probes found, and a real TS type-check
- **File(s)**: `typescript/tests/*`, `typescript/package.json` (`test` script), `python/tests/*`
- **Problem**: No tests cover split form, list/dict of group, bool `false`, out-of-range ints (TS), flags in a nested group, repeat with a zero-width body, or repeat with row defaults (Py). `src` is type-checked only through the compile-fail test, which passes on *any* `tsc` error. No coverage measurement (baseline).
- **Change**: Add the regression tests with each fix (B1–B14). Add an explicit `tsc --noEmit` of `src` to `npm test`, and make the compile-fail test assert `TS2554`.
- **Rationale**: Quality thresholds (AC scenario coverage; a type-check gate equivalent to CI parity).
- **Constraint Fit**: Test-only.
- **Risk**: low · **Dependencies**: travels with B1–B14 · **Points**: 2 (type-check + compile-fail assertion; regression tests are counted inside each fix)

### B24: Fix the documentation drift
- **File(s)**: `_docs/02_document/components/02_typescript_package/description.md`, `03_python_package/description.md`, `_docs/01_solution/schema.md`, `_docs/02_document/contracts/library/pack-session.md`, README (TS accessor-name rule, TS flat-row rule, error naming)
- **Problem**: D1–D8.
- **Change**: Document the `@noble/hashes` dependency; the real `unpack(bytes, ...handlers)` shape and error types; current TS snippets in schema.md (scheme/accessor API, anchored flags); the not-open session result; how TS derives a field name from the accessor's source text; that TS hands a plain flat object; that Python element rows are dicts.
- **Rationale**: schema.md is the language contract, and its TS example no longer compiles.
- **Constraint Fit**: Docs only. Wording waits on decisions in B2/B9/B16.
- **Risk**: low · **Dependencies**: B2, B9, B16 for the final wording · **Points**: 2

### Rejected ideas

| # | Idea | Reason |
|---|------|--------|
| R1 | Shared walker, shared error types or shared crypto code between TS and Python (or with any other package), or a generated walker | Violates ADR-001 and module-layout rule 2; LESSONS 2026-09-23 "a shared walker would contradict ADR-001"; also "no code generator in the first release" |
| R2 | Replace Python's pure ChaCha20/HKDF with `cryptography` | Adds the package's first runtime dependency for a path outside AC-10. Current code matches the C# vector (`test_ac1_ciphertext_matches_csharp`) |
| R3 | Replace TS `session-pad.ts` with `@noble/ciphers` | New dependency with no named requirement. The hand-written block function is tested against the C# ciphertext |
| R4 | Replace TS `memberName` source-text parsing with string names | Breaks the one-accessor API that matches C# expressions and Python probes. Documented instead (B24) |
| R5 | Remove the per-item `{...values}` copies for speed | Measured 19 ms for a 20 000-item repeat; no AC pressure. B18 may drop them as a side effect |
| R6 | Split `walker.ts` / `fields.ts` / `_nodes.py` for file length alone | All under the 500-line cap (458/426/424). Splits happen only through B18/B19 |
| R7 | Give Python a nested-object `group` like TS (or remove it from TS) to unify C3 | A product/API decision across six packages, not a refactor. Recorded as design contradiction C3 for the parent's cross-package review |

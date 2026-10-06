# Python refuses a member name used twice in one scope

**Task**: AZ-2245_python_duplicate_member_name_refused
**Name**: Python duplicate member names refused at construction
**Description**: `Scheme(...)` raises `ValueError` naming the member when two fields of one scope use the same accessor name (also once outside and once inside a `repeat` or `times` round), unless one of the two sits under a `when`; a flag byte handle is not a name and a `list` or `dict` element is a scope of its own. TypeScript has refused the same schemes since AZ-2188.
**Complexity**: 2 points
**Dependencies**: AZ-2188_typescript_duplicate_member_names (the rule, copied in behaviour, not in code); AZ-2230_python_split_bits_scheme_order (`Scheme(...)` binds flag bits before the check walks the fields)
**Component**: python
**Tracker**: AZ-2245
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment, round 2 (`_docs/loops/loop16/assessment16.md` X3), owner decision A on 2026-10-06. A Python row holds one value per accessor name, so two fields that use one name lose a value. TypeScript refuses this at construction (AZ-2188); Python builds it. Observed on `35544ed` (Python 3.14.6, `git archive` export):

| Scheme (`dict` row, accessors `lambda r: r["x"]`) | Today |
|---|---|
| `u8 x; u8 x` | builds; `{x: 5}` packs `010505`; unpack of `010708` gives `{x: 8}` (the 7 is gone) and that row packs again as `010808` |
| `u8 x; u8 c; times(c, u8 x)` | builds; `{x: 5, c: 2}` packs `0105020505`; unpack of `0105020708` gives `{x: [7, 8], c: 2}` (the outer 5 is gone) and that row does not pack: `TypeError: 0: expected int, got list` |
| `u8 x; repeat(u8 x)` | builds; unpack of `01050607` gives `{x: [6, 7]}`; packing it raises the same `TypeError` |
| `u8 n; times(n, u8 v); u8 m; times(m, u8 v)` | builds; unpack of `01020a0b010c` gives `{n: 2, v: [12], m: 1}` (only the last list); packing that row raises `IndexError: list index out of range` |
| `u8 x; flags(u8 x)` | builds; `{x: 3}` packs `01030103` |
| `u8 x; group(u8 x)` | builds; `{x: 3}` packs `010303`; unpack of `010305` gives `{x: 5}` |
| `m; m.bit(u8 x); u8 x` (split flag bit) | builds; `{x: 3}` packs `01010303` |
| `u8 x; utf8 x`, `u2` with two slots named `x`, `sized x` twice, `bits x` with `packed x`, `be(u16 x); u8 x`, `u8 xs; list(xs, ...)`, `list(xs, ...)` then `dict(xs, ...)`, attribute accessors `r.x` twice, `r[0]` twice | all build |

Same-scope duplicates also build under `flags`, in a `group`, and for every field kind, because nothing compares accessor names: `_pair` in `python/src/packbin/_nodes.py` finds the kind (`attr` or `item`) and the key of each accessor and then keeps only two closures. TypeScript, which refuses the same shapes, builds the legal ones and gives the same message for each (probed on `35544ed` with `node --experimental-strip-types`: `member x: declared twice in one scope; a row holds one value per name, so one would be lost` for `u8 x; u8 x`, for `u8 x; times(c, u8 x)`, for `u8 x; flags(u8 x)` and for a list named like a scalar; `when` branches that share a name, `u8 shape` with `when(u16 shape)` and two declarations in one `when` body build).

Two things in the ticket do not exist in Python. A Python `group(anchor, ...)` has no accessor and no name of its own, and its members are read from and written to the row around it (no nested row, no flattening), so TypeScript's "group named like one of its own members" and "declared inside a group and outside it" have no Python counterpart: a name in a `group` and outside it is the same-scope case above (`u8 x; group(u8 x)`). And a flag byte handle (`flag_byte()`) carries no accessor, so it can never collide with a data name.

## Outcome

- `Scheme(...)` raises `ValueError` when two fields of one scope have the same accessor name, with the message `member x: declared twice in one scope; a row holds one value per name, so one would be lost` (`x` is the accessor key: `x` for `r["x"]` and `r.x`, `0` for `r[0]`).
- Exemption, as in TypeScript: when one of the two declarations sits under a `when`, no error. Two or more `when` branches may share a member (two arms of a chain, in a round or outside), and a name declared once outside any `when` and once under one still builds.
- A scope is the top level, or one `list` or `dict` element. `repeat`, `times`, `flags`, `when`, `group`, and a flag bit's field share the scope around them, so a name used outside a round and inside it is refused. A `list` or `dict` element has a namespace of its own and may reuse the names of the row around it. A `list` or `dict` accessor is itself a name in the scope that holds it.
- A flag byte handle is never a name: one handle read in two scopes, or in two schemes, builds as today.
- A scheme with no duplicate name builds and packs and unpacks byte for byte as today.

## Scope

### Included
- A construction check run by `Scheme(...)` after every check that exists today (`_validate_order`, `_bind_flag_bits`, `_validate_round_nesting`), so a scheme refused today keeps its message and a scheme with a second fault reports the old one. It walks the bound fields (`Scheme._fields`), every field kind that has an accessor (scalars with `be`, `bool`, `bytes`, `utf8`, `sized`, `bits`, `packed`, each `u2` slot, `list`, `dict`), and recurses into each `list` and `dict` element as a scope of its own, at any depth.
- Keeping the `(kind, key)` of an accessor on its field, so the check can compare. `be(...)` rebuilds a `_Scalar` field by field and must carry it.
- Tests for the probes below, and the text that describes the new refusal (README, the Python component description and its `tests.md`; sentences below).

### Excluded
- Java (AZ-2246) and Rust (AZ-2247): their own tickets, own scope rules.
- Two declarations inside the same `when` body: they still build, as in TypeScript (AZ-2188 flagged concern); `{k: 1, v: 7}` packs `01010707` and unpack of `01010708` gives `{k: 1, v: 8}`.
- An attribute accessor and a key accessor with the same key (`r.x` and `r["x"]`): they are different accessors and build. On a `dict` row only `r["x"]` works and on a plain class only `r.x`; a row class that maps both onto one slot is not something the scheme can see (Risk 2).
- Accessors that are identity (`lambda r: r`, the element of a list of scalars): they have no name, so any number of list elements may use one.
- Renaming rows, changing how rounds store their lists (`_store_lists` keeps sharing one list between arms of two `when`s), and any change to pack or unpack.

## Acceptance Criteria

Result column text comes from `35544ed`; the refused results come from a throwaway version of the check on a scratch copy (`_validate_names` called last in `Scheme.__init__`), and the worker re-derives them from a real run.

**AC-1: The same name twice at one level**
Given `Scheme(1, dict, u8(0, lambda r: r["x"]), u8(1, lambda r: r["x"]))`
When it is built
Then it raises `ValueError` with the message `member x: declared twice in one scope; a row holds one value per name, so one would be lost` (today it builds and `{x: 5}` packs `010505`).

**AC-2: Outside a round and inside it**
Given `u8(0, x)`, `u8(1, c)`, `times(2, 1, u8(2, x))`; and `u8(0, x)`, `repeat(1, u8(1, x))`
When each is built
Then each raises `ValueError` with the AC-1 message for `x` (today both build; the first unpacks `0105020708` to `{x: [7, 8], c: 2}` and the row cannot be packed again, the second unpacks `01050607` to `{x: [6, 7]}`).

**AC-3: Two rounds sharing a name**
Given `u8(0, n)`, `times(1, 0, u8(1, v))`, `u8(2, m)`, `times(3, 2, u8(3, v))`
When it is built
Then it raises `ValueError` with the AC-1 message for `v` (today it builds and `01020a0b010c` unpacks to `{n: 2, v: [12], m: 1}`).

**AC-4: Under `flags`, in a group, in a flag bit**
Given each of `u8(0, x), flags(1, u8(1, x))`; `u8(0, x), group(1, u8(1, x))`; `flags(0, bool(0, on)), flags(1, bool(1, on))`; and `m = flag_byte()` with `m, m.bit(u8(0, x)), u8(1, x)`
When each is built
Then each raises `ValueError` with the AC-1 message for `x` (or `on`); today all four build and `{x: 3}` packs `01030103`, `010303` and `01010303` for the first, second and fourth.

**AC-5: Every kind of field counts, and so does a list or dict accessor**
Given `u8 x; utf8 x`, a `u2` with two slots named `x`, `u8 n; sized x; sized x`, `u8 n; bits x; packed x` (width 1), `be(u16 x); u8 x`, `u8 xs; list(xs, u8)` (element accessor `lambda r: r`), `list(xs, ...); dict(xs, ...)`, a class row with attribute accessors `r.x` twice, and `u8(0, lambda r: r[0]), u8(1, lambda r: r[0])`
When each is built
Then each raises `ValueError` with the AC-1 message naming the key (`x`, `xs`, `0`); today all of them build.

**AC-6: Names under different `when`s are allowed**
Given `u8(0, kind)`, `when(1, eq(0, 0), u8(1, shape))`, `when(2, eq(0, 1), u16(2, shape))`; the same two arms inside `repeat(0, u8(0, kind), when(1, ...), when(2, ...))`; `u8(0, kind)`, `u8(1, shape)`, `when(2, eq(0, 1), u16(2, shape))`; and `u8(0, k)`, `when(1, eq(0, 1), u8(1, v), u8(2, v))`
When each is built, packed and unpacked
Then all four build, and the bytes are unchanged: `{kind: 1, shape: 300}` packs `01012c01`; `{kind: [0, 1], shape: [5, 300]}` packs `010005012c01` and unpacks back; `{kind: 0, shape: 7}` packs `010007`; `{k: 1, v: 7}` packs `01010707` and `01010708` unpacks to `{k: 1, v: 8}` (the same-body case is the known gap of AZ-2188, unchanged here).

**AC-7: A list or dict element is a scope of its own**
Given `u8(0, a)`, `list(xs, group(0, u8(0, a)))` and `u8(0, a)`, `dict(m, group(0, u8(0, a)))`; `list(xs, group(0, u8(0, a), u8(1, a)))`; the same pair inside `list(xs, list(lambda r: r, group(...)))`; and `list(xs, u8(0, lambda r: r))` beside `list(ys, u8(0, lambda r: r))`
When each is built
Then the first two build (`{a: 7, xs: [{a: 1}, {a: 2}]}` packs `010702000102`; `{a: 7, m: {k: {a: 1}}}` packs `0107010001006b01`; both unpack to the row they were packed from), the next two raise the AC-1 message for `a` (today they build), and the last builds (`{xs: [1], ys: [2]}` packs `01010001010002`).

**AC-8: A flag byte handle is not a name**
Given `m = flag_byte()` with `u8(0, c), m, m.bit(u8(1, a)), times(2, 0, m, m.bit(u8(2, b)))`; `m, m.bit(u8(0, a)), m, m.bit(u8(1, b))`; and the handle `m` in two schemes `Scheme(1, dict, m, m.bit(u8(0, x)))` and `Scheme(2, dict, m, m.bit(u8(0, x)))`
When each is built and packed
Then all build and pack as today: `{c: 2, a: 5, b: [7, None]}` gives `01020105010700`, `{b: 9}` gives `01000109`, and `{x: 5}` gives `010105` and `020105`.

**AC-9: A scheme refused today for another reason keeps its message**
Given `u8(0, x), u8(2, x)`; `m.bit(u8(0, x)), u8(1, x)` with the handle never read; `u8(0, x), repeat(1, u8(1, x), repeat(2, u8(2, y)))`; `when(0, eq(1, 1), u8(0, x)), u8(1, x)`; `u8(0, x), group(1), u8(1, x)`; and a flag byte with nine bits, one named `x`, after `u8(0, x)`
When each is built
Then each raises the message it raises today: `field id 2 is not the next order 1`, `flag bit 0: its flag byte is not read earlier in the same scope`, `repeat 2 is inside a repeat or times round; a round cannot hold another repeat or times`, `when 0: eq names field id 1 is allowed only if declared earlier in the same scope`, `group 1 has no fields, so it can never carry a value`, `flags already has 8 bits`.

**AC-10: Schemes without a duplicate name are unchanged**
Given every `Scheme(...)` in the 326 Python tests, the 18 Python blocks of the README, `.github/workflows/drivers/handoff.py` (`USER`, `NESTED`, `POSITION`, `BOOLFLAG`, `BITWHEN`, `listgroup`, `dictgroup`, `listflags`) and `position.py`, and the Python hostile vectors of `fixtures/hostile/cases.txt`
When they are built and run
Then none is refused and every byte is unchanged: the golden position `4001000065cd1d00a3e1110100`, the session vector `b55d0a29c56c203712b241232e`, and the pack output of the nine driver schemes. A randomised differential (3,000 schemes of `u8`, `u16`, `utf8`, `flags`, `when`, `group`, `repeat`, `times`, `list` of group or scalar, split flag bits, names drawn from five) gives, on the throwaway check: 1,739 schemes accepted, each with identical pack and unpack results against `35544ed` (four rows and four packets per scheme); 1,261 refused, each one flagged by an independent oracle of the TypeScript rule and each with the AC-1 message; none refused for another reason. The worker repeats this differential and the results must agree.

## Non-Functional Requirements

**Compatibility**
- Packet bytes of every scheme that still builds do not change; nothing in pack or unpack changes. A scheme that built with a duplicate name now fails at construction. None of the 326 tests, the 18 README blocks or the nine driver schemes in the repository uses a duplicate name (zero refusals when the check was logged over all of them).

**Reliability**
- The refusal comes from `Scheme(...)`, before any pack or unpack, and names the member. No behaviour of `with_limits` or `on` changes (`with_limits` copies a scheme that was already checked).

**Performance**
- One walk of the fields at construction; no cost per pack or unpack.

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1 | `u8 x; u8 x` | `ValueError` with the exact message (builds today) | `python/tests/test_duplicate_names.py` (new) |
| AC-2 | `times` and `repeat` bodies named like an outer member | the same message for `x` | `python/tests/test_duplicate_names.py` |
| AC-3 | two `times` bodies sharing `v` | the same message for `v` | `python/tests/test_duplicate_names.py` |
| AC-4 | `flags`, `group`, two `flags` of `bool`, split flag bit | the same message | `python/tests/test_duplicate_names.py` |
| AC-5 | each field kind, `list` and `dict` accessor, attribute and integer-key accessors | the same message naming `x`, `xs` or `0` | `python/tests/test_duplicate_names.py` |
| AC-6 | `when` arms, in a round, once outside and once under `when`, twice in one `when` body | build; the listed bytes; `01010708` unpacks to `{k: 1, v: 8}` | `python/tests/test_duplicate_names.py` |
| AC-7 | element named like the row, duplicate inside an element, nested element, identity elements | build with the listed bytes, or refuse | `python/tests/test_duplicate_names.py` |
| AC-8 | a handle in two scopes, read twice, in two schemes | build with the listed bytes | `python/tests/test_duplicate_names.py` (the AZ-2230 tests keep their own) |
| AC-9 | six schemes with a second fault | the six existing messages | `python/tests/test_duplicate_names.py` |
| AC-10 | the existing suite and the differential | 326 tests pass; differential agrees | `python/tests/` (whole suite) |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-10 | `fixtures/golden.hex`, `.github/workflows/drivers/position.py` and `handoff.py` (`user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `listgroup`, `dictgroup`, `listflags`, `session`) | pack | unchanged hex, 0 mismatched bytes | Compatibility |
| AC-10 | `language-pair.sh` rings, Python as producer and as consumer | unchanged run | 0 mismatched bytes | Compatibility |
| AC-10 | the 18 Python blocks of the README (each runs after `from packbin import *`) | build and run | none refused | Compatibility |

## Constraints

- ADR-001: Python only; no shared walker, no cross-package import. TypeScript's `member-names.ts` is the rule's source for the scope and exemption behaviour, not code to port.
- Files at or under 500 lines (`_nodes.py` is 426, `_validate.py` 108, `_scheme.py` 135, `_pack.py` 311, `_unpack.py` 432). The check goes in `_validate.py` or a small new module, called from `Scheme.__init__` after `_validate_round_nesting`.
- Error kind and label of existing errors unchanged (decision C15): the six messages of AC-9 keep their text, and the new check runs after all of them. The new error is `ValueError`, the type every other construction refusal in Python uses.
- The wire bytes of every row that packs and unpacks today are unchanged. No public API change: the accessor name is kept on the field (for example as an attribute of the `get` closure, or a field of the node that `be()` copies).
- The messages in AC-1 to AC-5 are the TypeScript wording; Python names the member by its accessor key, not by field id (a `list` or `dict` accessor has no field id).
- Probes in the Problem table and AC-6 to AC-9 (builds, bytes, today's messages) were run on `35544ed`; the refusal results and the differential come from a throwaway check on a scratch copy. The worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller scheme with a duplicate name stops building**
- *Risk*: a scheme that builds (for example one whose two fields always hold the same value, or a `u8 x` beside a `repeat` of `u8 x`) is refused after an upgrade. None in the repository.
- *Mitigation*: such a scheme packs one value into two fields and unpacks only the last (AC-1, AC-2); the message names the member; the README upgrade note says to rename one.

**Risk 2: Attribute and key accessors with one key are not compared**
- *Risk*: `r.x` and `r["x"]` count as different names, so a row class that stores both in one slot, with a duplicate, still builds and loses a value. Python cannot see how a row class maps them.
- *Mitigation*: the common cases (all accessors `r["x"]` on a `dict` row, all `r.x` on a class) are covered. STOP-and-report option for the owner: match by key only, which would also refuse a legal mixed scheme. Not chosen here; reported.

**Risk 3: The key is lost when `be()` rebuilds a field**
- *Risk*: `be(field)` copies a `_Scalar` field by field; a name stored on the node and not copied would let `be(u16 x); u8 x` slip through.
- *Mitigation*: AC-5 tests it; keeping the name on the `get` closure (copied with it) avoids the problem.

**Risk 4: Same-body `when` duplicates and outside-plus-`when` duplicates still build**
- *Risk*: as in TypeScript, `when(.., u8 v, u8 v)` and `u8 s` with `when(.., u16 s)` build and can lose a value.
- *Mitigation*: the owner's decision is "same exemption as TypeScript"; recorded in Excluded and AC-6.

## Owner decision (2026-10-06)

DECIDED, assessment round 2 X3 option A (the recommendation, "implement everything now"): refuse a member name declared twice when the scheme is built, in Python as TypeScript does, with the same exemption for names that sit under different `when`s (the cross-language rule is "same scheme, same result"). A flag byte handle is not a data name. Java and Rust have their own tickets (AZ-2246, AZ-2247). Reading the code: Python names are accessor keys and a `group` has no name, so the group-specific TypeScript cases do not apply; the same-scope rule covers a group's members.

## Documentation pass

Touch these when the code lands (the docs worker; the sentences are proposals).

- **README**, Untrusted input list (next to the TypeScript bullet, near line 1090): "- In Python, a member name declared twice in one scope (`member x: declared twice in one scope; a row holds one value per name, so one would be lost`), unless one of the two sits under a `when`. A name is the accessor key (`row["x"]` and `row.x` are different accessors; a `list` or `dict` accessor counts, an identity accessor has none). The top level and each `list` or `dict` element are scopes; `repeat`, `times`, `flags`, `when` and `group` share the scope around them, and a flag byte handle is not a name. TypeScript refuses the same schemes." Python upgrade paragraph (`Python changed in several places`), append: "A member name declared twice in one scope now raises `ValueError` when the scheme is built, unless one of the two sits under a `when`: `u8 x` twice unpacked `01 07 08` to `{x: 8}` and packed it again as `01 08 08`, and `u8 x` beside a `times` or `repeat` holding `u8 x` unpacked to `{x: [7, 8]}` and could not be packed again. In calling code, rename one of the members." The older upgrade sentence "In calling code, import the four names explicitly..." stays.
- **`_docs/02_document/components/03_python_package/description.md`**: §2 `Scheme` row, add "a member name declared twice in one scope (AZ-2245)"; §5 source layout, name where `_validate_names` lives; §7, a new paragraph "**Member names** (loop 16, AZ-2245): the scopes, the `when` exemption, that a `group` and a flag byte handle have no name, and that `r.x` and `r["x"]` are different accessors"; §7 "Breaking changes for callers, loop 16", add "`Scheme(...)` refuses a member name declared twice in one scope (`u8 x` plus `repeat` of `u8 x` built before); rename one of them."
- **`_docs/02_document/components/03_python_package/tests.md`**: heading "Loop 16 Tests (...)" add AZ-2245; a row `test_duplicate_names`: "a member name declared twice in one scope raises `ValueError` at construction for every field kind, in a round, under `flags`, in a group and in a flag bit; `when` arms may share a name; a list or dict element has its own names; a flag byte handle is not a name; refusals that exist today keep their message (AZ-2245)" with file `python/tests/test_duplicate_names.py`.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 3), with AZ-2248 and AZ-2249 in the Python worker. `Scheme(...)` raises `ValueError` (`member x: declared twice in one scope; a row holds one value per name, so one would be lost`, the accessor key named) for a member name declared twice in one scope, unless one of the two sits under a `when`: the same name twice at one level, outside and inside a `times` or `repeat` round, in two rounds, under `flags`, in a group or a flag bit, for every kind of field including a `u2` slot, `be()` and a `list` or `dict` accessor. `u8 x` twice unpacked `01 07 08` to `{x: 8}` and packed that as `01 08 08`; `u8 x` beside a `times` holding `u8 x` unpacked to `{x: [7, 8]}` and could not be packed again; two `times` bodies sharing `v` unpacked `01020a0b010c` to `{n: 2, v: [12], m: 1}` and failed on repack with `IndexError`. The scope is the top level or one `list` or `dict` element; `repeat`, `times`, `flags`, `when`, `group` and a flag bit share the scope around them; a flag byte holds no name.

Mechanism: `_nodes.py` (+32/-2) `_pair` marks both closures of an accessor with `(kind, key)` through `_marked` (`be()`, flag bits and `with_limits` reuse the closures, so the mark survives; the identity accessor has none); `_validate.py` `_validate_names` and `_declare_name` (about +45); `_scheme.py` (+8/-1) runs the check last in `Scheme.__init__`, so the six earlier messages keep winning.

Tests (`python/tests/test_duplicate_names.py`, new, 267 lines, 35 tests; 19 fail at HEAD, the 16 build, bytes and message tests pass at HEAD): AC-1 `test_ac1_the_same_name_twice_at_one_level_is_refused`; AC-2 two tests (a `times` and a `repeat` round); AC-3 two rounds sharing a name; AC-4 four tests (`flags`, a group, a bool named twice under two `flags`, a split flag bit); AC-5 eight kinds of field and a list or dict accessor, and attribute accessors on a class row; AC-6 four tests (two `when` arms, arms in a `repeat`, a name outside plus under a `when`, two in one `when` body: `01012c01`, `010005012c01`, `010007`, `01010707`, and `01010708` unpacks to `{k: 1, v: 8}`); AC-7 an element reuses row names in a list and a dict, a duplicate inside an element is refused, a nested element, identity accessors beside each other; AC-8 a handle in two scopes, read twice, in two schemes; AC-9 six earlier messages; AC-10 the whole suite.

Evidence: a differential of 6,000 random schemes with names drawn from five, plus an independent oracle of the TypeScript rule: 2,902 accepted schemes build, pack (9,207 rows) and unpack identically to HEAD; 3,098 refused, each with the new message, each flagged by the oracle with the refused name in its set, and every one built at HEAD; 0 other refusals, 0 accepted-but-flagged. The spec author's differential over 3,000 schemes agrees. Nothing existing is refused: the 326 existing tests, the 18 README Python snippets (the checker runs 17, one has no pack call) and the nine driver schemes pack byte-identically (0 refusals logged).

Discoveries: Risk 2 as written (open, owner): `r.x` and `r["x"]` (or `row.x` and `row["x"]`) in one scheme count as different names and build; the option to match by key only was not taken. Keys compare by `==`, so `r[0]` and `r[False]` (and `r[1]`, `r[1.0]`) clash and the message names the second key; unhashable keys such as slices work because the check keeps a list. Python `group` has no name (it is flat), so the ticket's "group named like its own child" does not exist here; `u8 x; group(u8 x)` is the same-scope case. `be()` copies fields one by one, so a stored name has to survive it (it does). This check runs before the AZ-2249 check, so a scheme with both faults reports the duplicate name. Open: two declarations inside one `when` body build, as in TypeScript. Docs: README patch (the untrusted-input bullet, the upgrade paragraph, and the cross-package sentence at the TypeScript bullet), Python description and `tests.md`.

# TypeScript refuses an anchored group as a direct list or dict element

**Task**: AZ-2236_typescript_direct_element_kinds_refused
**Name**: TypeScript refuses an anchored group as a list or dict element when the scheme is built
**Description**: `scheme(...)` and `new Scheme(...)` throw `RangeError` naming the list or dict and the group when the element of a `list` or `dict` is an anchored `group`, instead of building a scheme that throws `missing a` on every pack. A `when` or `times` as a direct element is already refused at construction and keeps its message.
**Complexity**: 2 points
**Dependencies**: AZ-2102_typescript_list_group_elements (unanchored `group` and `flags` elements)
**Component**: typescript
**Tracker**: AZ-2236
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment (`_docs/loops/loop16/assessment16.md` Q7), owner decision A on 2026-10-06. Since AZ-2102 an unanchored `group` or a `flags` is a list or dict element that packs one object per item. The ticket says an anchored `group`, a `when` or a `times` as a direct element still builds and then throws `missing a` at pack. Observed on `2eb9875` (node 22.23, scratch copy of `typescript/`); the code differs from the ticket for two of the three kinds:

| Direct element | Builds? | Pack | Where it fails today |
|----------------|---------|------|----------------------|
| anchored `group(0, x => x.p, [u8(0, p => p.a)])` in `list(x => x.g, ...)`, `{g: [{a: 1}, {a: 2}]}` | yes | `RangeError: missing a` (also with `{g: [{p: {a: 1}}]}`) | at pack |
| the same in `dict(x => x.g, ...)`, `{g: {k: {a: 1}}}` | yes | `RangeError: missing a` | at pack |
| `when(0, eq(0, 1), [u8(0, ...)])` in a `list` | no | none | `scheme(...)` throws `RangeError: when 0: eq names field id 0, which is not declared earlier in the same scope` (the element is a scope of its own and nothing precedes the `when`; `bindReferences` in `ref-scope.ts`) |
| `times(0, 0, [u8(0, ...)])` in a `list` | no | none | `RangeError: times 0: count names field id 0, which is not declared earlier in the same scope` |

So only the anchored group is a late error. The anchored group also builds, and fails at pack the same way, when it stands in a `when` body, a `repeat` or `times` body, a group element, a `flags` member, a flag bit's field, or as the element of an inner `list` or `dict` (`dict(dict(group(0, ...)))`). Anchored groups elsewhere work: top level, and inside an unanchored group element (the element's scope holds it).

The ticket's other observation, a group inside a `repeat` round given as `g: [{a: 1}, {a: 2}]`, is reproduced (`repeat(0, [group(0, x => x.g, [u8(0, p => p.a)])])` throws `RangeError: missing a`, an unanchored group too), but that scheme is valid: the same scheme packs `{a: [1, 2]}` as `010102`. It is a value shape the round does not take, not a scheme that can be refused, so it is not part of this task.

## Outcome

- Building a scheme throws `RangeError` when a `list` or `dict`, wherever it stands, has an anchored `group` as its element. The message names the kind and the field: `list g: element is an anchored group (p); use a group without an anchor` (`dict g: ...` for a dict; `g` is the list or dict, `p` the group).
- A `when` or `times` as a direct element keeps its present refusal and message (decision C15); the new check does not run first for them.
- Unanchored `group` and `flags` elements, leaf elements, nested lists and dicts, an anchored group inside an unanchored group element, and every scheme that packs today are unchanged, byte for byte.

## Scope

### Included
- A construction check run by `new Scheme(...)` (so by `scheme(...)` and `withLimits`) after every check that exists today, so a scheme refused today keeps its message. The check looks at every `list` and `dict` in the scheme, at any depth, including inside list and dict elements.
- Tests for the probes below.
- The text that says the old behaviour: README (the TypeScript construction refusals near the Untrusted input bullets, with the Rust element list), `_docs/02_document/components/02_typescript_package/description.md` (the `Scheme` row, the known limitation that says an anchored group "keeps the old flat path", the List and dict elements paragraph) and its `tests.md` row.

### Excluded
- `when` and `times` as a direct element: already refused (table above); their message stays. Widening the new message to them would change an existing error text (C15); it is a one-line follow-up if the owner wants it.
- Making the anchored group work as an element (Q7 option B), and Python's behaviour (it accepts them).
- The group-in-`repeat`-round value shape `g: [{a: 1}, {a: 2}]`.
- `repeat` as an element (already refused: `list element must be one field`, `repeat is not a dictionary element`).
- Other direct elements that build today and are not named by the ticket (for example `list(x => x.t, flagByte("m"))` builds and packs `01010000`).

## Acceptance Criteria

**AC-1: A list of anchored groups is refused when the scheme is built**
Given `list(x => x.g, group(0, x => x.p, [u8(0, p => p.a)]))`
When `scheme<Row>(1, ...)` and `new Scheme<Row>(1, [...])` are called
Then both throw `RangeError` with the message `list g: element is an anchored group (p); use a group without an anchor` (today both build and `{g: [{a: 1}, {a: 2}]}` throws `missing a` at pack).

**AC-2: A dict of anchored groups is refused**
Given `dict(x => x.g, group(0, x => x.p, [u8(0, p => p.a)]))`
When the scheme is built
Then it throws `RangeError` with the message `dict g: element is an anchored group (p); use a group without an anchor` (today it builds and `{g: {k: {a: 1}}}` throws `missing a`).

**AC-3: Wherever the list or dict stands**
Given the AC-1 list placed in a `when` body (after `u8(0, k)`, `when(1, eq(0, 1), [...])`), a `repeat` body, a `times` body (after `u8(0, n)`, `times(1, 0, [...])`), an unanchored group element (`list(x => x.t, group(x => x.q, [<AC-1 list>]))`), a `flags(0, [...])` member, a flag bit (`m.bit(<AC-1 list>)`), and as the element of an inner list or dict (`dict(x => x.t, dict(y => y.u, group(0, x => x.g, [...])))`)
When each scheme is built
Then each throws `RangeError` `... element is an anchored group (p); use a group without an anchor`, naming the list or dict that holds the group (`dict u: ... (g)` for the nested dict); today each builds and its pack throws `missing a` (all seven probed).

**AC-4: `when` and `times` elements keep their refusal**
Given `list(x => x.w, when(0, eq(0, 1), [u8(0, p => p.a)]))` and `list(x => x.t, times(0, 0, [u8(0, p => p.a)]))`
When each scheme is built
Then they throw `RangeError` `when 0: eq names field id 0, which is not declared earlier in the same scope` and `times 0: count names field id 0, which is not declared earlier in the same scope`, as today.

**AC-5: A scheme refused today for another reason keeps its message**
Given `list(x => x.g, group(1, x => x.p, [u8(1, p => p.a)]))` and `list(x => x.g, group(0, x => x.p, []))`
When each scheme is built
Then they throw `RangeError` `field id: expected 0, got 1` and `empty group p: allowed only directly inside flags or a flag bit; move it into flags`, as today.

**AC-6: Elements that work today keep their bytes**
Given these schemes and rows (each packs today)
When they are packed
Then the bytes are:
- `list(x => x.pts, group(x => x.p, [u8(0, p => p.a), u8(1, p => p.b)]))`, `{pts: [{a: 1, b: 2}, {a: 3, b: 4}]}`: `01020001020304`
- `dict(x => x.m, <the same group>)`, `{m: {y: {a: 3, b: 4}, x: {a: 1, b: 2}}}`: `01020001007801020100790304`
- `list(x => x.pts, flags(0, [u8(0, p => p.a), u16(1, p => p.b)]))`, `{pts: [{a: 1}, {}, {b: 2}]}`: `010300010100020200`
- `list(x => x.t, u8(0, a => a.p))`, `{t: [1, 2]}`: `0102000102`
- `list(x => x.t, list(y => y.u, group(x => x.g, [u8(0, p => p.a)])))`, `{t: [[{a: 1}]]}`: `010100010001`
- `list(x => x.t, group(x => x.g, [u8(0, p => p.a), group(1, p => p.q, [u8(1, p => p.b)])]))`, `{t: [{a: 1, b: 2}]}`: `0101000102` (an anchored group inside the element)
- the same element group with `when(1, eq(0, 1), [u8(1, p => p.b)])` in place of the inner group, `{t: [{a: 1, b: 2}, {a: 0}]}`: `010200010200`
- the same element group with `times(1, 0, [u8(1, p => p.b)])`, `{t: [{a: 2, b: [3, 4]}]}`: `010100020304`
- `group(0, x => x.h, [u8(0, p => p.k)])` then `list(x => x.pts, group(x => x.p, [u8(0, p => p.a)]))`, `{k: 7, pts: [{a: 1}]}`: `0107010001`
- `group(0, x => x.g, [u8(0, p => p.a)])` at the top level, `{a: 1}`: `0101`

**AC-7: Fixtures and existing tests are unchanged**
Given the golden position, the route fixture and the language-pair `user` and `nested` hand-offs, and the 437 existing TypeScript tests
When they run
Then the bytes are unchanged and all 437 tests pass (a throwaway version of the check on a scratch copy passed all 437).

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every scheme that packs today are unchanged. A scheme that is refused now could only pack lists or dicts that were empty or never reached (`{g: []}` packs `010000`; a `repeat` with zero rounds, a `when` that does not match), or items whose values were silently dropped (an anchored group of only optional members packs `0102000000` and unpacks to `[null, null]`); owner decision A makes those fail when the scheme is built.

**Reliability**
- The mistake is reported when the scheme is built, not on the first pack, and the message names the list or dict and the group.

## Unit Tests

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1 | list of anchored group through `scheme` and `new Scheme` | `RangeError` with the exact message | `typescript/tests/list-element-kinds.test.ts` (new; the AZ-2102 file `list-group-elements.test.ts` keeps its tests) |
| AC-2 | dict of anchored group | `RangeError` with the exact message | `typescript/tests/list-element-kinds.test.ts` |
| AC-3 | the seven places | `RangeError`, naming the holder | `typescript/tests/list-element-kinds.test.ts` |
| AC-4 | `when` and `times` elements | the two existing messages | `typescript/tests/list-element-kinds.test.ts` |
| AC-5 | wrong anchor, empty anchored group | the two existing messages | `typescript/tests/list-element-kinds.test.ts` |
| AC-6 | the ten schemes | the listed bytes; each unpacks and repacks to the same bytes where it has an unpack side | `typescript/tests/list-element-kinds.test.ts` (the first three are already in `list-group-elements.test.ts`, AC-1, AC-3, AC-4 of AZ-2102) |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-7 | `fixtures/golden.hex`, `.github/workflows/drivers/position.ts` and `handoff.ts` (`user`, `nested`) | pack and unpack | unchanged hex, 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: TypeScript only; no shared walker, no cross-package import. Python, which accepts these elements, is not a code source.
- `RangeError` is the construction error type; browser-safe `src`; no public API change.
- Files at or under 500 lines (`fields.ts` is 436, `index.ts` 232; the check goes in a small new file or `flag-scope.ts`, which holds the other construction walks, 97 lines).
- Error kind and label of existing errors unchanged (decision C15): the `when`, `times`, field-id and empty-group refusals above keep their messages.
- Probes in the Problem table and AC-3 to AC-6 were run on `2eb9875`; the new message and the 437 passing tests come from a throwaway check on a scratch copy. The worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller built a list of anchored groups and never packed it**
- *Risk*: a scheme that built (and failed at every pack) now fails at construction.
- *Mitigation*: it could never pack a row; the message names the fix (a group without an anchor).

**Risk 2: The ticket expected a kind-naming message for `when` and `times` too**
- *Risk*: those two are refused today with a message about the `eq` id or the count, not about the element kind.
- *Mitigation*: kept under C15 and stated in Excluded; relabelling them is a separate, tiny change if wanted.

## Owner decision (2026-10-06)

DECIDED, assessment Q7 option A (the recommendation, "implement everything now"): refuse an anchored group, `when` or `times` as a direct list or dict element when the scheme is built, with a message naming the element kind and the field (`RangeError`), instead of a late pack error. Unanchored group and flags elements, leaf elements and nested lists and dicts keep working; the wire bytes of schemes that pack today do not change. Reading the code: only the anchored group is a late error; `when` and `times` are already construction errors, so this task adds the new message for the anchored group only.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2). `validateElementKinds` in `typescript/src/element-kinds.ts` (new, 31 lines) walks every `list` and `dict` at any depth (`when`, `flags`, flag bit, group, `repeat`, `times` and element bodies) and runs last in the `Scheme` constructor, so every earlier refusal keeps its message and `scheme(...)` and `new Scheme(...)` refuse the same schemes: `list g: element is an anchored group (p); use a group without an anchor` (`dict g: ...` for a dict). `index.ts` +2. Wire bytes of every scheme that builds are unchanged. As the spec found, only the anchored group was a late error: `when` and `times` as a direct element were already construction errors (`when 0: eq names field id 0, which is not declared earlier in the same scope`; `field id: expected 0, got 1`) and are unchanged.

Tests (`typescript/tests/list-element-kinds.test.ts`, new, 26 tests; the TypeScript suite is 463, HEAD 437): AC-1 `a list of anchored groups is refused by scheme and by new Scheme` and `withLimits on a valid scheme still builds`; AC-2 `a dict of anchored groups is refused`; AC-3 eight places (a `when` body, a `repeat` body, a `times` body, an unanchored group element, a `flags` member, a flag bit, `flags` directly inside `flags`, the element of an inner dict), each through both constructors; AC-4 `a when element keeps its refusal`, `a times element keeps its refusal`; AC-5 three tests on message order; AC-6 ten schemes that build keep their bytes and round-trip. Strict `tsc` exits 0; `position.ts` equals `golden.hex`; the seven `handoff.ts pack-*` commands give HEAD's bytes.

Evidence: 20,000 random schemes (seeds 1 to 5) against a scratch copy of the HEAD sources: about 3,400 newly refused, all with an anchored group element; about 6,000 keep their identical earlier message; about 10,500 build on both sides and pack and unpack identically on about 40,000 rows; the reviewer's own differential (20,000 schemes, an independent oracle for "has an anchored direct element anywhere") agrees both ways; of the reviewer's nine mutants (a case or the recursion removed, the anchor condition dropped) eight are caught, and the ninth, removing `case "flags"`, led to F3.

Review findings (PASS_WITH_WARNINGS):
- F1 (the spec text "a refused scheme never packed a row" was false): corrected in the spec and in the README upgrade note: HEAD packed empty lists (`{g: []}` gives `010000`), unreached lists (a `repeat` with zero rounds, a `when` that does not match, a `times` with count 0) and items of an anchored group whose members are all optional, whose values were silently dropped (`{g: [{a: 5}, {}]}` packed `0102000000`, with no `5` in it; the package's own unpack refuses that packet). A scheme that only ever did that fails at build now; the message names the fix.
- F2 (docs listed as Included were stale): fixed in the docs pass (README patch, `description.md`, `tests.md`, `module-layout.md`).
- F3 (`case "flags"` in `element-kinds.ts` looked unreachable): it is reachable, a `flags` nested directly in `flags` (`flatten` keeps the inner `flags` as the field of a flag bit); kept, and the AC-3 table gained `a flags nested directly in flags`, which fails without the case.

Open (spec Excluded, not changed, owner): a multi-slot `u2` as a direct element builds and fails at pack (`list(t, u2(0, a, 1, b))` with `{t: [1]}`: `y: expected 2-bit int`); a `flagByte` as a list or dict element builds and packs without the values (`{t: [1, 2]}` packs `0102000000`; the package's own unpack then refuses that packet): the same silent-drop class, a follow-up candidate. Found by the docs pass: under `strict`, `BinaryPacker.unpack` and `PackSession.unpack` take `SchemeHandler<object>` and `Scheme<Row>` is invariant, so the handler of a typed row is refused (TS2345) until it is cast `as SchemeHandler<any>`; the README examples now cast. A change of the parameter type is open for the owner (not part of this spec).

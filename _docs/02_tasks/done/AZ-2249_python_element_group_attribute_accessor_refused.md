# Python refuses an attribute accessor inside a list or dict element group

**Task**: AZ-2249_python_element_group_attribute_accessor_refused
**Name**: Python refuses an attribute-style accessor inside a `list` or `dict` element group when the scheme is built
**Description**: `Scheme(...)` raises `ValueError` naming the list or dict, the field and the attribute when a member of a `list` or `dict` element that is not a leaf (a `group`, `flags` or `u2`, at any depth below it) uses an attribute accessor (`lambda p: p.x`), instead of building a scheme whose valid packets raise `AttributeError` out of `BinaryPacker.unpack`. The message says to use a key accessor (`row["x"]`). Key accessors in element groups, leaf elements and every scheme without an attribute accessor in an element are unchanged.
**Complexity**: 2 points
**Dependencies**: none in Python; the rule follows AZ-2235_java_typed_element_groups_checked (intent only, no code shared) and AZ-2236_typescript_direct_element_kinds_refused
**Component**: python
**Tracker**: AZ-2249
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment round 2 (`_docs/loops/loop16/assessment16.md`, X5). The Python README shows typed rows with attribute accessors (`lambda row: row.sid`). A `list` or `dict` whose element is not a leaf is read into a plain `dict` per element (`_unpack_element` in `python/src/packbin/_unpack.py` starts every element that is not a leaf, a list or a dict with `child_row: dict[str, Any] = {}`), and the accessors inside the element then run on that `dict`. A key accessor (`lambda p: p["x"]`) sets and reads a `dict` key. An attribute accessor reads with `getattr(row, key, None)` and writes with `setattr(row, key, value)`, and `setattr` on a `dict` always raises, for any name. Python has no factory for an element row, so the scheme can pack and never unpack.

Observed on `35544ed` (`git archive` export, Python 3.14.6; probes in `probe_x5.py` and `probe_x5b.py` of the scratch dir). `Row` is a plain class with `pts`; `Pt` has `x`.

| # | Scheme | Builds | Pack | Unpack of the valid packet |
|---|--------|--------|------|----------------------------|
| A1 | `Scheme(1, Row, list(lambda r: r.pts, group(0, u8(0, lambda p: p.x))))` | yes | `Row.pts = [Pt(1), Pt(2)]` packs `0102000102` | `0102000102` raises `AttributeError: 'dict' object has no attribute 'x' and no __dict__ for setting new attributes` out of `BinaryPacker.unpack` |
| A2 | the same with `dict(...)` | yes | `{"a": Pt(1)}` packs `01010001006101` | `01010001006101` raises the same `AttributeError` |
| A3 | `list(..., flags(0, u8(0, lambda p: p.x)))` | yes | packs `01020001010102` | bit set (`01 0100 01 07`): the same `AttributeError`; bit clear (`01 0100 00`): works, `Row(pts=[{}])` |
| A4 | `list(..., u2((0, lambda p: p.x), (1, lambda p: p.y)))` | yes | | `01 0100 09` raises the same `AttributeError` |
| A5 | `list(..., group(0, group(0, u8(0, lambda p: p.x))))` | yes | | raises the same |
| A6 | element `group(0, u8(0, lambda p: p["k"]), when(1, eq(0, 1), u8(1, lambda p: p.y)))` | yes | | `01 0100 01 09` raises (`'y'`) |
| A7 | element `group(0, u8(0, lambda p: p["n"]), times(1, 0, u8(1, lambda p: p.v)))` | yes | | `01 0100 02 0708` raises (`'v'`) |
| A8 | element `group(0, list(lambda p: p.inner, u8(0, lambda z: z)))` (a nested list member with an attribute accessor; `dict` the same) | yes | | raises (`'inner'`) |
| A9 | `list(lambda r: r.pts, list(lambda p: p.q, group(0, u8(0, lambda p: p.x))))` (an inner container) | yes | | raises (`'x'`) |
| A10 | element `group(0, u8(0, lambda p: p["k"]), u8(1, lambda p: p.v))` (one key, one attribute) | yes | `{"l": [{"k": 1, "v": 2}]}` raises `KeyError: 'missing field 1'` (the attribute is read from a `dict`) | raises (`'v'`) |
| A11 | element `flags(0, bool(0, lambda p: p.on))` | yes | | `01 0100 01` raises (`'on'`) |

So an attribute accessor in an element scope can never set a value. Two readings of the assessment text are wrong and the spec does not repeat them:

- The assessment says the refusal costs "none for schemes that unpack today". A scheme with attribute accessors in an element group packs today whenever the items are objects (A1, A2, A3), so a pack-only caller breaks; and a scheme whose attribute members are all optional unpacks today for every packet that leaves them absent (A3, bit clear, returns `Row(pts=[{}])`). See Risks 1 and 2.
- The assessment says "the accessor probe already tells attribute from key access". It does, but only inside `_pair` (`python/src/packbin/_nodes.py`): the probe result carries `kind` `"attr"` or `"item"`, and `_pair` returns two lambdas that no longer say which they are. The check needs that kind kept (see Scope).

### What the probe decides, and what it cannot

`_pair(acc)` calls the accessor once with a probe object. Whatever is accepted is exactly one of three shapes (probed through `u8(0, acc)`): attribute access (`lambda r: r.x`, `operator.attrgetter("x")`, `lambda r: getattr(r, "x")`, a `functools.partial` or a callable object that reads one attribute), key access (`lambda r: r["x"]`, `operator.itemgetter("x")`, `lambda r: r[0]`) and the identity (`lambda r: r`). Everything else is refused today with `ValueError: accessor must be a member access`: `r.x.y`, `r["a"]["b"]`, `r.get("x")`, `len(r)`, `r.x + 1`, `5`, `attrgetter("x.y")`, `r.__class__`. So no arbitrary callable can reach a node: every accessor on a node is attribute, key or identity, and the runtime uses the lambdas `_pair` built, never the caller's function again. Decidable when the scheme is built:

- the kind of every accessor, for every node that has one (`u8` .. `f64`, `bool`, `bytes`, `utf8`, `sized`, `bits`, `packed`, a `u2` slot, `list`, `dict`);
- the row an element scope runs on: always a `dict`, for every non-leaf element (`group`, `flags`, `u2`, and anything below them: `group`, `flags`, `when`, `repeat`, `times` bodies, flag bits, nested `list` and `dict` members);
- which accessors are called: a leaf element (`u8`, `u16`, `utf8`, `bytes`, ...) is read and written by value and its accessor is never called (`list(..., u16(0, lambda row: row))` in the README, and the same with `lambda p: p.x`, builds and round-trips today), and the accessor of a `list` or `dict` that is itself an element is never called either (B5, B7 below).

Python's `group(anchor, ...)` has no accessor of its own: its `anchor` is a field order number, and a Python group shares the row of the scope around it. So the TypeScript and Java split into anchored and unanchored groups does not exist here, and every `group` element is the same shape.

Not decidable when the scheme is built (the rule is by scheme, not by value):

- whether the caller packs objects only and never unpacks (A1 packs today);
- whether an optional member (under `flags`, a flag bit or `when`) will be present in a packet (A3 with the bit clear unpacks today);
- whether a key accessor in an element will be given dict items or objects at pack time (it fails at pack with `TypeError` for an object, a value-shape matter, not a scheme error).

One shape is decidable but outside the ticket: the identity accessor in an element group (B9 below) builds, fails pack and loses the value on unpack. See Excluded and Risk 3.

## Outcome

- `Scheme(...)` raises `ValueError` when, anywhere in the scheme, a `list` or `dict` has a non-leaf element and a node in that element's scope has an attribute accessor. The message names the container that directly holds the element, the field and the attribute: `list element: field 0 uses the attribute accessor 'x'; an element row is a dict, so use a key accessor, row['x']` (`dict element: ...` for a dict; `field N` is the id of the value field or `u2` slot, and `a nested list` or `a nested dict` for a list or dict member).
- The element scope is the element and everything below it except the element of an inner `list` or `dict`, which is checked as its own element and names its own container. The first offending accessor in scheme order is named.
- The check runs after every check that exists today, so a scheme refused today keeps its message.
- Key accessors in element groups, leaf elements, an accessor on a `list` or `dict` that is itself an element, the identity accessor, and every scheme that has no attribute accessor in an element scope build exactly as today, and pack and unpack the same bytes and rows.

## Scope

### Included
- Keeping the accessor kind where the node can read it: `_pair` in `python/src/packbin/_nodes.py` builds the attribute getter and setter, and the check needs to know that a setter is an attribute setter and its attribute name (a marker on the setter, or a small record; no public name, no node field order, no node signature changes).
- A construction check run by `Scheme.__init__` (`python/src/packbin/_scheme.py`) after `_validate_round_nesting`, walking `list`, `dict`, `flags`, flag bits, `group`, `when`, `repeat` and `times` bodies at any depth, in `python/src/packbin/_validate.py` (108 lines) or a small new module.
- Tests for the probes below (`python/tests/test_element_accessors.py`, new).
- The docs pass (README, the Python description, `tests.md`, `module-layout.md`), with these sentence proposals:
  - README, the list of construction refusals (after the TypeScript `list` or `dict` of anchored `group` bullet, which ends "Python accepts an anchored group element."): "- In Python, a `list` or `dict` element that is a `group`, `flags` or `u2`, or holds one, whose members use attribute accessors (`lambda p: p.x`): `list element: field 0 uses the attribute accessor 'x'; an element row is a dict, so use a key accessor, row['x']`. Each element is unpacked into a `dict`, so give its members key accessors (`lambda p: p["x"]`). The accessor of the list itself (`lambda row: row.pts`), a leaf element (`u16(0, lambda p: p)`) and an accessor on a `list` or `dict` that is itself an element are not affected."
  - README, "Python changed in several places": "A `list` or `dict` whose element is a `group`, `flags` or `u2` now raises `ValueError` when the scheme is built if a member uses an attribute accessor; it built before, packed objects, and raised `AttributeError` out of `BinaryPacker.unpack` on a valid packet. Use key accessors in element groups; a scheme that only packs objects must pack `dict` elements instead."
  - `_docs/02_document/components/03_python_package/description.md`: the `Scheme` row of §2 gains ", a member of a `list` or `dict` element group (`group`, `flags` or `u2`) that uses an attribute accessor"; §7 gains an "Element accessors" paragraph (loop 16, AZ-2249: what the check walks, that the element row is a `dict`, that leaf elements and an inner container's own accessor are not checked, the message), a line under "Breaking changes for callers, loop 16" (a pack-only scheme with object elements no longer builds), and a known-limitation line for the identity accessor in an element group (Risk 3, open for the owner).
  - `tests.md` (Python): a `test_element_accessors` row under the loop 16 tests; `_docs/02_document/module-layout.md` line for the Python construction checks names the new function (and the new file if there is one).

### Excluded
- The identity accessor (`lambda p: p`) inside an element group, which builds, fails pack with `TypeError: 0: expected int, got dict`, and unpacks to `{'l': [{}]}` with the value lost (B9): decidable, but the ticket names attribute accessors only; STOP option B in Risks.
- A top-level scheme whose row class and accessors do not match (`Scheme(1, dict, u8(0, lambda r: r.a))` raises `AttributeError` on unpack; `Scheme(1, Row, u8(0, lambda r: r["a"]))` raises `AttributeError: 'Row' object has no attribute '__setitem__'`): the same kind of mismatch, but not an element scope, not decided by this ticket.
- Giving the element group a factory (`group(0, ..., factory=Pt)`) so typed elements work as in Java: new API, only if the owner wants typed element rows (assessment X5 option B).
- A key accessor given object items at pack time (a value shape), a leaf element's unused accessor, and every other package.
- Error kind and label of existing errors (decision C15).

## Acceptance Criteria

Every HEAD value below was produced on `35544ed`. The target values were produced by a throwaway version of the check on a scratch export (all 326 existing Python tests pass with it). The worker re-derives them from a real run.

**AC-1: A list element group with an attribute accessor is refused**
Given `Scheme(1, Row, list(lambda r: r.pts, group(0, u8(0, lambda p: p.x))))`
When it is built
Then it raises `ValueError` with the message `list element: field 0 uses the attribute accessor 'x'; an element row is a dict, so use a key accessor, row['x']` (HEAD builds it, packs `Row.pts = [Pt(1), Pt(2)]` as `0102000102`, and unpacking `0102000102` raises `AttributeError`).

**AC-2: A dict element group with an attribute accessor is refused**
Given the same with `dict(lambda r: r.pts, ...)`
When it is built
Then `ValueError` with the same message starting `dict element:` (HEAD packs `{"a": Pt(1)}` as `01010001006101` and unpack raises).

**AC-3: Every place the element scope holds it**
Given the AC-1 list with, in place of the group, each of: `flags(0, u8(0, lambda p: p.x))` (also with the bit clear: HEAD unpacks `01 0100 00` to `Row(pts=[{}])`), `u2((0, lambda p: p["a"]), (1, lambda p: p.b))`, `group(0, group(0, u8(0, lambda p: p.x)))`, `group(0, u8(0, lambda p: p["k"]), when(1, eq(0, 1), u8(1, lambda p: p.y)))`, `group(0, u8(0, lambda p: p["n"]), times(1, 0, u8(1, lambda p: p.v)))`, `flags(0, bool(0, lambda p: p.on))`, `group(0, u8(0, lambda p: p["k"]), u8(1, lambda p: p.v))`, `group(0, list(lambda p: p.inner, u8(0, lambda z: z)))` and the same with `dict`, and `group(0, be(u16(0, lambda p: p.x)))`; and the AC-1 list placed in a `when` body (after `u8(0, lambda r: r.k)`, `when(1, eq(0, 1), ...)`), under `flags(0, ...)`, as the payload of a flag bit (`m.bit(...)`), and in a `times` body at the top level (after `u8(0, lambda r: r.n)`, `times(1, 0, ...)`)
When each is built
Then each raises `ValueError` naming the first attribute accessor in scheme order and the holder: `list element: field 0 ... 'x'`, `field 1 ... 'b'`, `field 0 ... 'x'`, `field 1 ... 'y'`, `field 1 ... 'v'`, `field 0 ... 'on'`, `field 1 ... 'v'`, `list element: a nested list uses the attribute accessor 'inner'; ...`, the same with `a nested dict`, and `field 0 ... 'x'` for the `be` field; the four placements give the AC-1 message, `'x'` included (all built at HEAD).

**AC-4: An inner container names its own holder**
Given `list(lambda r: r.pts, list(lambda p: p["q"], group(0, u8(0, lambda p: p.x))))`, the same with `dict` for the inner container, and `dict(lambda r: r.m, list(lambda p: p["q"], group(0, u8(0, lambda p: p.x))))`
When each is built
Then they raise `list element: field 0 ... 'x'`, `dict element: field 0 ... 'x'` and `list element: field 0 ... 'x'`: the container that directly holds the group names itself, and an attribute accessor on that inner container (`lambda p: p.q` in place of `lambda p: p["q"]`, probe A9) is not refused, because an element that is a container is read by value.

**AC-5: Key accessors in element groups keep their bytes and rows**
Given these schemes (each builds, packs and unpacks today):
- `Scheme(1, dict, list(lambda r: r["pts"], group(0, u8(0, lambda p: p["x"]))))`, `{"pts": [{"x": 1}, {"x": 2}]}`: pack `0102000102`, unpack of those bytes gives `{'pts': [{'x': 1}, {'x': 2}]}`
- the same with `dict(lambda r: r["m"], ...)`, `{"m": {"y": {"x": 3}, "x": {"x": 1}}}`: pack `0102000100780101007903`, unpack gives `{'m': {'x': {'x': 1}, 'y': {'x': 3}}}`
- `list(lambda r: r["l"], flags(0, u8(0, lambda p: p["a"]), u16(1, lambda p: p["b"])))`, `{"l": [{"a": 1}, {}, {"b": 2}]}`: pack `010300010100020200`, unpack gives the same row
- `Scheme(1, Row, list(lambda r: r.pts, group(0, u8(0, lambda p: p["x"]))))` (typed row, attribute accessor on the list itself, key accessors inside), `Row.pts = [{"x": 1}, {"x": 2}]`: pack `0102000102`, unpack gives `Row(pts=[{'x': 1}, {'x': 2}])`
- `list(lambda r: r["l"], group(0, u8(0, lambda p: p["a"]), group(1, u8(1, lambda p: p["b"]))))`, `{"l": [{"a": 1, "b": 2}]}`: pack `0101000102`
When they are packed and unpacked
Then the bytes and rows are the HEAD ones.

**AC-6: Leaf elements and unused accessors are not checked**
Given `Scheme(1, Row, list(lambda r: r.pts, u8(0, lambda p: p.x)))` with `Row.pts = [1, 2]`, `Scheme(1, dict, list(lambda r: r["xs"], u16(0, lambda r: r)))` with `{"xs": [1, 2]}`, `Scheme(1, Row, list(lambda r: r.pts, list(lambda p: p.q, u8(0, lambda z: z.v))))` with `Row.pts = [[1, 2]]`, and `Scheme(1, Pt, group(0, u8(0, lambda p: p.x)))` at the top level (an attribute accessor in a group that is not an element)
When each is built, packed and unpacked
Then each builds and packs `0102000102`, `01020001000200`, `01010002000102` and `0105`; unpack of `0102000102` gives `Row.pts == [1, 2]`, of `01010002000102` gives `Row.pts == [[1, 2]]` and of `0107` gives a `Pt` with `x == 7`, as at HEAD.

**AC-7: The accessor kind is read from the probe, not from the function**
Given `operator.attrgetter("a")` and `lambda p: getattr(p, "a")` as the member accessor of an element group, and `operator.itemgetter("a")` and `lambda p: p[0]` as the same
When each scheme is built
Then the first two raise the AC-1 message (`'a'`), and the last two build, as at HEAD.

**AC-8: An earlier refusal keeps its message**
Given an element group with an attribute accessor and also a wrong field id (`group(0, u8(1, lambda p: p.x))`), an empty `group(0)`, a flag bit before its flag byte, and a `when` as the direct element
When each is built
Then they raise `field id 1 is not the next order 0`, `group 0 has no fields, so it can never carry a value`, `flag bit 0: its flag byte is not read earlier in the same scope` and `when 0: eq names field id 0 is allowed only if declared earlier in the same scope`, as at HEAD.

**AC-9: The shapes left alone stay**
Given `Scheme(1, dict, list(lambda r: r["l"], group(0, u8(0, lambda p: p))))` (identity accessor in an element group), `Scheme(1, Row, list(lambda r: r.pts, group(0, u8(0, lambda p: p["a"]))))` packed with a `Row` whose `pts` holds a `Pt` object, and the two top-level mismatches of Excluded
When built, packed and unpacked
Then the first builds, pack raises `TypeError: 0: expected int, got dict` for `{"l": [{"x": 1}]}` and unpack of `01 0100 07` gives `{'l': [{}]}`; the second builds and pack raises `TypeError: 'Pt' object is not subscriptable`; the two top-level schemes build and unpack raises the `AttributeError`s listed. All as at HEAD.

**AC-10: Everything else is unchanged**
Given the 326 existing Python tests, the language-pair Python driver (`.github/workflows/drivers/handoff.py`: `pack-user`, `pack-nested`, `pack-boolflag`, `pack-booltrue`, `pack-bitwhen`, `pack-listgroup`, `pack-dictgroup`, `pack-listflags`, `pack-session`) and `position.py`, and the 18 Python snippets of the README
When they run
Then all 326 pass with no test changed (the existing element tests, `test_zero_width_elements.py`, `test_round_limits.py`, `test_reference_scope.py`, use key accessors or leaf elements), the driver hex values are the HEAD ones (`01020001020304`, `01020001007801020100790304`, `010300010100020200`, `b55d0a29c56c203712b241232e`, ...; position `4001000065cd1d00a3e1110100`) and every snippet runs as before.

## Non-Functional Requirements

**Compatibility**
- No wire change and no public API change. A source-breaking construction refusal for the kinds of user code in Risks 1 and 2. Bytes of schemes that still build are unchanged.
- Differential against HEAD (what must stay byte-identical, probed on the HEAD export and the throwaway check: 6,000 seeded random schemes of `u8`, `u16`, `utf8`, `flags` with `bool`, `group`, `when`, `u2`, split flag bytes, `times`, and `list` and `dict` of leaf, group, `flags`, `u2` and nested containers, each accessor a key or an attribute at random, four random rows and three random packets each): 4,191 schemes have no attribute accessor in an element scope; every one built identically and gave identical packed bytes (16,764 pack calls, 12,447 of them packed) and identical unpack results (25,020 unpack calls, 13,136 of them ok). 1,809 schemes have one; HEAD built every one and the check refuses every one (866 `list element:`, 943 `dict element:`); at HEAD 505 of them raised `AttributeError` on one of the random packets and 1,456 packed at least one row.

**Reliability**
- The mistake is reported when the scheme is built, not out of `BinaryPacker.unpack` on a valid packet, and the message names the container, the field and the attribute and says what to write instead.

## Unit Tests

AC-1 to AC-4 must fail first (they build at HEAD).

| AC Ref | What to Test | Required Outcome | Test file |
|--------|-------------|------------------|-----------|
| AC-1, AC-2 | list and dict of a group with an attribute accessor | `ValueError` with the exact message | `python/tests/test_element_accessors.py` (new) |
| AC-3 | the eight element shapes and the four placements | the listed messages | `python/tests/test_element_accessors.py` |
| AC-4 | list of list, list of dict, dict of list | holder named as listed | `python/tests/test_element_accessors.py` |
| AC-5 | the five key-accessor schemes | the listed bytes; each unpacks to the listed row and repacks to the same bytes | `python/tests/test_element_accessors.py` |
| AC-6 | leaf elements, identity accessor on a leaf, inner container accessor, top-level attribute group | build; the listed bytes and rows | `python/tests/test_element_accessors.py` |
| AC-7 | `attrgetter`, `getattr`, `itemgetter`, integer key | two refused, two build | `python/tests/test_element_accessors.py` |
| AC-8 | four earlier refusals | the HEAD messages | `python/tests/test_element_accessors.py` |
| AC-9 | identity accessor in an element group; object items with key accessors; two top-level mismatches | as at HEAD | `python/tests/test_element_accessors.py` |
| AC-10 | the existing suite, driver, snippets | unchanged | `python/tests`, `.github/workflows/drivers/handoff.py` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-10 | `fixtures/golden.hex`, `.github/workflows/drivers/handoff.py` (`user`, `nested`, `listgroup`, `dictgroup`, `listflags`, `session`) and `position.py` | pack and unpack | unchanged hex, 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: Python only; no shared walker, no cross-package import. The Java check (`SchemeOrder.requireElementFactory`) and the TypeScript check (`element-kinds.ts`) are intent only.
- Files at or under 500 lines (`_nodes.py` 426, `_validate.py` 108, `_scheme.py` 135; the check goes in `_validate.py` or a small new module; the new test file stays under 500).
- `ValueError` is the construction error kind, as for every other `Scheme(...)` refusal.
- Error kind and label of existing errors unchanged (decision C15): the check runs last (AC-8).
- No new dependency, no change to the public names in `packbin/__init__.py`, the accessor helpers or the node field order.
- **STOP CONDITION:** the implementer stops and reports to the coordinator, before choosing anything else, if (1) the rule breaks a test, fixture, driver or README snippet not listed above (none was found on the HEAD export), (2) a shape turns up that this spec classifies neither as refused nor as left alone, or (3) the implementer thinks the rule should also cover the identity accessor, a leaf element, or a key accessor, look at values rather than the scheme, or add an element factory. Options to report: **A** the rule as written (default); **B** A plus a refusal of the identity accessor in an element scope (decidable: the probe result is the row itself; a trial would need a new message that says to use a key accessor; no existing test uses it in an element group); **C** an element factory, `group(0, ..., factory=Pt)` (new public API; typed elements then work as in Java); **D** leave the gap documented (`AttributeError` stays).
- Bytes and messages in the ACs were reproduced on the HEAD export (the HEAD values) and in a scratch trial of the check (the target values); the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A pack-only scheme with object elements stops building (cannot be told apart at build)**
- *Risk*: A1, A2 and A3 pack objects today (`Row.pts = [Pt(1), Pt(2)]` gives `0102000102`). The check cannot tell a caller who only packs from one who also unpacks, so the pack-only caller breaks. In the 6,000-scheme differential 1,456 of the 1,809 refused schemes packed at least one row at HEAD.
- *Mitigation*: the message names the fix. A caller that only packs gives the elements as `dict`s and uses key accessors (the bytes are the same: B1 packs `0102000102`). The README upgrade note says so. AZ-2235 took the same break for Java (its case (c), pack-only typed schemes). STOP option C (an element factory) is the only way to keep object elements and make them unpack.

**Risk 2: A scheme whose attribute members are all optional**
- *Risk*: A3 with the bit clear unpacks today (`Row(pts=[{}])`), and a scheme whose attribute members are under `flags` or `when` works for packets that omit them. The rule refuses by scheme, not by value, so it refuses these too, although they only fail once a value is present.
- *Mitigation*: the first packet with a value raises `AttributeError` at HEAD, so the scheme was already wrong; the check reports it when the scheme is built, which is the point of the task.

**Risk 3: The identity accessor is left alone**
- *Risk*: `lambda p: p` in an element group builds, fails pack (`0: expected int, got dict`) and drops the value on unpack (`[{}]`). It is a quieter failure than the attribute case and a reader of the new refusal may expect it to be covered.
- *Mitigation*: it is decidable and named in Excluded and in the STOP option B; the description known limitation records it. The README idiom `u16(0, lambda row: row)` is the leaf element, which stays legal (AC-6).

**Risk 4: The check must see the accessor kind**
- *Risk*: `_pair` today returns two lambdas and drops the probe's `kind`; a marker added there must survive `be()` (it reuses the field's `get` and `set`) and the rebuilding that `_bind_flag_bits` does (`_flag_scope.py` reuses `node.get` and `node.set` for flag bits, `list` and `dict`). `with_limits` copies a scheme that already passed the check.
- *Mitigation*: the throwaway check kept the setter's attribute name as an attribute on the setter function; it survived both, and AC-3 covers `be`, flag bits and bodies, and AC-7 operator-built accessors. Any equivalent record is acceptable.

**Risk 5: `AttributeError` text is not pinned**
- *Risk*: the HEAD error text (`'dict' object has no attribute 'x' and no __dict__ for setting new attributes`) is CPython wording and changes between versions.
- *Mitigation*: tests pin the new `ValueError` message and, for the HEAD values, only the exception class.

## Owner decision (2026-10-06)

DECIDED, assessment round 2 X5 option A (the recommendation; the owner answered the round 2 clarifications on 2026-10-06): Python refuses at `Scheme(...)` an attribute-style accessor inside a `list` or `dict` element group, with a message that says to use `row["x"]` accessors, as Java does for a typed element group (AZ-2235). Dict-style accessors in element groups, which unpack today, stay byte- and result-identical. Where construction cannot decide (a pack-only caller, an identity accessor, an element factory) the implementer stops and reports the options (Constraints) before choosing anything else.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 3), option A as decided; the owner confirmed it twice, knowing that it breaks pack-only callers with object elements. `Scheme(...)` raises `ValueError` (`list element: field 0 uses the attribute accessor 'x'; an element row is a dict, so use a key accessor, row['x']`; `dict element:` for a dict; `a nested list` or `a nested dict` for a container member) for a member that uses an attribute accessor in a non-leaf `list` or `dict` element, at any depth of the element: in a group, `flags`, `u2`, a `when`, `times` or `repeat` body, a flag bit or a nested container. Such a scheme built at HEAD, packed objects (`0102000102`) and raised `AttributeError` out of `BinaryPacker.unpack` on a valid packet, because each element is unpacked into a plain `dict`. Key accessors (`lambda p: p["x"]`), leaf elements, an accessor on a container that is itself an element (its own accessor is never called) and the identity accessor are unchanged; the check runs last, after the AZ-2245 check, so the older messages keep winning.

The spec text found wrong: the assessment said the refusal costs "none for schemes that unpack today". It is false: a scheme with attribute accessors in an element group packs today whenever the items are objects (`Row.pts = [Pt(1), Pt(2)]` packs `01 02 00 01 02`), so a pack-only caller breaks (1,456 of the 1,809 refused random schemes packed a row at HEAD, and 1,673 of the final 2,114), and a scheme whose attribute members are all optional unpacks today for every packet that leaves them absent (it is refused too, by scheme and not by value; Risk 2). Fix for callers: pack `dict` elements (`[{"x": 1}, {"x": 2}]` packs the same bytes) and use key accessors. The README upgrade paragraph names the break. The assessment's "the accessor probe already tells attribute from key access" is true only inside `_pair`, which returned two lambdas that no longer said which they were: `_nodes.py` now keeps the kind (the `access` mark of AZ-2245). The anchored versus unanchored distinction does not exist in Python (`group(anchor, ...)` has no accessor).

Files: `_validate.py` (`_validate_element_accessors`, `_validate_element`, `_require_key_accessor`; about +45), `_scheme.py`, new `python/tests/test_element_accessors.py` (277 lines, 39 tests; 21 fail at HEAD): AC-1 and AC-2 `test_ac1_a_list_element_group_with_an_attribute_accessor_is_refused`, `test_ac2_..._dict_...`; AC-3 ten shapes (`flags`, `u2`, a group in a group, a `when` body, a `times` body, a bool under `flags`, one key plus one attribute, a nested list, a nested dict, `be`) and four placements of the list itself (a `when`, `flags`, a flag bit, a `times` body); AC-4 list of list, list of dict, dict of list; AC-5 five key-accessor schemes build and round-trip (`0102000102`, `0102000100780101007903`, `010300010100020200`, a typed row, `0101000102`); AC-6 four tests (a leaf element with an attribute and with the identity accessor, an inner container as element, an attribute group that is not an element); AC-7 `attrgetter` and `getattr` are refused, `itemgetter` and `p[0]` build; AC-8 the four earlier messages; AC-9 identity accessor, object items with key accessors, the two top-level mismatches. Python 485 pass.

Evidence: 6,000 random schemes (accessors key or attribute, unique names so AZ-2245 never fires), HEAD against the change, with an oracle of the rule: 3,886 accepted are identical to the same tree without the check (0 differences; 15,544 pack calls, 11,270 packed); 2,114 refused (1,143 `list element:`, 971 `dict element:`), every message equals the oracle's first offender (holder, field or nested kind, name), and the tree without the check builds all of them; of the refused, 784 raised `AttributeError` on at least one unpack call at HEAD. Against pure HEAD 3 accepted schemes differ, all rows that raised `IndexError` at HEAD and now pack (AZ-2248), not an effect of this check. The spec author's differential agrees (4,191 identical, 1,809 refused). No STOP condition fired: no existing test, fixture, driver or README snippet used an attribute accessor in an element scope (18 of 18 README Python blocks run), and no unclassified shape turned up. Driver output and the 326 earlier tests are unchanged.

Open (owner, STOP options): the identity accessor `lambda p: p` in an element group is decidable but outside the ticket: it builds, pack raises `TypeError: 0: expected int, got dict` and unpack loses the value (`[{}]`); option B refuses it too, option C is an element factory (new API), option D leaves it documented. A pack-only caller cannot be told apart from a round-trip caller at build (the break Java AZ-2235 accepted). Out of scope and left alone: an attribute accessor on the list itself at the top level (`lambda row: row.pts`), and a top-level `dict` row with attribute accessors or a class row with key accessors, which raise `AttributeError` on unpack. Docs: README patch (untrusted-input bullet and the break in the Python upgrade paragraph), Python description and `tests.md`.

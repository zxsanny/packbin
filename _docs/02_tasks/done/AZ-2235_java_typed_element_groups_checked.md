# Java typed rows: list and dict element groups are checked when the scheme is built

**Task**: AZ-2235_java_typed_element_groups_checked
**Name**: Java typed rows: a list or dict element nested-row group without a factory is refused at construction
**Description**: On a row whose class is not a `Map` (and below a nested row that has a child factory), a list or dict whose element is a nested-row group built with the old overload `group(get, set, fields...)` fails `new Scheme<>(...)` with `IllegalArgumentException` naming the element and the missing child factory, instead of building a scheme whose valid packets throw `ClassCastException` on unpack.
**Complexity**: 2 points
**Dependencies**: AZ-2101_java_typed_nested_rows (child factory, `NEEDS_FACTORY`, typed scope in `SchemeOrder`)
**Component**: java
**Tracker**: AZ-2235
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment, Q5, option A, owner answer of 2026-10-06: "take all recommendations, implement everything now". AZ-2101 AC-2 says a typed row "never fails later with `ClassCastException`", but its Javadoc says construction checks only nested-row members and leaves element groups documented (batch 2 report row 7, review JA-F5).

All probes were run on Java at HEAD `2eb9875` (the working tree is identical for `java/`), JDK 21, on a scratch copy of `java/` and `fixtures/`. The typed row is `Holder { List<Item> items; List<Map<String,Object>> maps; Map<String,Item> byName; List<List<Item>> nested; }`, `Item { Integer v; }`. Every probe packs `{items: [Item(v=3)]}` (or `maps: [{v:3}]`) and unpacks `01 01 00 03`.

### What unpack gives an element

`Containers.readElement` takes the row of a non-leaf element from `Walker.newRow(element)`: the factory's product when the element is a nested-row group built with a factory, otherwise a `new HashMap`. The accessors inside the element receive that row. A leaf element (`u8`, `utf8`, ...) has no row. So construction can always tell **which class the element's accessors will receive**: the factory's class, or `HashMap`.

### What construction cannot tell

`Getter` and `Setter` are opaque lambdas. `Access.get("v")` (a `Map` accessor) and `Access.get((Item i) -> i.v)` (a typed accessor) are both plain lambdas, and callers write their own. So construction cannot tell whether the accessors inside an element group take a `Map` or a typed row. It can tell only the row they will be given and the class of the row that holds the list.

### Probes (HEAD)

| # | Scheme on `Holder.class` | Build | Pack | Unpack `01 01 00 03` |
|---|--------------------------|-------|------|----------------------|
| S1 | `list(items, group(identity, ignore, Item::new, u8 0 v typed))` | builds | `01 01 00 03` | OK, `items` holds an `Item` |
| S2 | `list(items, group(identity, ignore, u8 0 v typed))`, no factory | builds | `01 01 00 03` | `ClassCastException: class java.util.HashMap cannot be cast to class Item` thrown out of `BinaryPacker.unpack` |
| S3 | `list(maps, group(identity, ignore, u8 0 v` with `Access.get("v")`), no factory, member `List<Map>` | builds | `01 01 00 03` | OK, `maps = [{v=3}]` |
| S3b | the same with the factory `HashMap::new` | builds | `01 01 00 03` | OK, `maps = [{v=3}]` |
| S4 | typed accessors, element `group(0, u8 0 v)` (anchored) | builds | `01 01 00 03` | `ClassCastException` (HashMap to Item) |
| S4b | Map accessors on `List<Map>`, element `group(0, ...)` | builds | `01 01 00 03` | OK |
| S5 | typed accessors, element `flags(0, u8 0 v)` | builds | `01 01 00 01 03` | `ClassCastException` |
| S5b | Map accessors on `List<Map>`, element `flags(0, ...)` | builds | `01 01 00 01 03` | OK |
| S6 | `dict(byName, group(identity, ignore, u8 0 v typed))`, no factory | builds | `01 01 00 01 00 61 06` for `{a: Item(6)}` | `ClassCastException` |
| S7 | `list(nested, list(identity, ignore, group(identity, ignore, u8 0 v typed)))`, no factory | builds | `01 01 00 01 00 01` for `[[Item(1)]]` | (not run, same path as S2) |
| S8 | **`Map` scheme**, `list(items, group(identity, ignore, u8 0 v typed))`, no factory | builds | `01 01 00 03` | `ClassCastException` |
| S10 | typed nested row with a factory that holds `list(group without factory)` | builds | | |
| S11 | typed `repeat(0, list(items, group without factory))` | builds | | |
| S12 | a scheme whose class is `HashMap.class`, element group without factory, Map accessors | builds | | OK |

Other element kinds, same scratch run: a direct `when` or `times` element fails at construction already (`when 0 tests field 0, which is not an earlier integer or bool field in its scope`, `times 0 takes its count from field 0, ...`: the element scope has no earlier field), a `repeat` element fails (`repeat is not a list element`), and a direct `u2` element builds and unpacks to `{l=[{}]}` (an empty `HashMap` per element: its values go into the `HashMap` row, not into the list; pre-existing, not part of this task).

The Javadoc of `Packbin.group(get, set, create, fields...)` states the gap: construction "does not check list and dict element groups, anchored groups, `when` or flags elements". For `when` and `times` that sentence is moot (they cannot be a direct element, see above).

## What construction CAN decide (the rule of this task)

Two facts are known when the scheme is built: (a) whether the scope that holds the list or dict has a typed row (the scheme's row class is not a `Map`, or the enclosing nested row has a factory, carried through `repeat`, `times`, `when`, `flags` and anchored-group bodies exactly as AZ-2101 carries it for nested-row members); (b) whether the element is a nested-row group built without a factory (its row will be a `HashMap`). The rule:

**In a scope with a typed row, a list or dict whose element is a nested-row group built with `group(get, set, fields...)` (no factory) is refused, also when the element is the element of an inner list or dict.** The message is `list element: nested group on a typed row needs a child factory` or `dict element: nested group on a typed row needs a child factory` (the AZ-2101 text with the element named; the container that directly holds the element group names it).

This refuses exactly S2, S3, S6, S7, S10 and S11 and nothing else. Whether the accessors are typed (S2, S6, S7, would fail on unpack) or `Map` accessors (S3, works today) does not matter: the rule does not look at accessors, because it cannot.

### Shapes the rule leaves alone (undecidable here)

- **S8**: a `Map` scheme (or a `Map` nested row) whose element group has no factory and typed accessors. The row class is a `Map`, so the group is valid for `Map` accessors; the typed-accessor mistake cannot be seen. Unpack still throws `ClassCastException`; stays documented.
- **S4, S5**: on a typed scheme an anchored group, `flags` (or `u2`) element. Their row is a `HashMap` and there is no factory overload for them, so typed accessors there fail on unpack and `Map` accessors work; construction cannot tell which. Stays documented. A caller who wants typed accessors wraps the element in a nested-row group with a factory (`group(identity(), ignore(), Item::new, flags(0, ...))`: same bytes, verified: `01 01 00 01 03` for `flags` and `01 01 00 03` for an anchored group with `HashMap::new`).

### Blast radius of the rule (reproduced in a scratch trial)

- **Existing tests: none.** A trial of the rule (a check of the element in `SchemeOrder.walk` for `LIST` and `DICT`, `list element: ` / `dict element: ` plus the existing `NEEDS_FACTORY` text) passes `bash java/test.sh` with no test changed: `PackbinTest`, `SchemeTest`, `FieldIdBindingTest`, `SessionTest`, the hostile vectors and the golden fixtures. `TypedNestedRowTest.holderScheme` and AZ-2101 AC-5 already use the factory; every other list or dict test is a `Map` scheme with leaf elements (`FieldIdBindingTest.ac4NestedRowTypeHasOwnIds` is a typed row with a leaf element).
- **Drivers and fixtures: none.** The Java handoff driver (`.github/workflows/drivers/Handoff.java`) and `java/tools` use `Map` schemes with leaf, list and dict elements.
- **README examples: none.** The README has no Java list or dict element example; the Java prose in the typed-row sentence of the upgrade note ("Element groups, anchored groups, `when` and `flags` elements on a typed row still unpack into a `Map`") and in the construction-refusals list (the line that starts "In Java, a nested row `group(get, set, fields...)` on a typed row") are rewritten by the docs worker.
- **User code that breaks at construction**, on a typed row or below a nested row with a factory, for a list or dict whose element is `group(get, set, fields...)`: (a) `List<Map>` elements with `Map` accessors, which work today (S3): pass `group(identity(), ignore(), HashMap::new, ...)` (S3b, same bytes); (b) typed accessors, which pack but throw on unpack (S2, S6): pass the factory `Item::new`; (c) pack-only typed schemes that never unpack, which work today (S2 pack): they must name a factory they never call. AZ-2101 accepted the same three breaks for nested-row members.

## Outcome

- `new Scheme<>(...)` throws `IllegalArgumentException` with the messages above for every shape the rule refuses, and no scheme is built.
- Nothing else changes: element groups with a factory, `Map` schemes, anchored group, `flags`, `u2` and leaf elements build and behave as today; unpack and pack of built schemes are unchanged.

## Scope

### Included
- `SchemeOrder.walk` for `LIST` and `DICT`: the check above (typed scope, element a nested-row group without factory, inner lists and dicts included).
- The Javadoc of `Packbin.group(get, set, fields...)` (it is also refused as an element of a list or dict held by such a row) and of `Packbin.group(get, set, create, fields...)` (the sentence that construction does not check element groups). README Java prose: docs worker.
- Tests.

### Excluded
- **Anchored group, `flags` and `u2` elements on a typed scheme (S4, S5)** and the typed-accessor-on-`Map`-scheme case (S8): undecidable at construction, see above.
- Adding a factory overload for anchored or `flags` elements, any change to `Access` (a marker type for `Map` accessors cannot cover accessors the caller writes), and the empty `HashMap` of a direct `u2` element.
- Error kind and label of existing errors (decision C15): the AZ-2101 text for nested-row members is unchanged.
- Unpack, pack and every other package.

## Acceptance Criteria

**AC-1: A list element group without a factory on a typed row is refused (S2)**
Given `Holder.class` and `list(items, group(identity(), ignore(), u8 0 v))` with typed accessors, no factory
When `new Scheme<>(...)` runs
Then `IllegalArgumentException` with the message `list element: nested group on a typed row needs a child factory`, and no scheme is built (HEAD builds it, packs `01 01 00 03` and unpack throws `ClassCastException`: HashMap cannot be cast to Item).

**AC-2: Dict element and inner containers (S6, S7)**
Given the dict of S6 and the list of lists of S7
When each is built
Then `dict element: nested group on a typed row needs a child factory` and `list element: nested group on a typed row needs a child factory`.

**AC-3: Wherever the holding scope is typed (S10, S11)**
Given a typed nested row with a factory that holds `list(group without factory)` (S10); a typed `repeat(0, list(items, group without factory))` (S11); and the same `list` of a typed scheme placed below a `when`, as a `flags` member, as the payload of a flag-byte bit, and inside an anchored `group(0, ...)` (all build at HEAD)
When each is built
Then each throws `list element: nested group on a typed row needs a child factory`.

**AC-4: A factory builds, with typed rows and with `Map` rows (S1, S3, S3b)**
Given S1 (`Item::new`), S3b (`HashMap::new` on `List<Map>` with `Map` accessors), and the AZ-2101 `holderScheme` (list and dict with `Item::new`)
When each is built, `{items:[Item 3]}` / `{maps:[{v:3}]}` packed and `01 01 00 03` unpacked
Then they build, pack `01 01 00 03` and unpack to an `Item` / to `maps = [{v=3}]`, as at HEAD. The old overload S3 is refused (AC-1 message); that is the documented break.

**AC-5: Map schemes and undecidable shapes are unchanged (S4, S5, S8, S12)**
Given the `Map` scheme S8, the `HashMap.class` scheme S12, and on a typed scheme the anchored `group(0, ...)` element S4/S4b and the `flags(0, ...)` element S5/S5b
When each is built, packed and unpacked with `01 01 00 03` / `01 01 00 01 03`
Then every one builds; S8, S4 and S5 with typed accessors still throw `ClassCastException` on unpack and S12, S4b, S5b with `Map` accessors unpack to `[{v=3}]`; the same bytes as at HEAD.

**AC-6: Everything else is unchanged**
Given `bash java/test.sh` (all four mains), the golden and hostile fixtures, the Java handoff driver and `language-pair.sh`
When run
Then all pass with no existing test changed and 0 mismatched bytes (the trial of the rule did not change any).

## Non-Functional Requirements

**Compatibility**
- No wire change and no public API change. A source-breaking construction refusal for the three kinds of user code listed above, as AZ-2101 had for nested-row members. Bytes of schemes that still build are unchanged.

**Reliability**
- A scheme built on a typed row with a list or dict element group never fails with `ClassCastException` on a valid packet because the element group had no factory. The residual shapes (S4, S5, S8) are named in the Javadoc.

## Unit Tests

AC-1 to AC-3 must fail first.

| AC Ref | What to Test | Required Outcome | Test class |
|--------|-------------|-----------------|------------|
| AC-1 | S2 old overload on `Holder` | construction throws the `list element:` message; no scheme | `TypedNestedRowTest` |
| AC-2 | S6 dict; S7 list of lists | `dict element:` and `list element:` messages | `TypedNestedRowTest` |
| AC-3 | S10, S11, below a `when`, under `flags` | the `list element:` message | `TypedNestedRowTest` |
| AC-4 | S1, S3b, `holderScheme`; S3 refused | build, bytes `01 01 00 03`, round trip | `TypedNestedRowTest` |
| AC-5 | S4, S4b, S5, S5b, S8, S12 | build; `ClassCastException` / OK on unpack as listed | `TypedNestedRowTest` |
| AC-6 | whole suite, fixtures, driver | unchanged | `java/test.sh` (all mains) |

`TypedNestedRowTest.java` is 344 lines; the additions (about 80 lines) keep it under 500; if they do not, put the new cases in a new `TypedElementGroupTest` registered in `PackbinTest.main`.

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | `fixtures/golden.hex`, `fixtures/hostile/*` | Java pack and unpack | identical to HEAD | Compatibility |
| AC-6 | `language-pair.sh` rings that include Java (handoff driver) | producer and consumer | 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: Java only; no shared walker, no cross-package import.
- Files at or under 500 lines (`SchemeOrder.java` is 206).
- Error kind and label of existing errors unchanged (decision C15); the new text is the AZ-2101 text with the element named, so the AZ-2101 tests that pin the member message stay as they are.
- No public API change: no new overload, no change to `Access`.
- **STOP CONDITION (owner's brief, assessment 16 Q5):** the implementer stops and reports to the coordinator, before choosing anything else, if (1) the rule breaks an existing test, fixture, driver or README example not listed above, (2) a shape turns up that this spec does not classify as refused or left alone, or (3) the implementer thinks the rule should also cover anchored group, `flags` or `u2` elements, accept `Map` accessors on a typed row, or look at accessors. The options to report: **A** the rule as written (default); **B** A plus a refusal of anchored group, `flags` and `u2` elements on a typed row, with a message that says to wrap them in `group(identity(), ignore(), Factory::new, ...)` (a scratch trial passes the existing suite, and breaks S4b and S5b, which work today; an anchored element has no factory overload, so the message cannot reuse the AZ-2101 text); **C** add a factory overload for those elements (public API growth); **D** leave the gap documented, as at HEAD.
- Bytes and error texts in the ACs were reproduced on Java at HEAD and in a scratch trial of the rule; the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A typed scheme that worked now fails to build**
- *Risk*: `List<Map>` elements with `Map` accessors and pack-only typed schemes (S3, S2 pack) built before.
- *Mitigation*: the message names the element and the child factory; the README upgrade note lists the three kinds and the fix (`group(identity(), ignore(), HashMap::new, ...)`, same bytes); AZ-2101 took the same break for nested-row members.

**Risk 2: The residual gap (S4, S5, S8) looks closed**
- *Risk*: a reader of the new refusal expects every element on a typed row to be checked.
- *Mitigation*: the Javadoc of both `group` overloads names exactly the shapes left unchecked and the workaround (wrap in a nested-row group with a factory); the stop condition above keeps the extension an owner decision.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ticket asks for a message "naming the element and the factory overload". This spec names the element (`list element` / `dict element`) and the child factory, and keeps the AZ-2101 wording; it does not print the method signature (the README names `group(get, set, Child::new, fields...)`). The owner may ask for the signature in the text; the tests pin it | owner | open | Low |
| The ticket text says construction cannot tell typed from `Map` accessors "for some shapes". Reading the code: it can never tell (accessors are opaque), so the rule keys on the class of the holding row and the element's lack of a factory, and S4, S5, S8 stay undecidable. This changes the ticket's "whenever the element group's row would be a `Map` but the scheme's row class is not" only for anchored group, `flags` and `u2` elements, whose row is also a `Map` but which have no factory overload | owner | open | Medium |

## Owner decision (2026-10-06)

DECIDED, assessment 16 Q5, option A, recommendation taken ("take all recommendations, implement everything now"): refuse at construction, with a message naming the element and the child factory, a list or dict element group whose row would be a `Map` when the row that holds it is typed. Where construction cannot decide (accessor flavour; shapes with no factory overload) the implementer stops and reports the options before choosing anything else.

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2), option A as written. A `list` or `dict` whose element is `group(get, set, fields...)` (no factory) fails when the scheme is built if the holding scope is typed (a typed row, a nested row with a factory, and inside a `repeat`, `when`, `flags`, flag bit or anchored group of one): `list element: nested group on a typed row needs a child factory` (`dict element: ...`; an inner list or dict names the container that holds the element). `SchemeOrder.walk` calls the new private `requireElementFactory` for `LIST` and `DICT` and recurses into inner lists and dicts; the Javadoc of both `Packbin.group(get, set, ...)` overloads is updated (`Packbin.java` +8/-7). With a factory (`group(identity(), ignore(), Item::new, ...)`) the same bytes build.

Tests (`TypedNestedRowTest`, +152, now 496 lines: any further case needs the `TypedElementGroupTest` split the spec foresaw): `az2235Ac1ListElementWithoutAFactoryIsRefused`; `az2235Ac2DictAndInnerContainers` (S6, S7, a list of dicts, a dict of lists); `az2235Ac3WhereverTheHoldingScopeIsTyped`; `az2235Ac4AFactoryBuilds` (S1, S3b, `holderScheme`; S3 is refused); `az2235Ac5MapSchemesAndUndecidableShapesAreUnchanged` (S4, S4b, S5, S5b, S8, S12). Review fix: new `TypedElementScopeTest` (3 cases, registered in `PackbinTest`).

Evidence: the S1 to S12 table re-run at HEAD matches the spec; no existing test, fixture, driver or README Java example changed; `javap -public` of `Field`, `Scheme`, `Packbin`, `Access`, `PackSession`, `BinaryPacker`, `Getter` and `Setter` is identical to HEAD; 10,518 schemes the differential refuses with the element message are exactly the rule; mutants killed (the element check removed, the inner recursion removed).

Review findings (PASS_WITH_WARNINGS):
- F2 (no test pinned `typed=false` for element scopes): fixed, `TypedElementScopeTest`: an anchored group, a `flags` and a dict element on a typed `Holder` stay unrefused (`01 0100 03`, `01 0100 01 03`); passing `typed` into the element scope fails the first case.
- F3 (open, Low, owner): the message says "typed row" for a `Map` scheme whose nested row has a `Map` factory (`group(get, set, LinkedHashMap::new, list(l, group(identity, ignore, ...)))` built at HEAD and is refused now); pass `HashMap::new` to the element group. Say whether to keep the wording.

Open (owner, spec options): the residual shapes stay `ClassCastException` on unpack and are documented in the Javadoc, the README note and the Java description: S4 and S5 (an anchored group or a `flags` element on a typed scheme with typed accessors), S8 (a `Map` scheme whose element group has no factory and typed accessors). Options B (refuse anchored, `flags` and `u2` elements on a typed row), C (add an overload) and D (leave as is) are with the owner. An anchored-group element of a typed list that itself holds a nested-row element group without a factory is not refused either (element scopes are checked as untyped).

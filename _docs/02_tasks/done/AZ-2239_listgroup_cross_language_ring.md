# Cross-language ring for a list and a dict of group elements and a list of flags

**Task**: AZ-2239_listgroup_cross_language_ring
**Name**: `listgroup` ring in `language-pair.sh` for the packages that support the shapes
**Description**: `language-pair.sh` gains one ring, `listgroup`, with three pinned packets (list of group, dict of group, list of flags) that TypeScript, Python and Java pack and read around, plus a short-element case that each of the three must refuse. Drivers gain the commands; the packages that cannot build these schemes (Rust, C++, C#) are recorded with the reason and not run.
**Complexity**: 3 points
**Dependencies**: AZ-2193_ci_cross_language_ring (the ring job that runs the script), AZ-2102_typescript_list_group_elements (the shapes and their bytes). AZ-2238_harness_hygiene_prefix_find_consumer makes a failing consumer name itself; it is not needed for pass or fail.
**Component**: shared harness (`.github/workflows/language-pair.sh`, `.github/workflows/drivers/**`)
**Tracker**: AZ-2239
**Epic**: AZ-2069

## Problem

Loop 16 feature assessment, G5, answered by the owner on 2026-10-06 ("take all recommendations, implement everything now"). AZ-2102 gave TypeScript a list or dict of `group` and a list of `flags` with the bytes Python and Java produce, but no shared fixture or ring checks that across languages: the TypeScript bytes were pinned by hex copied from Python (AZ-2102 flagged concern, project AC-3).

The ticket assumed TypeScript, Python, Java, Rust and C++ support these shapes. Probing every package at the committed HEAD 2eb9875 (scratch copies, no repository file changed) shows only three do.

### Support table (probed at HEAD)

The three packets, from the AZ-2102 schemes. Bytes are type `01`, then `u16` count, then the elements:
- **list of group**: `list(pts, group(u8 a, u8 b))`, `{pts: [{a:1,b:2},{a:3,b:4}]}`: `01 0200 01 02 03 04`.
- **dict of group**: `dict(m, group(u8 a, u8 b))`, `{m: {y:{a:3,b:4}, x:{a:1,b:2}}}` (inserted y first): `01 0200 0100 78 01 02 0100 79 03 04`; keys are written in unsigned byte order.
- **list of flags**: `list(pts, flags(u8 a, u16 b))`, `{pts: [{a:1}, {}, {b:2}]}`: `01 0300 | 01 01 | 00 | 02 0200`.

| Package | List of group | Dict of group | List of flags | Bytes observed | A driver command would look like | Reason when not |
|---------|---------------|---------------|---------------|----------------|----------------------------------|-----------------|
| TypeScript | yes | yes | yes | pack `01020001020304`, `01020001007801020100790304`, `010300010100020200`; unpack of each gives the items back (`pts: [{a:1,b:2},{a:3,b:4}]`, `m: {x:{...}, y:{...}}`, `pts: [{a:1},{},{b:2}]`) | `list((r) => r.pts, group((r) => r.p, [u8(0, (p) => p.a), u8(1, (p) => p.b)]))`; `dict((r) => r.m, group(...))`; `list((r) => r.pts, flags(0, [u8(0, (p) => p.a), u16(1, (p) => p.b)]))` | |
| Python | yes | yes | yes | the same three packs; unpack gives `{'pts': [{'a': 1, 'b': 2}, ...]}`, `{'m': {'x': ..., 'y': ...}}`, `{'pts': [{'a': 1}, {}, {'b': 2}]}` | `list(lambda r: r["pts"], group(0, u8(0, lambda p: p["a"]), u8(1, lambda p: p["b"])))`, the same with `map_field`, and `flags(0, u8(0, ...), u16(1, ...))`; an accessor must be a member access (`p.get("a")` raises `accessor must be a member access`) | |
| Java | yes | yes | yes | the same three packs; unpack gives `{pts=[{a=1, b=2}, {a=3, b=4}]}`, `{m={x={a=1, b=2}, y={a=3, b=4}}}`, `{pts=[{a=1}, {}, {b=2}]}` (both `Packbin.group(0, ...)` and `Packbin.group(Access.identity(), Access.ignore(), ...)` give the same bytes) | `Packbin.list(Access.get("pts"), Access.set("pts"), Packbin.group(0, Packbin.u8(0, Access.get("a"), Access.set("a")), ...))`, `Packbin.dict(...)`, `Packbin.flags(0, ...)` as the element | |
| Rust | no | no | no | not run: the scheme is refused when it is built, a panic: `list "pts" cannot carry element "g": an element is one integer, float, bytes, utf8, list or dict, or a u2 with one name`; the same for `dict "m" ... "g"` and for `flags`: `list "pts" cannot carry element "f": ...` | none (`MapScheme::new(1, vec![list("pts", group(0, "g", vec![u8("a"), u8("b")]))])` panics) | by design: README upgrade notes (line 1097) and `rust/src/integrity_tests.rs` `list_of_group_is_refused`, `dict_of_group_is_refused`, `list_of_flags_is_refused` |
| C++ | no | no | no | not run: `constexpr auto s = scheme<Row>(1, list<&Row::pts>(group(0, u8(0), u8(1))))` does not compile (`constexpr variable 's' must be initialized by a constant expression`, from `invalid_field_id`); as a non-constexpr value the scheme is built and `pack` and `unpack` return `Error::SchemeInvalid` at offset 0; the same for `dict<&Row::m>(group(...))` and `list<&Row::pts>(flags(...))` | none | a list or dict binds one scalar, utf8, list or dict per element (`bind_element`, `cpp/include/packbin/table.hpp:334-356`); a group or flags root has span above 1, so the element is marked invalid |
| C# | no | no | no | not run: unpack of `01020001020304` throws `KeyNotFoundException: The given key 'P' was not present in the dictionary.` (my probe shape; matches AZ-2119); pack with the same shape throws `ArgumentException: 'A' (field id 0) has no value`, so no packing shape was found | none | AZ-2119_csharp_group_list_element, held with the C# work; the ticket excludes C# until it lands |

Probe environment: macOS arm64, node 22.23.0, Python 3.14.6, JDK 21.0.2, Rust cargo 1.79.0, Apple clang, .NET SDK 10.0.103. The three hex values of the ticket are reproduced exactly by TypeScript, Python and Java; none needed correction.

### Short elements (probed at HEAD)

Each supporting package refuses a packet whose last element is short, with no row delivered:

| Shape | Bytes | TypeScript | Python | Java |
|-------|-------|------------|--------|------|
| list of group | `010200010203` (second item lacks `b`) | `{ok:false, field:"b", needed:1, left:0}` | `ShortPacket(field='1', needed=1, left=0)` | `ShortPacket field=1 needed=1 left=0` |
| dict of group | `010200010078010201007903` (value of `y` lacks `b`) | `{ok:false, field:"b", needed:1, left:0}` | `ShortPacket(field='1', needed=1, left=0)` | `ShortPacket field=1 needed=1 left=0` |
| list of flags | `0103000101000202` (third item has flag `02` and one byte of `b`) | `{ok:false, field:"b", needed:2, left:1}` | `ShortPacket(field='1', needed=2, left=1)` | `ShortPacket field=1 needed=2 left=1` |

The error labels differ (`b` against `1`): a known difference outside this task (decision C15); the drivers check only that unpack fails and hands no row to the handler.

### The ring, prototyped on a scratch copy

- New driver commands in scratch copies of the three drivers (`handoff.py` 187 to 215 lines, `handoff.ts` 381 to 420, a new `HandoffElements.java` of 107 lines that `Handoff.java` calls from its `default` branch because `Handoff.java` is 416 lines and would pass the 500 cap).
- The block below ran against them: 9 handoffs and 9 short checks passed in about 2 s (the Java classes were built once before).
- Mutations, each ends the script with exit 1: TypeScript packing `a: 9` printed `typescript pack-listgroup mismatch`; a Python consumer that expects another row for `dictgroup` printed nothing at HEAD, and `python unpack-dictgroup failed on the bytes packed by typescript` with the AZ-2238 change to `handoff()` (prototyped); the `listgroup` short bytes replaced by the full valid packet printed `typescript unpack-listgroup-short failed: it read a short element or the driver crashed (see the output above)`.

## Outcome

- `language-pair.sh` runs the `listgroup` ring: TypeScript to Python, Python to Java, Java to TypeScript, for each of the three packets, with the three pinned hex values; then each of the three packages refuses the three short packets.
- The Rust, C++ and C# non-participation, and the reason, are written in the script next to the ring.
- No package behavior changes; the wire bytes are the ones above.

## Scope

### Included
- `.github/workflows/language-pair.sh`: the hex variables, 9 `handoff` lines, the short-element loop, a comment naming the packages not run; the Java branch of `run_lang` compiles and watches `HandoffElements.java`.
- `.github/workflows/drivers/handoff.ts`, `handoff.py`, `Handoff.java` (the `default` branch and `parse`, `hex` visibility) and the new `HandoffElements.java`: nine commands each, `pack-<kind>`, `unpack-<kind> <hex>`, `unpack-<kind>-short <hex>` for the kinds `listgroup`, `dictgroup`, `listflags`.

### Excluded
- Rust, C++ and C# drivers and packages (no package behavior is changed, none is worked around: a Rust `times` with a `u16` count writes the same bytes but is another feature, so it is not used as a stand-in).
- Making Rust or C++ accept these shapes; the C# fix (AZ-2119).
- Documentation changes.
- Any file outside `.github/workflows/language-pair.sh` and `.github/workflows/drivers/**`.

## Acceptance Criteria

**AC-1: Packages run and packages not run are recorded**
Given the support table above
When `language-pair.sh` is read
Then the new ring names TypeScript, Python and Java as its participants and a comment above it says Rust and C++ refuse these schemes when they are built, and C# throws `KeyNotFoundException` until AZ-2119 lands, so none of the three is run. The Rust, C++ and C# drivers get no command for these kinds. The check is review of that comment against the table; no script holds it.

**AC-2: The three packets go around with the pinned bytes**
Given the drivers of TypeScript, Python and Java
When `language-pair.sh` runs (in the `ring` job on CI, or by hand)
Then for each kind the pairs `typescript -> python`, `python -> java` and `java -> typescript` pass: the producer's `pack-<kind>` prints exactly `01020001020304` for `listgroup`, `01020001007801020100790304` for `dictgroup`, `010300010100020200` for `listflags`, and the consumer's `unpack-<kind>` exits 0 only when it reads back the items of the table (the dict compared without regard to key order). The script's last line stays `language pairs passed`. The check is `handoff` in `language-pair.sh`.

**AC-3: A producer that drifts is named**
Given a package that packs different bytes for one kind (observed: TypeScript with `a: 9` in the first list item)
When the script runs
Then it exits 1 with `typescript pack-listgroup mismatch` and the consumer is not called. The check is `handoff` in `language-pair.sh` (existing text); the mutation is a one-off run recorded in the batch report.

**AC-4: A short element is refused by every participant**
Given the packets `010200010203`, `010200010078010201007903` and `0103000101000202`
When each of TypeScript, Python and Java runs `unpack-<kind>-short <hex>`
Then it exits 0 only when unpack fails and no row reached the handler, and exits 1 when the packet is read or a row is delivered; the script runs the 9 combinations and exits 1 with `<language> unpack-<kind>-short failed: it read a short element or the driver crashed (see the output above)` otherwise (the line also covers a driver that exits 2 or crashes; its own stderr above gives the reason). The check is the short-element loop in `language-pair.sh` and the three `unpack-<kind>-short` commands of each driver. The drivers do not compare the error label (`b` against `1`).

**AC-5: A consumer that cannot read is a failure**
Given a consumer that cannot read the bytes of one kind (observed: a Python consumer that expects another row)
When the script runs
Then it exits 1 (with AZ-2238 the log names consumer, ring and producer, for example `python unpack-dictgroup failed on the bytes packed by typescript`; without it the exit is 1 and the log is empty, as for every ring today). The check is `handoff` in `language-pair.sh`; the mutation is a one-off run.

**AC-6: Nothing else changes**
Given the existing rings (`user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `roundflags`, `roundwhen`, `session`) and the golden position check
When the change is applied
Then their lines, order and expected hex are unchanged, no existing driver command changes, no package source file is touched, and the diff names only `.github/workflows/language-pair.sh` and files under `.github/workflows/drivers/`. The Java driver is rebuilt when `HandoffElements.java` is newer than the cached class directory (`find ... -newer` lists it). The check is the diff and `git diff --stat`; the unchanged rings are exercised by the `ring` job.

## Non-Functional Requirements

**Compatibility**
- Wire bytes are pinned by the three hex values above; the order of keys in the dict packet is the unsigned byte order of the keys.

**Reliability**
- A package that cannot produce the bytes is reported (table, script comment), not worked around.
- A refused short packet is a failure of unpack with no row; a driver that exits 1 for any other reason is also a failure of the ring.

**Performance**
- The ring adds about 2 s to the script with a built Java driver (observed). The `ring` job's 15 minute target (AZ-2193) is unaffected.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | each driver: `pack-listgroup`, `pack-dictgroup`, `pack-listflags` | prints the pinned hex and exits 0 |
| AC-2 | each driver: `unpack-<kind> <pinned hex>` | exit 0; exit 1 for a hex that holds other items |
| AC-4 | each driver: `unpack-<kind>-short <short hex>` | exit 0; exit 1 for the full packet |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2, AC-4 | `language-pair.sh` with Node, Python and a JDK on the host (and the other toolchains for the whole script) | the nine handoffs and nine short checks | the script reaches `language pairs passed` | Compatibility |
| AC-3, AC-5 | a scratch copy of the drivers with one value changed | the script | exit 1 with the named line (AC-3); exit 1 (AC-5) | Reliability |

## Constraints

- ADR-001: each driver uses its package's public API only; no shared walker, no cross-package import.
- Files at or under 500 lines: `handoff.ts` about 420, `handoff.py` about 215, `Handoff.java` stays 416 and the new `HandoffElements.java` about 110, `language-pair.sh` about 190 after AZ-2238.
- Error kind and label of existing errors unchanged (decision C15); no package changes.
- `.github/workflows/drivers/**` and `language-pair.sh` only (the task text).
- `bash.md` rules for the script: `set -euo pipefail`, quoted expansions, no `2>/dev/null`.
- Wire bytes in the ACs come from real runs of the packages listed in the table; the implementer re-derives them from a real run.

## Risks & Mitigation

**Risk 1: The Java driver is not rebuilt, so the new commands hit a missing class**
- *Risk*: `run_lang java` rebuilds only when a source is newer than `Handoff.class`; a cached `/tmp/packbin-handoff-java` from an older run would lack `HandoffElements.class` and fail the new commands with `NoClassDefFoundError`.
- *Mitigation*: AC-6: the `find -newer` list and the `javac` command both name `HandoffElements.java`.

**Risk 2: A participant starts to differ from the other two on an edge case**
- *Risk*: the ring is the first cross-language check of these shapes; an unknown difference (for example the order of dict keys on unpack, or the shape of an empty flags item) could fail on the first CI run.
- *Mitigation*: the three packets and three short cases ran green here on TypeScript, Python and Java with the real packages; the CI Node 24, JDK 26 and Python 3.14 runs are proven by the first CI run.

**Risk 3: The ring grows to six languages later**
- *Risk*: C# joins after AZ-2119 and Rust or C++ are asked to join.
- *Mitigation*: the ring is a list of `handoff` lines; the comment in the script names what to add. Rust and C++ refuse the schemes by design (README line 1097, `integrity_tests.rs`); joining them would be a feature decision, not a harness change.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ticket expected Rust and C++ to take part. Probed: Rust refuses the schemes at construction (documented in the README upgrade notes) and C++ builds an invalid scheme, so the ring has three participants and the support table says why. The rule "a package that cannot produce the bytes is reported" applies to Rust, C++ and C# | owner | open | Low |
| "One ring" is three kinds (`listgroup`, `dictgroup`, `listflags`) because a ring kind selects exactly one pinned packet and `handoff()` passes only `pack-<kind>`. The alternative is one combined packet; it would not pin the three values of AZ-2102 separately | implementer | open | Low |
| No test file guards that the ring stays in the script (the task text limits the change to `language-pair.sh` and the drivers). A grep check in `ring-wiring.test.sh` would; the owner may add it | owner | open | Low |
| The C# pack shape for these elements was not found, so C# unpack is the only observed C# failure; AZ-2119 owns it | owner | accepted-risk | Low |

## Owner decision (2026-10-06)

DECIDED, take all recommendations (feature assessment of loop 16, "implement everything now"): G5 is done now as a harness task: one ring `listgroup` in `language-pair.sh` with a producer and a consumer command in the drivers of the packages that support the shapes today, a short-element case that must fail in each of them, and a record of which packages run it and which do not, with the reason. The wire bytes are pinned, no package changes, and a package that cannot produce the bytes is reported, not worked around. The open concerns above are resolved by this section except the participant row, which the owner may answer "take the recommendation".

## Loop 16 result (2026-10-06)

Done in loop 16 (round 2), with AZ-2238 in one harness worker. `language-pair.sh` (156 to 204 lines) gains three rings for TypeScript, Python and Java: `listgroup` `01020001020304` (`[{a:1,b:2},{a:3,b:4}]`), `dictgroup` `01020001007801020100790304` (`{y:{a:3,b:4}, x:{a:1,b:2}}` in unsigned key order) and `listflags` `010300010100020200` (`[{a:1},{},{b:2}]`), nine `handoff` lines (TypeScript to Python, Python to Java, Java to TypeScript, per kind), and a short-element loop (each of the three packages refuses the three packets cut short: `010200010203`, `010200010078010201007903`, `0103000101000202`; 3 x 3 checks). A comment above the ring names why Rust (it refuses these schemes at construction), C++ (it builds an invalid scheme, `bind_element` in `table.hpp`) and C# (`KeyNotFoundException` on unpack until AZ-2119) do not take part; all three reasons were re-probed at HEAD.

Drivers: `handoff.ts` +52, `handoff.py` +55, `Handoff.java` (the `default` branch calls `HandoffElements.run`; `hex` and `parse` package-private, still 416 lines) and the new `HandoffElements.java` (88 lines): `pack-<kind>`, `unpack-<kind> <hex>`, `unpack-<kind>-short <hex>`; a missing or empty hex exits 2 (otherwise an empty packet would be refused and the short check would pass for nothing). The Java cache rebuilds for a missing `HandoffElements.class` (also a cache built from HEAD) and for a newer `HandoffElements.java`. No existing ring line or driver command changed.

Evidence: the bytes were re-derived from real runs; the unpacked items match the spec table in all three packages. Mutations (each exits 1 with a named line): TypeScript first item `a:9` gives `typescript pack-listgroup mismatch`; Python and Java producers printing other bytes give `python pack-listgroup mismatch` and `java pack-listgroup mismatch`; a Python consumer expecting another dict row gives `python unpack-dictgroup failed on the bytes packed by typescript`, TypeScript and Java consumers likewise; a full packet in the short list gives `typescript unpack-listgroup-short failed: it read a short element or the driver crashed (see the output above)`. Driver matrix (reviewer, 27 checks over three kinds and three drivers): `pack` prints the pinned hex; `unpack` exits 0 on the full packet and 1 on other items or a short packet; `-short` exits 0 on the short packet and 1 on the full one; no argument or an unknown command exits 2. The full ring prints `language pairs passed` (84 s cold, 92 s warm on macOS, 4 m 55 s under CPU load).

Review finding F5 (low): the short-check line blamed a short element when the driver had crashed. Fixed in the H2 fix pass: the line now reads `<lang> unpack-<kind>-short failed: it read a short element or the driver crashed (see the output above)` and AC-4 above quotes it; the driver's own stderr is printed just above it.

Open (Low): the short check does not compare the error kind, as the spec says, so a refusal for another reason passes it (the valid-packet handoffs would catch scheme or header drift; optional hardening: also require a short-packet error); nothing guards that the ring stays in the script (optional grep check in `ring-wiring.test.sh` for three `handoff ... listgroup` lines per kind plus the short loop). The Ubuntu runner proves Node 24 with `--experimental-strip-types` and `import { type Field }`, JDK 26 compiling `HandoffElements.java`, and Python 3.14.

# Implementation completeness

**Loop**: 13
**Date**: 2026-10-05
**Verdict**: PASS

| Task | Outcome | Result |
|------|---------|--------|
| AZ-2084 | TypeScript pack throws `RangeError` naming the member for an integer or float that does not fit, a non-number, an unsafe 64-bit `number` (pass a `bigint`); wire bytes of valid inputs unchanged | PASS |
| AZ-2085 | Rust typed schemes: two bound lists or dicts keep their own members; `when` matches by integer value at any width; a `when` on a non-integer source or a composite list/dict element fails at construction | PASS |
| AZ-2086 | Rust typed `times` binds a `Vec<E>` of element rows (`SchemeItem::times(anchor, count_id, get, set, members)`); the README times example and the route fixture pack and unpack; map form keeps rounds as `__times_<anchor>` Groups and refuses edited lists that disagree with them | PASS |
| AZ-2087 | C# `when` and borrowed counts must name an earlier field in the same scope, else `Scheme<T>` construction fails; plus (owner decision) pack by round index through `when` / `flags` / groups and aligned per-round unpack, which makes the AC-4 pack leg true | PASS |
| AZ-2088 | C# pack throws for a missing required value, a field declared for another row type, and a round that runs out of list; float `when` follows Java `Double.compare`; a scheme owns a copy of its fields and bindings (a shared `FlagGroup` stays shared, follow-up) | PASS |
| AZ-2090 | TypeScript `when` and count references resolve in their own id scope at construction (`new Scheme` and `scheme()` agree); `eq` compares numbers and bigints by value; three construct vectors are real tests | PASS |
| AZ-2091 | TypeScript flags inside groups are packed; member names that flattening would overwrite fail at construction; the flag-byte value is never a row member; plus (owner decision) repeat/times pack by round index and aligned unpack | PASS |
| AZ-2175 | C# pack decides every `when` and every count from the fields it wrote (per packet, per round, per list/dict element), as unpack does; a count whose field was not written throws; `Eq(bool, false)` with a clear bit no longer matches; PackSession counter and split-form flag byte round pinned | PASS |
| AZ-2176 | C# refuses a `repeat` / `times` nested inside a `repeat` / `times` round at construction (list/dict elements keep building), same message as Java | PASS |
| AZ-2177 | TypeScript refuses a `repeat` / `times` nested inside a round at construction (`new Scheme` and `scheme()`); `-0` pinned; AC-2 amended to what TypeScript can do (empty collections round-trip, AZ-2102) | PASS |
| AZ-2178 | Seven typed Rust `times` shapes pinned by tests (sibling times sharing a count, times in a `when`, element-local `sized`, u16 count 300, 255 rounds of an 8-member flags, primitive and tuple elements, session round trip); no production change | PASS |
| AZ-2179 | `roundflags` and `roundwhen` rings in `language-pair.sh` across C# (producer only), TypeScript, Rust, Java, C++; no package code changed | PASS |

No scaffold, stub or placeholder was added in any of the five batches (scan of the changed non-test source: the only hits are `Convert.ToDouble` matching "todo" case-insensitively; no `.todo`, `.skip`, `Skip =` or `#[ignore]` in the changed tests; the three TypeScript construct-vector todos are now real tests). Every rule runs in the real scheme construction and the real pack/unpack walkers; tests call the public pack and unpack.

Owner decisions and review fixes that go past the specs (batch reports): C# round slicing and aligned unpack pulled into AZ-2087 (the C# part of AZ-2134); the TypeScript twin pulled into AZ-2091; Rust F1 (generated-name collisions across scopes) and F2 (stale Groups overriding edited lists) fixed in AZ-2086; C# shared `FlagGroup` deferred; Rust unpack memory (about 8x), C# and TypeScript null padding (about packet bytes × names per round) accepted with a README note. Assessment round 1 (owner scope A, 2026-10-05) added AZ-2175 to AZ-2179; its deferred findings are follow-up tickets AZ-2180 to AZ-2194 and notes on AZ-2092, AZ-2112, AZ-2113, AZ-2117, AZ-2126, AZ-2127, AZ-2128. Known gaps carried as follow-ups: AZ-2134 (Python only), AZ-2135, and the items in the batch reports' Discovered tables.

## System Pipeline Audit

One pipeline per package: scheme construction (order, scope, shape and integrity checks, field-ownership copies) then pack and unpack walk the same field list. WIRED in TypeScript, Rust and C#; Python, Java and C++ unchanged. Cross-language: `language-pair.sh` `user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `session`, `position` and the new `roundflags` and `roundwhen` rings pass (C# produces only in the two new rings: no public reader, AZ-2092) producer → consumer across all six languages through the real drivers, after each batch and in the final parity runs.

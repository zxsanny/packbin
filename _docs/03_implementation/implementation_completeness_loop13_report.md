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

No scaffold, stub or placeholder was added (scan of the changed non-test source: the only hits are `Convert.ToDouble` matching "todo" case-insensitively; no `.todo`, `.skip`, `Skip =` or `#[ignore]` in the changed tests; the three TypeScript construct-vector todos are now real tests). Every rule runs in the real scheme construction and the real pack/unpack walkers; tests call the public pack and unpack.

Owner decisions and review fixes that go past the specs (batch reports): C# round slicing and aligned unpack pulled into AZ-2087 (the C# part of AZ-2134); the TypeScript twin pulled into AZ-2091; Rust F1 (generated-name collisions across scopes) and F2 (stale Groups overriding edited lists) fixed in AZ-2086; C# shared `FlagGroup` deferred; Rust unpack memory (about 8x), C# and TypeScript null padding (about packet bytes × names per round) accepted with a README note. Known gaps carried as follow-ups: AZ-2134 (Python only), AZ-2126, AZ-2127, AZ-2128, AZ-2135, plus the new items in the batch reports' Discovered tables.

## System Pipeline Audit

One pipeline per package: scheme construction (order, scope, shape and integrity checks, field-ownership copies) then pack and unpack walk the same field list. WIRED in TypeScript, Rust and C#; Python, Java and C++ unchanged. Cross-language: `language-pair.sh` `user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `session` and `position` rings pass producer → consumer across all six languages through the real drivers, after each batch and in the final parity runs.

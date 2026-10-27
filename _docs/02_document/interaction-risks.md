# Interaction risks

## Flows and seams

| Flow | Seam | What crosses |
|------|------|----------------|
| F1 Pack | caller → package | a value |
| F2 Unpack | caller → package | bytes |
| F3 Publish | the six packages, via the golden fixture | the hex |
| F3 Publish | Actions → the six registries | one package per language in the tag |
| F4 Session (retired, loop 74, ADR 009) | opener → waiter | nothing: the stream session is removed |
| F5 Frame session | sender → receiver | one body per message: clear part, ciphertext and a 4, 8 or 16-byte tag, at most 255 bytes |

## Risks

| Risk | Outcome | AC | Owner |
|------|---------|----|-------|
| The six languages write different bytes for the same list | mismatch count is 0, or the tag publishes nothing | AC-3, AC-14 | AZ-1875 and each package |
| Unpack returns part of a short buffer | value count is 0, and the next pack still matches the golden hex | AC-8 | each package |
| A clear flag is stored as 0 | a present 0 is written; absence adds 0 bytes | AC-4, AC-5 | each package |
| A language missing from the tag still publishes | that registry receives 0 packages | AC-15 | AZ-1875 |
| The crates.io token (and the NuGet key) is exchanged before the whole build phase; if it expires before the upload, earlier registries are published and crates.io is not | a partial release; re-running the tag with a fresh token finishes it. Token lifetime and cold-runner build time are unmeasured, watch both on the first real tag and split `publish.yml` into build, exchange and upload if the build nears 10 minutes (loop 14 assessment U1, batch 3 review finding 1) | accepted, no AC | AZ-2096 |
| Retired (loop 74, ADR 009): a stream session payload is dropped and the next unpack on that direction is not the sent row | the stream session is removed; a frame stands alone, so a lost frame affects only itself | pack-session AC-4 (retired) | none |
| A frame is changed, replayed, or opened under the wrong key or epoch | `TagMismatch`, `Duplicate` or `TooOld`; the output buffer and the replay window are unchanged | `pack-session.md` 3.0.0 § Open; the 157 rows of `fixtures/frame/vectors.txt` | C#, Java, Rust, Swift (C++, Go, Python, TypeScript in loop 75) |
| A `times` count in the billions with one lone value makes pack write gigabytes (security F21) | pack refuses a count above `maxRounds` (65,535 by default) before it writes a round; C++ holds its rounds in an `Array` of at most 65,535 | AZ-2329 AC-1 to AC-3 | C#, TypeScript, Python, Java, Rust |
| A split flag bit is decided before the field its `when` or `times` reads is written, so a given value is dropped without a word | pack fails naming the member when the body would be written; a false condition stays silent | AZ-2331 AC-1 to AC-4 | each package |
| A lone value under a `times` (or a `list` element that holds one) makes pack write gigabytes from a small request: a 65,535-character `utf8` under a count of 65,535 wrote 4 GiB; the round cap bounds one count, not the output (security F28, F31) | pack refuses a packet above `maxBytes` (16 MiB by default, the type byte included) before the write that passes it, charges `maxSlots` per round as unpack does, and refuses a `repeat` list above `maxRounds`; memory stays near the budget; C++ writes into the caller's buffer | AZ-2354 AC-1 to AC-5, AZ-2355 AC-1 to AC-3 | C#, TypeScript, Python, Java, Rust |
| A flag bit decides a late `when` or `times` nested in a `when` or `flags` of its body, or a count sits behind a clear `when`: C++ wrote rounds whose count was never written (`010003055a00`, `010005`) | pack refuses with `BadValue` naming the member; each late member of the bit is linked and checked, a `when` with a false outer condition still packs | AZ-2357 AC-1, AZ-2364 AC-1 (AC-2 of both: the arm flash and stack budgets) | C++ |
| A `repeat` or `times` with an empty body charges 0 slots and writes 0 bytes, so neither `maxSlots` nor `maxBytes` bounds its CPU: a `list` of 65,535 groups each holding `times(65535) {}` took 93 s to pack in TypeScript (security F33) | the scheme is refused when it is built, in all six; no per-round cost | AZ-2390 AC-1 to AC-3 | all six |
| The slot width of a round differed between packages (Rust counted group, `flags` and flag-byte names; Python missed an empty group and counted duplicates twice; Python's unpack charged 8 more per name for the first round of a run), so a packet right at `maxSlots` passed in one package and failed in another, and Python refused what its own pack wrote | one rule, the distinct names a round can hold, charged alike by pack and unpack in all six (Java counts a nested-row group as one slot) | AZ-2381 AC-1, AC-2; AZ-2382 AC-1, AC-2 | all six |
| A short list under `flags` in a `repeat` read as absent in the later rounds (TypeScript packed `010101050200`, Python refused); a count above 0 behind a clear `when` packed a clear bit with the count unwritten; Java refused a split-bit `times` with no body where TypeScript packed a clear bit; C++ and Rust refused a late `when` in a bit body that another member sets | refused or aligned in the packages that differed, with the rows pinned by hex (reference rows 27 to 56) | AZ-2383, AZ-2384, AZ-2385, AZ-2386, AZ-2387 | each package |
| A typed C# row has a member that cannot hold the list of a `repeat` or `times` round: typed `Unpack` threw `InvalidCastException` (security F17), or a `List<int>` of a `u32` threw `OverflowException` (F27) | unpack returns an error value naming the member, handler not called; a list member of a round that cannot hold the per-round list is refused at construction | AZ-2366 AC-1, AC-2 | C# |
| A `bits`, `packed` or `sized` count above 0 behind a clear `when`, with no value, packed a clear bit `01 00 00` while the same shape with a `times` was refused: the count the row gave meant nothing | refused in all six (C++ already refused every such row); count 0, no count and a holding `when` pack as before | AZ-2410 AC-1 to AC-3 | all six |
| A packet within the old `maxSlots` of 4,194,304 cost up to 1.07 GB of resident memory to unpack (finding F10: 4.3 MB, 64 names a round, 65,535 items), so the memory of a refused or accepted packet was set by a limit too high for a library | default `maxSlots` 1,048,576, peak 120 to 353 MB for the same packet; a scheme can still raise the limit; `maxRounds` and `maxBytes` unchanged | AZ-2415 AC-1 to AC-4 | C#, TypeScript, Java, Rust, Python |
| A C# `List<double>` for an integer `list` built and unpacked but pack refused it | refused when the scheme is built, so a scheme builds if and only if it packs | AZ-2411 AC-1 to AC-3 | C# |
| The six packages read the same `repeat` row differently: Rust dropped per-name lists given without `__repeat__` groups (packed `01`), Python refused a lone value and a `when` list that the others packed, Rust refused a short `times` list under `flags` that the others packed | Rust refuses per-name `repeat` lists without groups, Python packs the lone value and the `when` list (a short required list is refused as in TypeScript), Rust packs the short `times` list under `flags` (a `times` that is itself a `flags` member stays refused); each pinned by hex | AZ-2412, AZ-2413, AZ-2414 | Rust, Python |
| A C++ `repeat` or `times` whose body held only an empty `when` or group built, charging no slot and writing no byte | `SchemeInvalid` at construction, looking through `when` and groups; arm flash 8152 of 8192 B | AZ-2416 AC-1 to AC-3 | C++ |
| A hostile-case loader that does not check the rule of a refused case passes a refusal by the wrong rule | every loader has a standing test that a wrong rule-table entry fails it naming the case | AZ-2418 AC-1 | all six |
| Closed in loop 23 (loop 22 review): Rust unpack gives per-name lists holding only the rounds that read the name, so repacking a `times` under `flags` from them shifts values without an error; the Rust map form dropped per-name lists given beside `__repeat__` groups; a C++ `when` with a negative `eq` field id built and never held | README exception U18 B (repack from the `__times_N` groups); Rust refuses the dropped values (AZ-2433); C++ refuses `eq` ids outside 0..32 767 (AZ-2431) | review22 #1, #5, #6; AZ-2431 AC-1, AZ-2433 AC-1, AC-2 | Rust, C++ |
| A Rust `repeat` dropped a value kept beside `__repeat__` groups, a nested `times` name or `__times_<anchor>` key and a `flags` own name given without groups (security F37) | refused naming the value: `list for 'n' disagrees with its rounds` beside groups, the U13 text without; values that agree with the rounds pack | AZ-2433 AC-1 to AC-4, assessment23 G5, G6 | Rust |
| A C++ `when` whose `eq` id was negative or above 32 767 built, never held and dropped its members (security F36); the empty-body tests reached their rule only through it | `SchemeInvalid` at the `when`'s id, 0 B of flash; the body rule pinned by direct `check_shape` calls | AZ-2431 AC-1 to AC-4 | C++ |
| One U11 row read differently: TypeScript packed a `bigint` count above 2^53; Python refused a short count list in a round whose missing entry sits behind a clear `when` | TypeScript refuses the large count; Python packs the short list as TypeScript, Java and C#; the rule is pinned in six nested positions | AZ-2434, AZ-2437, AZ-2436 | TypeScript, Python, all six |
| Closed in loop 25 (loop 23 review and assessment): C++ ids outside 0 to 32,767 are `SchemeInvalid`, -1 stays the count sentinel (U25, AZ-2472); C++ packs the clear bit for an unbound counted member with count 3 behind a clear `when`, kept as a documented exception (U24, AZ-2479); a C# dictionary row reads and returns a nested-row group through the nested dictionary (U26, AZ-2473); Python raises `ValueError` for a value whose count no field wrote (Low-1, AZ-2474) | owner decisions of 2026-10-14 | review23 #1 to #3, assessment23 U24 to U26 | C++, C#, Python |

The dropped-payload row is retired with the stream session (loop 74, ADR 009); frame mode adds a tag and needs no ordered delivery. The token-lifetime row is accepted in loop 14 and has no AC. Each other material risk already has a numeric AC. For the first row, loop 16 (AZ-2193) added a second detector besides the golden fixture: the `ring` job of `test.yml` runs the cross-language hand-offs (`language-pair.sh`, bytes packed by one package and read by the next) on every push and pull request, and gates a tag publish like any other test job. It is unproven until its first run on the Ubuntu runner.

## Pending Step 2

These risks land on each language package task:

| Risk | AC | Owner |
|------|----|-------|
| This package's position bytes differ from the fixture | AC-3 | each package |
| Unpack returns part of a short buffer | AC-8 | each package |
| A clear flag is stored as 0 | AC-4, AC-5 | each package |

Strings, lists, and dictionaries:

| Risk | AC | Owner |
|------|----|-------|
| A string count includes its own 2 bytes, so the next field starts inside the text | AZ-1938 AC-1 | AZ-1938 |
| A list count consumes the following field | AZ-1939 AC-3 | AZ-1939 |
| A dictionary pair count is read as a byte length | AZ-1940 AC-1, AZ-1940 AC-3 | AZ-1940 |
| Two languages agree with a fixture but not with each other on a nested map | AZ-1941 AC-1, AZ-1941 AC-2 | AZ-1941 |

Go package (loop 24, AZ-2222; decompose 1.8):

| Risk | AC | Owner |
|------|----|-------|
| Go agrees with its own tests but not with a peer on a ring kind (bytes cross a language seam) | AZ-2449 AC-1, AC-2 | AZ-2449 |
| Go follows spec text where TypeScript and the five agree otherwise (a parity row drifts) | AZ-2447 AC-1, AC-2 | AZ-2447 |
| A Go golden mismatch still lets the other registries or the Go tag publish | AZ-2450 AC-1 | AZ-2450 |
| A re-run moves or duplicates `go/vX.Y.Z` | AZ-2450 AC-3 | AZ-2450 |
| The hostile checker counts "Go" inside another word and passes a section that omits Go | AZ-2446 AC-3 | AZ-2446 |
| The README Go example and its `Example` test drift apart, so the README prints bytes the test does not check | AZ-2451 AC-1 | AZ-2451 |

Swift package (loop 26, AZ-2223; decompose 1.8):

| Risk | AC | Owner |
|------|----|-------|
| Swift agrees with its own tests but not with a peer on a ring kind (bytes cross a language seam) | AZ-2522 AC-1, AC-2 | AZ-2522 |
| Swift follows spec text where TypeScript and the others agree otherwise (a parity row drifts) | AZ-2520 AC-1, AC-2 | AZ-2520 |
| A Swift golden mismatch still lets the other registries publish | AZ-2523 AC-1 | AZ-2523 |
| A re-run moves, creates or deletes a tag | AZ-2523 AC-3 | AZ-2523 |
| The hostile checker counts "Swift" inside another word and passes a section that omits Swift | AZ-2519 AC-3 | AZ-2519 |
| The README Swift example and its test drift apart, so the README prints bytes the test does not check | AZ-2524 AC-1 | AZ-2524 |
| A hostile packet traps the Swift process (overflow, index, force unwrap) instead of throwing | AZ-2519 AC-1, AZ-2517 AC-2 | AZ-2519 |
| A feature newer than Swift 5.9 compiles on `swift:6` and fails for a 5.9 consumer (superseded 2026-10-14: Swift 6 only, tools 6.0) | AZ-2521 AC-4 | AZ-2521 |
| The root `Package.swift` breaks resolution for consumers (an unsafe flag, a wrong path) | AZ-2523 AC-2 | AZ-2523 |

## Deferred

None.
| Two packages choose differently between equal-cost parses (a switch or LOCK at a tie) and write different bytes for one string | mismatched bytes: 0 on the vectors file and on the ring | CS-7, CS-19 | AZ-2646, AZ-2647 and each package |
| A flipped bit in a string payload shifts the codes and corrupts the next field | the field after the string is unchanged while the count header is intact; nothing is read past the payload | CS-8 | each package |
| C++ borrows text from the input (`View`) while the codec has to decode it | `utf8` binds to `Text<N>` only; `TooMany` instead of a cut | CS-18 | AZ-2655, AZ-2656 |
| The Cortex-M4F size probe links the codec through the string dispatch | `PACKBIN_NO_TEXT` removes it; flash and stack budgets hold | CS-12 | AZ-2656 |
| A protected message loses or gains one byte at the end (a trailing `00`) and still passes a plain systematic check | the code covers the clear length: 0 of 10,000 shifted messages accepted at n = 4, t = 0 | EC-14 | each package |
| A caller repairs `t` bytes and random bytes decode to a different row | the default is detect only (t = 0); the contract lists the chance for every n and t (n = 2, t = 1 accepts 1 in 17 random buffers) | EC-6, EC-15 | each package, contract |
| The type byte of a protected message is among the wrong bytes and the scheme is chosen by it | one dispatch accepts handlers of one parity count only; the message is repaired, then dispatched | EC-16 | C++, TypeScript, Rust and any dispatch form |
| Retired (loop 74, ADR 009): a protected stream session payload is repaired after the pad is removed | the stream session is removed; EC-10 has no subject | EC-10 (retired) | none |
| C++ repair needs a scratch copy of up to 254 bytes on a small target | repair in place in the caller's writable buffer | EC-17 | C++ |

### Rust no_std core (epic AZ-2750, loop 50)

| Risk | Mitigation (testable) | AC | Owner |
|------|----------------------|----|-------|
| The core walker and the std walker write different bytes for one row | the differential test packs and unpacks every fixture row with both | AZ-2749 AC-2, AZ-2757 AC-2 | AZ-2749, AZ-2757 |
| A heap call or a panic path is linked into decode and nothing notices | link checks on the decode objects, each proven to fail on a seeded mutant | AZ-2751 AC-4, AC-5 | AZ-2751 |
| Adding Cargo features changes the std build, the ring driver or the crates.io publish | the default-feature suite and ring stay green; `cargo publish --dry-run` with default and with no default features | AZ-2749 AC-7, AZ-2757 AC-3 | AZ-2749, AZ-2757 |
| A new CI job name is missing from the job guards | `publish-jobs.test.sh` and the wiring tests list the new job | AZ-2751 (included scope) | AZ-2751 |
| Shared pure code (ecc tables, sha256) is edited for the core and the std suite moves | the std ecc suites and the 27 crypto rows run unchanged (the std session suite was retired in loop 74, ADR 009) | AZ-2755 AC-4, AZ-2756 AC-1 | AZ-2755, AZ-2756 |

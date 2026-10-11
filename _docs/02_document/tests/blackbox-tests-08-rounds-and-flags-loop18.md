# Blackbox Tests 8: Rounds and flags members, loop 18 (FT-X-11 to FT-X-16)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md).

### FT-X-11: A lone dictionary in a round is refused

**Summary**: A single dictionary given for a `Dict` name in a `repeat` or `times` round is refused naming the member, instead of being broadcast to every round or read as one round; one dictionary per round still packs (loop 18, AZ-2308).
**Traces to**: AZ-2308 AC-1, AZ-2308 AC-2, AZ-2308 AC-3
**Category**: Errors

**Preconditions**:
- C#, TypeScript, Python, Java and Rust as built in loop 18 (wave 1); C++ has typed array rounds, so the case does not apply

**Input data**: the scheme `u8 n; times(count n){ dict d { utf8 e } }`, and `repeat{ dict d { utf8 e } }`; the rows `{n: 2, d: {a: "x"}}` (a lone dictionary) and `{n: 2, d: [{a: "x"}, {b: "y"}]}`

| Package | Before loop 18 | After |
|---------|----------------|-------|
| C# | broadcast to every round | `ArgumentException` naming the member |
| TypeScript | object: broadcast; `Map`: an empty dictionary per round; `repeat`: one round | error naming the member (a `Map`, `Set` or `Date` is no dictionary) |
| Python | `times`: broadcast; `repeat`: one round, or `ValueError` | `TypeError` naming the member (also with count 0) |
| Java | broadcast (`times`) or one round (`repeat`) | `IllegalArgumentException` naming the member |
| Rust (map API) | n = 1 packed; n = 2 `Missing` | `PackError::Type` naming the member |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the lone-dictionary row with the `times` scheme and with the `repeat` scheme | an error naming `d`; no bytes returned |
| 2 | pack the list of two dictionaries | hex `010201000100610100780100010062010079` (`times`); `0101000100610100780100010062010079` (`repeat` with the same two rounds) |
| 3 | pack a dictionary outside any round; pack a lone `string` for a `utf8` name in a round | `010100010061010078`; the string goes to every round, as before |

**Expected outcome**: step 1 is an error naming the member in all five packages; step 2 gives the hex above and the bytes of a list of dictionaries are unchanged; step 3 is unchanged. Not specified: a lone byte buffer for a `Bytes` or `Sized` name in a round is refused in C# and broadcast in TypeScript, Python, Java and Rust (open owner question, batch 1 discovery 1).
**Max execution time**: 1s

### FT-X-12: A lone scalar in a Rust `times` goes to every round

**Summary**: A Rust map scheme with a `times` and a single scalar for a name in the round puts the scalar in every round, as TypeScript, Python, Java and C# do (loop 18, AZ-2311).
**Traces to**: AZ-2311 AC-1, AZ-2311 AC-2, AZ-2311 AC-3
**Category**: Bytes

**Preconditions**:
- Rust as built in loop 18 (wave 1); the bytes were read from a TypeScript run

**Input data**: the scheme `u8 n; times(count n){ u8 x, u8 y }`; the rows `{n: 2, x: 1, y: [4, 5]}`, `{n: 3, x: 1, y: [4, 5, 6]}`, `{n: 2, x: 1, y: 4}` (two lone scalars), `{n: 1, x: 1, y: 4}` (one round), `{n: 2, x: [1, 2], y: [4, 5]}` (a list per name) and `{n: 2, x: [1], y: [4, 5]}` (a list shorter than the count)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the first three rows with the Rust map API | `010201040105`; `0103010401050106`; `010201040104` |
| 2 | unpack `010201040105`, then pack the unpacked row | the same bytes |
| 3 | pack the one-round row and the per-round lists; pack the row with the short list | `01010104` and `010201040205`, as before; a pack error naming `x` (`Missing`), no bytes |

**Expected outcome**: steps 1 and 2 give the hex above and equal the TypeScript, Python, Java and C# bytes for the same row; step 3 is unchanged. `repeat` has no lone-scalar form in the map API.
**Max execution time**: 1s

### FT-X-13: A `when`, `times` or `repeat` member of `flags` is written

**Summary**: A `when`, `times` or `repeat` that is a member of a `flags` container (or sits in a group or flag-bit field under it) is written like any other value, and its bit is on exactly when it writes a value; all six packages give the same bytes and rows (loop 18, AZ-2120, AZ-2128; owner decision 10, option A).
**Traces to**: AZ-2120 AC-1, AZ-2120 AC-2, AZ-2120 AC-3, AZ-2120 AC-4, AZ-2120 AC-5, AZ-2128 AC-1
**Category**: Bytes

**Preconditions**:
- The six packages as built in loop 18 (wave 3); the reference rows are `_docs/03_implementation/flags_member_reference_cases_loop18.md` (about 60 hex-pinned cases over the schemes WA to R2, taken from a C# run; each package matches the table byte for byte). Typed rows and dictionary or map rows both give the table's bytes where the package has both.

**Input data**: six representative rows of the table (the other rows are in the table file: split form WS and TS, group form WG and TG, two-value bodies W2, T2 and R2, and the same-`flags` condition WE):

| Case | Scheme | Row | Packs to | Unpacks to |
|------|--------|-----|----------|-----------|
| W-true (AZ-2120 AC-3) | WA: `u8 mode; flags{ when eq(0,1){ u8 speed }, u16 heading }` | `mode=1 speed=7 heading=90` | `010103075a00` | the same row |
| W-false | WA | `mode=0 heading=90` | `0100025a00` | the same row |
| W-same-flags-true | WE: `flags{ u8 mode, when eq(0,1){ u8 speed } }` | `mode=1 speed=7` | `01030107` | the same row |
| T-0-rounds / T-2-rounds (AZ-2120 AC-4) | TA: `u8 n; flags{ times(count n){ u8 pt }, u16 heading }` | `n=0 heading=90`; `n=2 pt=[5,6] heading=90` | `0100025a00`; `01020305065a00` | the same rows |
| R-0-rounds / R-2-rounds (AZ-2120 AC-4) | RA: `u8 mode; flags{ u16 heading, repeat{ u8 pt } }` | `mode=1 heading=90`; `mode=1 pt=[5,6] heading=90` | `0101015a00`; `0101035a000506` | the same rows |
| R-two-values-unpack | R2: `repeat{ u8 pt, u8 pu }` | unpack `0101035a0005060708` | - | `mode=1 pt=[5,7] pu=[6,8] heading=90` |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | in each package pack each row | the hex of the table; the bit of the member is on exactly when a value is written (a `when` whose condition holds and whose body has a value; a `times` or `repeat` with at least one round) |
| 2 | in each package unpack each hex of the table (AZ-2120 AC-5: the packet one package wrote is read by every other) | the row of the table; a clear bit reads nothing |
| 3 | unpack, then pack the unpacked row | the same bytes (the row repacks) |

**Expected outcome**: `Mode=1, Speed=7, Heading=90` packs `01 01 03 07 5a00` in C#, TypeScript, Python, Rust, Java and C++ (it was `01 01 02 5a00` with `Speed` dropped, in all six); every row of the table gives its hex in all six packages; C++ also counts a `u2`, nested `flags` or `flag_bit` head as a present group value (AZ-2128 AC-1).
**Max execution time**: 1s

### FT-X-14: A set `flags` member that cannot be written fails; old packets and other shapes are unchanged

**Summary**: Where a `when`, `times` or `repeat` member of `flags` has its bit set but cannot be written in full, pack fails naming the missing value and returns no bytes; packets written before loop 18 still unpack; golden and route fixtures do not change (loop 18, AZ-2120, AZ-2128).
**Traces to**: AZ-2120 AC-6, AZ-2128 AC-2, AZ-2128 AC-3
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 18 (wave 3); the schemes are in `flags_member_reference_cases_loop18.md`

**Input data**: W2 (`flags{ when eq(0,1){ u8 speed, u8 extra }, u16 heading }`) with `mode=1 speed=7 heading=90` (`extra` missing); TA with `n=2 pt=[5] heading=90` (list too short); TA with `n=0 pt=[5] heading=90` (count 0, list given); R2 with `mode=1 pt=[5] heading=90` (`pu` missing); the old packets `0101025a00` (WA), `0100025a00` (TA), `0101015a00` (RA); the golden `4001000065cd1d00a3e1110100`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack each of the four incomplete rows | a pack error naming `extra`, `pt`, `pt` (count 0 with a list given; the C# text is "holds 1 items, but the times count is 0") and `pu`; no bytes |
| 2 | unpack each old packet | no error; WA gives `mode=1 heading=90` (no `speed`), TA gives `n=0 heading=90`, RA gives `mode=1 heading=90` |
| 3 | pack the position golden and the route fixture | the bytes of FT-P-01 and FT-C-04, unchanged |

**Expected outcome**: step 1 is a pack error in all six packages (C++ also refuses a `times` count 0 with a non-empty list outside `flags`: batch 3 discovery 22, owner to confirm); step 2 unpacks without error; step 3 is byte-identical. A packet whose `times` count is above 0 but whose bit is clear (what the old packers wrote) unpacks to a row that no longer repacks (`missing pt`): an upgrade note, not a failure. Not specified: a split `flagByte` decides its `when` or `times` bit where the byte is read, so a condition written between the byte and the bit leaves the bit clear and the body is dropped (review finding C3, open owner question).
**Max execution time**: 1s

### FT-X-15: A flag byte inside a `flags` member or a flag-bit child is invisible to a later bit (C++)

**Summary**: A flag byte read inside a `flags` member or a flag-bit child is a conditional scope: a later flag bit outside it cannot bind to it, and binds to an outer byte when one exists (loop 18, AZ-2304; closes AZ-2135 for C++).
**Traces to**: AZ-2304 AC-1, AZ-2304 AC-2, AZ-2304 AC-3, AZ-2304 AC-4, AZ-2135 AC-2
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 18 (wave 1); `cpp/tests/core/flag_scope_host_tests.cpp` and two compile-fail cases

**Input data**: (a) `flags(0, group(u8 v, flag_byte(0), flag_bit(0, u8 x)))` then `flag_bit(0, u8 b)`; (b) `flag_byte(0)`, then `flag_bit(0, group(u8 v, flag_byte(1), flag_bit(1, u8 x)))` where the only byte 1 sits in the child, then `flag_bit(1, u8 b)`; (c) `flag_byte(0)`, then `flags(0, group(u8 v, flag_byte(0), flag_bit(0, u8 x)))`, then `flag_bit(0, u8 b)`; rows with `v = 3`, `x = 5`, `b = 7`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build (a) and (b) (`constexpr` and the host `validate`) | compile error, or `SchemeInvalid` naming `b` (field 2) with 0 bytes written |
| 2 | pack and unpack scheme (c) with `b` only, `v` and `b`, `v`, `x` and `b` | `01010007`, `010101030007`, `01010103010507` (also `010001030105`, `0100010300`, `010000` for the rows without `b`); each unpacks to the row and repacks to the same bytes; the variant with the outer byte 1 guarding a flag-bit child gives the same bytes for its rows |
| 3 | build the golden, the route and the motion examples and every scheme in `cpp/tests` | bytes and results unchanged; the embedded flash stays within its budget |

**Expected outcome**: step 1 refuses (a) and (b) as Rust, TypeScript and Java do (compile-fail cases `flag_byte_in_flags_member.cpp` and `flag_byte_in_flag_bit_child.cpp`); step 2 gives the hex above, equal to the Rust and TypeScript bytes; step 3 is unchanged (the flash of `unpack_scoped` is measured in the embedded stages of the total run, FT-E-05). Not specified: sibling `flags` members are separate scopes in C++, TypeScript and Java and one shared scope in Rust; and a group under `flags` whose only children are `flag_byte` and `flag_bit` is never present on pack in C++ (batch 1 discoveries 3 and 4, open owner questions). Loop 19 (AZ-2340, FT-X-35): a group of `flag_byte` and `flag_bit` with one lone value is present (`01010105`) and absent when the value is missing (`0100`).
**Max execution time**: 1s

### FT-X-16: Split-form bits are numbered by field order for each flag-byte read

**Summary**: TypeScript, C# and Java number split bits by field order per flag-byte read, as Rust and C++ do, and give the Rust bytes for the three probes; C++ packs the `k`/`a`/`b` rows below (AZ-2135 closed in loop 18 with AZ-2304).
**Traces to**: AZ-2135 AC-1, AZ-2135 AC-2, AZ-2135 AC-3
**Category**: Bytes

**Preconditions**:
- The packages as built in loops 16 and 17 (TypeScript, Java, C++ in loop 16; Python by AZ-2230; C# in loop 17)

**Input data**: three probes with one `flagByte` handle `m`: `[m, m.bit(u8 x)]` with `x = 5` in two schemes sharing the handle; `[m, early a, late b]` (`late` created first) with `b = 9`; `[m, m.bit(a), m, m.bit(b)]` with `b = 9`. C++: `u8 k, flag_byte(0), when(k == 1, [flag_byte(0), flag_bit(0, u8 a)]), flag_bit(0, u8 b)` with `{k: 0, b: 6}` and `{k: 1, a: 5, b: 6}`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the three probes in TypeScript, C# and Java (Rust is the reference) | `010105` (both schemes build), `010209`, `01000109` |
| 2 | pack the two C++ rows and unpack them | `01000106` and `010101010506`; both unpack; with no outer `flag_byte(0)` building fails with `SchemeInvalid` naming `b` |
| 3 | pack the golden, route and motion examples | unchanged |

**Expected outcome**: the bytes above in every package that has the probe; golden, route and motion unchanged.
**Max execution time**: 1s


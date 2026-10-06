# Feature assessment — loop 16

loop: 16
feature: hopper of epic AZ-2069 (41 open specs, 25 finished this loop)
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-06
**Implement pass**: batches 01..04 (`_docs/03_implementation/batch_0{1,2,3,4}_loop16_report.md`; no `implementation_report_*_loop16.md`, no completeness report), reviews `reviews/batch_0{1,2,3,4}_loop16_review.md`
**Verdict**: CLARIFY — 18 covered / 9 out-of-scope / 5 gap-clear / 10 gap-unclear

Intent baseline: `handoff16.md`, `plan16.md`, the ACs of each spec, `_docs/00_problem/acceptance_criteria.md`. `scenarios.md absent (hopper loop)`: none created or appended (the skill's step 5.2 is skipped on the caller's instruction). Suite numbers below come from the batch reports; a re-run belongs to step 11. Rows marked `new` come from the step 2 re-walk (Python `Scheme.with_limits`, Java `group(get, set, create, ...)`, TypeScript `bindFlagBits` and the npm `dist` layout, Rust `PackSession::pack`, the `ring` job, the vcpkg port); the cap of 12 was not reached (4 new rows, rest under Not walked).

### Coverage matrix

Specs and owner decisions

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | TypeScript specs AZ-2112, 2102, 2185, 2188, 2183, 2184, 2197 and the TS parts of AZ-2128, 2115, 2135 hold | covered | ACs of each spec; tests `typescript/tests/{u64-count,list-group-elements,times-longer-list,duplicate-names,flags-under-split-bit,dict-keys-not-flattened,when-on-written-values,flag-group-presence,split-form-reference,split-bits-field-order}.test.ts` (437 green, strict `tsc` clean); code `src/{walker,pack-fields,fields,rounds,member-names,flag-bits,flag-scope}.ts` | batch 1-3 |
| S2 | Rust specs AZ-2118, 2105, 2117 (+2121 AC-3), 2189 and the Rust parts of AZ-2128, 2114, 2121 hold | covered | ACs; tests `rust/src/{name_scope,flag_group,session_hostile,element}_tests.rs`, `rust/tests/*` (288 green); code `src/walk/{pack,times}.rs`, `src/session/mod.rs` (`Result<Vec<u8>, SessionPackError>`; driver `handoff-rust/src/main.rs` updated) | batch 1-2 |
| S3 | Java specs AZ-2127, 2187, 2190, 2101 and the Java parts of AZ-2128, 2114, 2121, 2135 hold | covered | ACs; tests `NestedRoundTest, TimesLongerTest, PackStrictTest, TypedNestedRowTest, SplitBitOrderTest, FlagPresenceTest, HostileSessionTest, FlagScopeContainerTest` (1324 checks, api-check PASS); code `Rounds.java, Scalars.java, SchemeOrder.java, Walker.java, Packbin.java:105-120, Field.java` | batch 1-3 |
| S4 | Python specs AZ-2113, 2104, 2186, 2192, 2100, 2134 and the Python part of AZ-2128 hold | covered | ACs; tests `test_reference_scope, test_star_import, test_times_longer_list, test_float_pack_strict, test_split_form, test_round_lists, test_flag_group_presence, test_round_limits` (286 green); code `_validate.py, _pack.py, _unpack.py, _scheme.py` | batch 1-2 |
| S5 | C++ AZ-2135 G1: a flag bit binds only to a flag byte read before it, not inside a closed `when` | covered | AZ-2135 AC-2, AC-3; test `cpp/tests/core/grouped_tests.cpp` (255 expects, embedded vectors 241); code `cpp/include/packbin/order.hpp:113` `find_flag_byte`, `cpp/src/core/unpack.cpp:54` `unpack_when` | batch 3 |
| S6 | AZ-2103: the npm package ships `dist/*.js` and `.d.ts`, no `src/` | covered | AC-1 to AC-6; test `publish-npm.test.sh` (3 tarball layouts, mutation-checked); code `typescript/package.json`, `tsconfig.build.json`, `publish-inside.sh`, `publish-check.py:102-104` | batch 3 |
| S7 | AZ-2099: an embedded target that fails fails the harness (errexit) | covered | AC-1 to AC-4, AC-6 (AC-5: ARM 4/4, ESP 4/5 here, the 10 by CI, see D7); test `cpp/embedded/lib.test.sh` (30 checks, red against the old harness); code `cpp/embedded/{lib,run,arm,esp,examples}.sh` | batch 3 |
| S8 | AZ-2193: the `ring` job runs `language-pair.sh` on every push and pull request | covered | AC-1 to AC-6, proof pending the first CI run (D7); test `ring-wiring.test.sh` (28 corrupted copies rejected); code `test.yml` job `ring`, `ring-cxx.sh`, `ring-toolchains.sh` | batch 3 |
| S9 | AZ-2098: the vcpkg port builds and a consumer prints the golden hex | covered | AC-1 to AC-5 (real vcpkg, arm64-osx; Ubuntu in D7); test `publish-vcpkg.test.sh`, `publish-gate.test.sh --vcpkg` (7+ mutants rejected); code `cpp/CMakeLists.txt:19-50`, `publish-embedded.sh` `stage_vcpkg_port`; review F1-F3, F6(a) fixed, F6(b) documented | batch 4 |
| S10 | Owner decisions of batches 1-3 are applied: Python round limits, Python nested rounds refused, TS `eq(id, undefined)`, Python test restore, Java inner `repeat` refused at pack, Java nested-row byte scope, `gcc:16` ring wrapper, TS-only hunks | covered | tests `test_round_limits.py` (37), `test_round_lists.py:278`, `when-on-written-values.test.ts`, `test_zero_width_elements.py:62`, `NestedRoundTest.java`, `SplitBitOrderTest.java`, `ring-wiring.test.sh`, `publish-npm.test.sh`; code `_unpack.py` `_Budget`, `_scheme.py` `with_limits`, `_validate.py`, `pack-fields.ts`, `Rounds.java`, `SchemeOrder.java`, `ring-cxx.sh`; README 929, 1095, 1105, 1107, 1111 | batch 2, 3 reviews |

Discoveries and findings already handled

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| D1 | TS dict entries and list items overwrote row members; name checks skipped element scopes | covered | AZ-2184 AC-1 to AC-7, AZ-2188 AC-6; tests `dict-keys-not-flattened.test.ts` (both key orders), `duplicate-names.test.ts`; code `fields.ts` `flattenValues`, `member-names.ts` | B1 #1 #2, B1 TS-F1 TS-F2 TS-F4 |
| D2 | Python refusals: numpy `float32` and Decimal, unequal `repeat` lists, over-long list under a never-matching `when`; the old Python `times`/`flag_byte` defects | covered | AZ-2192 AC-3 (`int` or `float` only), AZ-2134 AC-1, AZ-2100 AC-1 to AC-3; tests `test_float_pack_strict.py:51`, `test_round_lists.py:226`, `test_split_form.py`; code `_pack.py:104,138,294`; README 927, 1101. numpy has no test of its own | B1 #7 #8, B2 #4 #6, PY-F4 PY-F6 |
| D3 | Rust: a numeric reference to a slot with a non-numeric name is refused; flat-name limit of AZ-2189; `bound.rs` is 514 lines | covered | AZ-2117 AC-1 to AC-4, AZ-2189 AC-1 to AC-4 (limit stated in the spec result); tests `name_scope_tests.rs`, `rust/tests/times_*`; code `walk/times.rs` `check_aligned`; README 1103; `bound.rs` not touched by loop 16 (`git log`: last change AZ-2010 era) | B1 #10 #11 #12 |
| D4 | Java: nested-row ids no longer shadow outer ids; typed child inside a round; Map-valued member on a typed row now fails at construction | covered | AZ-2101 AC-1, AC-2, AC-4; test `TypedNestedRowTest`; code `SchemeOrder.java:17` (`NEEDS_FACTORY`), `Walker.java:300-335`; README 1079, 1105 | B1 #15a #16, B2 #8, B2 JA-F4 JA-F6 |
| D5 | Docs and upgrade notes of batches 1-3 are written (`.d.ts` need TypeScript 5.0 or `skipLibCheck`, deep imports blocked, `import *`, session pack `Result`, limits, hostile README line 134) | covered | README 146, 929, 1089-1111 and `fixtures/hostile/README.md:134` read; `04_rust_package/description.md` and `03_python_package/description.md` carry the new rows; batch 4 items are G4 | B1 #17 #18, B2 #12, B3 #9, review doc rows |
| D6 | Zero-width `bytes` repeat stands in for the README `01 00 ff` scheme (refused at construction in Rust, Java, Python); the embedded harness on Darwin 25.6 | covered | AZ-2114 progress table; tests `session_hostile_tests.rs`, `HostileSessionTest.java`, `lib.test.sh` (exits 2 where `date +%s%N` prints `N`) | B2 #10, B3 #12 |
| D7 | Linux-only proofs wait for the first CI run: `ring` end to end, errexit on bash 5, vcpkg on x64-linux with gcc 13, Pico/Arduino cold cache, the npm build in `node:24` with the read-only mount, cold times, the 15 minute ring target, the wall-clock AC-10 Rust test (failed once at load average 47) | covered | plan16 `### Proof` ("the first CI run after the push decides the Linux-only parts"); AC-10 test `packbin_tests.rs:155`; batch 3 and 4 "Only the Ubuntu runner proves" lists | B3 CI list, B4 #4 #6, B2 #9b, B1 JA-F6 |
| N1 | new: embedded budget headroom after AZ-2135 G1 (flash 7784 of 8192 B, stack 488 of 512 B on Cortex-M4F: 408 B and 24 B left) | covered | cpp-microcontroller AC-5 holds (`cpp-m4f` PASS); `unpack_when` adds a 32 B frame per nested `when`. The held C++ scope-parity spec (O5) must fit the same budget | assess-round-1, B3 CP-F4 |

Held or declared by the owner

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| O1 | C# specs (AZ-2092, 2093, 2119, 2120, 2180, 2181, 2182, 2191) and the C# parts of AZ-2114, 2115, 2121, 2128, 2135 wait for the uncommitted multi-target work; until then C# and the other five differ on handle-reuse split bits (AZ-2135 G4) and on `when` under `flags` (AZ-2120) | out-of-scope | handoff16 line 14; plan16 `## Foreign work`, Risks line "Wire-changing specs ... widen the C# gap". A tag before the C# parts land would publish the divergence | handoff, plan16 |
| O2 | `when` / `times` / `repeat` as a `flags` member or flag-bit field is dropped silently on pack (TypeScript, Rust, Java, Python) | out-of-scope | batch 2 review "Owner decisions" item 4 (hold for the loop that lands the C# work); AZ-2128 `## Loop 16 progress` last row | B1 #14, B2 #1, B1 JA-F2, B2 PY-F3 |
| O3 | Which kinds a `when` or a count may name (float `eq`, bool counts in Python/Java/C++, f32 `eq` rounding) | out-of-scope | plan16 Held list: AZ-2126; handoff16 owner answers (integer or bool only) | B1 #5, B2 #11 |
| O4 | Hostile `pack` stage, the construct vector `when_names_inner_field_after_times`, the AVR build | out-of-scope | plan16 Held list (AZ-2194, AZ-2068) and `### Divergences` bullet 2 | B1 #9 |
| O5 | C++ keeps a `flags` member and the child of a flag bit visible to later bits; Rust, TypeScript, Java do not | out-of-scope | batch 3 review "Owner decisions" item 4 (option B, follow-up spec). No spec is ticketed yet (see Harness gaps) | B3 #1, CP-F1 |
| O6 | Go (and Swift) packages with full parity | out-of-scope | handoff16 line 12 and epics AZ-2222, AZ-2223; memory note `go-package-next-loop` | owner |
| O7 | Two declarations inside the same `when` body still build and write the value twice in TypeScript | out-of-scope | AZ-2188 `## Owner decision` (option B) and `## Loop 16 result` last sentence | B2 #2a |
| O8 | `ring` also gates a `v*` tag publish (`publish.yml` calls `test.yml`); a flaky pull of `gcc:16` blocks it until "Re-run failed jobs" | out-of-scope | batch 3 review HW-F1 "Accepted (consequence stated to the owner when option A was chosen)"; AZ-2193 owner decision A | B3 #5, HW-F1 |
| O9 | Error kind and label differences (longer-list wording across four packages, Rust label of counts at 2^63, bare `IndexError` for a short `times` list, `10**400` into f64, name of `SessionPackError`) | out-of-scope | AZ-2118 `### Excluded` "Error kind and label of any error value (C15)"; AZ-2186 Excluded line on the raw `IndexError`; AZ-2105 flagged row (C15) | B1 #4 #11a, B2 #4b, B1 RU-F2 |

### Gaps that need a decision (gap-unclear)

Ask in this order; every Low row can be answered "take the recommendation".

#### Q1: Python numbers split flag bits in call order, the other five by scheme order (Medium)

**What is not decided**
You can write a flag byte in "split form": the flag byte first, each bit's field later. TypeScript, Java, Rust and C++ now give a bit the number of its place in the scheme (AZ-2135). Python gives it the number of the order in which you called `.bit(...)`, and builds no scheme in which one handle serves two schemes. If the calls are not in scheme order, Python writes bytes that the other packages read as different fields. AZ-2135 does not list Python; README says "call them in scheme order".

**Options**
- **A — Add Python to AZ-2135**: same bytes as the others; one handle can serve several schemes. Trade-off: bytes change for callers who call out of order, and those bytes were unreadable elsewhere.
- **B — Keep call order and document it**: no change. Trade-off: one more rule that only Python has.

**Recommendation**: A — the cross-language rule is "same scheme, same bytes", and the `bitwhen` ring already includes Python.

#### Q2: `PackSession.load(32)` in Python returns a working session with an all-zero key (Medium, security)

**What is not decided**
`load` is meant to return `None` for a seed that is not 32 bytes. Passing the integer `32` instead of bytes makes Python build 32 zero bytes, so a mistake yields a session whose key anyone can derive (verified: `load(32)` is a session, `load(33)` is `None`). AZ-2104 says `load` is unchanged, so no spec covers it.

**Options**
- **A — `load` returns `None` for anything that is not bytes-like**: fits the existing "bad seed gives `None`" rule.
- **B — `load` raises `TypeError`**: louder. Trade-off: differs from the other bad-seed path.
- **C — leave it**.

**Recommendation**: A.

#### Q3: Which platforms does the vcpkg port promise? (Medium, new)

**What is not decided**
README says "CMake 3.16+ or vcpkg on desktop and server". The port has no platform limit, and the C++ core was compiled only with gcc (Linux) and on a Mac. On Windows the library falls to the `/dev/urandom` branch of `os_random`, so even if it compiled, `PackSession::start` with `os_random` would fail. A Windows user finds out at their first `vcpkg install packbin`.

**Options**
- **A — Declare the port Linux and macOS only** (`"supports": "linux | osx"` in the staged `vcpkg.json`): Windows users get a clear message. Trade-off: Windows is not offered.
- **B — Prove Windows**: a `windows-latest` MSVC job plus a real random source. Trade-off: a new job and new code.
- **C — Leave it**.

**Recommendation**: A now (one line, checked by the gate test), B only when Windows is wanted.

#### Q4: Java pack accepts shapes that its own unpack reads back differently or drops (Medium)

**What is not decided**
The owner refused only a second write of the same inner `repeat`. Still accepted by Java pack: (a) an inner `repeat` reached by one round with later rounds or fields after it; (b) a flag byte outside a nested row whose bit sits inside it (unreadable bytes); (c) a null nested member or null list element, dropped silently; (d) a `u2` inside a round ignoring the round item; (e) a nested row absent on pack whose fields unpack reads. All are old at HEAD; (a) is documented at README 929 and matches how a top-level `repeat` behaves.

**Options**
- **A — One Java spec makes each of these fail loudly** (construction for b, pack for the rest). Trade-off: a scheme that "worked" but wrote wrong bytes now throws; nothing that reads back correctly changes.
- **B — Leave them, documented**.

**Recommendation**: A for b to e; keep (a) documented, as for a top-level `repeat`.

#### Q5: Java typed rows: list and dict element groups are not checked at construction (Medium, new)

**What is not decided**
AZ-2101 AC-2 says a typed row "never fails later with `ClassCastException`", but the Javadoc of `group(get, set, create, ...)` says construction checks only nested-row members; list and dict element groups built without a factory still unpack into a `HashMap`, so a typed accessor fails when a valid packet is unpacked.

**Options**
- **A — Refuse such an element group at construction** (same rule as AC-2). Trade-off: breaks a typed scheme whose element accessors happen to take a `Map`.
- **B — Leave it, documented**.

**Recommendation**: A — the failure moves from the user's runtime to the build of the scheme.

#### Q6: Other non-value members inside `flags` (Low to Medium)

**What is not decided**
You held `when`, `times` and `repeat` as a `flags` member for the C# loop (O2). The same silent drop exists for a flag byte as a direct `flags` member (Rust), a flag bit used directly as a `flags` member (C++), and a split bit inside a combined `flags` under a split bit (TypeScript). Nobody has said whether these join that decision.

**Options**
- **A — Decide them together with O2** (one rule for every member that holds no value of its own).
- **B — Separate specs per package now**.

**Recommendation**: A — one rule, five packages, one loop.

#### Q7: TypeScript: an anchored group, `when` or `times` as a direct list or dict element (Low)

**What is not decided**
Python accepts them; TypeScript builds the scheme and then throws `missing a` at pack (rows are flat, so the element has nowhere to hold its own group). AZ-2102 left them out and kept the question open.

**Options**
- **A — Refuse at construction in TypeScript** with a message that says to use an unanchored group. 
- **B — Make TypeScript handle them like Python**.
- **C — Leave it** (it is loud at pack).

**Recommendation**: A.

#### Q8: README TypeScript examples do not type-check under `strict` (Low)

**What is not decided**
`u16(0, (x) => x.sid)` makes `x` of type `unknown`, an error in a strict project. README now says to annotate (`(x: Target) => x.sid`) and that the examples leave it out.

**Options**
- **A — Annotate the README examples**: no API change.
- **B — Give the accessor helpers a default row type** so the short form compiles (the row is then loosely typed).
- **C — Leave the note**.

**Recommendation**: A.

#### Q9: Lows of the `ring` job (Low)

**What is not decided**
The `gcc:16` container needs no network and no writable repo (`--network none`, read-only mount, `--cap-drop ALL`); a failing ring consumer is not named in the log (AZ-2193 says `language-pair.sh` does not change); one `find | head` is fragile under `pipefail`. None changes a result.

**Options**
- **A — Do all three after the first green ring run** (the flags can only be proven on the runner).
- **B — Leave them**.

**Recommendation**: A.

#### Q10: vcpkg `find_package` version rule for 0.x (Low)

**What is not decided**
The package version file uses "same major version", so an installed 0.9 satisfies a request for 0.2 (review F4). This project's upgrade notes break things between 0.x minors. vcpkg pins exact versions, so it matters only for manual `cmake --install`.

**Options**
- **A — Keep "same major"**.
- **B — "Same minor"** while the major is 0 (one word in `cpp/CMakeLists.txt`).

**Recommendation**: B.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| G1 | Given the Rust map scheme `u8 p; when(p==0, [u8 n]); when(n==0, [u8 v])` and values `p=1, n=0, v=4`, When packed, Then the bytes are `01 01` and they unpack (probed today: `01 01 04`, unpack `Trailing { left: 1 }`). Given `u8 c; times(c, [u8 x])` and `c=2, x=[1,2,3]`, When packed, Then `PackError::Type` names `x`, 3 items and count 2 (probed today: `01 02 01 02`, the third item dropped). Check the typed `Scheme<T>` first; AZ-2197's "Rust not affected" is wrong for the map form | "Pack decides every `when` from the fields it wrote in the same scope; a tested field that was skipped or absent does not match" (AZ-2197 Outcome); "a longer list is refused, naming the member, the items and the count" (AZ-2185 AC-1) | new Rust task, twin of AZ-2197 + AZ-2185 (3 points) |
| G2 | Given a macOS checkout without `typescript/node_modules`, When `publish-position.sh typescript` runs, Then it installs on the copy (`(cd "$work/typescript" && npm ci)`) and prints the golden hex; today `npm ci --prefix <mktemp dir>` fails through the `/var` symlink | script comment: "npm ci writes node_modules next to package.json, so without one it runs on a copy that keeps the layout position.ts imports" (`publish-position.sh:40`) | new harness task, 1 point |
| G3 | Given a tag-time staged vcpkg port that lacks `CMakeLists.txt`, `LICENSE` or the `vcpkg-cmake` and `vcpkg-cmake-config` host dependencies, When `publish-check.py` runs, Then it fails and nothing is pushed (`check_vcpkg` asserts only name, version, license, portfile, one header, one source; the npm check asserts only `dist/index.js` and `index.d.ts`, so a `dist` that lacks a module that `index.js` imports passes) | AZ-2098 AC-4 "`vcpkg.json` has ... the `vcpkg-cmake`/`vcpkg-cmake-config` host dependencies. `share/packbin/copyright` holds the repository `LICENSE` text"; project AC-14 "A tag that fails the golden-byte check publishes 0 packages" | AZ-2098 follow-up; edits the owner's `publish-check.py`, so after the owner commits the C# hunks or with a hunk-only approval as for AZ-2103 |
| G4 | Given the README after step 13, When a C++ user reads the install row, Then it shows `find_package(packbin CONFIG REQUIRED)` and `target_link_libraries(app PRIVATE packbin::packbin)`, a `vcpkg-configuration.json` with a `default-registry` baseline next to the git registry, and the sentence that port versions before AZ-2098 do not link (move to a later version); the Python upgrade note names numpy `float32` and numpy ints for float fields; `security_report.md` lines 49 and 95 stop saying Python has no limit | AZ-2098 Outcome last bullet; review F5 "Closed by the docs patch" — README:409 still has the old row at assessment time | step 13 and step 14 of this loop, no new task |
| G5 | Given shared fixture rows for `list(group)`, `dict(group)` and `list(flags)`, When each of the six packages packs and unpacks them, Then the bytes are identical (TypeScript list-of-group is new in this loop and pinned only by hex copied from Python) | "No cross-language fixture covers list/dict of group or flags; this task's Python-produced hex should go into the shared vectors" (AZ-2102 flagged concerns); project AC-3 | new task after the C# work (the C# loader reads the vector) |

### Not walked

- Python 3.10 to 3.13: `requires-python >=3.10`, CI runs 3.14 only; loop-16 sources parse under `ast.parse(feature_version=(3,10))`, stdlib calls are not exercised.
- No `prepack` hook: a manual `npm pack` from a checkout without a build ships no code. The canonical path builds first and `publish-check.py` requires `dist/index.js`.
- `SessionPackError` is an exhaustive public enum: a later variant is source-breaking (naming belongs to C15, O9).
- Java `create` returning null or one shared object (a caller bug; the null case is a named `NullPointerException`).
- Python `with_limits` with a `max_slots` under the first round's cost (nine per name) refuses every packet; documented README 1111.
- Maintainability findings outside step 1 item 3: B2 TS-F6 (near-duplicate name walker), B3 JA-F2 and JA-F5 (accepted, no behavior change).

### Harness gaps

- Every batch report of this loop has the discoveries table (48 rows: 18, 12, 12, 6). No `implementation_report_*_loop16.md` and no `implementation_completeness_loop16_report.md` (loops 14 and 15 had none either).
- AZ-2098 is done (batch 4) but its spec is still in `todo/` at assessment time, and the batch 4 report's verdict line points to a review that now exists.
- 10 finished specs have no `## Loop 16 result` section (AZ-2112, 2102, 2185, 2118, 2117, 2187, 2190, 2104, 2186, 2192); their results live in the batch reports and README only.
- The follow-up spec for the C++ scope-parity decision (O5) and for the Python numbering answer (Q1) are not ticketed.
- AZ-2197 `### Excluded` ("Java and Rust are not affected by this shape") is wrong for the Rust map form (G1).

### Source map: every discovery and finding has one row

| source | rows |
|--------|------|
| Batch 1 #1-#18 | #1 D1, #2 D1, #3 Q7, #4 O9, #5 O3, #6 Q2, #7 D2, #8 D2, #9 O4, #10 D3, #11 O9+D3, #12 D3, #13 Q4, #14 O2, #15 D4+Q4, #16 D4, #17 D5, #18 D5 |
| Batch 2 #1-#12 | #1 O2, #2 O7+Q7, #3 Q1, #4 D2+O9, #5 Q2, #6 D2, #7 Q4+Q5, #8 D4, #9 Q6+D7, #10 D6, #11 O3, #12 D5 |
| Batch 3 #1-#12 | #1 O5, #2 Q1, #3 Q6, #4 Q4, #5 O8, #6 Q9, #7 Q9, #8 Q8, #9 D5, #10 G2, #11 G1, #12 D6 |
| Batch 4 #1-#6 | #1 G3, #2 G4, #3 Q10, #4 D7, #5 G4, #6 D7 |
| Review 1 | PY-F1 S4/S10, JA-F1 Q4, TS-F1 D1, RU-F2 O9, JA-F2 O2, JA-F6 D7, PY-F3 Q2, PY-F4 D2, docs D5 |
| Review 2 | PY-F3 O2, PY-F4 Q1, PY-F6 D2, TS-F3 S1, JA-F2 JA-F3 Q4, JA-F4 JA-F6 D4, docs D5 and G4, TS-F6 Not walked |
| Review 3 | CP-F1 O5, HW-F1 O8, TS-F2 CP-F2 Q6, HW-F4 HW-F7 HW-F8 Q9, CP-F4 N1, TS-F4 D5, docs D5, JA-F2 JA-F5 Not walked |
| Review 4 | F1 F2 F3 F6a S9, F4 Q10, F5 G4, F6b S9 (documented) |
| Open flagged rows of finished specs | AZ-2100 S4 and Q1, AZ-2101 S3, AZ-2102 Q7 and G5, AZ-2103 D5, AZ-2105 O9, AZ-2117 O4, AZ-2127 Q4, DECISION rows of AZ-2188, 2189, 2190, 2192, 2193 resolved by their `## Owner decision` sections |

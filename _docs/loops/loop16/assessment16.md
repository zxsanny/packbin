# Feature assessment — loop 16

loop: 16
feature: hopper of epic AZ-2069 (41 open specs, 25 finished this loop)
rounds: 2
verdict: CLARIFY
report_of_round: 2

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

## Round 2

**Date**: 2026-10-06
**Implement pass**: batch 5 = AZ-2230 to AZ-2240 (`_docs/03_implementation/batch_05_loop16_report.md`, review `reviews/batch_05_loop16_review.md`; still no `implementation_report_*_loop16.md` and no completeness report)
**Verdict**: CLARIFY — 11 covered / 11 out-of-scope / 2 gap-clear / 3 gap-unclear

`scenarios.md absent (hopper loop)`: there is none under `_docs/loops/loop16/` and no loop 16 plan slug, so nothing was appended; the five `_docs/02_task_plans/*/scenarios.md` files belong to earlier features and were not touched. Intent baseline: `handoff16.md`, `plan16.md` (`### Round 2`, `## Assessment rounds`), the round 1 answers (take all recommendations, implement everything now), the specs AZ-2230 to AZ-2240 in `done/`, the project ACs. Suite numbers are the batch 5 numbers (TypeScript 463, Python 326, Rust 331, Java 1501 checks); as a spot check I re-ran TypeScript (463 pass) and Rust (253 + 78 pass) on the scratch export and compiled the Java main sources with `--release 17`, the publish target (clean).

**How the new rows were found.** All probes ran on a `git archive` export of `35544ed` under the session scratchpad (`.../scratchpad/assess2/`; no repo file was touched; node 22.23, Python 3.14.6, cargo 1.79, JDK 21, cmake 4.1.1). For every round 2 rule I asked which other package has the same shape and was not changed, and ran it there. Besides hand probes there is a three-way differential: a seeded generator of schemes (`u8`/`u16`, `when`, `flags` with `bool`, `u8`, `u2`, nested `flags` and anchored `group`, `times`, `repeat`, split flag bytes whose bits are created in shuffled order, `list` and `dict` of group, of flags and of scalars, flag bytes and bits inside elements) with random packets and random rows, built and run by a Python, a TypeScript and a Java runner (a Rust runner for the subset Rust shares), compared on: scheme accepted or refused, unpack ok or error, the unpacked row, the bytes of repack and of pack. About 49,000 schemes for Python and TypeScript, 38,000 of them also for Java, 1,622 for Rust.
Result: no byte difference in any pair. Python, TypeScript and Java agree on every accepted scheme, on the refused set (59 of 4,000 and 196 of 3,000 schemes refused by all three, "its flag byte is not read earlier in the same scope"), on every unpack result and on every packed byte; Rust agrees with TypeScript on build, unpack accept or refuse, and repack bytes for 3,634 packets. The differences left are the rows below (what a package accepts, not what it writes) and two artefacts of my harness (two `times` sharing one count field; TypeScript's `$` name for an identity group).

### Coverage matrix

Specs of round 2

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S11 | AZ-2230: Python numbers split flag bits by place in the scheme; one `flag_byte()` handle serves any number of schemes and reads; an unplaced bit leaves its bit clear | covered | AC-1 to AC-10; tests `python/tests/test_split_bits_field_order.py` (16), `test_split_form.py::test_ac3_*`, `test_bool_placement.py`; code `python/src/packbin/_flag_scope.py:31` `_bind_flag_bits`. Cross-package probe: Python, TypeScript and Java build, refuse and pack identically over 22,000 random schemes with bits created in shuffled order (`[m, early a, late b]` with only `b` set packs `010209` in Python, as in the spec) | batch 5 AZ-2230, assess-round-2 |
| S12 | AZ-2231: Python `PackSession.load` returns `None` for anything that is not `bytes`, `bytearray` or `memoryview` of 32 bytes | covered | AC-1 to AC-5; tests `python/tests/test_session.py::test_ac1_load_of_an_integer_returns_none`, `test_ac3_anything_not_bytes_like_returns_none_and_raises_nothing`, `test_ac3_a_released_memoryview_returns_none_and_raises_nothing`; code `python/src/packbin/_session.py:31-39`. The same hole in TypeScript and in Python `start` and `join` is X1 and X2 | batch 5 AZ-2231 |
| S13 | AZ-2232: the vcpkg port declares `linux \| osx` and a 0.x install answers only its own minor | covered | AC-1 to AC-6; tests `publish-vcpkg.test.sh` (`vcpkg_supports_check`, `vcpkg_version_rule_check`, the second consumer), `publish-gate.test.sh --vcpkg`; code `cpp/CMakeLists.txt:46-52` (`PACKBIN_VERSION_RULE`), `.github/workflows/publish-embedded.sh:70`. Probe, cmake 4.1.1: `cpp/` installed with `-DPACKBIN_VERSION=0.9.0` refuses `find_package(packbin 0.2 CONFIG REQUIRED)` ("compatible with requested version "0.2" ... version: 0.9.0"); installed without the variable the config file has "version: unknown" and no versioned request can match (the README documents only the vcpkg and `add_subdirectory` paths) | batch 5 AZ-2232 |
| S14 | AZ-2233: a Java flag bit whose only flag byte lies outside its nested row is refused when the scheme is built | covered | AC-1 to AC-6; tests `SplitBitOrderTest.az2233Ac1` to `az2233Ac5`; code `java/src/main/java/packbin/SchemeOrder.java` (`bind`: a nested row gets its own `HashMap`). TypeScript has no nested-row scope for flag bytes and round-trips the same shape (probe `[m, group(get, [m.bit(u8 v)])]`, `{g:{v:5}}` packs `010105` and unpacks), see O17 | batch 5 AZ-2233 |
| S15 | AZ-2234: Java pack throws `missing group`, `missing list element I`, `missing dict element "k"` for null or absent nested rows and elements; `u2` in a round packs the round item | covered | AC-1 to AC-9; tests `MissingNestedValueTest`, `FlagPresenceTest.az2234Ac6NullNestedRowClearsTheBit`, `RepeatRoundTest.az2234Ac7U2PacksTheRoundItem`; code `Walker.java:181`, `Containers.java:29,92`, `VarFields.packU2`. Other packages, probes: TypeScript is loud for the same rows (`RangeError: missing v` for `{}`, `{g:null}`, `{g:[null,null]}`, `{g:[{v:1},null]}`; `RangeError: l: expected an object for each item` for a null list or dict item), Python is loud (`TypeError: 'NoneType' object is not subscriptable`, `KeyError: 'missing field 0'`); `repeat(u2 a, b)` with `{a:[1,2], b:[3,0]}` packs `010d02` in TypeScript, Python and Java | batch 5 AZ-2234 |
| S16 | AZ-2235: a Java list or dict element group without a factory on a typed row is refused when the scheme is built | covered | AC-1 to AC-6; tests `TypedNestedRowTest.az2235Ac1` to `Ac5`, `TypedElementScopeTest`; code `SchemeOrder.java:182` `requireElementFactory`. The same shape in Python is unchecked: X5 | batch 5 AZ-2235 |
| S17 | AZ-2236: TypeScript refuses an anchored group as a direct list or dict element at any depth | covered | AC-1 to AC-7; test `typescript/tests/list-element-kinds.test.ts` (26); code `typescript/src/element-kinds.ts`, called last in the `Scheme` constructor. Probe on a `tsc` build of `dist`: `RangeError: list g: element is an anchored group (p); use a group without an anchor` | batch 5 AZ-2236 |
| S18 | AZ-2237: Rust map and typed pack decide every `when` and count from what they wrote, publish round names as lists after a `times`, and refuse a longer `times` list | covered | AC-1 to AC-8; tests `rust/src/when_written_tests.rs`, `when_kept_tests.rs`, `when_names_tests.rs`, `times_longer_tests.rs`; code `rust/src/walk/pack.rs:14` `Written`, `:124` `RoundLists`, `rust/src/walk/times.rs:95` `check_longer`, `walk/flag_bits.rs`. Probes of the spec's shapes in the other packages: chain A packs `0101` in Python and Java; a count that names a skipped field fails (`RuntimeError: 2: count 1 is missing` in Python, `IllegalStateException: 2: count 1 is missing` in Java); a `repeat` round chain packs `0100` in both, `eq(bool, false)` on a clear bit `0100` in Java. A round name published into the parent cannot clash in Python, TypeScript or Java: ids are unique and a `when` may not name a round field after the round (refused when built: `when 2: eq names field id 1 is allowed only if declared earlier in the same scope` in Python, `when 2: eq names field id 1, which is not declared earlier in the same scope` in TypeScript, `when 2 tests field 1, which is not an earlier integer or bool field in its scope` in Java); the clash of equal names is X3 | batch 5 AZ-2237 |
| S19 | AZ-2238: position gate installs through a symlinked temp path, the examples scan cannot fail on SIGPIPE, a failing ring consumer is named | covered | AC-1 to AC-5; tests `publish-position.test.sh`, `ring-wiring.test.sh` (`consumer_failure_checks`), `cpp/embedded/lib.test.sh` (`find_head_hits`); code `publish-position.sh:40-48`, `language-pair.sh` `handoff()`, `cpp/embedded/examples.sh`. Linux-only proofs wait for the first CI run (as D7) | batch 5 AZ-2238 |
| S20 | AZ-2239: rings `listgroup`, `dictgroup`, `listflags` among TypeScript, Python and Java with pinned bytes; every participant refuses the cut-short packets | covered | AC-1 to AC-6; test `ring-wiring.test.sh` and the ring run (65 s); code `language-pair.sh:153-181`, `drivers/HandoffElements.java`, `handoff.ts`, `handoff.py`. Beyond the pinned packets: 6,000 random schemes with list and dict of group, of flags and of scalars, with flag bytes and bits inside the elements, 14 packets and 10 rows each, give identical builds, refusals, unpack results and bytes in the three packages | batch 5 AZ-2239 |
| S21 | AZ-2240: the tag-time guard asserts the npm `exports`, `types`, every `dist` file the entry points import and no `src/`, and the vcpkg port `CMakeLists.txt`, `LICENSE` and host dependencies | covered | AC-1 to AC-6; tests `publish-npm.test.sh` (`npm_guard_checks`), `publish-vcpkg.test.sh` (`vcpkg_guard_checks`); code `.github/workflows/publish-check.py:92-123` (npm), `:194-211` (vcpkg). A `tsc` build of `typescript/` gives `dist/element-kinds.js` and `.d.ts`, so the closure holds for the file this loop added | batch 5 AZ-2240 |

Held or declared (not re-walked)

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| O10 | The C# specs, AZ-2126, AZ-2194, AZ-2068 and the C# parts of AZ-2114, 2115, 2121, 2128, 2135 | out-of-scope | plan16 `## Scope`: "Held (stay in `todo/`): AZ-2092, AZ-2093, AZ-2119, AZ-2120, AZ-2180, AZ-2181, AZ-2182, AZ-2191 (C#); AZ-2126 ...; AZ-2194 ...; the C# parts of AZ-2114, AZ-2115, AZ-2121, AZ-2128, AZ-2135; AZ-2068" | plan16 |
| O11 | `when`, `times` or `repeat` as a `flags` member or flag-bit field is dropped on pack | out-of-scope | batch 5 report discovery row 10: "The held decisions are unchanged: `when`/`times`/`repeat` as a `flags` member (all packages)" | batch 5 #10 |
| O12 | C++ keeps a flags member and a flag-bit child visible to later bits | out-of-scope | batch 5 report discovery row 10: "C++ flags/flag-bit scope parity" | batch 5 #10 |
| O13 | Go and Swift packages | out-of-scope | plan16 line 7: "the Go package follows loop 16"; handoff16 epics AZ-2222, AZ-2223 | plan16 |
| O14 | Container hardening of the `gcc:16` ring wrapper (`--network none`, read-only mount, `--cap-drop ALL`) | out-of-scope | plan16 `## Assessment rounds` row 1: "Q9 container hardening of the `gcc:16` wrapper waits for the first green `ring` run" | plan16 |
| O15 | The open Low items of the batch 5 discovery table: unplaced bit leaves its bit clear (#1), Java S4, S5, S8 typed accessors in anchored, flags and `Map` elements (#2), Java "typed row" wording (#3), `missing group` without a path (#4), TypeScript `u2`, `flagByte`, `when`, `times` direct elements (#5), Rust flat-scheme cost 1.3x to 1.57x (#6), Rust multi-name `u2` in a map `times` (#7), no `supports` assert and the import regex at tag time (#8), Ubuntu-only proofs (#9) | out-of-scope | the owner's instruction for this round (rows 1 to 10 of the batch 5 table are recorded, do not re-raise); the shape of none of them changed in round 2 (see Not walked for the cross-package facts found about #5 and #8) | batch 5 #1-#10 |
| O16 | Rust refuses list and dict elements that are a group, `flags`, flag byte, `sized`, `bits`, `packed`, `when`, `times` or a multi-name `u2`, which TypeScript, Python and Java accept | out-of-scope | AZ-2239 `### Excluded`: "Making Rust or C++ accept these shapes"; README 1093 and 1108 state the Rust refusal; probe: `list` of any of them panics `an element is one integer, float, bytes, utf8, list or dict, or a u2 with one name` | AZ-2239 |
| O17 | A Java nested row is a scope of its own for flag bytes, a TypeScript nested row is not; a scheme valid in TypeScript can be refused by Java | out-of-scope | AZ-2233 `### Excluded`: "Other packages: TypeScript, Rust, C++ and Python decide their own scope rules (ADR-001)"; batch 5 AZ-2233 result: "this is Java-specific" | AZ-2233 |
| O18 | TypeScript refuses an anchored group element, Python accepts it | out-of-scope | AZ-2236 `### Excluded`: "Making the anchored group work as an element (Q7 option B), and Python's behaviour (it accepts them)"; README 1091 | AZ-2236 |
| O19 | `PackSession([7] * 32)` builds a Python session through the constructor | out-of-scope | AZ-2231 `### Excluded`: "The constructor `PackSession(seed)` ... It still builds a session from a list of 32 integers ... it is reported, not changed here" | AZ-2231 |
| O20 | Windows for the port and the other C++ registries (PlatformIO `"platforms": "*"`, Arduino `architectures=*`, ESP-IDF) | out-of-scope | AZ-2232 `### Excluded`: "Proving Windows ... Q3 option B, only when Windows is wanted" and "The PlatformIO, Arduino and ESP-IDF packages (embedded targets; they do not go through vcpkg)"; AZ-2068 (AVR) is held | AZ-2232 |

Round 1 rows closed by round 2: G1 by S18, G2 by S19, G3 by S21, G5 by S20, Q1 by S11, Q2 by S12 (Python only), Q3 and Q10 by S13, Q4 (b to e) by S14 and S15 (a stays documented), Q5 by S16, Q7 by S17; G4 and Q8 by the docs pass (README 402 to 423 read: the `find_package` row, the `vcpkg-configuration.json` with `default-registry`, "do not link: use the next port version"); Q6 joined O11; Q9 is O14.

### Gaps that need a decision (gap-unclear)

Ask in this order. Every probe below was run on the scratch export.

#### X3: Python, Java and Rust accept a member name used twice and lose a value (Medium)

**What is not decided**
In TypeScript a name used twice in one scope, or once outside and once inside a `repeat` or `times`, is refused when the scheme is built (AZ-2188, your option B: "a row holds one value per name, so one would be lost"). Python, Java and Rust build the same schemes. Same scope, `u8 x` then `u8 x`: all three pack `{x:5}` as `010505`; unpack of `010708` gives `{x: 8}` (the 7 is gone) and packing that row again writes `010808`. Outside and inside a round (`u8 x; u8 c; times(c, [u8 x])`): unpack of `0105020708` gives `{x:[7,8], c:2}` in Python (the outer 5 is gone), `{c=2, x=[5, 7, 8]}` in Java (the outer value became the first entry) and `x=List([7,8])` in Rust, and the row cannot be packed again (`0: expected int, got list` in Python, `IllegalArgumentException: 0: expected int, got ArrayList` in Java, `Type("int")` in Rust). AZ-2188 was a TypeScript task, so no spec says what the other three do.

**Options**
- **A: refuse it when the scheme is built in Python and Java, as TypeScript does** (same exemption for names that sit under different `when`s); Rust refuses a repeated data name too but not a flag-byte handle read in two scopes, which is legal there. Trade-off: a scheme that built and packed before now fails to build; none of them could read its own bytes back.
- **B: leave it**, and state in the README that only TypeScript checks. Trade-off: the same scheme is an error in one package and a silent loss in three.
- **C: refuse only the round case** (a name outside and inside a `repeat` or `times`), where the row cannot be packed again. Trade-off: the same-scope case stays silent.

**Recommendation**: A, for Python and Java, and for Rust data names; the cross-language rule is "same scheme, same result".

#### X4: a `times` list shorter than the count, for a member that may be absent (Low to Medium)

**What is not decided**
README says a `times` list has "entry `i` for round `i`, `null` for a round that skipped the name" and refuses a longer list in every package. It says nothing about a list that is shorter than the count when the member sits under `flags`. `u8 c; times(c, [flags([bool on])])` with `{c:2, on:[true]}`: TypeScript packs `01020100` (the second round is a clear bit), Python raises `IndexError: list index out of range`, and an empty list `[]` packs `01020000` in TypeScript but raises in Python (while a row with no `on` at all packs in both). `flags([u8 v])` with `{c:2, v:[5]}`: TypeScript and Java pack `0102010500`, Python raises `IndexError`, Rust refuses (`times at id 1: '1' is under a flags or when; give its values per round under '__times_1'`; Rust lists hold only the rounds that had a value, so it cannot align them). A plain member refuses in all four (`missing x`, `1: expected int, got null`, `IndexError`, `Missing("1")`), and a member under `when` refuses in TypeScript and Java. Error label differences are decided (C15); this is accept or refuse.

**Options**
- **A: accept a short or empty list for an optional member in Python too** (a missing trailing entry means absent, as TypeScript and Java do); Rust stays as it is by design. Trade-off: a forgotten entry becomes a clear bit with no message.
- **B: refuse it in TypeScript and Java**; the way to say absent stays `[true, null]`. Trade-off: breaks callers who rely on the short list today.
- **C: leave it**, documented per package.

**Recommendation**: A, because it only turns an error into a result and breaks no working caller.

#### X5: Python builds a typed list or dict element group whose unpack then raises (Medium)

**What is not decided**
The Python README shows rows as classes with attribute accessors (`lambda row: row.sid`). A `list` or `dict` whose element is a `group` creates each element as a `dict`, so an attribute accessor inside it cannot set its value. Probe: `Scheme(1, Row, list(lambda r: r.pts, group(0, u8(0, lambda p: p.x))))` builds, packs `Row.pts = [Pt(1), Pt(2)]` as `0102000102`, and unpacking that valid packet raises `AttributeError: 'dict' object has no attribute 'x' and no __dict__ for setting new attributes`, out of `BinaryPacker.unpack` instead of returning an error value. This is the Java shape of AZ-2235 (a typed element group fails on unpack with `ClassCastException`), which you answered by refusing it when the scheme is built (Q5, option A). Python has no factory for an element, and nothing in the README or the Python description mentions the limit.

**Options**
- **A: refuse it when the scheme is built** (an attribute-style accessor inside a list or dict element group; the accessor probe already tells attribute from key access), with a message that says to use `row["x"]` accessors. Trade-off: none for schemes that unpack today; it only moves a crash earlier.
- **B: let the element group take a factory** (`group(0, ..., factory=Pt)`), so typed elements work as they do in Java. Trade-off: a new API surface in Python.
- **C: leave it** and document it. Trade-off: unpack of a valid packet crashes with a raw `AttributeError`.

**Recommendation**: A now (same rule as Java), B only if typed element rows are wanted.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| X1 | Given TypeScript `PackSession.load` called with a 32-character string, `{length: 32}`, a plain `Array` of 32 items, a `Uint16Array(32)`, an `ArrayBuffer(32)`, a number, `null` or `undefined`, When it runs, Then it returns `null` and throws nothing. A `Uint8Array` or `Buffer` of exactly 32 bytes still opens a session and the session vector `b55d0a29c56c203712b241232e` is unchanged. Today (probe on the source and on a `tsc` build of `dist`): `"a".repeat(32)`, `{length:32}` and `new Array(32).fill("x")` give a session keyed by 32 zero bytes (it packs `{a:0}` under nonce `01`x16 as `5781`, exactly what `load(new Uint8Array(32))` packs); `"0123456789abcdef0123456789abcdef"`, a 32-character env text like README's `VITE_PACKBIN_SEED`, gives a key of its digits with every letter turned to 0 (`d31a`); a `Uint16Array(32)` of `0x0107` is taken as 32 bytes of `07` (`5e43`); `null` and `undefined` throw `TypeError: Cannot read properties of null (reading 'length')`; Java `load(null)` and Python (AZ-2231) return no session | "Load \| 32 bytes \| a session that is not yet open \| length other than 32 creates 0 sessions" (`_docs/02_document/contracts/library/pack-session.md:20`); "For anything else it returns `None`. It never raises for the type of its argument" (AZ-2231 Outcome, your answer A to Q2) | new TypeScript task, twin of AZ-2231 (1 point); the npm package ships JavaScript (AZ-2103), so untyped callers are first-class |
| X2 | Given Python `start(16)`, `start([1] * 16)`, `start("a" * 16)`, `join(16)`, `join([1] * 16)`, `join("a" * 16)` and `join(None)`, When called, Then `start` returns `None`, `join` returns `False`, nothing is raised and the session stays closed. `bytes`, `bytearray` and `memoryview` of 16 bytes still open it. Today: `start(16)` returns `00000000000000000000000000000000` and opens a session that packs `{a:0}` as `d2bf`, byte for byte `start(bytes(16))` (a fixed zero nonce means two sessions with the same seed use the same pad); `join(16)` and `join([1]*16)` return `True`; `start([1]*16)` opens with nonce `0101...01`; `start("a"*16)`, `join("a"*16)` and `join(None)` raise `TypeError`. TypeScript for the same inputs throws `TypeError: "key" expected Uint8Array` (loud) | "Start ... a nonce length other than 16 opens 0 sessions" and "Join ... length other than 16 joins 0 sessions" (`pack-session.md:21-22`); AZ-2231 Outcome as above; AZ-2231 `### Excluded` names `start` and `join` as scope only, not as a decision | new Python task, twin of AZ-2231 (1 point), same worker as X1's twin |

### Not walked

- Tag-time guard for the Python wheel and sdist and the Java jar (hardening, the other targets are `### Excluded` in AZ-2240): a wheel built from `python/src/packbin/*.py` without `_flag_scope.py` (the module `_scheme.py` imports, new in this loop) and an sdist holding only `src/packbin/__init__.py` give `check ok: python`, and importing that wheel fails with `ModuleNotFoundError: No module named 'packbin._flag_scope'`; Java asserts only that some `packbin/` class exists (`publish-check.py:181`). By construction `setuptools` (`packages.find`), `cargo package` (it compiles the packaged crate) and `javac` over every source file include every module, and the golden-byte check runs on the source tree (`publish-position.sh`), so no artifact is executed before upload. A crafted crate with only `lib.rs` also prints `check ok: rust`, but `cargo package` would have refused it.
- Batch 5 row 5 (O15), cross-package facts: a multi-slot `u2` as a direct list element packs `01010009` in Python and Java and fails at pack in TypeScript (`a: expected 2-bit int`); a `flag_byte` as a direct element writes `0102000000` and drops the values identically in TypeScript, Python and Java. Batch 5 row 8: the guard also lacks a `supports` assert (O15).
- Carried flagged concerns, Low, owner: a `find_package(packbin 0 ...)` that names only the major finds nothing for a 0.x install (AZ-2232); the ring is three kinds, not one packet, and nothing guards that it stays in the script (AZ-2239); `missing group` has no round index (AZ-2234); the TypeScript `unpack` handler variance under `strict` (plan16 `### Round 2`: "an open item, not a spec"; README casts).
- Pre-existing and recorded: `when` and `times` direct elements say "eq names field id N", not their kind (AZ-2236 Excluded).
- `grep -q` after a pipe under `pipefail` in the publish tests (the SIGPIPE class of AZ-2238): the outputs are tiny, not reproduced. Two concurrent `publish-position.sh java` runs share `/tmp/packbin-position-java`: 3 of 3 pairs passed, not reproduced.
- Python 3.10 to 3.13 stdlib calls, Rust 1.79 against 1.98, wall-clock Rust AC-10 test under load (all as D7).

### Harness gaps

- Batch 5 has its discovery table (10 rows). Still no `implementation_report_*_loop16.md` and no `implementation_completeness_loop16_report.md`.
- `scenarios.md absent (hopper loop)`; Round 2 rows could not be appended, so X1 to X5 and S11 to S21 live only in this report.
- AZ-2231, AZ-2232 and AZ-2240 each name an excluded sibling (constructor, `start` and `join`, other targets' guards) that this round shows as X1, X2 and the Not walked guard row; the specs' `### Excluded` lists are scope notes, not owner decisions.

### Source map (round 2)

| source | rows |
|--------|------|
| Batch 5 #1-#10 | #1 O15, #2 O15, #3 O15, #4 O15, #5 O15 and Not walked, #6 O15, #7 O15, #8 O15 and Not walked, #9 S19 S20 and D7, #10 O10 O11 O12 |
| Review 5 | Python F1 F2 F4 S11 S12, F3 O15; TypeScript F1 F2 F3 S17; Java F1 S14, F2 S16, F3 O15, F4 S15; Rust F1 F2 F3 S18, F4 O15, F5 F6 S18; harness F1 F3 F5 S19 S20, F2 F6 S13, F4 O15 and Not walked |
| Open flagged rows of round 2 specs | AZ-2232 (major-only, version moved to 0.9.0) Not walked, AZ-2234 and AZ-2235 wording O15, AZ-2238 producer row S19, AZ-2239 three kinds and ring guard Not walked, AZ-2240 `supports` O15 |
| This walk | X1, X2, X3, X4, X5 and the Not walked rows |

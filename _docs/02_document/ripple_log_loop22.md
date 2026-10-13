# Ripple log — loop 22

One pass. Scope: all six packages (`git diff 88c063f..04a8cd9`, 89 paths, plus the review fixes of `1dceae6`; specs AZ-2410 to AZ-2418, owner decisions U11 to U17). Mode: the batch report `batch_01_loop22_report.md`, `reference_loop22.md`, `notes22.md`, `review22.md`, `assessment22.md`, the specs with their parent decisions, then the changed source files and the tests that pin each claim (`typescript/src/flag-bits.ts`, `index.ts`; `python/src/packbin/_pack.py`, `_nodes.py`, `_validate.py`, `_flag_scope.py`, `_unpack.py`; `java/src/main/java/packbin/Presence.java`, `SchemeOrder.java`, `Scheme.java`; `csharp/FieldBinding.cs`, `SchemeOrder.cs`, `Walker.StrandedCounts.cs`, `Packbin.cs`; `rust/src/walk/flag_bits.rs`, `times.rs`, `pack.rs`, `field/map_scheme.rs`; `cpp/include/packbin/order.hpp`; the loaders and `fixtures/hostile/{cases.txt,README.md}`).

Callers and sourcers found by reading:

- TypeScript `refuseUnwrittenCount` (now also `bits`, `packed`, `sized`) is called by `pack-fields.ts` at the clear split bit and the clear combined-`flags` member; it recurses through `flags`, flag bits, groups and holding `when`s. `Scheme.DefaultMaxSlots` is read by the constructor and `withLimits` in `index.ts`
- Python `_unwritten_sources` and `_refuse_unwritten_count` are called by the flag-byte and split-bit paths of `_pack.py` (lines 378 and 436); `count_source` is set by `_validate.py` on the three kinds and kept by `_bind` in `_flag_scope.py`; `DEFAULT_MAX_SLOTS` lives in `_unpack.py` and is re-exported by `_scheme.py` and `_pack_limits.py`
- Java `Presence.requireCountWritten` is called by the clear-bit paths of `Presence`; `positive(value, bias)` is its only reader; `SchemeOrder` gives `BITS`, `PACKED`, `SIZED` their count source
- C# `Walker.StrandedCounts.cs` is called by `PackFlags` and `PackFlagBit`; `CollectionShape.IsReal` is read by the list-element check in `SchemeOrder.cs`
- Rust `refuse_count` is called by `refuse_unwritten_count` (`walk/flag_bits.rs`), which `walk/pack.rs` calls at the clear member and the clear flag bit; `check_repeat_lists` is called by `walk/pack.rs` when `__repeat__` holds no groups; `slice_times` reads a member under `flags` one item per round
- C++ `has_member` is called by `empty_round` in `check_shape`, so by `check_table` and the `constexpr` scheme check
- The hostile loaders of all six packages replay the ten new cases of `fixtures/hostile/cases.txt` and fail when a rule-table entry is wrong

Direct refresh:

- `components/01_csharp_package/description.md` — default `MaxSlots` and the slot message in Round limits and Pack output budget, the unpack bullet; a Loop 22 changes list and a loop 22 breaking-changes list. Changed by AZ-2410, AZ-2411, AZ-2415
- `components/02_typescript_package/description.md`, `03_python_package`, `04_rust_package`, `06_java_package` — the same number updates (default `maxSlots`, the message with 1048580 / 1048576) and a Loop 22 changes list and a loop 22 breaking-changes list; stale sentences labelled: Python's equal-length rule (gone, AZ-2413), Rust's per-name list refusal under `flags` (AZ-2414). `05_cpp_package/description.md` — a Loop 22 changes list (no breaking-changes list: C++ refuses what it refused before) and the loop 21 sentence on direct children labelled
- `components/01_csharp_package/tests.md` … `06_java_package/tests.md` — each got a Loop 22 section: the new test files or classes, the task, the suite counts. `01_csharp_package/tests.md` also the constants row (1,048,576)
- `tests/blackbox-tests-15-loop22-parity-and-memory-bound.md` (new, FT-X-66 to FT-X-74) and the index `tests/blackbox-tests.md`; `tests/traceability-matrix.md` (34 rows, seven loop 21 rows closed, summary counts); `tests/blackbox-tests-07-hostile-case-file.md` (ten cases, renumbered `pack_slots_over_limit` and `pack_element_times_over_budget`); `tests/blackbox-tests-13-loop20-pack-budget-and-parity.md` and `tests/blackbox-tests-14-loop21-slot-rule-and-parity.md` (old numbers labelled as loop 20 or loop 21); `tests/blackbox-tests-10-catchup-loops-13-15.md` (loop 15 default labelled); `tests/resource-limit-tests.md` (NFT-RES-LIM-02 label, new NFT-RES-LIM-04 memory ceiling)
- `module-layout.md` — a loop 22 line in each package block and the hostile fixtures block (65 cases, the ten new ids)
- `system-flows.md` — the slot limit rows (default 1,048,576, message numbers), the count-behind-a-clear-`when` row (no value, AZ-2410), the empty round body row (C++ looks through `when` and groups), the short list under `flags` row (Rust, Python, per-name `repeat` lists)
- `interaction-risks.md` — seven rows (no-value count, the F10 memory bound, C# float list, the Rust/Python/Rust parity group, C++ empty `when`, the standing wrong-rule check, and the open loop 22 review rows)
- `architecture.md` — the slot figure in the unpack bound bullet
- `glossary.md` — the Repeat entry (C++ looks through `when` and groups; the Rust `__repeat__` rule; the longest list sets the round count elsewhere)

Checked, not changed:

- `data_model.md`, `contracts/library/pack-session.md`, `adr/*`, `diagrams/*`, `deployment/*`, `common-helpers/*`, `epics.md`, `risk_mitigations.md`, `FINAL_report.md`, `architecture_compliance_baseline.md`, earlier ripple logs — no statement about the changed behavior found by `grep` for `maxSlots`, `4,194,304`, `4194304`, `4194320`, `equal length` and `AZ-2410` to `AZ-2418`
- Sections of `components/*/description.md` and `tests.md` that describe loops 15 to 21 keep their figures (4,194,304 and 4194320 as loop 15 to 21 numbers) where the sentence names the loop; the current-default sentences were updated
- `README.md`, `fixtures/hostile/README.md` — owned by the parent in this loop; the parent edited both

Open items recorded in the docs (stated, not fixed; each is a row in `review22.md` or `notes22.md`, to the loop 23 handoff):

- Rust unpack gives per-name lists with only the rounds that read the name, so repacking a `times` under `flags` from them shifts values (the README Times note says repack from `__times_N` groups); Rust still refuses a list for a member under a `when` inside a `times` (review22 1, 9)
- Rust `repeat` per-name check misses names of a nested `times` or `repeat`, and lists given beside `__repeat__` groups are dropped without a word (review22 5)
- C++ builds `when` with a negative `eq` field id; the `construct_empty_*when*` cases pass for the scope rule in five packages and the empty-body rule is unreachable through public builders in Python, Java, C# and Rust (review22 2, 6)
- A TypeScript bigint count above 2^53 packs the clear bit where the others refuse (review22 8); the C++ `packed` with bias -1 is refused in every cell, not traced; a C# `List<decimal>` for an `f32`/`f64` field is refused at build (notes22)
- Python unpack memory after the surcharge removal (Review21 #2): loop 22 measured the F10 shape only

Stale after this pass, in files this pass does not own:

- `_docs/00_problem/acceptance_criteria.md` — the interaction ACs for the new risk rows were not promoted
- `README.md` line quoting "29,127" as the round at which the 36-name `when` body is refused: the TypeScript test refuses it at round 28,340 because the body holds 37 names (the 36 names and `k`); not verified which width the README sentence means
- Test-spec files over the 500-line soft cap: `components/01_csharp_package/tests.md` (514), `06_java_package/tests.md` (509), `05_cpp_package/tests.md` (506) and `tests/traceability-matrix.md` (about 535); the first three were at or over the cap before this pass, and a split by loop is the follow-up

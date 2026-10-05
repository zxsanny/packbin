# Autodev loop record — loop 12

loop: 12
branch:
worktree: none (worked on dev, same as loop 11)
plan_artifact: _docs/loops/loop12/plan12.md
tasks_shipped: [AZ-2079_csharp_bool_rule_flag_limit, AZ-2080_typescript_bool_flag_limit, AZ-2082_rust_flag_bits_bool, AZ-2083_python_bool_flag_limit, AZ-2089_java_forward_refs_bool, AZ-2129_typescript_constructor_checks, AZ-2130_csharp_empty_nested_row, AZ-2131_java_empty_group_refused, AZ-2132_python_empty_group_refused, AZ-2133_rust_cpp_bitwhen, AZ-2147_cpp_empty_group_without_member]
leftovers:
  - "Follow-up tickets filed this loop (todo/, epic AZ-2069): AZ-2126 (`eq` on a bool accepts only `true`, all packages; also the bool-as-count question), AZ-2127 (Java nested rounds as per-round lists; also the nested-row-in-repeat throw, G2), AZ-2128 (flag group presence counts every child kind, C#/Java/Rust/TS/Python; Rust map `times`/`when` as a flags member), AZ-2134 (per-round aligned values in TS, C#, Python; C# values under flags in a round dropped), AZ-2135 (split-bit numbering by field order in TS/C#/Java; C++ binds a bit to a byte read inside an earlier `when`). AZ-2086, AZ-2100, AZ-2101, AZ-2090, AZ-2091 gained flagged-concern rows"
  - "Remaining bug-fix hopper from loop 11 (unclaimed): AZ-2084..2088, AZ-2090..2093, AZ-2094..2098 (v0.2.0 waits for AZ-2094..2097), AZ-2099..2105, AZ-2112..2121; AZ-2068 stays an optional stretch"
  - "`cpp-example-pico` cannot run on an arm64 host (no Linux arm64 PlatformIO ARM toolchain); CI x86_64 covers it. Run Tests verdict PARTIAL for that reason only"
  - "`language-pair.sh` (boolflag, booltrue, bitwhen rings) is not run by CI; recorded only as DR6 in the whole-project assessment, no ticket"
  - "Docs not fixed (pre-existing): Rust component doc lists `BinaryPacker::unpack` as public (it is private); no typed `BoundField` list test for a bare flag-bit element; README / schema.md do not describe the `bitwhen` behavior (project AC-4 and the ring comment do)"
  - "Candidate dead code: TypeScript `case \"flags\"` in `pack-fields.ts` / `walker.ts` is unreachable through `Scheme` now that the constructor flattens"
  - "Not walked by the assessment: C# list/dict element of kind `Flags` packs `00` for every item (members dropped), no C# ticket; empty `flags(anchor)` with no members across packages; Java empty nested row sets its bit for any non-null member"
  - "Owner decision still open: error kind and label of the interim error (C15)"
  - "Environment: the embedded toolchain cache lives at the gitignored repo-root `.cache/embedded/` (~7.7 GB; override `PACKBIN_EMBEDDED_CACHE`). The C# and TypeScript AC-10 NFRs are load-sensitive in containers when other Docker stacks run on this host"
smoke: PASS
smoke_artifact: _docs/loops/loop12/smoke12.md
assessment_artifact: _docs/loops/loop12/assessment12.md
suite: PARTIAL (Pico example host-only)
suite_report: _docs/03_implementation/test_run_loop12_report.md
merged_local: true
conflicts_resolved: ""
loop_end_merge: stage

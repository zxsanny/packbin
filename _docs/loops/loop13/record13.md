# Autodev loop record — loop 13

loop: 13
branch:
worktree: none (worked on dev, same as loops 11 and 12)
plan_artifact: _docs/loops/loop13/plan13.md
tasks_shipped: [AZ-2084_typescript_int_range, AZ-2085_rust_typed_scheme_integrity, AZ-2086_rust_typed_times_vec, AZ-2087_csharp_forward_refs, AZ-2088_csharp_pack_fails_loudly, AZ-2090_typescript_reference_scope, AZ-2091_typescript_nested_flags_names, AZ-2175_csharp_when_on_written_values, AZ-2176_csharp_nested_round_refused, AZ-2177_typescript_nested_round_refused, AZ-2178_rust_typed_times_pins, AZ-2179_rounds_ring]
leftovers:
  - "Security audit (step 14, PASS_WITH_WARNINGS): F10 Medium, unpack of a `repeat` / `times` round costs memory and time per name per round with no budget (TypeScript 401 MB, C# 525 MB, Java 570 MB, Rust 311 MB and 1.4 GB with eight set flag bits, for 1 MiB; documented in the README, owner-accepted in the assessment, X10). F11 Low, no test bounds unpack cost by packet size. No tickets yet: the owner decides keep, per-call budget, or compact rounds (`_docs/05_security/security_report.md`)"
  - "Follow-up hopper under epic AZ-2069 (unclaimed, in todo/): AZ-2180 to AZ-2194 (deferred assessment follow-ups) and AZ-2197 (TypeScript `when` on written values, found by the README writer; spec and dependency row written in step 13). AZ-2092 (C# typed `Unpack` of rounds), AZ-2112, AZ-2113, AZ-2117, AZ-2126, AZ-2127, AZ-2128 gained notes. Rest of the bug-fix hopper from loop 11: AZ-2093 to AZ-2105 (AZ-2094 to AZ-2097 gate v0.2.0), AZ-2112 to AZ-2121; AZ-2068 stays an optional stretch"
  - "Release: v0.2.2 is the owner's chosen tag (plan13 `## Release`); not created. It needs one explicit confirmation with the exact commit, a green `test.yml` on that commit (AZ-2095: publish does not wait for tests), and the owner's answer on whether `origin/main` is fast-forwarded too. The Rust three-argument `times` removal is a source-breaking change, so 0.3.0 was offered"
  - "`cpp-example-pico` cannot run on an arm64 host (no Linux arm64 PlatformIO ARM toolchain); CI x86_64 covers it. Run Tests verdict PARTIAL for that reason only (`_docs/03_implementation/test_run_loop13_report.md`)"
  - "Open from earlier loops: no `tsc --noEmit --strict` job in `test.yml` (loop 11 action); F1 to F3 (unpinned `actions/checkout@v7`, `arduino-cli` download without a checksum, images by tag); error kind and label of the interim error (C15); the audit's fuzz and amplification harness still lives in a scratchpad (`_docs/AGENT_GOTCHAS.md`)"
  - "Environment: the embedded toolchain cache lives at the gitignored repo-root `.cache/embedded/` (~7.7 GB; override `PACKBIN_EMBEDDED_CACHE`). The C# and TypeScript AC-10 NFRs are load-sensitive in containers when other Docker stacks run on this host"
smoke: PASS
smoke_artifact: _docs/loops/loop13/smoke13.md
assessment_artifact: _docs/loops/loop13/assessment13.md
suite: PARTIAL (Pico example host-only)
suite_report: _docs/03_implementation/test_run_loop13_report.md
merged_local: true
conflicts_resolved: ""
loop_end_merge: stage

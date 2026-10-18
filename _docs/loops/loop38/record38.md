# Autodev loop record — loop 38

loop: 38
branch: dev
plan_artifact: _docs/loops/loop38/plan38.md
tasks_shipped: [AZ-2678, AZ-2679, AZ-2680, AZ-2681, AZ-2682, AZ-2683, AZ-2684, AZ-2685, AZ-2686, AZ-2687, AZ-2688, AZ-2689, AZ-2690]
decisions:
  - owner 2026-10-18: option A (CRC for the whole message) widened to detect and correct with a configurable number of parity bytes; accepted all five recommended decisions (one mechanism, Reed-Solomon over bytes, no separate CRC; per-scheme setting; typed error beyond the size limit; session parity over the padded bytes; correction behind PACKBIN_NO_ECC, off on Cortex-M4F) and the scope "full correction now" (57 points) over "detect first"
  - agent, found by the reference fuzz and recorded as decision 6 of `problem.md`: the code also covers the clear length as an unsent first byte, because a plain systematic code accepts a message with a trailing 00 more or less (about 1 in 256 for a lost last byte); cost: at most 254 bytes sent, not 255
  - agent (flag to owner): the default correction limit is 0 (detect only). Repairing t bytes gives up detection: with 2 parity bytes and t = 1 a random buffer is accepted 1 time in 17 (contract table). Changing the default is one line per package
  - agent: `withLimits`/`with_limits` keep an existing parity count in every package (TypeScript, Python and Swift were changed to match C#, Java, Rust and Go)
  - agent: the repair call is a sibling of the plain unpack (`unpackRepair`, `unpack_repair`, `UnpackRepair`) in every package except Python (`limit=` argument) and C# (`Unpack(..., limit, out repaired, ...)`); the plain call is detect-only
  - agent: C++ `Result` grows 16 to 20 bytes on 32-bit in ECC builds; `PACKBIN_NO_ECC` keeps the old layout, and Cortex-M4F builds with it (8,132 B flash, 492 B stack unchanged)
leftovers:
  - review (high, 9 findings, none blocking): duplicate-type check order differs (Python and Java before the receive index, TypeScript, C# and Rust after); Rust `DispatchHandler` gains a required `parity()` method (breaking for outside implementors); Go, Swift and C++ report a buffer over 254 bytes as the rounds error, the other five have a distinct `TooLong`; TypeScript, Java and Rust plain unpack give no repaired count for a scheme without parity; the post-repair re-verify is covered by one test only (mutation run); C++ description lines 130 and 163 to 182 still say 456 of 512 B and 8152 of 8192 B; parity is set in the limits setter in Python, TypeScript and Swift and by a separate method in the other four
  - the Cortex-M4F gate no longer measures an ECC build; M0+, M3 and ESP32 run with ECC and only pass or fail covers their stack
  - not run locally: ESP32-S3/C3, Pico and Arduino builds with ECC on, vcpkg supports and consumer checks, the `test.yml` median over two CI runs (AZ-2689 AC-3, budget 238.5 s)
  - the timing checks `round-scope-cost` (TypeScript) and AC-8 100,000 round trips (Java) failed once each beside other suites and passed alone; the serial retry hides this, so a regression would only show as a repeated failure
  - `/feature-assess`, `/security` (AZ-2666, now also the ECC decoders) and the retrospective of loops 35 to 38 are owner-run and not done
  - D5 real messages, F44 and the first v*/go/v* tags (owner only); AZ-2068 in todo/; main not pushed
smoke: PASS (agent run 6/6 at 64db597, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop38/smoke38.md
step11: RESULT 13 passed (typescript go only on the serial retry), 0 failed, 1264 s at 64db597
loop_end_merge: main (not executed: the dev push only, as in loop 37)

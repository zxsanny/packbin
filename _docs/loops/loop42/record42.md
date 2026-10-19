# Autodev loop record — loop 42

loop: 42
branch: dev
plan_artifact: _docs/loops/loop42/plan42.md
tasks_shipped: [AZ-2713, AZ-2722]
decisions:
  - owner 2026-10-19 ("accept all recommended"): AZ-2713 (strictly ascending dict keys, F51 and F56) plus the cheap loop 41 Lows F57, F59, F60 and the F19 instances in Python and TypeScript (new ticket AZ-2722); F58 (Python session pad) deferred; `main` fast-forward at close per `ci_cd_pipeline.md`
  - agent: the rule is UTF-8 byte order of the decoded keys, strictly greater than the previous key; the refusal is each package's existing repeated-key error. Java, C#, TypeScript compare by code point (UTF-16 order differs above U+FFFF); five shared hostile cases (`dict_keys_*`) and the fuzz corpus carry it
  - agent: C++ compares the previous and the new key payload a byte at a time (`txt::Stream`, `compare_payloads`, a resumable compact decoder shared with the full decode), so a dict that is not bound is checked too and no key is stored; a PACKBIN_NO_TEXT build checks no order (documented). Probe dict-quad: 65,535 keys 16.9 s to 2 ms. M4F flash 7,920 B (margin 272 B, was 60 B), stack 504 B of 512 (margin 8 B, was 20 B)
  - agent: the C++ session scheme check (F57) covers the handler overload too and is documented in `message-ecc.md`; Python `bytearray(memoryview(data))` before the index; TypeScript `toBuf` throws on a non-binary payload; C# and Go repair use fixed arrays (Go 37 allocations to 1, fuzzed 3.7M executions and 300k random calls with 0 panics); Rust `shrink_to_fit`
  - agent: four workers by package pair (Python + TypeScript, C# + Java, Rust + Go, Swift), C++ in the parent; total review 6 findings (hand-over: 2 fixed in `b427967`: handler status test and contract order, Stream mode guard; 4 accepted: M4F stack margin, three decodes per key, NO_TEXT unbound dict unchecked, loose Rust debug speed bound)
leftovers:
  - F58 (Python session pad cost before the type byte) open; the load-aware timing bounds (retro action 2): Go `TestAC3RaisedSlotLimit...` (1.14 s of 1 s under -race at load 27 to 30) failed twice in the pool this loop; AZ-2068 in todo/
  - not run: the C# fuzz-ecc probe on the new repair arrays (the probe build picked the wrong project; the 4,223 C# tests and the ECC vectors pass), vcpkg checks, Linux x64
  - `/feature-assess`, `/security` follow-up and the retrospective are owner-run; F44 and the first v*/go/v* tags
smoke: PASS (agent run 9/9 at b427967, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop42/smoke42.md
step11: RESULT 13 stages passed at b427967 (csharp, python on the serial retry; go failed in the pool and on its retry under load, passed alone and on a later loop-tests run, 183 s), 0 failed; first run 1677 s
loop_end_merge: main

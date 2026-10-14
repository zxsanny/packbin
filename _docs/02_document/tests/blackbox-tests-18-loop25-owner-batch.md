# Blackbox Tests 18: Loop 25 owner batch (FT-X-113 to FT-X-123)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md). Loop 25 (AZ-2472 to AZ-2479, 8 specs, 14 points) applied the owner batch of 2026-10-14 ("accept all recommended") on the loop 24 handoff: the short wave U25 A, U26 A, Low-1 A, U24 B, the probes D1 and D7, the `run-suite.sh` alignment D6 and the Go memory measurement D8. One table row per scenario, as in file 17.

**Where it runs.** Step 11 of loop 25 ran 12 stages at commit `07500b6` and all passed: scaffold, Go, TypeScript, C#, Python, Rust, Java, C++ (GCC 16, `-Werror`), the ARM embedded stage, the cross-language ring, AC-10 in C# Release, and the publish gate. The Go memory test is opt-in: `go test -tags packbin_memtest -v -run TestMem -count=1 ./...` in `golang:1.27`.

**Status words.** Covered: a test or script ran green in loop 25. The mutation checks (the test is red when the fix is reverted) are named where they were made.

## Scenarios

| Id | What it checks | Evidence | Expected result | AC ref |
|----|----------------|----------|-----------------|--------|
| FT-X-113 | U25: the C++ builder refuses a count id (`bits`, `packed`, `times`, `sized`), a field id or a `when` anchor outside 0 to 32,767 | `cpp/tests/core/builder_id_range_host_tests.cpp`; each refusal case wraps to a valid earlier id and has a control that builds; the boundary pair 32,767 builds and 32,768 is refused is pinned on the node through `check_shape`; mutation: both hunks reverted gives 21 failures, only `leaf` 8, only `counted_leaf` 13 | `SchemeInvalid` at the field; pack and unpack of a refused scheme write and read nothing; the error names the wrapped 16-bit id (open row Assessment25 G1) | AZ-2472 AC-1, AC-2, AC-3 |
| FT-X-114 | U25: a count id of -1 still builds and fails every pack and unpack; the Cortex-M4F budget holds | the same test file (AC-4 case); step 11 stage 9: flash 8152 of 8192 B (margin 40 B), deepest pack/unpack stack 456 of 512 B (margin 56 B), M0+ PASS, M3 QEMU 241 of 241, s390x 241 of 241 | `BadValue` at the member; no change in flash or stack | AZ-2472 AC-4, AC-5 |
| FT-X-115 | U26: a C# dictionary row packs and unpacks a nested-row group through the nested dictionary | `csharp/tests/DictNestedRowGroupTests.cs` (7 facts); the existing tests of rounds, list and dict elements, flags and typed rows with their expected hex unchanged and only the dictionary inputs wrapped; step 11 stage 4: 2003 tests | `{G: {N: 7}, X: 1}` packs `010701`; the flat row is refused naming the inner member or the group; unpack returns `G` as a nested dictionary and repacks to the same bytes | AZ-2473 AC-1 to AC-4 |
| FT-X-116 | Low-1: Python raises `ValueError` with TypeScript's text for a value given to a member whose count no field wrote | `python/tests/test_az2474_value_error_text.py` (10 tests: bits, packed, sized, times; type; text; `TypeError` unchanged; unpack unchanged); step 11 stage 5: 1494 passed | `ValueError("2: count 1 was not written")`; wrong value type still `TypeError` | AZ-2474 AC-1 to AC-4 |
| FT-X-117 | D8: Go's peak memory for the F10 packet and the wide round | `go/mem_test.go` (tag `packbin_memtest`): heap in use sampled every 500 µs during the unpack, one run each, about 10 %; README memory bullet; table row in file 15; NFT-RES-LIM-05 | F10 packet at `maxSlots` 4,194,304: about 625 MB; wide round (16,128 rounds of 65 one-byte members) at the defaults: about 94 MB; both agree with the F41 audit (about 624 MB; about 105 MB per MiB) | AZ-2475 AC-1 to AC-4 |
| FT-X-118 | D6: each of the six non-Go suites fails when its manifest is missing | `.github/workflows/run-suite.test.sh` M1 to M3; mutation: against the old `run-suite.sh` every bare tree passed with a PASS row; the compose run of all seven languages at step 11 for the present-manifest path | exit non-zero, a message naming the manifest, one FAIL row, no tool run; with the manifest present the suite and its report row are unchanged; AC-15 is decided by `publish-gate.sh` (`absent <lang>`), which no publish script reads from `run-suite.sh` | AZ-2477 AC-1 to AC-3 |
| FT-X-119 | D7: the split flag bit inside a false `when`, member given, in Python, Rust, C#, Java and C++ | `python/tests/test_loop25_probe_d1_d7.py`, `rust/tests/loop25_probe_d1_d7_tests.rs`, `csharp/tests/Loop25ProbeD1D7Tests.cs`, `java/src/test/java/packbin/Loop25ProbeD1D7Test.java`, `cpp/tests/core/loop25_probe_d1_d7_host_tests.cpp`; TypeScript measured with `node --experimental-strip-types` | pack `0101030506` (k=1) and `01000306` (k=0); unpack `{k:0, b:6}`; repack `01000206`; all five equal TypeScript and Go, so no walker changed | AZ-2478 AC-1 to AC-4 |
| FT-X-120 | D1: the empty anchored group `Flags(0, Group(0,"mark")), U8(0,"n")` in the five other packages | the same five files, the `..._differs_from_typescript` tests; tables in `batch_02_loop25_report.md` | hex rows equal TypeScript wherever the scheme builds; Python refuses construction; Rust numbers the id slot (the `U8` is id 1) and builds a `when` on the mark; Java reads `Boolean.FALSE` as present and unpacks `{mark:{}}`; C++ builds a `when` on the mark. Kept and documented (decision A) | AZ-2476 AC-1 to AC-3 |
| FT-X-121 | U24 B: the README names C++'s unbound member as the "not carried" spelling and records the decided open rows | `README.md` bullet "Decided in loop 25"; the pinned outcome `packed_bias_novalue_host_tests.cpp::u20_unbound_packed_bias...` | documented exception, no code change; build and tests unchanged | AZ-2479 AC-1 to AC-3 |

## Loop test script (AZ-2500)

| Id | What it checks | Evidence | Expected result | AC ref |
|----|----------------|----------|-----------------|--------|
| FT-X-122 | Stage selection by changed files: a C# source selects the C# suite, the ring and AC-10; `README.md` only the publish gate; an added package file also the gate; a test file not the ring or the gate; fixtures every suite; a dirty tree, an untracked file, a foreign or missing stamp run the stage; `--all`, `--only` | `scripts/loop-tests.test.sh` cases 1 to 13 (a temporary git repository, `--plan`); mutation: widening the gate's pattern fails it | each case prints the expected `PLAN <stage> RUN|SKIP`; 12 stages | AZ-2500 AC-1 |
| FT-X-123 | Execution: a suite that fails beside the others is re-run alone and passes; one that fails again fails the run (exit 1); stamps only from a clean tree and only for passing stages | `scripts/loop-tests.test.sh` case 14 with a fake `docker`; mutation: stamping from a dirty tree fails it; a real run of four suites in parallel: 28 s against 70 s in sequence | as described; no stamp for a failed stage or a dirty tree | AZ-2500 AC-2, AC-3 |

## Harness speed-up (AZ-2477 follow-up, commit `d5646cf`)

Not a product scenario. `language-pair.sh` builds the C# and C++ drivers once a run into a private `mktemp -d` directory (the ring went from 239 s to 43 s, exit 0), and `check-cases.sh` counts package names with one word list per pack case (4.8 s to 2.6 s of CPU). `ring-wiring.test.sh` (24 s) and `cases.test.sh` (11 corruption cases) pass unchanged.

## Open rows

| Id | Row | Recommendation |
|----|-----|----------------|
| Assessment25 G1 | The C++ range-check error names the id after the 16-bit wrap (`when(65537)` reports field 1) | A keep and document (done in the README); B would carry the 32-bit id in the error and needs an arm stage run with a 40 B flash margin |

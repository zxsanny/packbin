# Batch 01 report — loop 56

Tasks: AZ-3143 (flag-byte bit at resolve), AZ-3144 (one path for held whens), AZ-3145 (corpus counts derived). Two workers: C++ (AZ-3143 then AZ-3144), loaders (Go, Swift, Rust). Review: one total review at the end of the loop (owner rule). Commits: 56c476e (C++), ebd5e9b (loaders).

## Results

| Task | Status | Evidence |
|------|--------|----------|
| AZ-3143 | Done, AC-1 not met | `flag::HoldsFlagByte` (128) set in `resolve()`; `reads_flag_byte` removed; `Field` still 16 bytes before `eq`; host test `when_flag_bit_host_tests.cpp` builds the scheme at compile time and at run time. Flash 8,080 B (was 8,120 B): a 40 B saving against the 80 B asked (AC-1 target 8,040 B); margin 112 B. Host, `gcc:16`, arm stage PASS (vectors 287 of 287), avr-uno 15,608 B |
| AZ-3144 | Fold not made (allowed outcome of AC-1) | fold tried as one NOINLINE `unpack_held` called from `unpack_children` and `unpack_one`: flash 8,140 B (over 8,120 B), stack 676 B net (over 512 B; flag chain raw 564 to 740, plain chain 356 to 456, round chain 500 to 600). Restored by hand. Round-chain image scheme 0x5d added: 3-deep `when` chain inside a `times` round, 436 B net on unpack and on pack, packets equal Python on host, M3, s390x, M4F |
| AZ-3145 | Done | no literal 75, 17, 43, 25, 18, 14 or 32 count in the six owned files; missing and unused handlers named by case id in Go, Swift and the Rust heap-free loaders, shown with a broken copy (one line added, one removed) |

Stack figures after the batch (M4F, net): deepest 504 B (all-kinds sample row), flag-byte chain unpack 500 B / pack 384 B, plain chain unpack 292 B / pack 348 B, round chain 436 B / 436 B. Flash 8,080 B of 8,192 B.

## Commands

C++ `make -C cpp test` host, `make -C cpp clean` then `docker run ... gcc:16 make test`, `docker compose -f docker-compose.test.yml run --rm cpp-embedded` exit 0 (m0plus, m3-qemu, m4f, s390x, avr-uno PASS). Go container `gofmt`, `go vet`, `go test -race` ok (72.8 s). Swift plain `swift test` 422 tests in 72 suites passed. Rust `cargo test` ok; `cargo test --features text,ecc --test nostd_hostile_tests --test nostd_hostile_pack_tests` 9 passed.

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear / unclear |
|----------|-----------|-------------------|-----------------|
| AZ-3143 AC-1 | The resolve-time bit saves 40 B, not 80 B; 8,080 B against the 8,040 B target | AC-1 recorded as not met; a bigger saving needs a search elsewhere in `cpp/src/core` | unclear (owner priority) |
| AZ-3144 | The fold fails because the loop calls an out-of-line function per `when` (frame per level); a later try needs `unpack_held` inlined into `unpack_children` without a bigger frame, and about 60 B of flash saved first | not made; recorded for a later loop | unclear (depends on the row above) |
| AZ-3144 | The round chain measured is plain (no flag byte); a flag-byte chain inside a `times` round is not built | not measured; no AC names it | clear (handoff 57) |
| AZ-3145 | The main Rust loader (`rust/src/hostile_tests.rs`) cannot see an unused unpack or limit handler: `scheme_for` and `rust_outcome` are `match` expressions; the nostd corpus test catches it by id | accepted; the Rust suite as a whole fails by id | clear |
| AZ-3145 | `corpus.txt` counts remain: Swift `FuzzTests.swift` `corpus.count == 33` and Rust nostd `inputs.len() >= 33` (another fixture); adding a case needs a corpus line and breaks Swift with a count error, not an id | not in AC-1 (counts of `cases.txt`); handoff 57 | clear |

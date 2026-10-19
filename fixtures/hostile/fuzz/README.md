# Unpack fuzz corpus

`corpus.txt` holds the raw inputs every package's unpack fuzz run starts from (made in loop 26, AZ-2517, for Swift; any package may read it). One input a line, `name kind hex`; `#` lines are comments.

- `name`: unique, `[a-z0-9_]+`, so an input that breaks a run can be named.
- `kind`: the scheme the input is a packet of. A `hostile_*` input has the scheme of its case in `../README.md` (the case id is the kind; a `limit` case is read with that section's limit and the defaults too). A `ring_*` input has the scheme of that kind in `.github/workflows/language-pair.sh` (`position` is the golden scheme of `fixtures/golden.hex`); `any` is a packet of no scheme (the session ciphertext).
- `hex`: the whole packet, type byte included, lowercase.

How it was made: the hex of every `unpack` and `limit` line of `../cases.txt` (12 inputs), then each `*_packet` file of Go's seed corpus `go/testdata/fuzz/FuzzUnpack/` that is not one of those (the ring payloads, their `-short` forms, the golden packet, 16 inputs), decoded from the `go test fuzz v1` format. Go's `*_body` files are the same packets without the type byte; a fuzz run makes those itself. Go's corpus is not changed. When a case is added to `../cases.txt` with an `unpack` or `limit` stage, add its line here (the Swift `FuzzTests` check that every one is present).

A fuzz run reads each input with the scheme of its kind, as the body of a packet of every fuzz scheme, and with every fuzz scheme at once, then mutates the inputs and draws fresh bytes from a printed seed. It asserts only that each unpack returns a row or the package's error within 1 second; it never asserts that an unpacked row packs again (a `flags` `times` whose bit is clear with a count above 0 unpacks and then refuses to pack).

## Audit probes (loop 41, AZ-2666)

One directory per package holds the probes of the loop 41 security audit of the compact text decoder and the message ECC unpack path (`_docs/05_security/security_report.md`, "Loop 41 addendum"). They are not part of any suite and CI does not run them. Re-run them before a change to a decoder, the repair or the session unpack path, and compare the figures with the addendum's. Each one takes the repository checkout as its first argument, reads `fixtures/` from it, writes nothing into it (build output goes to a directory you name outside the checkout), and stops itself. Every runnable file starts with a comment that gives its command line.

| Directory | What runs | Probes |
|-----------|-----------|--------|
| `python/` | `python3.14 -I -B <file> <checkout> [seed] [seconds]` | `fuzz_text.py`, `fuzz_ecc_session.py` (shared `fuzz_common.py`; differential against `scripts/text/textfmt.py` and `scripts/ecc/eccfmt.py`), `ecc_worst.py`, `text_amp.py`, `edges.py` |
| `typescript/` | `node <file> <checkout> ...` (needs `typescript/node_modules`) | the same five, plus bounds-checked copies of `text.ts` and `ecc.ts` written to the OS temp dir |
| `rust/` | `sh run.sh <checkout> <build dir> <debug\|release> <command>` | random, ecctime, textamp, edges (debug keeps overflow checks on) |
| `go/` | `sh run.sh` in `golang:1.27` (command in the file) | random, ecctime, textamp, edges, allocs, and four `go test -fuzz` targets in `fuzz_test.go` |
| `csharp/` | build `PackbinProbe.csproj` from a copy outside the checkout (command in the file) | fuzz-text, fuzz-ecc, ecc-worst, text-amp, edges; `ns20/` checks the netstandard2.0 UTF-8 branch |
| `java/` | `javac --release 17` with the package sources, then `java packbin.AuditProbe` | the same five as C# |
| `swift/` | `build_swift.sh <checkout> <empty dir> release\|debug\|asan` | text-fuzz, ecc-fuzz, edge, ecc-worst, text-amp, text-long, dictkey (F47 shapes) |
| `cpp/` | `build_cpp.sh <checkout> <probe dir> <outdir> [both\|asan\|o2]` | text-fuzz, ecc-fuzz, edge under ASan and UBSan; ecc-worst, text-amp, text-long, dict-quad (F51) at -O2 |

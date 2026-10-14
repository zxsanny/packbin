# Unpack fuzz corpus

`corpus.txt` holds the raw inputs every package's unpack fuzz run starts from (made in loop 26, AZ-2517, for Swift; any package may read it). One input a line, `name kind hex`; `#` lines are comments.

- `name`: unique, `[a-z0-9_]+`, so an input that breaks a run can be named.
- `kind`: the scheme the input is a packet of. A `hostile_*` input has the scheme of its case in `../README.md` (the case id is the kind; a `limit` case is read with that section's limit and the defaults too). A `ring_*` input has the scheme of that kind in `.github/workflows/language-pair.sh` (`position` is the golden scheme of `fixtures/golden.hex`); `any` is a packet of no scheme (the session ciphertext).
- `hex`: the whole packet, type byte included, lowercase.

How it was made: the hex of every `unpack` and `limit` line of `../cases.txt` (12 inputs), then each `*_packet` file of Go's seed corpus `go/testdata/fuzz/FuzzUnpack/` that is not one of those (the ring payloads, their `-short` forms, the golden packet, 16 inputs), decoded from the `go test fuzz v1` format. Go's `*_body` files are the same packets without the type byte; a fuzz run makes those itself. Go's corpus is not changed. When a case is added to `../cases.txt` with an `unpack` or `limit` stage, add its line here (the Swift `FuzzTests` check that every one is present).

A fuzz run reads each input with the scheme of its kind, as the body of a packet of every fuzz scheme, and with every fuzz scheme at once, then mutates the inputs and draws fresh bytes from a printed seed. It asserts only that each unpack returns a row or the package's error within 1 second; it never asserts that an unpacked row packs again (a `flags` `times` whose bit is clear with a count above 0 unpacks and then refuses to pack).

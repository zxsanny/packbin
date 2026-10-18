# Worker rules — compact strings (loop 35)

Read this file first. It applies to every package worker of epic AZ-2645. The parent (the conversation that spawned you) owns tracker, git, review, shared fixtures and CI wiring.

## What you build

One package writes and reads every string in the compact text format. The format is frozen:

- Contract: `_docs/02_document/contracts/library/compact-text.md` (version 1.0.0). It is the specification.
- Reference code: `scripts/text/textfmt.py` is the executable definition of the encoder (`parse`, `encode`) and the decoder (`decode`). When the text of the contract and the reference seem to disagree, stop and report; do not guess.
- Tables: `fixtures/text/tables.json`. Do not copy numbers by hand: run `python3 scripts/text/emit_tables.py <lang>` (`<lang>`: python typescript csharp java rust go swift cpp) and save its output unedited at the path printed by `python3 scripts/text/emit_tables.py <lang> --path`. Your tests must include a check that the committed file equals the emitter output (`emit_tables.py <lang> --check FILE`, or a copy of its text compared in your test).
- Vectors: `fixtures/text/vectors.txt` (row syntax at the top of the file, `fixtures/text/README.md`). Your tests load it from the repository root and run every row kind: `enc` (pack gives exactly the bytes; unpack gives the text and uses every byte), `alt` (unpack gives the text), `bad` (unpack is refused), `ref` (the ring packets; see your task for the scheme), `flip` (each bit of that field's payload, not its count, flipped in `[field][0x5a]`: the result is a string or an error; if it is a string the byte after it is `0x5a`; nothing throws, traps, panics or reads past the payload).
- A command line to compute expected bytes while you write tests: `python3 scripts/text/textfmt.py enc "text"` and `python3 scripts/text/textfmt.py dec <field hex>`.
- Your task spec is `_docs/02_tasks/todo/<ticket>_*.md`. Implement every AC in it with a test. Its `Where` list names the functions to change; the codec must be used for every string position (field, list element, dictionary key, dictionary value list, `repeat`/`times`/`flags` strings).

## Decoder and encoder rules to get right

- The encoder works on the UTF-8 bytes your package already produces for a string today (so the language's own behavior for lone surrogates and invalid input does not change). Text over 65,535 UTF-8 bytes is refused on pack, naming the field, as today.
- The encoder is the optimal parse with the contract's tie-break (suffix costs, then the smallest first-symbol index at every step). Use integer costs. Bound the work: states 8, edges small; do not recurse per character.
- The decoder must be bounded by the payload length: no allocation sized from untrusted numbers other than the payload itself; the output is at most 6N + 8 bytes for an N-byte payload; the text is limited to 65,535 UTF-8 bytes as it grows.
- Refusal kinds are listed in the contract. Your error type already names the field; carry the kind only as far as the vectors need (rows are checked as "refused").
- Keep the public API unchanged. Only the bytes of string fields change.
- `maxBytes` and other pack limits keep working: check the size before the write that passes the limit.

## You own / you must not touch

- You own the directory named in your task (`python/`, `typescript/`, `csharp/`, `java/`, `rust/`, `go/`, `swift/` or `cpp/`) and nothing else.
- Forbidden: every other path, including `fixtures/`, `scripts/`, `.github/`, `README.md`, `_docs/`, other packages, root manifests. If you need a change there (a wrong vector, a contract gap), stop that line of work and describe it in your report.
- Known and expected until AZ-2657: the shared hostile cases (`fixtures/hostile/cases.txt`) still hold two string rows in the old format (`invalid_utf8`, `invalid_utf8_dict_key`) and your hostile loader test may fail on exactly those rows, and the ring scripts still carry the old `user`/`nested` bytes. Leave those tests as they are, do not skip or weaken them, and name the failing test ids in your report.
- The existing tests of your package that contain old string bytes (inline hex of the `user` packet and similar) are yours to update with bytes from the reference.

## Shell hygiene (every command)

- Stdin from `/dev/null` on every command that could read it; no bare `cat`, `read` or unfinished here-doc; nothing interactive.
- A time limit on anything that can hang: `perl -e 'alarm 900; exec @ARGV' -- command ...` (macOS has no `timeout`).
- No leftover background processes: start none, or kill what you started. One build or test run at a time (the host is under load: swap is full, an emulator and other containers run).
- Python only in a virtual environment; never `pip install` globally.
- Forbidden git commands: `add`, `rm`, `mv`, `restore`, `stash`, `checkout`, `reset`, `clean`, `commit`, `push`. Read-only git (`status`, `diff`, `log`) is fine. Check `git diff --cached` is empty at the end.
- No formatter or linter that writes to files you do not own. `cargo fmt` is not to be run (the crate is not rustfmt-clean); format your own new code by hand.
- No Docker compose rebuilds. Single `docker run` is allowed only where your task says so.
- No tracker (Jira) calls, no network downloads.

## Package recipes (`_docs/AGENT_GOTCHAS.md` has the details)

- C#: `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` (without the variable it hangs forever).
- Go: only in `golang:1.27`: `docker run --rm -v "$PWD":/src -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -w /src/go golang:1.27 sh -c 'gofmt -l . && go vet ./... && go test -race -count=1 ./...'`.
- Swift: local `swift test` needs the `-Xswiftc -F ... -Xlinker -rpath ...` flags of AGENT_GOTCHAS; one `swift build`/`swift test` at a time.
- Python: needs Python 3.10 or newer: put a directory holding `python3 -> /opt/homebrew/bin/python3.14` first on `PATH`; use a venv.
- Rust: `cargo test` in `rust/`.
- TypeScript: the package's `npm test` and the strict `tsc --noEmit` recipe of AGENT_GOTCHAS.
- Java: `java/test.sh`.
- C++: the host `make -C cpp test` and the container `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` (run `make -C cpp clean` before switching between them); `-Wall -Wextra -Werror`; no heap, no exceptions.
- The commands CI runs for your package are in `.github/workflows/run-suite.sh <package>`; run the same typecheck and unit commands.

## Report (at the end, 40 lines at most)

1. Files created and changed (paths), with the line count of the codec files.
2. Per AC of your task: PASS or what is missing, with the test name.
3. The exact test commands you ran and their last result line (counts of passed, failed, skipped).
4. Failing tests that are expected (see above) by id, and any other failure.
5. Measured speed of the 100,000-round-trip loop (seconds).
6. Anything in the contract, reference or vectors that was ambiguous or wrong, and any behavior you had to decide.
7. `git status --short` of your package directory and the line `git diff --cached` empty: yes/no.

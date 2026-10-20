# Worker rules — text and ECC test waves (loop 46)

Read this file first. It applies to every worker of loop 46 (tasks AZ-2735, AZ-2736, AZ-2737, AZ-2739). The parent (the conversation that spawned you) owns tracker, git, review, documents, shared fixtures and the step 11 run.

## What you build

Tests, not features. Each package already packs and unpacks the compact text format and the message error correction; your job adds the tests named in your task specs under `_docs/02_tasks/todo/` (read them first: AC list, scope, excluded). The behavior is frozen:

- Contract: `_docs/02_document/contracts/library/compact-text.md`. Reference code: `scripts/text/textfmt.py` (`python3 scripts/text/textfmt.py enc "text"` gives the bytes; `dec <hex>` the text). Vectors: `fixtures/text/vectors.txt`. Hostile seeds: `fixtures/hostile/fuzz/corpus.txt`. ECC reference: `scripts/ecc/eccfmt.py`.
- Mirror an existing test of your own package: the loaders of `vectors.txt` and the hostile corpus, the text test files (`TextPositionsTest`, `CompactTextTests*`, `text_positions_tests.rs`, `go/text_positions_test.go`, `python/tests/test_compact_text.py`, `swift` text tests) and, for the speed case, the Python/TypeScript HD-2 test (65,535 characters, 200 rounds, 1 s).
- Each test has `Arrange` / `Act` / `Assert` comments in the language's comment style, a descriptive name, and the ids of the task AC in a comment. A fixed seed for every random generator. No sleeps and no fixed delay: start concurrent workers together with a barrier or latch and join with a time limit.
- A wall-clock check uses the package's load-aware helper, never a fixed bound: Python `tests/timing_support.py` (`bound`, `assert_within`), C# `tests/Timing.cs` (`Timing.Bound`), Java `Timing.java` (`Timing.bound`), Rust `src/timing_support.rs` (`load_factor`, `assert_within`), Go `timing_test.go` (`loadFactor`, `assertWithin`), Swift `LoadFactor.swift` (`bound`, `expectWithin`), C++ `tests/core/load_factor.hpp` (`load_factor::bound`, `expect_within`).
- Every new file ≤ 500 lines. Register a new test where the package's runner finds it (Rust `lib.rs` module line, Java runner list, C++ Makefile only if it does not glob).
- A new test that fails is a finding, not a reason to weaken it. Stop on that test, report the failing input and the numbers. Only AZ-2737 allows a production change: if the repeated-text test of Java, C# or Rust misses its bound, you may fix that package's pack walker so the repeated text is not encoded again each round, with every `enc` row byte unchanged and the whole package suite green, and you say so first in the report. C++ production code (`cpp/src`, `cpp/include`, `cpp/embedded`) is never touched: report a C++ miss.

## You own / you must not touch

- You own only the paths in your prompt. Forbidden: every other path, including `fixtures/`, `scripts/`, `.github/` (except the CI worker), `README.md`, `_docs/`, other packages, root manifests, and every `src` directory except where your prompt allows it.
- If you need a change in a forbidden place (a wrong vector, a missing helper), stop that line of work and describe it in the report.

## Shell hygiene (every command)

- Stdin from `/dev/null` on every command that could read it; no bare `cat`, `read` or unfinished here-doc; nothing interactive.
- A time limit on anything that can hang: `perl -e 'alarm 900; exec @ARGV' -- command ...` (macOS has no `timeout`).
- No leftover background processes: start none, or kill what you started. One build or test run at a time (the host is shared: other sessions run, swap is nearly full). Print a status line every 30 seconds of a run longer than a minute.
- Python only in a virtual environment; never `pip install` globally.
- Forbidden git commands: `add`, `rm`, `mv`, `restore`, `stash`, `checkout`, `reset`, `clean`, `commit`, `push`. Read-only git (`status`, `diff`, `log`) is fine. Check `git diff --cached` is empty at the end.
- No formatter or linter that writes to files you do not own (`cargo fmt` is not to be run). Format your own new code by hand.
- No Docker compose. A single `docker run` only where the recipe below says so. No tracker (Jira) calls, no network downloads.

## Package recipes (`_docs/AGENT_GOTCHAS.md` has the details)

- C#: `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` (without the variable it hangs forever); use `--filter` for your focused run, then once the whole package.
- Go: only in `golang:1.27`: `docker run --rm -v "$PWD":/src -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -w /src/go golang:1.27 sh -c 'gofmt -l . && go vet ./... && go test -race -count=1 ./...'`.
- Swift: local `swift test` needs the flags `-Xswiftc -F -Xswiftc $F -Xlinker -rpath -Xlinker $F -Xlinker -rpath -Xlinker $L` with `F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks` and `L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib`; one `swift build`/`swift test` at a time; swift-testing, not XCTest.
- Python: needs Python 3.10 or newer: put a directory holding `python3 -> /opt/homebrew/bin/python3.14` first on `PATH`; use a venv.
- Rust: `cargo test` in `rust/`.
- Java: `java/test.sh`.
- C++: the host `make -C cpp test` and the container `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` (about 15 s; run `make -C cpp clean` before switching between them and after editing `load_factor.hpp`); `-Wall -Wextra -Werror`; no heap, no exceptions in the core.
- The commands CI runs for a package are in `.github/workflows/run-suite.sh <package>`; run the same typecheck and unit commands.

## Report (at the end, 40 lines at most)

1. Files created and changed (paths) with line counts.
2. Per AC of each of your tasks: PASS or what is missing, with the test name.
3. The exact test commands you ran and their last result line (passed, failed, skipped).
4. Measured time of each new test (seconds, idle-equivalent if you can say) and the suite time added.
5. Any failing test with the input and the numbers, and any production defect or ambiguity found.
6. `git status --short` of your owned paths and the line `git diff --cached` empty: yes/no.

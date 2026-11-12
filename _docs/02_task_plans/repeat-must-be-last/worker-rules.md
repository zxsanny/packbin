# Worker rules: a repeat must be last (loop 113)

Read this file first. It applies to every worker of loop 113 (tasks AZ-4210 to AZ-4219, epic AZ-4209). The parent (the conversation that spawned you) owns the tracker, git, the review, `_docs/`, the batch report and the total test run.

## What you build

One rule, in your package only: a scheme is refused when it is built if a `repeat` is not the last thing its packet reads. The rule, its nine refused cases (R1 to R9), its five cases that keep building (K1 to K5) and the refusal texts are the contract `_docs/02_document/contracts/library/repeat-last.md`. The contract decides; your task spec (`_docs/02_tasks/todo/AZ-42xx_*.md`) says how the rule looks in your package and which commands prove it. Read both, then `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md` (what your package does today), the new sections of `fixtures/hostile/README.md`, `scripts/probes/repeat-followed-by-field/README.md`, and the lines of `_docs/AGENT_GOTCHAS.md` that name your package.

Order of work:

1. Before any change: build, pack and unpack K1 to K5 (the ones your package can write) on the unchanged code and note the packets. A packet that differs from the contract is reported first, not fixed.
2. Add the check beside the package's empty-round-body rule (where the scheme is built; `feature-description.md` in this folder names the file). It is one walk of the scheme at build. Nothing is added to pack or unpack. No new public name, no new error kind, no new dependency, no new source file unless the existing one would pass 500 lines.
3. Run the whole package suite with the check in place. List every scheme of the package's own tests, examples and docs that stops building (file and count). Rewrite each with `times`, or turn it into a test of the refusal. Never narrow the check to keep a test.
4. The hostile loader: add a hand-written scheme for each new case id of `fixtures/hostile/cases.txt`. A case your package cannot write is named as skipped with its reason in the test output, never silently.
5. The tests of your spec's AC list. Each refusal test compares the whole text (or the status and the field id). Each test has `Arrange` / `Act` / `Assert` comments and the AC id in a comment.
6. Prove each new refusal test once against the old behaviour: switch the new check off in your working copy (one line, by hand), run the new tests, see them fail, switch it back on. Say in the report that you did. No `git stash`, no `git checkout`.
7. `bash scripts/probes/repeat-followed-by-field/run.sh <package>`: the build column and the `control` line as your spec's probe AC says.
8. The whole package suite the way CI runs it (`.github/workflows/run-suite.sh <package>` names the commands), once, at the end.

The refusal texts, word for word (`<anchor>` and `<field>` in the words your package's other scheme errors use for a field):

- Followed: `repeat <anchor>: <field> follows it; a repeat reads to the end of the packet, so nothing can follow it; use times`
- Inside an element: `repeat <anchor> is inside a list or dict element; a repeat reads to the end of the packet, so another element cannot follow it; use times`
- Inside a round (Java and C++ only; the other seven keep their nesting rule and its text): `repeat <anchor> is inside a repeat or times round; a repeat reads to the end of the packet, so another round cannot follow it; use times`

A field "can write a byte" by the table of the contract (a `bool` and a zero-width `bytes` do not; a `when`, group, nested row or flag bit counts when it holds something that counts). The check is on the scheme, never on a row.

## You own / you must not touch

- You own only the paths in your prompt: your package directory and `scripts/probes/repeat-followed-by-field/<package>/`.
- Forbidden: every other path. That includes the root `README.md`, `fixtures/`, `_docs/`, `.github/`, other packages, other probe folders, root manifests and lock files.
- If the work needs a change in a forbidden place (a wrong case, a ring driver scheme the rule refuses, a core source list), stop that line of work and describe the change in the report. The parent makes it.

## Shell hygiene (every command)

- Stdin from `/dev/null` on every command that could read it; no bare `cat`, `read` or unfinished here-doc; nothing interactive.
- A time limit on anything that can hang: `perl -e 'alarm 900; exec @ARGV' -- command ...` (macOS has no `timeout`). A limit goes first, never after `env VAR=1`.
- No leftover background processes. One build or test run at a time: the host is shared with three other workers and swap is nearly full. Print a status line every 30 seconds of a run longer than a minute.
- Forbidden git commands: `add`, `rm`, `mv`, `restore`, `stash`, `checkout`, `reset`, `clean`, `commit`, `push`, `worktree`. Read-only git (`status`, `diff`, `log`, `show`) is fine. `git diff --cached` must be empty at the end.
- No formatter or linter that writes to files you do not own (never `cargo fmt` on the crate; `rustfmt` on single files of yours, then `git diff` shows only your files). On macOS `sed -i -e` leaves `file-e` copies: use the Edit tool.
- Python only in a virtual environment; never `pip install` globally.
- No tracker (Jira) calls. No network downloads beyond what the package's own test command does.
- Write temporary files under the directory your prompt names, never in the repository.

## Package recipes

- TypeScript: `cd typescript && node --test tests/*.ts`; strict check from the repo root: `typescript/node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions typescript/src/index.ts`.
- C#: always `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` (without the variable it hangs forever at 646 of 649). Count theory cases from the run, not by hand. A test input the framework cannot carry is built in the test body.
- Python: needs Python 3.10 or newer (`/opt/homebrew/bin/python3.13`), in a venv; `pytest -v --tb=short`, never `-q`.
- Java: `java/test.sh`.
- Go: not installed on this Mac. `docker run --rm -v "$PWD":/src -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -w /src/go golang:1.27 sh -c 'gofmt -l . && go vet ./... && go test -race -count=1 ./...'` (about 30 s).
- Swift: plain `swift test` from the repo root (Xcode 6.4 is selected). One `swift build` / `swift test` at a time. A test hook is `package`, never `@testable` or `@_spi`. The README snippet test reads the root `README.md`.
- Dart: `cd dart && dart analyze && dart format --output=none --set-exit-if-changed . && dart test`.
- Rust: host runs with `RUSTUP_TOOLCHAIN=1.98`; the CI matrix is `docker compose -f docker-compose.test.yml run --rm rust </dev/null`; the device row is `rust/embedded/run.sh libs` then `docker compose -f docker-compose.test.yml run --rm rust-embedded </dev/null`. In `rust/src/nostd` no `split_at_mut`, `rotate_left`, `copy_within`, `reverse`, `copy_from_slice`, `chunks*`. No new variant on a public enum. A new test file in `rust/tests/` that uses the std API carries `#![cfg(feature = "std")]`.
- C++: host `make -C cpp test` (Apple clang) and `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` (GCC 16, `-Wall -Wextra -Werror`); `make -C cpp clean` between the two, inside the container when a container run follows at once. `make -C cpp no-text-test no-ecc-test`. Device rows: `docker compose -f docker-compose.test.yml run --rm cpp-embedded </dev/null`. The core takes standard names only from `packbin/platform.hpp`. No heap, no exceptions in the core.
- These compose runs are allowed for the Rust and C++ workers only (the parent holds the runtime lock for the loop).

## Stop and report instead of deciding

- A device pin (flash or stack) that grows by more than 256 B of flash or 64 B of stack: stop, report the figures before and after. A smaller move: set the pin to the measured figure and report what the bytes bought (the parent writes the gotcha line).
- A K1 to K5 packet that differs, a refused case your package cannot write that the spec does not name, a scheme in a ring driver or a shared fixture that the rule refuses.
- The same file changed three times without a green run.

## Report (at the end, 50 lines at most)

1. Files created and changed (paths, line counts).
2. Per AC of your task: PASS or what is missing, with the test name.
3. The exact commands you ran and their last result line (passed, failed, skipped), the whole-suite count before and after.
4. The schemes of the package's own tests, examples and docs that the rule refused: file, count, what each became.
5. K1 to K5 packets on the unchanged code; the probe lines after the change.
6. Device figures before and after (Rust, C++), pins moved.
7. Discoveries: any case, collision or question the spec and the contract did not cover, with what the code does now, each marked clear or unclear.
8. `git status --short` of your owned paths; `git diff --cached` empty: yes or no.

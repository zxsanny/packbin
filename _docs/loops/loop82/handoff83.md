# Handoff to loop 83

From the loop 82 record (`record82.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 82

AZ-3381 to AZ-3386 (28 points, In Testing): no CI script uses Ruby.
- `scripts/ci/yaml_get.py` is the one YAML reader (`safe_load`; no PyYAML, no file and malformed YAML each exit 2 naming the cause). `pyyaml==6.0.3` is in `.github/workflows/tool-pins.txt`; `scaffold` and `publish-gate-rest` install it after `setup-python`.
- `publish-precheck.sh` (release path) reads the runs JSON with the standard library; its 11 mutants and 13 scenarios are kept.
- `publish-workflow.test.sh`, `publish-jobs.test.sh`, `ring-wiring.test.sh`, `ring-wiring-swift.test.sh`, `publish-pins.test.sh` and the three one-liner scripts run on the reader; the `if:` evaluator is a parser without `eval`; `publish-jobs` keeps 115 refusals.
- `publish-pins.test.sh` also fails on any `ruby` in the CI scripts and on a job that reads the CI YAML without the PyYAML install.

## First actions of loop 83

0. CI of the loop 82 push (`dev`, then `main`): `gh run list --repo zxsanny/packbin --branch dev`. Read any red job's log with `gh api` before calling it a flake. The six scripts that never ran on the loop 81 host (`report-row`, `run-suite`, `ring-wiring`, `ring-wiring-swift`, `publish-workflow`, `publish-pins`) must be PASS in the `scaffold` and `publish-gate-rest` logs, and `ring` is the first run on the pinned toolchains Node 24, GCC 16, Rust 1.98. Put the result into the first commit of loop 83; do not push a record-only commit.
1. `uptime` and `ps -Ao pcpu,command --sort=-pcpu | head`. A total run is not a result above load 60 from a foreign job.
2. This Linux host: `ruby` is no longer needed. The JDK is a user-directory tarball (`~/.local/share/packbin-jdk26/bin`), not on PATH by default: the ring stage needs it on PATH.

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows; a public-key pairing step.
- Multi-part MAC rows in the ring (G8m of loop 77) were owner-declined then; they need an opt-in like U1 had.

## Candidates (not specs yet; probe each on HEAD first, LESSONS loop 76)

- Splitting `handoff.cpp` (639 lines, over the 500-line cap).
- One shared module for the helpers the two ring-wiring checkers duplicate (about 50 lines), next to `scripts/ci/yaml_get.py`.
- Folding the Python version of the two `setup-python` steps and `RING_PYTHON` into one place.
- A ring row that combines a wrong-length key or id with a second refusal, to pin which error comes first in the 8 drivers.
- The AVR runtime check of the C++ `chacha20_xor` count-down loop on a 16-bit `size_t` (needs an emulator; complexity check first).
- Refresh the stage stamps on the owner's Mac (one clean run; this Linux clone has none).
- Unchanged from `handoff75.md`: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

- **L82-1**: the six scripts above ran for the first time in CI after this push; the Python checkers were proven on this host by label inventory and deliberate mutations, not against the Ruby originals (no Ruby here).
- **L82-2**: the `if:` evaluator is stricter than the old `eval` (a lone `&`, `|`, `=`, `()` and chained `==` are refused); no workflow uses them.
- **L82-3**: PyYAML is a new pinned dependency of two CI jobs, without a hash lock (as the other pip tools).
- **L81-2, L80-1, L80-2, L78-2, L79-1, L79-2, L76-1, L75-1, L74-2, L73-1, L72-1, L71-1, L71-2** (unchanged): see `handoff82.md`, `handoff81.md`, `handoff80.md`, `handoff76.md` and `handoff75.md`.

# Handoff to loop 82

From the loop 81 record (`record81.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 81

AZ-3378 (3 points, In Testing):
- `fixtures/frame/ring-cases.txt`: 15 refuse rows (a key of 0, 31, 33 bytes in seal, open, mac; a `msg_id` of 0, 7, 9 bytes in seal, open). The real ring: `64 pairs, mismatched: 0`, `refusals <lang>: 58 rows, 0 mismatched` x 8 (43 before).
- `scripts/frame/ring_frame.py` writes `-` for an empty key or `msg_id`; the Rust (key, `msg_id`) and C++ (`msg_id`) drivers print `BadValue` themselves (owner, as for directions 0 and 4); `fixtures/frame/README.md` says so.
- `ring-frame-drivers.test.sh`: 276 checks (132 before); `ring-frame.test.sh`: 37 PASS (34 before).

## Owner decision: loop 82 is the Ruby-to-Python port of the CI scripts

Ruby is not the test runner (that is bash). It is the YAML and JSON reader inside 10 scripts of `.github/workflows/`. A host without Ruby cannot run four `scaffold` scripts and two checks of the publish gate; loop 81 ran on such a host and the owner waived those six (see `record81.md`).

Measured on HEAD ed7d144:

| script | role | embedded Ruby |
|---|---|---|
| `publish-jobs.test.sh` | job layout of `test.yml`; its mutation tests are Ruby expressions over the workflow hash | 197 lines heredoc |
| `publish-workflow.test.sh` | translates GitHub `if:` expressions to Ruby and `eval`s them | 128 lines |
| `ring-wiring.test.sh` | ring job wiring against `test.yml` and the compose file | 117 lines |
| `ring-wiring-swift.test.sh` | same for the Swift ring | 68 lines |
| `publish-pins.test.sh` | pins in the workflow | 39 lines |
| `publish-precheck.test.sh` | builds JSON runs for the precheck | 6 lines |
| `publish-precheck.sh` | **release path** (`publish.yml` line 32): reads the runs API JSON | 1 call, a 17-line lookup (JSON only: Python's stdlib is enough) |
| `report-row.test.sh`, `run-suite.test.sh`, `run-suite-swift.test.sh` | one `ruby -ryaml -e` each | 1 line each |

About 555 lines of embedded Ruby plus 5 one-liners. Estimate 8 points: `/problem` Phase 1, `/new-task` (hands off to `/decompose --feature`), several tasks.

Points the design must settle:
- **PyYAML is not in Python's standard library.** The repo has no PyYAML use today and `test.yml` has no `pip install` (the ring job has `setup-python` only). A port needs `pyyaml==<pin>` in `tool-pins.txt` (the file says it holds every tool the scripts install), an install step in the CI jobs that run the ported scripts, and a line in the setup docs. PyYAML 6.0.3 is already installed for the system `python3` on the Linux dev host.
- **One shared helper** (for example `scripts/ci/yaml_get.py`, run with `python3 -I`) against ten copies of the loading code.
- **`publish-workflow.test.sh`:** the `if:` evaluator needs a Python equivalent with the same refusals (unsupported term, does not evaluate); no bare `eval` on workflow text without the same character filter.
- **`publish-jobs.test.sh`:** the `mutant "<label>" '<ruby expression>'` calls become Python edits of the loaded dict; each mutant keeps its expected refusal.
- **`publish-precheck.sh`:** a change on the release path; its test must still hold the good and bad runs.
- **YAML 1.1 quirk:** `on:` loads as the key `True` in PyYAML as in Ruby's Psych; the existing code reads `w["on"] || w[true]`.
- **No stand-in:** each ported script keeps all its checks; a port that drops one is a failure. Proof: every ported script green, and each fails on a deliberate mutation.

## First actions of loop 82

0. CI of the loop 81 push (`dev`, then `main`): `gh run list --repo zxsanny/packbin --branch dev`. Read any red job's log with `gh api` before calling it a flake. Three jobs matter most: `ring` (the first run on the pinned toolchains Node 24, GCC 16, Rust 1.98; loop 81 ran Node 22, C++ in `gcc:16`, Rust 1.99.1 and 1.97.0), and `scaffold` and `publish-gate-rest` (they run the six Ruby scripts that did not run on the loop 81 host). Put the result into the first commit of loop 82; do not push a record-only commit.
1. `uptime` and `ps -Ao pcpu,command --sort=-pcpu | head`. A total run is not a result above load 60 from a foreign job.
2. This Linux host: the JDK is a user-directory tarball and `ruby` is absent. Either `sudo apt install openjdk-26-jdk-headless ruby` (the documented path) before the loop, or the port itself removes the Ruby need; say which in the first message.

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows (needs a Windows build and test first); a public-key pairing step.
- Multi-part MAC rows in the ring (G8m of loop 77) were owner-declined then; they need an opt-in like U1 had.

## Candidates (not specs yet; probe each on HEAD first, LESSONS loop 76)

- Splitting `handoff.cpp` (639 lines, over the 500-line cap before loop 81).
- A ring row that combines a wrong-length key or id with a second refusal, to pin which error comes first in the 8 drivers.
- The AVR runtime check of the C++ `chacha20_xor` count-down loop on a 16-bit `size_t` (needs an emulator; complexity check first).
- Refresh the stage stamps on the owner's Mac (one clean run; this Linux clone has none).
- Unchanged from `handoff75.md`: a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part.

## Risks

- **L81-1**: six Ruby scripts (`report-row`, `run-suite`, `ring-wiring`, `ring-wiring-swift`, `publish-workflow`, `publish-pins`) were not run before the push; none reads a file loop 81 changed. CI is their first run.
- **L81-2**: the toolchains of loop 81 differ from CI's pins (Node 22 against 24, GCC 15 and `gcc:16` for the C++ driver, Rust 1.99.1 and 1.97 against 1.98).
- **L80-1, L80-2, L78-2, L79-1, L79-2, L76-1, L75-1, L74-2, L73-1, L72-1, L71-1, L71-2** (unchanged): see `handoff81.md`, `handoff80.md`, `handoff76.md` and `handoff75.md`.

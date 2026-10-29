# Security lite — loop 81

Diff: `489d291..ed7d144` without `_docs/` (7 files, +107/-27): the Rust ring driver `handoff-rust/src/frame.rs`, the C++ ring driver `handoff.cpp` (frame functions), `scripts/frame/ring_frame.py` (`hx()` for key and msg_id), `fixtures/frame/ring-cases.txt` (15 rows) and `README.md`, and the two self-tests `ring-frame.test.sh` and `ring-frame-drivers.test.sh`.

| Trigger | Hit | Note |
|---|---|---|
| T1 sensitive path | yes | `.github/workflows/`: two test scripts and the two ring drivers; `test.yml` unchanged; no `uses:`, `permissions:`, secret or env added |
| T2 sensitive content | no | a regex for password, secret, token, api key, curl, wget, eval, exec, sudo, URLs, chmod and `rm -rf` finds nothing on the 107 added lines |
| T3 size | no | 7 files, 107 added lines, 3 points |
| T4 dependencies | no | no manifest or lockfile changed (`handoff-rust` builds with the same `Cargo.lock`) |
| T5 carried finding | no | `security_report.md` names none of the files |
| T6 stale audit | no | not a ship loop, 3 points |
| T7 lite concern | no | see checks |

Verdict: ESCALATE by T1, answered with a diff-scoped pass below (as in loops 78 to 80: CI test scripts and test-infrastructure drivers, no product code path changed).

Checks on the changed lines:
- Input validation: both drivers get stricter, not looser. The Rust driver no longer zero-pads a short `msg_id` and no longer aborts on a key of the wrong length; it answers `BadValue` for both. The C++ driver no longer pads or cuts the id (HEAD opened a frame sealed under another id when the new id was a 9-byte extension of it); it answers `BadValue`. A malformed number or hex token is still a malformed line (the numbers and tokens are parsed before the key and id are checked).
- Injection / process args: the new shell cases build driver lines with `printf` from constants of the script (`key`, `id`, `ad`, `plain`, `body`) and a `case` over a literal size list; nothing from the environment or the repository's data reaches a command line. The two stand-in lies are literals over the fake driver.
- Secrets and logs: the keys in the rows are test vectors already in `ring-cases.txt`; the empty key is `-`. No network call, token or credential is added; `ring_frame.py` prints nothing new.
- Error handling: Rust uses `let ... else` returning the typed answer; C++ returns the answer string the checker already reads; neither swallows an error. The self-test additions fail the script (`failures`) when a check is red.
- Blast radius: `frame.rs` and `handoff.cpp` are read by the CI `ring` job and, for the shared crate and source file, by `language-pair.sh`; only `frame.rs` functions and `frame_seal` / `frame_open` changed, so no pack or unpack command moves. The C++ driver was built in `gcc:16` with `-std=c++17 -O2 -Wall -Wextra -Werror` and the Rust crate on 1.99.1 and 1.97.0 without a warning.
- Out of the diff, for the record: a Temurin JDK 26.0.2.1 tarball was unpacked under `~/.local/share/packbin-jdk26` on the owner's choice (its SHA-256 matched the value the Adoptium API returned for the file), and `npm ci` ran in `typescript/` from the committed lockfile. Neither is part of the repository.

Findings: 0 Critical, 0 High, 0 Medium, 0 Low new.

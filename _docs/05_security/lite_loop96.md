# Security lite — loop 96

Diff: `98d2202..HEAD` without `_docs/` (13 files, +256/-54): the eight ring drivers' `mac` / `verify` functions (`handoff_frame.py`, `handoff-frame.ts`, `HandoffFrame.java`, `csharp/HandoffFrame.cs`, `handoff-go/frame.go`, `handoff-rust/src/frame.rs`, `handoff_frame.cpp`, `handoff-swift/.../Frame.swift`), `scripts/frame/ring_frame.py`, `fixtures/frame/ring-cases.txt` and `README.md`, and the two ring test scripts.

| Trigger | Hit | Note |
|---|---|---|
| T1 sensitive path | yes | `.github/workflows/`: two test scripts and eight test-infrastructure drivers; `test.yml` unchanged; no `uses:`, `permissions:`, secret or env added |
| T2 sensitive content | no | the regex (password, secret, api key, curl, wget, eval, exec, sudo, URLs, chmod, `rm -rf`) finds nothing on the added lines; `token` matches only the parameter name of the new piece readers |
| T3 size | no | 13 files, 256 added lines, 5 points |
| T4 dependencies | no | no manifest or lockfile changed |
| T5 carried finding | no | `security_report.md` names none of the files |
| T6 stale audit | no | not a ship loop |
| T7 lite concern | no | see checks |

Verdict: ESCALATE by T1, answered with a diff-scoped pass below (as in loops 78 to 81: CI test scripts and test-infrastructure drivers, no product code path changed).

Checks on the changed lines:
- Input validation: the drivers get stricter, not looser. Every piece of a message must be hex or `-`; an empty piece (`ab||cd`, `|ab`, `ab|`) is a malformed line in all eight, where an empty hex string was accepted as zero bytes before. A bad piece ends the batch with a message naming the line (exit non-zero), no result for it.
- Injection / process args: the new shell cases build driver lines with `printf` from literals of the script (`key22`, `e4a`, `e4b`) and write them to temp files; nothing from the environment or the repository's data reaches a command line. The two stand-in liars are literals of the self-test.
- Secrets and logs: the keys in the new rows are test vectors already in `ring-cases.txt`; no network call, token or credential is added; `ring_frame.py` prints nothing new except the row-named file error.
- Error handling: each driver throws or returns its existing malformed-line error; none swallows one. Rust and Swift return a typed error from the piece reader; Go keeps the first error in the existing `frameFields` field.
- Blast radius: only `mac` and `verify` and their helpers changed in the drivers; `seal` and `open` lines are untouched. The Go driver mutation proof was restored and compared with a copy before the next run.
- Out of the diff, for the record: the owner's `sudo chown -R` of the root-owned build folders (build output left by container runs; owner's command, 2026-10-31).

Findings: 0 Critical, 0 High, 0 Medium, 0 Low new.

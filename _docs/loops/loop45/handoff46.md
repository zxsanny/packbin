# Handoff to loop 46

From the loop 45 feature assessment (`_docs/loops/loop45/assessment45.md`, round 1, verdict CLARIFY). The owner answered on 2026-10-20: all six recommended answers, and "small items now, tests next loop". The small items are AZ-2733 (loop 45). What is left is below, as non-overlapping waves of disjoint directories.

## Wave 1: tests and criteria (disjoint per package)

| Row | Work | Owns |
|-----|------|------|
| CS-S3 | A concurrency test in the text test set: N threads pack and unpack different texts at once, every result equals the reference bytes. Packages: C#, Java, Rust, Go, Swift (Python, TypeScript and C++ have interleaved or caller-scratch tests only). | `csharp/tests`, `java/src/test`, `rust/src`, `go/`, `swift/Tests` |
| CS-A5, CS-A10 | Change CS-5 and CS-10 in `_docs/02_task_plans/compact-strings/acceptance_criteria.md` to 3,000 random strings and 30,000 hostile payloads per package, and add the missing tests to Python, C# and Swift (they run none today). Today: TypeScript 4,000 / 30,000, Java 20,000 / 60,000, Rust 3,000 / 30,000, Go 3,000 / 20,000, C++ 20,000 / 100,000. | `python/tests`, `csharp/tests`, `swift/Tests`, the criteria file |
| CS-D7 | One 1 s test of a 65,535-character text repeated in 200 rounds in Java, C#, Rust and C++. Fix the walker only if a test fails. | `java/src/test`, `csharp/tests`, `rust/src`, `cpp/tests` |
| EC-D2 | One protected session payload (n = 4) in the session cross-language check: `.github/workflows/language-pair.sh` and the eight session drivers, both directions as for the unprotected one. | `.github/workflows/`, the driver directories |

## Small leftovers found in loop 45 (docs, no wave needed)

- `_docs/02_document/tests/blackbox-tests-02-strings-lists-dicts.md` FT-D-01 to FT-D-04 and FT-H-02 still hold old-format hex (the 103-byte user value, `000000000000`, the 58-byte nested value); AZ-2733 AC-4 named only FT-U-01 and FT-U-02.
- `_docs/02_document/tests/traceability-matrix.md` is 504 lines after the 29 new rows (soft cap 500); move rows to a side file as in loop 26.
- `_docs/02_task_plans/compact-strings/size_report.md` has a hand-written header (date, sha256 of the recipe files): a rerun of `scripts/text/size_report.py` on that path drops it; the script should write the header.

## Open, waiting on the owner

- CS-D5: retrain the compact-string tables on the owner's 100 to 200 real messages before the first `v*` tag (a wire break; free until the tag).
- The first `v*` and `go/v*` tags and F44 stay owner-run.

## Due

- The retrospective (5 loops since loop 41) is due after loop 45.
- Jira: epics AZ-2645 and AZ-2059 are still To Do although every child is Done (AZ-2677 is Done).

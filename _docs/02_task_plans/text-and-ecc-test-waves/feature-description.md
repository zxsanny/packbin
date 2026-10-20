# Feature description — text and ECC test waves

**Slug**: text-and-ecc-test-waves · **Loop**: 46 · **Points**: 15 (five tasks, eight packages and one CI script) → `/decompose --feature`.

## Description

Close the test gaps of the compact string format and the message error correction that the loop 45 feature assessment found and the owner decided on 2026-10-20 ("small items now, tests next loop"): a concurrency test of the text codec (C#, Java, Rust, Go, Swift), the criteria change to 3,000 random strings and 30,000 hostile payloads per package with the missing tests (Python, C#, Swift, and Go's payload count), a 1 s test of a 65,535-character text repeated in 200 rounds (Java, C#, Rust, C++), one protected session payload in the session cross-language check (eight drivers and `language-pair.sh`), and three documentation leftovers. Production code changes only if a new test fails (CS-D7).

Inputs: `problem.md`, `acceptance_criteria.md` (TW-1 to TW-10), `_docs/loops/loop45/assessment45.md` and `handoff46.md`, `compact-strings/acceptance_criteria.md` (CS-5, CS-10), `_docs/AGENT_GOTCHAS.md` (load-aware timing helpers, per-language test recipes).

## Fit (Part A, today → after)

| Area | Today | After | Who depends on today | Collision |
|------|-------|-------|----------------------|-----------|
| Text test sets, 8 packages | random strings: ts 4,000, java 20,000, rust 3,000, go 3,000, cpp 20,000; none in py, cs, swift. Hostile payloads: ts 30,000, java 60,000, rust 30,000, go 20,000, cpp 100,000; none in py, cs, swift | every package ≥ 3,000 strings and ≥ 30,000 payloads; a concurrency test in cs, java, rust, go, swift; a repeated-text test in java, cs, rust, cpp | `run-suite.sh`, `loop-tests.sh`, CI wall time | each suite grows by seconds; the Python suite most (30,000 payloads in pure Python) |
| Session cross-language check | `pack-session` / `unpack-session` of one unprotected payload; 8 packs plus 22 pairs | the same for one protected payload | `ring-wiring.test.sh` reads the exact lines of `language-pair.sh` | the wiring self-test edits those lines; update it with the new rows |
| Criteria CS-5 and CS-10 | 100,000 each | 3,000 and 30,000 per package in the suites; 100,000 stays as a manual probe | the assessment, `traceability-matrix.md` | none |
| Test-spec documents | five cases hold old-format hex; matrix 504 lines; size report header by hand | compact hex; matrix ≤ 500 lines; header written by the script | readers | none |

No problem card: nothing collides with today's behavior; all rows add tests or text.

## Scenarios

| id | scenario | status | behavior (confirmed) | AC ref |
|----|----------|--------|----------------------|--------|
| TS1 | Eight workers pack and unpack different texts at once with one scheme (S3) | confirmed | each result equals the reference bytes or its own input; 0 mismatches | TW-1 |
| TS2 | A package runs the suite on a loaded host | confirmed | wall-clock checks scale with the package's load factor (`AGENT_GOTCHAS.md`) | TW-1, TW-5 |
| TS3 | A package has no random or hostile text test today (Python, C#, Swift) | confirmed | it gains both at 3,000 / 30,000; Go's 20,000 rises to 30,000 | TW-2, TW-3 |
| TS4 | A decoder change needs the large run | confirmed | the 100,000 run stays a manual probe under `fixtures/hostile/fuzz/` and is named in the criteria | TW-4 |
| TS5 | The same large text in 200 rounds in Java, C#, Rust, C++ | confirmed | finishes in 1 s nominal; a failing package is fixed in the walker, bytes unchanged. Result: Java fixed in `ByteSink`; C++ 3 s nominal, AZ-2742 for the shortcut (owner 2026-10-20) | TW-5 |
| TS6 | A protected session payload crosses languages | confirmed | all eight write the same bytes, equal to the reference codec; all existing session pairs read it | TW-6 |
| TS7 | A driver of one language is missing a protected session command | confirmed | the ring fails, naming the language | TW-6 |
| TS8 | The Pico/AVR/Cortex-M4F builds | out-of-scope | no file under `cpp/src`, `cpp/include`, `cpp/embedded` changes | TW-10 |
| TS9 | Retrain the tables on real messages (CS-D5), first tags, F44 | out-of-scope | owner-run | — |
| TS10 | Concurrent use of one protected session from two threads (not walked in loop 45) | out-of-scope | not part of the handoff | — |
| TS11 | A run of the new tests in a package with the slowest CI group | confirmed | no new CI job; the added time is read from the CI annotations after the push | TW-6 |

## Fit decisions

None: no problem card.

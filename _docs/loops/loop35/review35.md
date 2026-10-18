# Loop 35 total review

Range `a93d5f6~1..HEAD` (267 files, 18,310 insertions), `code-review` at `high`, 2026-10-18. 9 findings: 2 fixed in `acc965b`, 7 carried to the loop 36 handoff.

| # | Severity | Finding | Outcome |
|---|----------|---------|---------|
| 1 | Medium | Contract and AZ-2655 spec said the C++ scratch is 32 B per character; the built `Scratch` is 12 B per code point | fixed |
| 2 | Low | `Scratch<65535>` is a 786 KB object with no guard against a local declaration | carried |
| 3 | Medium | Five packages each added their own memo for a lone string repeated under `times`/`repeat` (Python and TypeScript hold process-wide state); the root cause is the walker encoding the same value once per round | carried |
| 4 | Medium | The 1 s speed bound (CS-11) is asserted only in release for Rust and Swift, and CI runs debug | carried |
| 5 | Low | `csharp/tests/CompactTextTests.cs` is 620 lines (cap 500) | carried |
| 6 | Low | `research/bench.py` is 688 lines and duplicates the parse of `textfmt.py` | carried |
| 7 | Low | AZ-2656 worker rewrote `put_number`/`get_number` and re-aligned `Field::eq` to save 196 B of flash (unrequested) | carried |
| 8 | Low | Every compact-text refusal except a cut buffer is reported in the short-packet shape with needed 0; the contract's refusal kinds are not exposed | carried |
| 9 | Low | Dead locals in `gen_vectors.py` | fixed |

Differential evidence beyond the review: every package passes the 418-row vectors file; the reference and each package agreed on 12,000 to 45,000 random texts and 40,000 to 200,000 random or damaged payloads (reports of the workers).

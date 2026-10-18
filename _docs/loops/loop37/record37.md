# Autodev loop record — loop 37

loop: 37
branch: dev
plan_artifact: _docs/loops/loop37/plan37.md
tasks_shipped: [AZ-2674, AZ-2675, AZ-2676]
decisions:
  - review35 finding 2: a `-Wframe-larger-than=65536` flag in `cpp/Makefile` plus `tests/frame-check.sh` (a local `Scratch<65535>` fails, a static one passes; the check needs code generation, so it is not a `-fsyntax-only` compile-fail case); comment in `core.hpp` and a README line only. Flash 8,132 B and stack 492 B unchanged on the arm stage
  - finding 5: `CompactTextTests.cs` (620 lines) is four files of 49, 166, 190 and 231 lines; `CompactTextTests` is a partial class; 789 compact-text tests before and after
  - finding 6: `bench.py` (688) is four files of 54, 168, 243 and 251 lines; the alphabets and canonical codes come from `scripts/text/textfmt.py`; output equal except the elapsed-seconds prefix, the lens JSON files byte-identical
  - finding 7 accepted, no code: the `put_number`/`get_number`/`Field::eq` edits are merged, a 196 B flash saving with tests green; the margin is in `AGENT_GOTCHAS.md`
  - finding 8 accepted, no code: the contract (`compact-text.md`) says every package returns its own error naming the field and the kind only decides whether a row is refused
leftovers:
  - AZ-2676 AC-1 as first written ("no second parser remains") is met in part: the bench's own Viterbi tokenizer stays because it runs experimental schemes (5-bit prefix, 2-bit mode field, no number mode) that `textfmt.parse` cannot express; the AC text was amended to say so. `bench.py`'s UTF-8 lead-byte check is also not shared (`textfmt._utf8_char` is private)
  - `/feature-assess`, `/security` (AZ-2666) and the retrospective of loops 35 to 37 are owner-run and not done
  - the `-Wframe-larger-than` flag lives only in `cpp/Makefile`: a consumer's own build and the embedded builds do not get it (the README line says to use `static`)
  - the vcpkg supports and consumer checks did not run on this Mac (CI runs them)
  - D5 real messages, CRC for the whole message, F44 and the first v*/go/v* tags (owner only); AZ-2068 in todo/; main not pushed
smoke: PASS (agent run 6/6 at 7963837, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop37/smoke37.md
step11: RESULT 6 passed, 7 skipped as unchanged, 0 failed, 476 s at 6a8d273
loop_end_merge: main (not executed: the owner asked for the dev push only)

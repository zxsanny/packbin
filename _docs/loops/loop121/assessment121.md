# Feature assessment — loop 121 (AZ-4257 to AZ-4261)

round: 1
verdict: COMPLETE — 16 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

| angle | spec | evidence (test; code path) | status |
|-------|------|----------------------------|--------|
| Java repeat-last walk linear (chain 4,000 `when`s, 16,000 siblings, random-tree differential) | AZ-4257 entry 1 | `RepeatLastWalkTest` (3 tests, fails on old: chain 0.123 s vs 3 to 5 ms); `SchemeOrder.RepeatLast` | covered |
| C# repeat-last walk linear | AZ-4259 | `RepeatLastWalkTests` + `OldRoundScopes` oracle (3,000 trees); `RoundScopes.Writer/Held` | covered |
| Go repeat-last walk linear | AZ-4259 | `repeat_last_walk_test.go` (20,000 trees); `counted.go writerMemo` | covered |
| Java missing `utf8` named (Map rows `missing text`; typed rows `missing utf8 1`) | AZ-4257 entry 2 | `MissingMemberNameTest`; `VarFields.packUtf8`, `Field.missingText` | covered (typed-row wording is a stated deviation) |
| Java wrong-type value and short round list keep their texts | AZ-4257 entry 2 | same test | covered |
| Java top-level row class refused at build; base class builds; no-constructor / abstract / interface / Map / throwing constructor build as before | AZ-4257 entry 3, D14 | `TopRowClassTest` (9 failures on old); `RowClassCheck.requireTopRow` | covered |
| Python missing member named; wrong type keeps text | AZ-4258 entry 1 | `test_missing_member_none_item.py` (10 of 16 fail on old); `refuse_missing` | covered |
| Python `None` item of a list or dict of rows refused; plain-value lists keep their message | AZ-4258 entry 2 | same file; `_pack_element` | covered |
| Dart: every wall-clock bound load-aware (colliding keys, hostile rounds, hostile cases, fuzz) | AZ-4260 | `dart test` 2,088 passed idle and at load up to 56; `git grep lessThan` shows only non-timing uses | covered |
| C++ s390x percentage packets compared with M3; missing M3 file noted | AZ-4261 entry 1 | `lib.test.sh` scenario (4 of 6 checks fail on old); `cpp-embedded` container run | covered |
| C++ sanitizer build passes 5 runs; plain builds keep every bound; slowed section still fails plain | AZ-4261 entry 2, D15 | `make -C cpp CXX=clang++ sanitizer-test` x5; `make test`; `gcc:16`; broken-copy check | covered |
| ESP core pinned in one place, printed, checked; gotcha file | AZ-4261 entry 3 | `lib.test.sh` scenario (4 of 5 fail on old); `run.sh host esp core` with 3.3.12; pins check | covered |
| no packet byte changes anywhere | all | every package suite and the shared hostile cases / golden vectors unchanged; step 11 re-runs them | covered (step 11) |
| refusal texts of paths the entries do not name | all | differential tests on random trees; suites | covered |
| Java rows with names (only Map rows) | AZ-4257 entry 2 | README bullet; probe README note | covered |
| README bullets for the four user-visible changes | all | `README.md` Java and Python bullets | covered |

Discoveries read: `implementation_report_hygiene_loop121.md` (six rows, all handled or accepted as Low), `reviews/batch_01_loop121_review.md` (7 Low).

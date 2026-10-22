# Worker rules — loop 57 (AZ-3151, AZ-3152, AZ-3153, AZ-3154)

Read `_docs/02_task_plans/text-and-ecc-test-waves/worker-rules.md` and `_docs/02_task_plans/held-when-one-path-and-flash/worker-rules.md` first (shell hygiene, forbidden git commands including every index write, package recipes, report shape); they apply unchanged except where this file differs. Read `_docs/AGENT_GOTCHAS.md` (flash margin 112 B, stack margin 8 B; gcc:16 check; arm stage ~3 min; `make -C cpp clean` between host and container builds; stdin from /dev/null on every command). Specs: `_docs/02_tasks/todo/AZ-315{1,2,3,4}_*.md`. ACs and numbers: `acceptance_criteria.md` and `input_data/expected_results/results_report.md` here.

## C++ worker (owns `cpp/` only): AZ-3151, then AZ-3152, then AZ-3154

- AZ-3151: rank symbols by size, save at least 40 B with identical behavior (no removed check, no changed refusal). Measure with the arm stage (`docker compose -f docker-compose.test.yml run --rm cpp-embedded`, ~3 min), once per candidate set. Report the figure before AZ-3152.
- AZ-3152: only after AZ-3151 is measured. Inline `unpack_held` into `unpack_children`, no larger frame. If flash is above 8,080 B or a chain stack above 504 / 500 / 436 B, restore your own edit by hand and report the figures (accepted outcome).
- AZ-3154: after AZ-3152, pin the final flash figure in `cpp/embedded/lib.sh`, enforced in `arm.sh`; prove it on a copy with the pin one byte below.
- Before finishing: `make -C cpp test` (host), `make -C cpp clean`, `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test`, the arm stage. A depth limit or wire change is never yours: stop and report. Do not write `_docs/` or `fixtures/`.

## Loader worker (owns `rust/src/hostile_tests.rs`, `rust/tests/nostd_hostile_tests.rs`, `swift/Tests/PackbinTests/FuzzTests.swift`, `go/hostile_loader_test.go`, `go/hostile_pack_test.go`): AZ-3153

- Broken-copy proof per AC-6, AC-7, AC-8 in a scratchpad copy (never edit `fixtures/` in the real tree). Run Go (in `golang:1.27`), Swift (plain `swift test`; check `xcode-select -p`) and Rust (`cargo test`; `--features text,ecc --test nostd_hostile_tests --test nostd_hostile_pack_tests`) once at the end. Only one swift build at a time. No `cargo fmt` on the whole crate.

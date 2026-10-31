# Expected results - drop-m4f-rows

| id | input | expected output | AC |
|----|-------|-----------------|----|
| E1 | `bash cpp/embedded/run.sh host arm` after the change | report rows: cpp-m0plus, cpp-m3-qemu, cpp-m33f, cpp-s390x (as today), cpp-avr-uno all PASS; no `cpp-m4f` row | AC-1, AC-5 |
| E2 | `docker compose -f docker-compose.test.yml run --rm rust-embedded` after the change | rows rust-m33f and rust-mutants PASS; no `rust-m4f` row; `SIZE base/text/ecc/frame` lines equal `limits-m33f.txt` (15132/456, 27268/2736, 18764/744, 20404/1728) | AC-1, AC-3, AC-5 |
| E3 | `git grep -nE 'target_m4f\|target_rust_m4f\|flash_pin\|stack_pin\|thumbv7em\|mps2-an386\|rust-m4f\|cpp-m4f' -- cpp rust scripts .github docker-compose.test.yml README.md` | no hit outside the dated history named in AC-7 | AC-2, AC-7 |
| E4 | `rust-m33f` run on its own (no `rust-m4f` log in the results folder) | PASS; no "no run of the earlier row" message | AC-3 |
| E5 | scratch copy: seeded panic probe replaced by the clean probe | `rust-mutants` FAIL: "the panic check found nothing in the image with the seeded panic defect" | AC-4 |
| E6 | `bash cpp/embedded/lib.test.sh`, `run-parts.test.sh`, `rust/embedded/checks.test.sh` | all cases PASS; no case names `cpp-m4f` | AC-6 |
| E7 | `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded` | `N passed, 0 failed` | AC-8 |

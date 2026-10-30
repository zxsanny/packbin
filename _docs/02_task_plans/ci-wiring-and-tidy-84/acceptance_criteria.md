# Acceptance criteria - loop 84 (CI wiring, all_kinds.cpp, review cleanups)

Measured on HEAD a925aa7. Every count is re-read on HEAD at new-task (`AGENT_GOTCHAS`).

## T1 - scaffold requires the two helper-test steps

- **AC-1.1** `SCAFFOLD_SCRIPTS` has 5 entries (HEAD: 3): the two new ones are `scripts/ci/yaml_get.test.sh` and `scripts/ci/workflow_yaml.test.sh`.
- **AC-1.2** The real `test.yml` and compose file give 0 violations and exit 0 (HEAD: 0).
- **AC-1.3** `ring-wiring.test.sh` gains 2 mutants (one deleted step per new script); each is rejected with exit 1 and a message that names the script. Mutants: HEAD N, after N+2 (N read on HEAD in the task spec); no existing mutant is removed or loosened.
- **AC-1.4** Deleting each of the 2 steps from a copy of `test.yml` makes `ring-wiring-check.py` exit 1 (HEAD: exit 0 for both).

## T2 - split all_kinds.cpp

- **AC-2.1** No `.cpp` under `cpp/embedded/common/` has more than 500 lines (`wc -l`); HEAD: `all_kinds.cpp` 560.
- **AC-2.2** The host test builds with `-Wall -Wextra -Werror` on gcc:16 and `make -C cpp test` ends with the same pass count as HEAD (recorded in the task spec); 0 warnings.
- **AC-2.3** Each of the 3 consumers (`cpp/Makefile`, `cpp/embedded/arm.sh`, `cpp/embedded/esp/main/CMakeLists.txt`) names every new source; `git grep -n 'all_kinds.cpp'` shows no consumer that lists the old file alone while a part lives elsewhere.
- **AC-2.4** For every row of the base scheme and the 3 chain families the `pack` bytes, `unpack` result and `*_failures` count are identical to HEAD (the vectors program prints the same lines).
- **AC-2.5** Each embedded stage this host can run (arm, big-endian) ends as on HEAD; a stage it cannot run is reported NOT RUN, not as a pass.

## T3 - review cleanups

- **AC-3.1** Each header in `handoff_ecc.cpp` and `handoff_frame.cpp` is used by that file (a symbol of it appears) or is removed; the list shrinks only by headers with 0 uses. Count removed is recorded.
- **AC-3.2** `.github/workflows/drivers/handoff*.cpp` still builds from the one compile line of `ring-lib.sh` with `-std=c++17 -O2 -Wall -Wextra -Werror`, 0 warnings; the C++ driver output over the 108 invocations of loop 83 is byte-identical to HEAD.
- **AC-3.3** The `id-padded` test of `ring-frame.test.sh` passes when 10 further rows sort ahead of its needle (a scratch copy with the extra rows), and still fails when the go driver pads the id (HEAD: passes now, breaks with the extra rows).
- **AC-3.4** `kMax` and `frame_hex` are unchanged, and the spec states the probe that shows neither is a defect.

## T4 - one place for the Python version

- **AC-4.1** `grep -c '3\.14' .github/workflows/test.yml` falls from 3 to 1 (the one `RING_PYTHON` value); no `python-version:` line holds a literal.
- **AC-4.2** The real `test.yml` still gives 0 violations; the ring job's check of `RING_PYTHON` against `python:3.14` of the compose file still runs and rejects a mismatch (a copy with `RING_PYTHON: "3.13"` is rejected).
- **AC-4.3** A copy of `test.yml` with a literal `python-version: "3.14"` in any job is rejected by the wiring check (1 new mutant; HEAD accepts it).
- **AC-4.4** `publish-pins.test.sh` passes: every job that reads the CI YAML still has `setup-python` and the pinned PyYAML install.

## Loop

- **AC-L.1** `scripts/loop-tests.sh --only scaffold,ring,publish-gate --all` (or the stages the touched scripts belong to) is green at host load below 60; the CI of the push is read first in loop 85.

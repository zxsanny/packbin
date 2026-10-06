# Embedded targets run with errexit in force

**Task**: AZ-2099_embedded_errexit
**Name**: Embedded harness fails a target on any failed command
**Description**: Every embedded CI target stops and reports FAIL when an unchecked command fails, while explicit checks still report every violated budget, and pass/fail no longer depends on the text "FAIL" in a summary.
**Complexity**: 2 points
**Dependencies**: None
**Component**: cpp-embedded
**Tracker**: AZ-2099
**Epic**: AZ-2069

## Problem

`cpp/embedded/run.sh` runs each target through `run_stage_target` (`run.sh:31-33`):

```
run_target "$@" || failed=$((failed + 1))
```

`run_target` (`cpp/embedded/lib.sh:46-78`) runs the target function in a subshell that sets `set -euo pipefail` (`lib.sh:55-58`), with the output piped to `tee`.

Bash ignores `-e` for every command executed inside a function called from an `||` list. This applies **even when that code sets `-e` again**: "If a compound command or shell function executes in a context where -e is being ignored, none of the commands executed within the compound command or function body will be affected by the -e setting, even if -e is set."

A probe script confirmed it (`scan_ci_docs.md` LF3):
- Called under `||`, a subshell doing `set -euo pipefail; false; echo continued` printed `continued`, and the function returned 0.
- Called outside a condition context, the subshell stopped at `false`.
- Re-enabling `set -e` inside the function before returning a non-zero status then terminated the *caller*.

Consequences in the targets: commands without an explicit `|| fail` do not stop the target, and the target's status is the status of its **last** command. Examples:
- `cpp/embedded/examples.sh:25-27` — `curl` download and `tar` of `arduino-cli`.
- `:38` — `pio pkg pack`.
- `:45-46` — `cp -a`, `sed -i`.
- `:63-66` — `arduino-cli core update-index` / `core install`.
- `:83`, `:91` — `compote component pack`, `tar`.
- `arm.sh:83` — `arm-none-eabi-nm`.
- `lib.sh:22-24` — `make … print-VECTOR_TESTS`, inside `read -r -a tests <<< "$(vector_tests)"` at `arm.sh:113,147,236`.
- `arm.sh:204` — `arm-none-eabi-size … | tee`.

`target_s390x` ends with an `if/else note`, so its status is 0 unless a `fail` note was written.

The workaround added this loop: `lib.sh:61-65` greps the target's summary file `<id>.msg` for the substring `FAIL` and turns that into exit 1. The comment there ("errexit is not reliable inside functions") names the symptom, not the cause. Pass/fail therefore rests on a hidden text convention (S32, `components/08_drivers_embedded.md` EM1, EM2), and failures that never reach `fail()` pass silently (S25).

Feature AC-13 (`_docs/02_task_plans/cpp-microcontroller/acceptance_criteria.md` "Every target in CI") requires these rows to be trustworthy. Sources: `list-of-changes.md` C14, `scan_ci_docs.md` D1.

## Outcome

- Inside every target function, a failing command not explicitly handled ends that target. Its report row says FAIL with the exit status and the log path, as `run_target` does today (`lib.sh:68-73`).
- Explicit checks (`fail "reason"`) record their reason and **let the target continue** to its remaining checks. `target_m4f` therefore still reports flash, stack and data+bss violations together (`arm.sh:224-228`). Any recorded check failure makes the target FAIL.
- The FAIL decision comes from the exit status plus an explicit failure marker that `fail` writes. It no longer depends on the substring `FAIL` appearing in the human summary.
- Other targets in the stage still run after a failed target, one report row per target. `run.sh` exit codes stay 0 (all passed), 1 (any failed), 2 (usage) (`run.sh:10`).
- Name the QEMU timeout (`arm.sh:102`, `timeout 300`) while touching the file.

## Scope

### Included
- `cpp/embedded/run.sh` (`run_stage_target`), `cpp/embedded/lib.sh` (`run_target`, `note`, `fail`), and the call sites in `arm.sh`, `esp.sh`, `examples.sh` that relied on non-terminating failures, if any must stay non-terminating (each one becomes an explicit `|| fail …` or an `if`).
- A harness self-test script (e.g. `cpp/embedded/lib.test.sh`). It sources `lib.sh` with temp `SRC_ROOT`/`TEST_RESULTS`, defines fake targets, and runs them through the real `run_stage_target`/`run_target`. It runs in the `scaffold` job of `.github/workflows/test.yml` (Linux, GNU `date`; `lib.sh:52` uses `date +%s%N`).
- Comment at `lib.sh:61-62` replaced by the actual rule.

### Excluded
- `WRAPPER_CALLS` tautology (`arm/ac2_main.cpp:57`, EM3), toolchain pinning and caching (EM8, D12/D15), the `expect(` count convention (EM2, `arm.sh:109-130`), and C++ source-list duplication (DR2/D9).
- Changing what any target measures or its budgets (`lib.sh:18-19`).

## Acceptance Criteria

**AC-1: An unchecked failing command fails the target**
Given a target function that runs `false` (or a failing `cp`) and then writes a passing note
When the stage runs it
Then the commands after the failure do not run, the report row is `FAIL` with `exit <n>` and the log path, and the stage exit code is 1.

**AC-2: Explicit checks continue and are all reported**
Given a target that calls `fail "budget A"` and later `fail "budget B"`, with no failing command
When the stage runs it
Then both reasons appear in the row's message, the row is `FAIL`, and the commands between and after the checks ran.

**AC-3: A passing target passes**
Given a target with no failing command and no `fail`
When the stage runs it
Then the row is `PASS`, even if its notes contain the word "FAIL" in ordinary text (e.g. `note "FAILURES 0"`).

**AC-4: Later targets still run**
Given three targets where the first fails (AC-1 style)
When the stage runs
Then rows exist for all three, and the stage exit code is 1.

**AC-5: Real targets unchanged when healthy**
Given the current embedded tree and toolchains
When `bash cpp/embedded/run.sh` runs in CI (`test.yml` `embedded` job)
Then all 10 targets report `PASS`, as in the baseline (`baseline_metrics.md`: "C++ embedded … PASS 10 targets").

**AC-6: An injected real failure is caught**
Given the arm stage in `packbin-embedded:local` with a PATH shim `arm-none-eabi-nm` that exits 1 (used unchecked at `arm.sh:83`)
When the stage runs
Then `cpp-m0plus` reports `FAIL`. Today it reports `PASS`: the symbol file is empty, so the heap and OS-random counts read 0 and every link check passes vacuously.

## Non-Functional Requirements

**Reliability**
- No target can report PASS after a command it did not explicitly handle has failed.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | self-test: fake target `false; note after` | row FAIL, "after" absent from log, exit 1 |
| AC-2 | self-test: two `fail` calls | row FAIL with both reasons; later command ran |
| AC-3 | self-test: `note "FAILURES 0"` only | row PASS |
| AC-4 | self-test: fail, pass, pass | three rows; stage exit 1 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5 | CI `embedded` job (`packbin-embedded:local` + `espressif/idf:v5.3.2`) | full run | 10 PASS rows in `test-results/report.csv` | Reliability |
| AC-6 | `packbin-embedded:local`, PATH shim `arm-none-eabi-nm` → exit 1, arm stage only | failure injection | `cpp-m0plus` row FAIL (PASS before the fix — record both) | Reliability |

## Constraints

- Canonical environment: targets run in the compose services `cpp-embedded` / `cpp-embedded-esp` (`docker-compose.test.yml:80-103`). No host substitute for the QEMU/ESP runs (testing rule: no higher tier on the wrong host).
- `bash.md`: strict mode, no `case` in process substitution, no `2>/dev/null` silencing (`command -v … > /dev/null` probes stay), shellcheck-clean.
- Keep one CSV row per target via `.github/workflows/report-row.sh`, and keep the log path in the message.
- Pitfall from the probe: re-enabling `set -e` inside the wrapper and then returning non-zero ends the calling stage. Capture the target's status without an `||`/`if` context and without leaking `-e` changes into the caller (for example by running the target in a child process).

## Risks & Mitigation

**Risk 1: A healthy target relied on a non-terminating failure**
- *Risk*: Some command may legitimately fail today (e.g. a probe) without anyone noticing.
- *Mitigation*: AC-5 full CI run. Any newly failing command is either a real defect (report it) or gets an explicit, commented handler.

**Risk 2: Self-test needs GNU tools**
- *Mitigation*: Run it in the Linux `scaffold` job. The macOS `date +%s%N` incompatibility is noted, not fixed here.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Making errexit effective may surface currently hidden failures in the examples targets (downloads, `pio`, `compote`) that need network; flaky network then shows as FAIL instead of silent PASS | CI owner | accepted-risk | Medium |
| `lib.sh` uses GNU `date +%s%N`, so the harness (and its self-test) cannot run on macOS hosts | CI owner | open | Low |

## Loop 16 result (2026-10-06)

Done in loop 16 (batch 3). `run_target` runs the target in a child with errexit and always returns 0; `fail` records the reason and a `<id>.failed` marker; the row is FAIL on a non-zero exit or the marker; the log names the failed command; `run_stage_target` is removed; the QEMU timeout is named. `cpp/embedded/lib.test.sh` (30 checks, red against the old harness) runs in the `scaffold` job. AC-5: the ARM stage reports 4 PASS on this Mac and the ESP stage 4 of 5 (the Pico example fails on this arm64 host by design); the full 10 PASS needs the CI `embedded` job. AC-6 measured on `packbin-embedded:local` with an `arm-none-eabi-nm` shim that exits 1: old harness exit 0 and 4 PASS, new harness exit 1 and FAIL for `cpp-m0plus`, `cpp-m3-qemu`, `cpp-m4f`. Call sites converted (`cmd | tee log || status=$?`, listed `read` input, `if ! command -v`, `|| true` with a reason, `return 1` after `fail`): newly effective errexit may expose a hidden failure in a healthy CI run; the first run decides.

# Expected results - arm-no-text-no-ecc-run

| id | input | expected output | AC |
|----|-------|-----------------|----|
| E1 | `bash cpp/embedded/run.sh host arm` after the change | the Cortex-M33F part of the stage prints the reduced image's run: `FAILURES 0`, per-file `VECTORS_RUN`-style site counts equal to the `expect(` counts, `compile warnings: 0`; every row still PASS | AC-1, AC-2, AC-6 |
| E2 | the reduced image's QEMU log | `WRAPPER_CALLS 0`; the three kinds of AC-2 each report 0 failures | AC-2, AC-3 |
| E3 | `image_checks` line for the reduced image | `__cxa_throw=0 __cxa_allocate_exception=0 heap_symbols=0 os_rng_symbols=0 dev_urandom=0`; stack top equals the 128 KiB window end | AC-3 |
| E4 | `arm-none-eabi-nm` of the reduced image and `arm-none-eabi-size` of its core objects | 0 codec or message-ECC symbols; core data+bss 0 B | AC-4 |
| E5 | scratch copy: one expected value in the reduced test changed | stage FAIL, `FAILURES` above 0 | AC-5 |
| E6 | scratch copy: `malloc` called from the reduced image | stage FAIL, `references the heap` | AC-5 |
| E7 | scratch copy: reduced core objects built without `-DPACKBIN_NO_TEXT` | stage FAIL, a codec symbol is reported | AC-4, AC-5 |
| E8 | arm stage time before and after, same host | added time at most 60 s | AC-7 |
| E9 | `bash cpp/embedded/lib.test.sh`, `run-parts.test.sh`, `rust/embedded/checks.test.sh` | all cases PASS | AC-8 |
| E10 | `git grep -n 'no ARM run\|no longer on an ARM core' -- README.md _docs/AGENT_GOTCHAS.md cpp scripts .github` | no hit that says the reduced build has no ARM run | AC-9 |
| E11 | `scripts/loop-tests.sh --only cpp-embedded-arm` | `N passed, 0 failed` | AC-10 |

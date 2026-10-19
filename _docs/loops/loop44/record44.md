# Autodev loop record — loop 44

loop: 44
branch: dev
plan_artifact: _docs/loops/loop44/plan44.md
tasks_shipped: [AZ-2068, AZ-2728]
decisions:
  - owner 2026-10-19 ("accept all recommended" after loop 43): AZ-2068 (C++ AVR build, the last open spec of epic AZ-2059) and AZ-2728 (TypeScript hostile hang guard, new ticket, epic AZ-2645); `/feature-assess`, F44 and the first tags stay owner-run; retro not due (3 loops since loop 41); `main` fast-forward at close
  - agent: the core takes its standard names only from `packbin/platform.hpp`: a compiler with `<cstdint>` (by `__has_include`) gets the C++ headers, avr-gcc 7.3 (no C++ library) the C headers named in `std`; hand-written traits and `detail::FixedArray` replace `<type_traits>` and `<array>` on every target, so `Scheme::fields` and `Node::f` are `detail::FixedArray<Field, N>` now (a source change for a caller that names `std::array`; no release exists)
  - agent: avr-gcc 7.3 has no `__builtin_is_constant_evaluated`: on GCC before 9 `constant_evaluated()` is false, a broken constant scheme is `SchemeInvalid` with the field id, and `static_assert(scheme.status.ok())` is the stop (README; the arm stage compiles a probe that asserts it); a 16-bit `int` and `size_t` needed `int32_t` in `find_flag_byte_in` and `txt::over_max_count`; `offsetof(Field, eq) == 16` holds on AVR too (`EqValue` aligned to 4), so loop 19 review C10 does not occur
  - agent: `target_avr_uno` in `cpp/embedded/arm.sh` (the image gets `gcc-avr`, `avr-libc`, `binutils-avr` in a layer of its own): the full core with 0 warnings, the Uno example (`cpp/examples/avr_uno`, no Arduino core, `PACKBIN_NO_TEXT` and `PACKBIN_NO_ECC`) 15386 B flash and 220 B static RAM, the f64 compile-fail probe; M4F flash 7920 B and stack 504 B unchanged
  - agent: AZ-2728 by one worker: `tests/support/hostile-runner.ts`, the worker posts ready after its imports, a 30 s start-up guard and the 5 s case guard after ready, both scaled by the load factor; total review 5 findings (3 fixed in `f5785b1`: the AC-2 probe guard, the worker exit event, the AVR status probe; 2 accepted: the `FixedArray` type change, `__has_include` also taking the C path on a hosted compiler with a broken include path)
leftovers:
  - not run here: the ESP stage (CI only), the vcpkg supports and consumer checks (no vcpkg on this Mac); no AVR image runs (spec excludes an emulator)
  - Arduino IDE builds for AVR use `-std=gnu++11` by default; the Uno example uses avr-gcc directly
  - `/feature-assess`, F44 and the first v*/go/v* tags are owner-run; retrospective due after loop 45 (5 loops since loop 41)
smoke: PASS (agent run 8/8 at f5785b1, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop44/smoke44.md
step11: RESULT 6 passed, 7 skipped as unchanged, 0 failed, 656 s at f5785b1
loop_end_merge: main

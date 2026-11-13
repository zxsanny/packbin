---
title: "On the arm64 Mac, set PACKBIN_CXX_SYSROOT, a python3 3.13 dir first on PATH and RUSTUP_TOOLCHAIN=1.98 before a run"
applies_when: "running language-pair.sh, the ring, the publish gate, publish-vcpkg.test.sh, the TypeScript strict check, the Pico example or a total scripts/loop-tests.sh on this Mac"
source: "loops 13, 14 and 19 (host recipes); 2026-10-06, AZ-2098 (publish-vcpkg); loops 100 and 107 (loop-tests environment)"
---

A green run on this arm64 Mac needs host recipes written nowhere else (repeated from loop 13, tripped again in loop 14).

## Host recipes (loops 13, 14, 19)

- `PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"` for `language-pair.sh` (else `'cstddef' file not found`).
- `typescript/node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions typescript/src/index.ts` for the strict check.
- The Pico example needs a `--platform linux/amd64` container with its own cache under `.cache/embedded/amd64` (PlatformIO has no linux arm64 build of `toolchain-gccarmnoneeabi ~1.90201.0`; the ESP stage of `cpp/embedded/run.sh` shows `cpp-example-pico` failed on this host by design).
- Loop 19: the ring and the publish gate also need `python3` 3.10 or newer, Apple's is 3.9: put a dir with `python3 -> /opt/homebrew/bin/python3.14` first on `PATH`, and give `publish-gate.test.sh` the same `PACKBIN_CXX_SYSROOT`. (Superseded for the Python version by loop 100 below: use `python3.13`.)

## publish-vcpkg.test.sh (2026-10-06, AZ-2098)

`publish-vcpkg.test.sh` honors `PACKBIN_CXX_SYSROOT` for its cmake builds and the vcpkg consumer (it writes a temp overlay triplet); no extra recipe. Without a vcpkg tool it prints NOT RUN, which is not a pass.

## A total scripts/loop-tests.sh run (loops 100, 107)

A total `scripts/loop-tests.sh` run on this Mac needs the loop 99 smoke environment, or `scaffold`, `ring` and `publish-gate` fail in seconds (loop 100: `PyYAML is required` from `scripts/ci/yaml_get.py`, then `is_none_or` not found because rustup's default is 1.79.0):

- put a dir with `python3 -> /opt/homebrew/bin/python3.13` first on `PATH` (3.13 is the only Homebrew Python here with PyYAML; 3.14 has none, so the older note about `python3 -> python3.14` no longer holds),
- set `LOOP_TESTS_PYTHON=/opt/homebrew/bin/python3.13`,
- `PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"`,
- and `RUSTUP_TOOLCHAIN=1.98`.

The `phases` groups of `publish-gate` need the same Python 3.13 (default 3.9 fails the pip pin of `idf-component-manager`; tripped again in loop 107). A run started without them still passes the nine language suites; rerun only the failed stages with `--only scaffold,ring,publish-gate` (818 s) after stopping it.

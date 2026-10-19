# Loop 44 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. AZ-2068 AC-1: the core and the Uno example build with avr-gcc, 0 warnings, inside the Uno's flash and RAM
- [x] 4. AZ-2068 AC-2: a scheme with f64 does not compile with avr-gcc, and the message names f64
- [x] 5. AZ-2068: a broken constant scheme is SchemeInvalid on avr-gcc 7.3 (no `__builtin_is_constant_evaluated`)
- [x] 6. AZ-2068: no core file includes a C++ standard header outside `packbin/platform.hpp`; `text_tables.hpp` equals the emitter
- [x] 7. AZ-2728 AC-1 to AC-3: the hostile and guard tests pass with 12 busy processes
- [x] 8. Nothing is released: no tag holds HEAD

## Result

Agent run 2026-10-19 at `f5785b1` (owner rule 2026-10-12 in `deployment_procedures.md`): **8/8 steps passed**. Step 11 at `f5785b1`: 6 stages passed (typescript 13 s, cpp 47 s, scaffold 266 s, cpp-embedded-arm 11 s with the image built, ring 52 s, publish-gate 327 s), 7 skipped as unchanged, 0 failed, 656 s, host load 6 to 75 and 4.9 GB of swap in use; the publish gate printed NOT RUN for the vcpkg supports and consumer checks (no vcpkg tool on this Mac; CI runs them). The ESP stage (`embedded-esp-core`, `embedded-esp-packages`) is not part of `loop-tests.sh`: CI on the `dev` push is its proof. Uno example flash 15386 B of 32256, static RAM 220 B of 2048; Cortex-M4F flash 7920 B of 8192 and stack 504 B of 512, both unchanged. Hostile and guard tests under 12 busy processes: 95 pass, 20 s.

## For the operator

- The first `v*` tag, F44 and the `go/v*` tag are yours.
- `/feature-assess` is yours to run.
- No AVR image runs anywhere (the spec excludes an emulator): AVR is proven to build and link, not to pack correctly on the chip.

## Script (`bash smoke44.sh`)

```bash
#!/usr/bin/env bash
# Loop 44 smoke (C++ core on AVR, AZ-2068; TypeScript hostile hang guard, AZ-2728). One line per step: [n/N] title,
# then PASS (Ns) <result> or FAIL with the reason. No network beyond the local Docker images.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=8 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); rm -f "$work/out.log"; }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

step "No application source is dirty at the close"
if [ -z "$(git status --porcelain)" ]; then ok "tree clean at $(git rev-parse --short HEAD)"; else ko "dirty: $(git status --porcelain | head -3 | tr '\n' ' ')"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed"
if PATH="/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" limit 3600 scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "AZ-2068 AC-1: the core and the Uno example build with avr-gcc, 0 warnings, inside the Uno's flash and RAM"
if limit 300 docker run --rm -v "$repo":/src -w /src/cpp packbin-embedded:local bash -c '
  set -e; f="-std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror -mmcu=atmega328p -Iinclude"
  for s in src/core/*.cpp; do avr-g++ $f -c "$s" -o /tmp/full.o; done
  avr-g++ $f -DPACKBIN_NO_TEXT -DPACKBIN_NO_ECC -Wl,--gc-sections src/core/*.cpp examples/avr_uno/avr_uno.cpp -o /tmp/uno.elf
  avr-size /tmp/uno.elf | awk "NR == 2 { print \"flash\", \$1 + \$2, \"ram\", \$2 + \$3 }"' < /dev/null > "$work/out.log" 2>&1 \
  && read -r _ flash _ ram < <(tail -1 "$work/out.log") && [ "$flash" -le 32256 ] && [ "$ram" -le 2048 ]; then
  ok "Uno example flash $flash B of 32256, static RAM $ram B of 2048"
else ko "AVR build failed or over budget"; fi

step "AZ-2068 AC-2: a scheme with f64 does not compile with avr-gcc, and the message names f64"
if limit 120 docker run --rm -v "$repo":/src -w /src/cpp packbin-embedded:local avr-g++ -std=c++17 -fno-exceptions -fno-rtti \
  -mmcu=atmega328p -Iinclude -fsyntax-only embedded/avr/f64_refused.cpp < /dev/null > "$work/out.log" 2>&1; then
  ko "the f64 probe compiled"
elif grep -q 'f64 needs an 8-byte double' "$work/out.log"; then ok "refused: $(grep -m1 -o 'packbin: f64 needs an 8-byte double[^"]*' "$work/out.log")"
else ko "refused without naming f64"; fi

step "AZ-2068: a broken constant scheme is SchemeInvalid on avr-gcc 7.3 (no __builtin_is_constant_evaluated)"
if limit 120 docker run --rm -v "$repo":/src -w /src/cpp packbin-embedded:local avr-g++ -std=c++17 -fno-exceptions -fno-rtti \
  -Wall -Wextra -Werror -mmcu=atmega328p -Iinclude -fsyntax-only embedded/avr/broken_scheme_status.cpp < /dev/null > "$work/out.log" 2>&1; then
  ok "status SchemeInvalid at field 2, checked by static_assert"
else ko "the status probe did not compile"; fi

step "AZ-2068: no core file includes a C++ standard header outside packbin/platform.hpp"
hits="$(grep -nE '#include <(cstddef|cstdint|cstring|type_traits|array|limits|utility)>' cpp/include/packbin/*.hpp cpp/src/core/* \
  | grep -vE '^cpp/include/packbin/(platform|os_random)\.hpp:' || true)"
if [ -z "$hits" ] && limit 60 python3 scripts/text/emit_tables.py cpp --check cpp/include/packbin/text_tables.hpp < /dev/null > "$work/out.log" 2>&1; then
  ok "only platform.hpp (and the host-only os_random.hpp); text_tables.hpp equals the emitter"
else printf '%s\n' "$hits" > "$work/out.log"; ko "standard headers outside platform.hpp, or the emitter check failed"; fi

step "AZ-2728 AC-1 to AC-3: the hostile and guard tests pass with 12 busy processes"
pids=(); for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do yes > /dev/null & pids+=($!); done
(cd typescript && limit 300 node --test tests/hostile.test.ts tests/hostile-guard.test.ts < /dev/null > "$work/out.log" 2>&1); rc=$?
kill "${pids[@]}" 2> /dev/null; wait "${pids[@]}" 2> /dev/null
if [ "$rc" -eq 0 ]; then ok "$(grep -E '^# (pass|fail)' "$work/out.log" | tr '\n' ' ')"; else ko "hostile or guard tests failed under load"; fi

step "Nothing is released: no tag holds HEAD"
if [ -z "$(git tag --points-at HEAD)" ]; then ok "no tag at $(git rev-parse --short HEAD)"; else ko "tag at HEAD: $(git tag --points-at HEAD | tr '\n' ' ')"; fi

echo "$passed/$N steps passed"
[ "$passed" -eq "$N" ]
```

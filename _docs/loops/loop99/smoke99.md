# Loop 99 smoke - Dart package (checks run by the agent)

LOCAL_URL: none (library; no UI, no local deploy)
Branch: dev (the commit before the close commit)

One bash script; every step prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines. Owner rule 2026-10-12 (`deployment_procedures.md` § Loop smoke gate): the agent runs it, and all steps passing passes the gate.

```bash
set -u
cd "$(git rev-parse --show-toplevel)"
export PATH="${SMOKE_PY:-/opt/homebrew/bin}:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" RUSTUP_TOOLCHAIN=1.98 LOOP_TESTS_PYTHON=/opt/homebrew/bin/python3.13
N=11; n=0; fails=0
step() { n=$((n+1)); local title="$1"; shift; printf '[%s/%s] %s\n' "$n" "$N" "$title"; local t0=$SECONDS log; log=$(mktemp); if perl -e 'alarm 900; exec @ARGV' -- bash -c "$*" </dev/null >"$log" 2>&1; then printf 'PASS (%ss) %s\n' "$((SECONDS-t0))" "$(tail -1 "$log" | cut -c1-120)"; else fails=$((fails+1)); printf 'FAIL (%ss)\n' "$((SECONDS-t0))"; tail -12 "$log"; fi; rm -f "$log"; }

step "tree is clean" 'test -z "$(git status --porcelain)" && git log -1 --format=%h'
step "loop test stages: nothing changed since step 11 (all stages skipped or pass)" 'bash scripts/loop-tests.sh | tail -3 | grep -E "^RESULT .* 0 failed"'
step "dart: format, analyze, 1,919 tests" 'cd dart && dart format --output=none --set-exit-if-changed . && dart analyze --fatal-infos && dart test -r expanded | tail -1 | grep "All tests passed"'
step "dart: compiled speed bound (100,000 round trips <= 1 s; 1,000 frame unpacks <= 10 ms)" 'd=$(mktemp -d) && cd dart && dart compile exe tool/speed.dart -o "$d/speed" >/dev/null && "$d/speed"'
step "dart: README example prints the golden hex" 'cd dart && test "$(dart run example/packbin_example.dart | head -1)" = "$(cat ../fixtures/golden.hex)" && cat ../fixtures/golden.hex'
step "dart: 10 s seeded unpack run" 'cd dart && PACKBIN_FUZZ_SECONDS=10 dart test test/limits/seeded_run_test.dart -r expanded | tail -1'
step "hostile cases: 75, nine packages" 'bash fixtures/hostile/check-cases.sh'
step "frame README examples (nine languages)" 'bash scripts/frame/readme-examples.sh | tail -2'
step "release: position program for Dart prints the golden hex" 'bash .github/workflows/publish-position.sh dart | tail -1 | grep -x "$(cat fixtures/golden.hex)"'
step "release: pub publish dry run on a copy (0 warnings)" 'd=$(mktemp -d) && cp -R dart "$d/packbin" && cd "$d/packbin" && dart pub get >/dev/null && dart pub publish --dry-run 2>&1 | tail -3 | tee /dev/stderr | grep -q "0 warnings" && echo "0 warnings"'
step "no tag and no upload in this loop (last tag is still v0.4.0)" 'test "$(git tag -l "v*" | sort -V | tail -1)" = v0.4.0 && echo v0.4.0'

printf '\n%s of %s steps passed\n' "$((N-fails))" "$N"
test "$fails" -eq 0
```

## Result

(pending)

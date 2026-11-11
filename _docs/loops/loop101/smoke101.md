# Loop 101 smoke - TypeScript refuses colliding dictionary keys (checks run by the agent)

LOCAL_URL: none (library; no UI, no local deploy)
Branch: dev (the commit before the close commit)

One bash script; every step prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines. Owner rule 2026-10-12 (`deployment_procedures.md` § Loop smoke gate): the agent runs it, and all steps passing passes the gate. It needs the host environment of `AGENT_GOTCHAS.md` (set `SMOKE_PY` to a directory whose `python3` is 3.13).

```bash
set -u
cd "$(git rev-parse --show-toplevel)"
export PATH="${SMOKE_PY:-/opt/homebrew/bin}:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" RUSTUP_TOOLCHAIN=1.98 LOOP_TESTS_PYTHON=/opt/homebrew/bin/python3.13
N=8; n=0; fails=0
step() { n=$((n+1)); local title="$1"; shift; printf '[%s/%s] %s\n' "$n" "$N" "$title"; local t0=$SECONDS log; log=$(mktemp); if perl -e 'alarm 1800; exec @ARGV' -- bash -c "$*" </dev/null >"$log" 2>&1; then printf 'PASS (%ss) %s\n' "$((SECONDS-t0))" "$(tail -1 "$log" | cut -c1-120)"; else fails=$((fails+1)); printf 'FAIL (%ss)\n' "$((SECONDS-t0))"; tail -12 "$log"; fi; rm -f "$log"; }

step "tree is clean" 'test -z "$(git status --porcelain)" && git log -1 --format=%h'
step "loop test stages: nothing changed since step 11 (all stages skipped or pass)" 'bash scripts/loop-tests.sh | tail -3 | grep -E "^RESULT .* 0 failed"'
step "typescript: strict type check and 3,638 tests" 'cd typescript && node_modules/.bin/tsc --noEmit --strict --target es2022 --module nodenext --moduleResolution nodenext --allowImportingTsExtensions src/index.ts && node --test tests/*.ts 2>&1 | grep -E "^# (pass|fail)" | tr "\n" " " | grep -q "# pass 3638 # fail 0" && echo "3638 pass, 0 fail"'
step "typescript: the collision tests (4 refused, 4 unchanged packets, 20,000 seeded dictionaries)" 'cd typescript && node --test tests/dict-colliding-keys.test.ts 2>&1 | grep -E "^# (pass|fail)" | tr "\n" " "'
step "dart: the same dictionaries (16 TypeScript packets, collisions refused) and the parity doc test" 'cd dart && dart test test/collections/lone_surrogate_test.dart test/parity/parity_doc_test.dart -r expanded | tail -1 | grep "All tests passed"'
step "hostile cases: 75, nine packages" 'bash fixtures/hostile/check-cases.sh'
step "release: position programs for TypeScript and Dart print the golden hex" 'bash .github/workflows/publish-position.sh typescript | tail -1 | grep -x "$(cat fixtures/golden.hex)" && bash .github/workflows/publish-position.sh dart | tail -1 | grep -x "$(cat fixtures/golden.hex)"'
step "no tag and no upload in this loop (last tag is still v0.4.0)" 'test "$(git tag -l "v*" | sort -V | tail -1)" = v0.4.0 && echo v0.4.0'

printf '\n%s of %s steps passed\n' "$((N-fails))" "$N"
test "$fails" -eq 0
```

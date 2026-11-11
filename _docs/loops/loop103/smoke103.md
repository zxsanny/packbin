# Loop 103 smoke - C# and Java refuse colliding dictionary keys (checks run by the agent)

LOCAL_URL: none (library; no UI, no local deploy)
Branch: dev (the commit before the close commit)

One bash script; every step prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines. Owner rule 2026-10-12 (`deployment_procedures.md` § Loop smoke gate): the agent runs it, and all steps passing passes the gate. It needs the host environment of `AGENT_GOTCHAS.md` (set `SMOKE_PY` to a directory whose `python3` is 3.13).

```bash
set -u
cd "$(git rev-parse --show-toplevel)"
R="$PWD"; DF="$R/_docs/02_task_plans/csharp-java-lone-surrogate-keys/differential"
export PATH="${SMOKE_PY:-/opt/homebrew/bin}:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" RUSTUP_TOOLCHAIN=1.98 LOOP_TESTS_PYTHON=/opt/homebrew/bin/python3.13
N=8; n=0; fails=0
step() { n=$((n+1)); local title="$1"; shift; printf '[%s/%s] %s\n' "$n" "$N" "$title"; local t0=$SECONDS log; log=$(mktemp); if perl -e 'alarm 1800; exec @ARGV' -- bash -c "$*" </dev/null >"$log" 2>&1; then printf 'PASS (%ss) %s\n' "$((SECONDS-t0))" "$(tail -1 "$log" | cut -c1-120)"; else fails=$((fails+1)); printf 'FAIL (%ss)\n' "$((SECONDS-t0))"; tail -12 "$log"; fi; rm -f "$log"; }

step "tree is clean" 'test -z "$(git status --porcelain)" && git log -1 --format=%h'
step "loop test stages: nothing changed since step 11 (all stages skipped or pass)" 'bash scripts/loop-tests.sh | tail -3 | grep -E "^RESULT .* 0 failed"'
step "C#: the collision tests (collisions refused, unchanged packets, one lone half, 20,000 seeded dictionaries)" 'cd csharp && env MSBUILDDISABLENODEREUSE=1 dotnet test tests --nologo --filter "FullyQualifiedName~DictCollidingKeysTests" 2>&1 | tail -1 | grep "Passed:     4"'
step "Java: the whole suite passes (0 FAIL lines, exit 0)" 'bash java/test.sh > "$TMPDIR/java103.log" 2>&1; rc=$?; test $rc -eq 0 && test "$(grep -c "^FAIL" "$TMPDIR/java103.log")" = 0 && echo "java suite exit 0, 0 FAIL lines"'
step "TypeScript: the collision tests (4 refused, 4 unchanged packets, 20,000 seeded dictionaries)" 'cd typescript && node --test tests/dict-colliding-keys.test.ts 2>&1 | grep -E "^# (pass|fail)" | tr "\n" " " | grep -q "# pass 10 # fail 0" && echo "10 pass, 0 fail"'
step "four packages: TypeScript writes 5,000 seeded dictionaries; C#, Java and Dart agree on every one" "d=\$(mktemp -d) && cd $R/typescript && node $DF/gen.ts \$d/cases.txt && cp -R $DF/csharp \$d/cs && (cd \$d/cs && env MSBUILDDISABLENODEREUSE=1 dotnet build -c Release -o \$d/csout -p:BaseIntermediateOutputPath=\$d/obj/ >/dev/null && env MSBUILDDISABLENODEREUSE=1 dotnet \$d/csout/Diff.dll \$d/cases.txt) | tee \$d/o.txt && (find $R/java/src/main/java -name '*.java'; echo $DF/java/Diff103.java) > \$d/srcs.txt && javac -d \$d/jout @\$d/srcs.txt && java -cp \$d/jout packbin.Diff103 \$d/cases.txt | tee -a \$d/o.txt && mkdir \$d/dart && cp $DF/dart/diff.dart \$d/dart/ && printf 'name: diff_probe\nenvironment:\n  sdk: ^3.13.0\ndependencies:\n  packbin:\n    path: $R/dart\n' > \$d/dart/pubspec.yaml && (cd \$d/dart && dart pub get --offline >/dev/null && dart run diff.dart \$d/cases.txt) | tee -a \$d/o.txt && grep -c ' 5000 same, 0 different' \$d/o.txt | grep -x 3 >/dev/null && echo 'C#, Java, Dart: 5000 same, 0 different'"
step "hostile cases: 75, nine packages" 'bash fixtures/hostile/check-cases.sh'
step "no tag and no upload in this loop (last tag is still v0.4.0)" 'test "$(git tag -l "v*" | sort -V | tail -1)" = v0.4.0 && echo v0.4.0'

printf '\n%s of %s steps passed\n' "$((N-fails))" "$N"
test "$fails" -eq 0
```

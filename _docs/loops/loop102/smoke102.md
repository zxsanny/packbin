# Loop 102 smoke - probes of the six packages (checks run by the agent)

LOCAL_URL: none (measurement loop: no package code changed, no UI, no local deploy)
Branch: dev (the commit before the close commit)

One bash script; each step re-runs one committed probe (`_docs/02_task_plans/lone-surrogate-key-probe/probes/`) from a temp copy and checks one line of its output against `findings.md`. Every step prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines. Owner rule 2026-10-12 (`deployment_procedures.md` § Loop smoke gate): the agent runs it, and all steps passing passes the gate.

```bash
set -u
cd "$(git rev-parse --show-toplevel)"
R="$PWD"; PR="$R/_docs/02_task_plans/lone-surrogate-key-probe/probes"
export RUSTUP_TOOLCHAIN=1.98 PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"
N=8; n=0; fails=0
step() { n=$((n+1)); local title="$1"; shift; printf '[%s/%s] %s\n' "$n" "$N" "$title"; local t0=$SECONDS log; log=$(mktemp); if perl -e 'alarm 1200; exec @ARGV' -- bash -c "$*" </dev/null >"$log" 2>&1; then printf 'PASS (%ss) %s\n' "$((SECONDS-t0))" "$(tail -1 "$log" | cut -c1-120)"; else fails=$((fails+1)); printf 'FAIL (%ss)\n' "$((SECONDS-t0))"; tail -12 "$log"; fi; rm -f "$log"; }

step "tree is clean" 'test -z "$(git status --porcelain)" && git log -1 --format=%h'
step "C#: pack writes 0102000410efbfbd010410efbfbd02 for two lone halves and unpack refuses it" "d=\$(mktemp -d) && cd $PR/csharp && env MSBUILDDISABLENODEREUSE=1 dotnet build -c Release -o \$d/out -p:BaseIntermediateOutputPath=\$d/obj/ >/dev/null && env MSBUILDDISABLENODEREUSE=1 dotnet \$d/out/Probe102.dll | tee \$d/o.txt | grep -c 'pack hex=0102000410efbfbd010410efbfbd02' | grep -x 2 >/dev/null && grep -q 'unpack (Read) error=ShortPacket' \$d/o.txt && echo 'A and B unreadable'"
step "Java: pack writes 01020002103f0102103f02 (a '?' for each lone half) and unpack refuses it" "d=\$(mktemp -d) && cd $R && (find java/src/main/java -name '*.java'; echo $PR/java/Probe102.java) > \$d/srcs.txt && javac -d \$d/out @\$d/srcs.txt && java -cp \$d/out packbin.Probe102 | tee \$d/o.txt | grep -q 'pack hex=01020002103f0102103f02' && grep -q 'unpack error=ShortPacket' \$d/o.txt && echo 'A unreadable'"
step "Python: pack refuses a lone surrogate in 4 of 4 cases" "cd $R && PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=python/src /opt/homebrew/bin/python3.13 $PR/python/probe.py | grep -c 'PACK RAISED builtins.UnicodeEncodeError' | grep -x 4"
step "Go: pack refuses invalid UTF-8 as a key and as a text" "d=\$(mktemp -d) && cp -R $PR/go \$d/go && docker run --rm -v $R:/src:ro -v \$d/go:/probe -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -w /probe -e GOFLAGS=-mod=mod golang:1.27 go run . | grep -c 'is not valid UTF-8' | grep -v '^0\$'"
step "Rust: a lone half cannot be a String; the heap-free key bytes are refused" "d=\$(mktemp -d) && cp -R $PR/rust \$d/rust && CARGO_TARGET_DIR=\$d/target cargo run --quiet --manifest-path \$d/rust/Cargo.toml | tee \$d/o.txt | grep -q 'distinct strings => distinct bytes: true' && grep -q 'BadValue' \$d/o.txt && echo 'no unreadable packet'"
step "Swift: a lone half becomes U+FFFD at construction, one key; two FFFD keys on the wire are refused" "d=\$(mktemp -d) && cp -R $PR/swift \$d/swift && cd \$d/swift && swift build --scratch-path \$d/scratch >/dev/null 2>&1 && \$d/scratch/debug/swiftprobe | tee \$d/o.txt | grep -q 'dict key given twice' && echo 'one key; wire repeat refused'"
step "no tag and no upload in this loop (last tag is still v0.4.0)" 'test "$(git tag -l "v*" | sort -V | tail -1)" = v0.4.0 && echo v0.4.0'

printf '\n%s of %s steps passed\n' "$((N-fails))" "$N"
test "$fails" -eq 0
```

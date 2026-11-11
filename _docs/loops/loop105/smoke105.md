# Loop 105 smoke - release v0.5.0 (checks run by the agent)

LOCAL_URL: none (library release: the checks read the public registries and the repository)
Branch: dev (the commit before the close commit)

One bash script; every step prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines. Owner rule 2026-10-12 (`deployment_procedures.md` § Loop smoke gate): the agent runs it, and all steps passing passes the gate. It asks no registry about the Go proxy.

```bash
set -u
cd "$(git rev-parse --show-toplevel)"
N=9; n=0; fails=0
q() { perl -e 'alarm 30; exec @ARGV' -- curl -s -m 25 -A 'packbin-release-check' -o /dev/null -w '%{http_code}' "$1" </dev/null; }
step() { n=$((n+1)); local title="$1"; shift; printf '[%s/%s] %s\n' "$n" "$N" "$title"; local t0=$SECONDS log; log=$(mktemp); if perl -e 'alarm 300; exec @ARGV' -- bash -c "$*" </dev/null >"$log" 2>&1; then printf 'PASS (%ss) %s\n' "$((SECONDS-t0))" "$(tail -1 "$log" | cut -c1-120)"; else fails=$((fails+1)); printf 'FAIL (%ss)\n' "$((SECONDS-t0))"; tail -12 "$log"; fi; rm -f "$log"; }
export -f q

step "tree is clean" 'test -z "$(git status --porcelain)" && git log -1 --format=%h'
step "the tag v0.5.0 is annotated and points at 4e9110a, and the tag go/v0.5.0 points at the same commit" 'git fetch -q --tags && test "$(git cat-file -t v0.5.0)" = tag && test "$(git rev-parse v0.5.0^{commit})" = "$(git rev-parse 4e9110a)" && test "$(git rev-parse go/v0.5.0^{commit})" = "$(git rev-parse 4e9110a)" && echo "v0.5.0 and go/v0.5.0 at 4e9110a"'
step "npm, PyPI and crates.io hold 0.5.0" 'test "$(q https://registry.npmjs.org/packbin/0.5.0)" = 200 && test "$(q https://pypi.org/pypi/packbin/0.5.0/json)" = 200 && test "$(q https://crates.io/api/v1/crates/packbin/0.5.0)" = 200 && echo "npm, pypi, crates: 200"'
step "NuGet lists 0.5.0" 'curl -s -m 25 https://api.nuget.org/v3-flatcontainer/packbin/index.json | python3 -c "import sys,json; v=json.load(sys.stdin)[\"versions\"]; assert \"0.5.0\" in v; print(\"nuget has 0.5.0\")"'
step "Maven Central serves the pom and its signature for 0.5.0" 'test "$(q https://repo1.maven.org/maven2/io/github/zxsanny/packbin/0.5.0/packbin-0.5.0.pom)" = 200 && test "$(q https://repo1.maven.org/maven2/io/github/zxsanny/packbin/0.5.0/packbin-0.5.0.pom.asc)" = 200 && echo "pom and pom.asc: 200"'
step "the signing key is served by keys.openpgp.org (by fingerprint and by key id)" 'test "$(q https://keys.openpgp.org/vks/v1/by-fingerprint/3C51A862BEA87BC1BE7B0AB5AC576082216B95B9)" = 200 && test "$(q https://keys.openpgp.org/vks/v1/by-keyid/AC576082216B95B9)" = 200 && echo "key served"'
step "the publish run succeeded and pub.dev was skipped with the expected warning" 'test "$(gh run view 43041230549 --json conclusion --jq .conclusion)" = success && gh run view 43041230549 --log | sed "s/\x1b\[[0-9;]*m//g" | grep -q "skipping optional target pubdev" && echo "run 43041230549 success, pubdev skipped"'
step "the GitHub release v0.5.0 is the latest release and is not a draft" 'test "$(gh release view v0.5.0 --json isLatest,isDraft --jq "\(.isLatest) \(.isDraft)")" = "true false" && echo "latest, published"'
step "the position program prints the golden hex for the tagged tree in the languages the host can run" 'bash .github/workflows/publish-position.sh typescript | tail -1 | grep -x "$(cat fixtures/golden.hex)" && bash .github/workflows/publish-position.sh dart | tail -1 | grep -x "$(cat fixtures/golden.hex)" && echo "golden hex"'

printf '\n%s of %s steps passed\n' "$((N-fails))" "$N"
test "$fails" -eq 0
```

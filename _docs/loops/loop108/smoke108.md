# Loop 108 smoke - retrospective of loops 105 to 107 (checks run by the agent)

LOCAL_URL: none (documents only: no code, no UI, no local deploy)
Branch: dev (the commit before the close commit)

One bash script; every step prints `[n/N] title`, then `PASS (Ns) <result>` or `FAIL` with the last log lines. Owner rule 2026-10-12 (`deployment_procedures.md` § Loop smoke gate): the agent runs it, and all steps passing passes the gate.

```bash
set -u
cd "$(git rev-parse --show-toplevel)"
N=7; n=0; fails=0
step() { n=$((n+1)); local title="$1"; shift; printf '[%s/%s] %s\n' "$n" "$N" "$title"; local t0=$SECONDS log; log=$(mktemp); if perl -e 'alarm 300; exec @ARGV' -- bash -c "$*" </dev/null >"$log" 2>&1; then printf 'PASS (%ss) %s\n' "$((SECONDS-t0))" "$(tail -1 "$log" | cut -c1-120)"; else fails=$((fails+1)); printf 'FAIL (%ss)\n' "$((SECONDS-t0))"; tail -12 "$log"; fi; rm -f "$log"; }

step "tree is clean" 'test -z "$(git status --porcelain)" && git log -1 --format=%h'
step "the retro and the structure snapshot exist and the retro names its top 3 actions" 'f=_docs/06_metrics/retro_2026-11-11_loop108.md; test -s "$f" && test -s _docs/06_metrics/structure_2026-11-11_loop108.md && grep -q "^## Top 3 actions" "$f" && test "$(awk "/^## Top 3 actions/{f=1;next} /^## /{f=0} f && /^[0-9]\\./" "$f" | wc -l)" -eq 3 && echo "retro with 3 actions"'
step "LESSONS.md holds 15 entries, each with a Source line that names an existing file" 'test "$(grep -c "^- \[" _docs/LESSONS.md)" -eq 15 && test "$(grep -c "^  Source: " _docs/LESSONS.md)" -eq 15 && grep "^  Source: " _docs/LESSONS.md | sed "s/^  Source: //" | sort -u | while read -r p; do test -f "$p" || { echo "missing $p"; exit 1; }; done && echo "15 entries, sources exist"'
step "the Python 3.13 gotcha names the phases groups" 'grep -q "phases. groups of .publish-gate. need the same Python 3.13" _docs/AGENT_GOTCHAS.md && echo "gotcha clause present"'
step "this loop changes documents only (so the push starts no CI run)" 'test -z "$(git diff --name-only aacbf04..HEAD | grep -v "^_docs/")" && echo "docs only"'
step "no tag in this loop (last tag is still v0.5.0)" 'test "$(git tag -l "v*" | sort -V | tail -1)" = v0.5.0 && echo v0.5.0'
step "the loop 107 push is green on dev (all jobs of its run)" 'gh run list --branch dev --workflow test --limit 5 --json headSha,conclusion --jq ".[]|select(.headSha|startswith(\"aacbf04\"))|.conclusion" | grep -qx success && echo "dev run of aacbf04 success"'

printf '\n%s of %s steps passed\n' "$((N-fails))" "$N"
test "$fails" -eq 0
```

# Loop 33 smoke — checks

LOCAL_URL: none (CI and test tooling, no UI; the proof is the CI runs and the step 11 log)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close (only `_docs/` files, the close commit)
- [x] 2. CI run 39031026351 (`19f4c33`): 23 of 23 jobs `success`, wall 251 s
- [ ] 3. `ring` at most 180 s: **209 s, FAIL** — accepted by the owner (2026-10-17, "Accept, record"): `ring` is no longer on the wall's path (`suites (swift, tests)` 248 s); C3 next loop
- [x] 4. One `ring preparation timing` notice with pull-gcc, pull-swift, swift-drivers, npm, cargo, go and the wait
- [x] 5. The five-image pull steps shorter: phases 35, phases-rerun 35, rest 51 s (were 57, about 57, 59)
- [x] 6. `scaffold` ran the `Swift ring wiring` and `ring preparation` steps, both `success`
- [x] 7. Step 11 (`scripts/loop-tests.sh`): PASS, 3 stages in 613 s
- [x] 8. Every changed script and workflow is at most 500 lines (largest 500: `ring-wiring.test.sh`)
- [x] 9. No tag contains a loop 33 commit, and `origin/main` does not contain the loop (no push of `main`)

## Result

Agent run 2026-10-17 at `19f4c33` (owner rule 2026-10-12 in `deployment_procedures.md`): **8/9 steps passed**; step 3 failed (`ring` 209 s against 180 s). Per the rule a failed step stops the gate: the owner was asked with the numbers and chose to accept the miss and close (2026-10-17). Smoke: PASS with one accepted miss.

## For the operator

- AC-1 is the median of two runs: run 1 is 251 s; run 2 is the close push (recorded after it in `notes33.md`).
- `suites (swift, tests)` (248 s) and `suites (swift, speed)` (221 s) set the wall now; `ring`'s path is the swift pull plus the 84 s Swift driver build.
- The two vcpkg checks are NOT RUN on this Mac (no vcpkg tool); the CI job `publish-gate-rest` runs them (green in run 1).
- `main` was not pushed, no tag. `ubuntu-latest` moves to Ubuntu 26 from 2026-10-19.

## Script (run with the CI run id: `bash smoke33.sh 39031026351`)

```bash
#!/usr/bin/env bash
# Loop 33 smoke (AZ-2626): smoke33.sh <run id>. One line per step: [n/N] title, then PASS (Ns) <result> or FAIL with
# the reason. Reads the CI run from the public GitHub API (no token), the rest from the tree.
set -uo pipefail
run="${1:?run id}"
repo=/Users/zxsanny/dev/zxsanny/packbin
api=https://api.github.com/repos/zxsanny/packbin
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$repo" || exit 1
N=9 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; }

curl -sS -m 30 "$api/actions/runs/$run" -o "$work/run.json" < /dev/null
curl -sS -m 30 "$api/actions/runs/$run/jobs?per_page=50" -o "$work/jobs.json" < /dev/null
py() { python3 -I - "$work" "$@" < /dev/stdin; }

step "No application source is dirty (only _docs/ may be)"
dirty="$(git status --porcelain | grep -v ' _docs/' || true)"
if [ -z "$dirty" ]; then ok "tree clean outside _docs/ at $(git rev-parse --short HEAD)"; else ko "$dirty"; fi

step "CI run $run: every job success, wall time"
out="$(py <<'PY'
import json, sys, datetime as d
w = sys.argv[1]
run = json.load(open(w + "/run.json")); jobs = json.load(open(w + "/jobs.json"))["jobs"]
t = lambda s: d.datetime.fromisoformat(s.replace("Z", "+00:00"))
bad = [j["name"] for j in jobs if j["conclusion"] != "success"]
wall = (max(t(j["completed_at"]) for j in jobs) - t(run["created_at"])).total_seconds()
print(("OK" if run["conclusion"] == "success" and not bad else "BAD"), f"{len(jobs)} jobs, wall {wall:.0f} s, head {run['head_sha'][:7]}, not green: {bad}")
PY
)"
case "$out" in OK*) ok "${out#OK }" ;; *) ko "$out" ;; esac

step "ring job at most 180 s, its steps"
out="$(py <<'PY'
import json, sys, datetime as d
jobs = json.load(open(sys.argv[1] + "/jobs.json"))["jobs"]
t = lambda s: d.datetime.fromisoformat(s.replace("Z", "+00:00"))
j = next(j for j in jobs if j["name"] == "ring")
s = (t(j["completed_at"]) - t(j["started_at"])).total_seconds()
steps = "; ".join(f"{x['name'][:28]} {(t(x['completed_at']) - t(x['started_at'])).total_seconds():.0f}" for x in j["steps"] if x.get("completed_at") and not x["name"].startswith("Post"))
print(("OK" if s <= 180 else "BAD"), f"ring {s:.0f} s: {steps}")
PY
)"
case "$out" in OK*) ok "${out#OK }" ;; *) ko "$out" ;; esac

step "ring preparation timing notice: every build and the wait"
rid="$(python3 -I -c 'import json,sys; print(next(j["id"] for j in json.load(open(sys.argv[1]))["jobs"] if j["name"]=="ring"))' "$work/jobs.json")"
curl -sS -m 30 "$api/check-runs/$rid/annotations?per_page=100" -o "$work/ring-ann.json" < /dev/null
out="$(python3 -I -c '
import json,sys
a=[x["message"] for x in json.load(open(sys.argv[1])) if x.get("title")=="ring preparation timing"]
need=["pull-gcc","pull-swift","swift-drivers","npm","cargo","go","the wait took"]
miss=[n for n in need if not a or n not in a[0]]
print(("OK" if len(a)==1 and not miss else "BAD"), (a[0].replace(chr(10)," | ") if a else "no notice"), "missing:", miss)' "$work/ring-ann.json")"
case "$out" in OK*) ok "${out#OK }" ;; *) ko "$out" ;; esac

step "Five-image pull steps shorter than run 39025925515 (phases 57, phases-rerun ~57, rest 59 s)"
out="$(py <<'PY'
import json, sys, datetime as d
jobs = json.load(open(sys.argv[1] + "/jobs.json"))["jobs"]
t = lambda s: d.datetime.fromisoformat(s.replace("Z", "+00:00"))
was = {"publish-gate-phases": 57, "publish-gate-phases-rerun": 57, "publish-gate-rest": 59}
res, okk = [], True
for name, before in was.items():
    j = next(j for j in jobs if j["name"] == name)
    st = next(x for x in j["steps"] if x["name"] == "pull images")
    s = (t(st["completed_at"]) - t(st["started_at"])).total_seconds()
    okk &= s < before
    res.append(f"{name.replace('publish-gate-', '')} {s:.0f} s (was {before})")
print(("OK" if okk else "BAD"), "; ".join(res))
PY
)"
case "$out" in OK*) ok "${out#OK }" ;; *) ko "$out" ;; esac

step "scaffold ran the Swift ring wiring and ring preparation steps"
out="$(py <<'PY'
import json, sys
jobs = json.load(open(sys.argv[1] + "/jobs.json"))["jobs"]
j = next(j for j in jobs if j["name"] == "scaffold")
st = {x["name"]: x["conclusion"] for x in j["steps"]}
want = ["Swift ring wiring", "ring preparation"]
print(("OK" if all(st.get(w) == "success" for w in want) else "BAD"), {w: st.get(w) for w in want})
PY
)"
case "$out" in OK*) ok "${out#OK }" ;; *) ko "$out" ;; esac

step "Step 11 report: PASS"
if grep -q '^Verdict: PASS' _docs/03_implementation/test_run_loop33_report.md; then ok "$(sed -n 's/^TEST RESULTS: //p' _docs/03_implementation/test_run_loop33_report.md)"; else ko "no PASS verdict"; fi

step "Changed scripts and workflow at most 500 lines"
long="$(git diff --name-only a67aade..HEAD -- .github scripts | while read -r f; do [ -f "$f" ] && [ "$(wc -l < "$f")" -gt 500 ] && echo "$f"; done)"
max="$(git diff --name-only a67aade..HEAD -- .github scripts | while read -r f; do [ -f "$f" ] && wc -l < "$f"; done | sort -n | tail -n 1)"
if [ -z "$long" ]; then ok "largest $max lines"; else ko "$long"; fi

step "No tag and no origin/main contains a loop 33 commit"
tags="$(git tag --contains 57fa391 2>&1)"
if [ -z "$tags" ] && ! git merge-base --is-ancestor 57fa391 origin/main; then ok "no tag, origin/main $(git rev-parse --short origin/main)"; else ko "tags: $tags"; fi

echo "$passed/$N steps passed"
[ "$passed" -eq "$N" ]
```

## Output

```
[1/9] No application source is dirty (only _docs/ may be)
  PASS (0s) tree clean outside _docs/ at 19f4c33
[2/9] CI run 39031026351: every job success, wall time
  PASS (0s) 23 jobs, wall 251 s, head 19f4c33, not green: []
[3/9] ring job at most 180 s, its steps
  FAIL BAD ring 209 s: Set up job 8; Run actions/checkout@3d3c42e 2; start image pulls and the Sw 0; Run actions/setup-dotnet@a98 20; Run actions/setup-node@82076 1; Run actions/setup-python@5fd 0; Run actions/setup-java@de727 3; Run actions/setup-go@b7ad1da 25; Rust toolchain 11; driver dependencies and buil 92; toolchain versions 2; cross-language ring 39; Complete job 0
[4/9] ring preparation timing notice: every build and the wait
  PASS (1s) ring-prepare: pull-gcc took 73 s | ring-prepare: pull-swift took 68 s | ring-prepare: swift-drivers took 84 s | ring-prepare: npm took 2 s | ring-prepare: cargo took 2 s | ring-prepare: go took 1 s | ring-prepare: the wait took 89 s (limit 900 s), 152 s since start missing: []
[5/9] Five-image pull steps shorter than run 39025925515 (phases 57, phases-rerun ~57, rest 59 s)
  PASS (0s) phases 35 s (was 57); phases-rerun 35 s (was 57); rest 51 s (was 59)
[6/9] scaffold ran the Swift ring wiring and ring preparation steps
  PASS (0s) {'Swift ring wiring': 'success', 'ring preparation': 'success'}
[7/9] Step 11 report: PASS
  PASS (0s) 3 stages passed, 0 failed, 0 errors (no serial re-run)
[8/9] Changed scripts and workflow at most 500 lines
  PASS (0s) largest      500 lines
[9/9] No tag and no origin/main contains a loop 33 commit
  PASS (0s) no tag, origin/main 2cade74
8/9 steps passed
```

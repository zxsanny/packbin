#!/usr/bin/env bash
# Is there a green test run for the commit a v* tag points at? (publish.yml, job `precheck`.)
# Asks the Actions runs API for runs of test.yml at PACKBIN_SHA (the answer is read by python3 -I, standard
# library only) and writes green=true to $GITHUB_OUTPUT only for a completed, successful push run of this
# repository whose workflow path is .github/workflows/test.yml. Anything
# else (no run, a red or running one, a failed API call, an answer that is not JSON) writes green=false and says
# why: the publish workflow then runs the whole test workflow itself. The script never fails a run and never
# decides to publish; publish.yml does that from the output and the result of the test job.
#
# Environment: PACKBIN_REPO (owner/name), PACKBIN_SHA (40 hex), GH_TOKEN (actions: read), GITHUB_OUTPUT (default
# stdout), PACKBIN_API (default https://api.github.com).
# Exit: 0 always for a lookup result; 2 for a missing or malformed PACKBIN_REPO or PACKBIN_SHA.
set -euo pipefail

repo="${PACKBIN_REPO:-}"
sha="${PACKBIN_SHA:-}"
api="${PACKBIN_API:-https://api.github.com}"
out="${GITHUB_OUTPUT:-/dev/stdout}"

if ! printf '%s' "$repo" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
  echo "precheck: PACKBIN_REPO is not owner/name: [$repo]" >&2
  exit 2
fi
if ! printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
  echo "precheck: PACKBIN_SHA is not a 40 hex commit: [$sha]" >&2
  exit 2
fi

no_proof() {
  echo "precheck: $1; the test workflow runs for this tag"
  echo "green=false" >> "$out"
  exit 0
}

url="$api/repos/$repo/actions/workflows/test.yml/runs?head_sha=$sha&event=push&status=success&per_page=100"
auth=()
if [ -n "${GH_TOKEN:-}" ]; then
  auth=(-H "Authorization: Bearer $GH_TOKEN")
fi
body="$(mktemp)"
trap 'rm -f "$body"' EXIT
if ! curl -fsS --max-time 30 --retry 2 "${auth[@]+"${auth[@]}"}" -H "Accept: application/vnd.github+json" \
  "$url" > "$body" < /dev/null; then
  no_proof "the runs API call failed"
fi

read -r -d '' lookup <<'PYTHON' || true
import json
import sys

body, repo, sha = sys.argv[1:4]
try:
    with open(body, "rb") as f:
        data = json.load(f)
except OSError as e:
    print(f"bad:the runs API answer could not be read ({type(e).__name__})")
    sys.exit(0)
except (json.JSONDecodeError, UnicodeDecodeError, RecursionError) as e:
    print(f"bad:the runs API answer is not JSON ({type(e).__name__})")
    sys.exit(0)
runs = data.get("workflow_runs") if isinstance(data, dict) else None
if not isinstance(runs, list):
    print("bad:the runs API answer has no workflow_runs")
    sys.exit(0)


def is_green(r):
    return (
        isinstance(r, dict)
        and r.get("head_sha") == sha
        and r.get("event") == "push"
        and r.get("status") == "completed"
        and r.get("conclusion") == "success"
        and str(r.get("path")).split("@")[0] == ".github/workflows/test.yml"
        and isinstance(r.get("head_repository"), dict)
        and r["head_repository"].get("full_name") == repo
    )


good = next((r for r in runs if is_green(r)), None)
if good is None:
    print(f"none:{len(runs)}")
else:
    print(f"ok:{good.get('id') or ''}:{good.get('head_branch') or ''}")
PYTHON
verdict="$(python3 -I -c "$lookup" "$body" "$repo" "$sha")"

case "$verdict" in
  ok:*)
    run_id="${verdict#ok:}"
    echo "precheck: test run ${run_id%%:*} on ${run_id#*:} is green for $sha; the test workflow is skipped for this tag"
    echo "green=true" >> "$out"
    ;;
  bad:*) no_proof "${verdict#bad:}" ;;
  *) no_proof "no successful push run of test.yml for $sha" ;;
esac

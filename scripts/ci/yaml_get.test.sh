#!/usr/bin/env bash
# scripts/ci/yaml_get.py reads the CI YAML for the CI scripts: the two forms of the `on:` key, the
# YAML 1.1 words, anchors and merge keys, and the three ways a read can fail (no PyYAML, no file, not YAML), each of
# which must exit 2 and name its cause.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
bad() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# py <program> [args]: the program runs under python3 -I with this directory on sys.path, as the CI scripts do.
py() {
  local program="$1"
  shift
  python3 -I -c "import sys; sys.path.insert(0, sys.argv[1]); $program" "$here" "$@"
}

# Arrange
printf 'on: [push, pull_request]\njobs: {}\n' > "$work/bare.yml"
printf '"on": [push, pull_request]\njobs: {}\n' > "$work/quoted.yml"
cat > "$work/words.yml" <<'YAML'
base: &base {a: 1, b: 2}
derived: {<<: *base, b: 3}
flags: {x: yes, y: no, z: off}
YAML
printf 'jobs: [unclosed\n' > "$work/malformed.yml"

# Act and assert: the two forms of `on:` give the same triggers
for name in bare quoted; do
  got="$(py 'import yaml_get; print(yaml_get.triggers(yaml_get.load(sys.argv[2])))' "$work/$name.yml")"
  [ "$got" = "['push', 'pull_request']" ] || bad "on: in $name.yml read as [$got]"
done

# Act and assert: anchors, merge keys and the YAML 1.1 words read as safe_load reads them
got="$(py 'import yaml_get; d = yaml_get.load(sys.argv[2]); print(d["derived"], d["flags"])' "$work/words.yml")"
[ "$got" = "{'a': 1, 'b': 3} {'x': True, 'y': False, 'z': False}" ] || bad "words.yml read as [$got]"

# Act and assert: each failure exits 2 and names its cause
expect_refusal() {
  local label="$1" wanted="$2" out code=0
  shift 2
  out="$("$@" 2>&1 < /dev/null)" || code=$?
  [ "$code" -eq 2 ] || bad "$label: exit $code, wanted 2: $out"
  grep -qF -- "$wanted" <<< "$out" || bad "$label: the cause is not named ($wanted): $out"
}
expect_refusal "no PyYAML" "PyYAML is required to parse the workflow YAML" \
  python3 -I -c 'import sys; sys.modules["yaml"] = None; sys.path.insert(0, sys.argv[1]); import yaml_get' "$here"
expect_refusal "no file" "cannot read $work/missing.yml" py 'import yaml_get; yaml_get.load(sys.argv[2])' "$work/missing.yml"
expect_refusal "not YAML" "$work/malformed.yml is not valid YAML" py 'import yaml_get; yaml_get.load(sys.argv[2])' "$work/malformed.yml"

# Assert: safe_load only, one reader. Nothing else loads YAML; the one other importer only dumps (the mutants of
# publish-jobs-mutate.py write a changed copy of test.yml).
if grep -nE 'yaml\.(load|unsafe_load|full_load)\(' "$here/yaml_get.py"; then bad "yaml_get.py does not use safe_load only"; fi
root="$(cd "$here/../.." && pwd)"
loaders="$(grep -rlE '^[[:space:]]*(import|from)[[:space:]]+yaml\b|\byaml\.(safe_load|load|full_load|unsafe_load)\(' \
  "$root/.github/workflows" "$root/scripts" --include='*.py' --include='*.sh' | grep -v -e '/scripts/ci/yaml_get.py$' -e '/scripts/ci/yaml_get.test.sh$' -e '/publish-jobs-mutate.py$' || true)"
[ -z "$loaders" ] || bad "YAML is read outside scripts/ci/yaml_get.py: $loaders"
if grep -nE '\byaml\.(safe_load|load|full_load|unsafe_load)\(' "$root/.github/workflows/publish-jobs-mutate.py"; then bad "publish-jobs-mutate.py reads YAML itself"; fi

if [ "$failures" -eq 0 ]; then echo "yaml_get.test.sh: all checks passed"; fi
exit "$failures"

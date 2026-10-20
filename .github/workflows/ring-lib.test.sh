#!/usr/bin/env bash
# Test of the split of the ring runner (AZ-2744 AC-4): language-pair.sh and ring-ecc.sh read run_lang from ring-lib.sh,
# so a tree without ring-lib.sh, or with one that has no run_lang, ends each of them with a non-zero exit and one line
# that names ring-lib.sh. Run in temp trees that hold copies of the two scripts: nothing in the repo is touched.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# expect_names_lib <label> <tree> <script>: the copy of <script> in <tree> exits non-zero and prints a line naming ring-lib.sh.
expect_names_lib() {
  local label="$1" dir="$2/.github/workflows" script="$3" out rc=0
  out="$(bash "$dir/$script" < /dev/null 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'ring-lib\.sh' <<< "$out"; then
    echo "names ring-lib.sh: $label (exit $rc)"
  else
    fail "$label: exit $rc, output [$out], expected a non-zero exit and a line naming ring-lib.sh"
  fi
}

for script in language-pair.sh ring-ecc.sh; do
  # Arrange: a tree with the script and no ring-lib.sh
  missing="$tmp/missing-$script"
  mkdir -p "$missing/.github/workflows"
  cp "$here/$script" "$missing/.github/workflows/"
  # Act, Assert
  expect_names_lib "$script, ring-lib.sh missing" "$missing" "$script"

  # Arrange: ring-lib.sh present but without run_lang
  empty="$tmp/empty-$script"
  mkdir -p "$empty/.github/workflows"
  cp "$here/$script" "$empty/.github/workflows/"
  echo '# no run_lang here' > "$empty/.github/workflows/ring-lib.sh"
  expect_names_lib "$script, ring-lib.sh without run_lang" "$empty" "$script"
done

# The real files still agree: both scripts find run_lang in the real ring-lib.sh.
if ! grep -qx 'run_lang() {' "$here/ring-lib.sh"; then fail "ring-lib.sh has no run_lang"; fi

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "ring-lib checks passed"

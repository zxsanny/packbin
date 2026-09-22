#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"

root="$(publish_root)"
fixture="${PACKBIN_FIXTURE:-$root/fixtures/golden.hex}"
expected="$(fixture_hex "$fixture")"
out="${PACKBIN_OUT:-$root/.github/workflows/out}"
mkdir -p "$out"
plan="$out/publish-plan.txt"
: > "$plan"

run_pack() {
  local lang="$1"
  if [ "${PACKBIN_DOCKER:-1}" = "0" ]; then
    SRC_ROOT="$root" bash "$here/publish-position.sh" "$lang"
    return
  fi
  docker compose -f "$root/docker-compose.test.yml" --project-directory "$root" \
    -p packbin-publish run -T --rm --no-deps \
    -e SRC_ROOT=/src \
    "$lang" "exec /src/.github/workflows/publish-position.sh $lang"
}

last_line() {
  printf '%s\n' "$1" | sed '/^[[:space:]]*$/d' | tail -n 1 | tr -d '[:space:]'
}

mismatch=0
present=()
for lang in "${PACKBIN_LANGS[@]}"; do
  if ! language_present "$root" "$lang"; then
    echo "absent $lang"
    continue
  fi
  hex="$(last_line "$(run_pack "$lang")")"
  echo "pack $lang $hex"
  if [ "$hex" != "$expected" ]; then
    mismatch=$((mismatch + $(byte_mismatch "$hex" "$expected")))
  fi
  present+=("$lang")
done

echo "mismatch $mismatch"
if [ "$mismatch" -gt 0 ]; then
  echo "publishing 0 packages"
  exit 1
fi

printf '%s\n' "${present[@]}" > "$plan"
for lang in "${present[@]}"; do
  echo "publish $lang"
done

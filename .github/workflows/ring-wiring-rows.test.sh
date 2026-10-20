#!/usr/bin/env bash
# Wiring check of language-pair.sh and its drivers (AZ-2238 AC-4, AC-5; AZ-2307 AC-2, AC-3; AZ-2449 AC-3), the sibling
# of ring-wiring.test.sh (the checks of test.yml): language-pair.sh against PATH shims for its toolchains
# (consumer_failure_checks), the C# element rings (element_ring_checks) and the Go ring (go_ring_checks). Every guard is
# proven against a temp copy with one piece removed: the copy must be rejected, naming it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ring-wiring-lib.sh
source "$here/ring-wiring-lib.sh" # tmp, failures, fail
ring_all="$tmp/ring-all.sh" # the rows (language-pair.sh) and the runner (ring-lib.sh) in one file: the guards read both
cat "$here/ring-lib.sh" "$here/language-pair.sh" > "$ring_all"

# write_shim <dir> <tool> <pack output> <pack exit status> <unpack exit status>: a stand-in for the toolchain command
# <tool> the ring runs. A pack-* command prints <pack output> and exits with the pack status, an unpack-* command exits
# with the unpack status; every call is logged to $SHIM_LOG.
write_shim() {
  cat > "$1/$2" <<SHIM
#!/bin/sh
echo "$2 \$*" >> "\$SHIM_LOG"
for arg in "\$@"; do
  case "\$arg" in
    pack-*) printf '%s\n' '$3'; exit $4 ;;
    unpack-*) exit $5 ;;
  esac
done
SHIM
  chmod +x "$1/$2"
}

# expect_ring <label> <expected output> <exit status>: runs language-pair.sh in the temp tree, the shims first on PATH.
expect_ring() {
  local label="$1" want="$2" want_rc="$3" out rc=0
  : > "$shim_log"
  out="$(PATH="$shims:$PATH" SHIM_LOG="$shim_log" bash "$ring_tree/.github/workflows/language-pair.sh" 2>&1)" || rc=$?
  if [ "$out" != "$want" ] || [ "$rc" -ne "$want_rc" ]; then
    fail "$label: exit $rc, output [$out], expected exit $want_rc, output [$want]"
  else
    echo "names the pair: $label ($out)"
  fi
}

# AZ-2238 AC-4, AC-5: a pair that fails ends the script with exit 1 and one line that names it. The first
# pair is csharp -> typescript, the second typescript -> python; the script stops at the first failure.
consumer_failure_checks() {
  # expect_ring reads these three (bash scopes a local to the functions it calls).
  local user_hex shim_log="$tmp/shim.log" shims="$tmp/shims" ring_tree="$tmp/ring-tree"
  user_hex="$(sed -n 's/^user_hex="\([0-9a-f]*\)"$/\1/p' "$here/language-pair.sh")"
  if [ -z "$user_hex" ]; then
    fail "language-pair.sh has no user_hex line to feed the shims"
    return
  fi
  mkdir -p "$shims" "$ring_tree/.github/workflows"
  cp "$here/language-pair.sh" "$here/ring-lib.sh" "$ring_tree/.github/workflows/"

  write_shim "$shims" dotnet "$user_hex" 0 0
  write_shim "$shims" python3 "$user_hex" 0 0
  write_shim "$shims" node "$user_hex" 0 1
  expect_ring "the node consumer fails" "typescript unpack-user failed on the bytes packed by csharp" 1

  write_shim "$shims" node "$user_hex" 0 0
  write_shim "$shims" python3 "$user_hex" 0 1
  expect_ring "the python consumer fails after a passing node" \
    "python unpack-user failed on the bytes packed by typescript" 1

  write_shim "$shims" python3 "$user_hex" 0 0
  write_shim "$shims" dotnet 00 0 0
  expect_ring "the csharp producer prints other bytes" "csharp pack-user mismatch" 1
  if grep -q 'unpack' "$shim_log"; then
    fail "a consumer ran after a producer mismatch: $(cat "$shim_log")"
  fi

  write_shim "$shims" dotnet "$user_hex" 1 0
  expect_ring "the csharp producer exits 1 while packing" "csharp pack-user failed" 1
}

# AZ-2307 AC-2, AC-3: C# is a producer and a consumer of each element ring (listgroup, dictgroup, listflags) in
# language-pair.sh, refuses their short packets there, and has the three commands in its driver. Prints one line per
# missing piece of the script $1 (default: the real one) or of the driver $2 (default: the real one). The driver builds
# its commands as pack-{kind}, unpack-{kind} and unpack-{kind}-short for each kind in the array of its Run loop.
element_ring_violations() {
  local script="${1:-$ring_all}" driver="${2:-$here/drivers/csharp/HandoffElements.cs}" kind form
  for form in 'pack-{kind}' 'unpack-{kind}' 'unpack-{kind}-short'; do
    grep -qF "\$\"$form\"" "$driver" \
      || echo "the csharp driver does not build the command $form"
  done
  for kind in listgroup dictgroup listflags; do
    grep -Eq "^handoff csharp [a-z]+ ${kind} \"[$]${kind}_hex\"\$" "$script" \
      || echo "no handoff line with csharp as the producer of $kind"
    grep -Eq "^handoff [a-z]+ csharp ${kind} \"[$]${kind}_hex\"\$" "$script" \
      || echo "no handoff line with csharp as the consumer of $kind"
    grep -E 'foreach [(]var kind in new' "$driver" | grep -qF "\"$kind\"" \
      || echo "the csharp driver has no command for $kind"
  done
  # The loop that refuses the short packets is the last "for lang in" line before the one that names the rows.
  awk '/^for lang in /{ langs = $0 } /for row in "listgroup/{ print langs }' "$script" | grep -Eq '[ ]csharp[ ;]' \
    || echo "csharp is not in the loop that refuses the short element packets"
}

# expect_element_ring_rejected <label> <language-pair.sh copy>: the copy lacks something and the check names it.
expect_element_ring_rejected() {
  local label="$1" copy="$2" out
  if cmp -s "$ring_all" "$copy"; then
    fail "temp copy is unchanged: $label"
    return
  fi
  out="$(element_ring_violations "$copy")"
  if [ -z "$out" ]; then
    fail "the element ring check passed a script without: $label"
  else
    echo "rejects: $label ($out)"
  fi
}

# expect_driver_rejected <label> <driver copy>: the copy lacks a command and the check names it.
expect_driver_rejected() {
  local label="$1" copy="$2" out
  if cmp -s "$here/drivers/csharp/HandoffElements.cs" "$copy"; then
    fail "temp copy is unchanged: $label"
    return
  fi
  out="$(element_ring_violations "$ring_all" "$copy")"
  if [ -z "$out" ]; then
    fail "the element ring check passed a driver without: $label"
  else
    echo "rejects: $label ($out)"
  fi
}

element_ring_checks() {
  local out kind
  out="$(element_ring_violations)"
  if [ -n "$out" ]; then
    fail "language-pair.sh: $out"
    return
  fi
  for kind in listgroup dictgroup listflags; do
    sed "/^handoff csharp [a-z]* ${kind} /d" "$ring_all" > "$tmp/no-producer-$kind.sh"
    expect_element_ring_rejected "the csharp producer line of $kind" "$tmp/no-producer-$kind.sh"
    sed "/^handoff [a-z]* csharp ${kind} /d" "$ring_all" > "$tmp/no-consumer-$kind.sh"
    expect_element_ring_rejected "the csharp consumer line of $kind" "$tmp/no-consumer-$kind.sh"
  done
  for kind in listgroup dictgroup listflags; do
    sed "/foreach (var kind in new/s/\"$kind\"[,]* *//" "$here/drivers/csharp/HandoffElements.cs" > "$tmp/no-driver-$kind.cs"
    expect_driver_rejected "the $kind case of the csharp driver" "$tmp/no-driver-$kind.cs"
  done
  for form in 'pack-{kind}' 'unpack-{kind}-short'; do
    sed "s/\$\"$form\"/\$\"x$form\"/" "$here/drivers/csharp/HandoffElements.cs" > "$tmp/no-form-$form.cs"
    expect_driver_rejected "the $form command of the csharp driver" "$tmp/no-form-$form.cs"
  done
  sed 's/^for lang in typescript python java csharp go; do$/for lang in typescript python java go; do/' \
    "$ring_all" > "$tmp/no-short-csharp.sh"
  expect_element_ring_rejected "csharp in the short packet loop" "$tmp/no-short-csharp.sh"
}

# AZ-2449 AC-3: Go joins every kind of language-pair.sh both ways with each member of that kind's ring (go_members),
# refuses the short element packets, packs the session and the position row, and has its kinds in the driver.
go_kinds="user nested boolflag booltrue bitwhen roundflags roundwhen listgroup dictgroup listflags session session-ecc" # session-ecc: AZ-2739, hex in session_ecc_hex
go_members() {
  case "$1" in
    roundflags | roundwhen) echo "csharp typescript rust java cpp" ;;
    listgroup | dictgroup | listflags) echo "typescript python java csharp" ;;
    *) echo "csharp typescript python rust java cpp" ;;
  esac
}
go_expected_lines() {
  local kind member
  for kind in $go_kinds; do
    for member in $(go_members "$kind"); do
      # C# only produces the round kinds (no public C# API reads an aligned round row yet).
      case "$kind$member" in roundflagscsharp | roundwhencsharp) ;; *) echo "handoff go $member $kind \"\$${kind//-/_}_hex\"" ;; esac
      echo "handoff $member go $kind \"\$${kind//-/_}_hex\""
    done
  done
}

# go_ring_violations [script] [driver kinds.go] [toolchains]: one line per missing piece (defaults: the real files).
go_ring_violations() {
  local script="${1:-$ring_all}" driver="${2:-$here/drivers/handoff-go/kinds.go}"
  local toolchains="${3:-$here/ring-toolchains.sh}" kind row tab=$'\t'
  go_expected_lines > "$tmp/go-expected.txt"
  grep -Fxv -f "$script" "$tmp/go-expected.txt" | sed 's/^/no handoff line: /' || true
  grep -Eq '^    go[)]$' "$script" || echo "run_lang has no go case"
  for row in 'for row in "listgroup|short element packets' '"pack-session"|pack-session' '"pack-session-ecc"|pack-session-ecc' 'publish-position[.]sh|position row'; do
    awk -v pat="${row%%|*}" '/^for lang in /{ langs = $0 } index($0, pat) || $0 ~ pat { print langs }' "$script" \
      | grep -Eq '[ ]go[ ;]' || echo "go is not in the loop that checks ${row#*|}"
  done
  for kind in ${go_kinds% session session-ecc}; do
    grep -q "^${tab}${tab}\"$kind\": *{" "$driver" || echo "the go driver has no kind $kind"
  done
  for kind in listgroup dictgroup listflags; do
    grep '^var short = ' "$driver" | grep -qF "\"$kind\": true" || echo "the go driver does not refuse the short $kind packet"
  done
  grep -qF 'check go "${RING_GO:?}"' "$toolchains" || echo "ring-toolchains.sh does not check the Go version"
}

# expect_go_rejected <label> <script copy> [<driver copy> [<toolchains copy>]]: the copy lacks something, the check names it.
expect_go_rejected() {
  local label="$1" copy="$2" driver="${3:-}" tools="${4:-}" out
  if cmp -s "$ring_all" "$copy" && [ -z "$driver$tools" ]; then fail "temp copy is unchanged: $label"; return; fi
  out="$(go_ring_violations "$copy" "${driver:-$here/drivers/handoff-go/kinds.go}" "${tools:-$here/ring-toolchains.sh}")"
  if [ -z "$out" ]; then
    fail "the Go ring check passed a copy without: $label"
  else
    echo "rejects: $label ($out)"
  fi
}

go_ring_checks() {
  local line n=0 kind tab=$'\t' out
  out="$(go_ring_violations)"
  if [ -n "$out" ]; then fail "go ring: $out"; return; fi
  # Every one of the Go handoff lines, removed alone, is named.
  while IFS= read -r line; do
    n=$((n + 1))
    grep -Fxv -- "$line" "$ring_all" > "$tmp/no-go-line.sh"
    if ! go_ring_violations "$tmp/no-go-line.sh" | grep -qF "no handoff line: $line"; then
      fail "removing [$line] was not named by the Go ring check"
    fi
  done < "$tmp/go-expected.txt"
  echo "rejects: each of the $n Go handoff lines removed alone"
  sed 's/^\(for lang in .*\) go; do$/\1; do/' "$ring_all" > "$tmp/no-loop-go.sh"
  expect_go_rejected "go in the short packet, pack-session and position loops" "$tmp/no-loop-go.sh"
  awk '/^    go[)]$/ { sub(/go[)]/, "gox)") } { print }' "$ring_all" > "$tmp/no-go-case.sh"
  expect_go_rejected "the go case of run_lang" "$tmp/no-go-case.sh"
  for kind in user dictgroup; do
    sed "s/^\\(${tab}${tab}\\)\"$kind\": {/\\1\"x$kind\": {/" "$here/drivers/handoff-go/kinds.go" > "$tmp/no-driver-$kind.go"
    expect_go_rejected "the $kind kind of the go driver" "$ring_all" "$tmp/no-driver-$kind.go"
  done
  sed 's/"listflags": true//' "$here/drivers/handoff-go/kinds.go" > "$tmp/no-short-listflags.go"
  expect_go_rejected "the short listflags refusal of the go driver" "$ring_all" "$tmp/no-short-listflags.go"
  sed 's/^check go /check gox /' "$here/ring-toolchains.sh" > "$tmp/no-go-toolchain.sh"
  expect_go_rejected "the Go version check" "$ring_all" "" "$tmp/no-go-toolchain.sh"
}

consumer_failure_checks
element_ring_checks
go_ring_checks

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "ring row wiring checks passed"

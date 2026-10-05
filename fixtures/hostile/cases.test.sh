#!/usr/bin/env bash
# Tests the hostile-case format check: the committed file passes, corrupted copies fail.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
check="$here/check-cases.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ids="zero_progress_repeat_bool zero_progress_repeat_when negative_count oversize_count
oversize_count_times oversize_list_count invalid_utf8 invalid_utf8_dict_key
count_behind_clear_flag count_behind_clear_flag_bits nine_flag_bits nine_flag_bits_split
when_names_later_field count_names_later_field when_names_outer_field_in_repeat
bool_outside_flags empty_group_outside_flags"

out="$(bash "$check")"
echo "$out"
[[ "$out" == "hostile cases ok: 17" ]]
for id in $ids; do
  grep -q "^$id " "$here/cases.txt"
done

# Each corruption must make the check fail and name the offending line.
corrupt() {
  local name="$1" from="$2" to="$3"
  sed "s/$from/$to/" "$here/cases.txt" >"$tmp/$name.txt"
  if bash "$check" "$tmp/$name.txt" "$here/README.md" 2>"$tmp/$name.err"; then
    echo "$name: check passed on a corrupted file" >&2
    exit 1
  fi
  grep -q "$name.txt:[0-9]*:" "$tmp/$name.err"
  echo "$name: rejected"
}

corrupt odd_hex "01ff\$" "01f"
corrupt bad_stage "unpack     trailing_bytes|scheme_error  01ff" "unpackk    trailing_bytes|scheme_error  01ff"
corrupt unknown_term "short_packet                 01ffffffff61" "shortpacket                  01ffffffff61"
corrupt duplicate_id "^negative_count " "zero_progress_repeat_bool "
echo "hostile case tests passed"

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
bool_outside_flags empty_group_outside_flags repeat_rounds_over_limit times_rounds_over_limit"

out="$(bash "$check")"
echo "$out"
[[ "$out" == "hostile cases ok: 19" ]]
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

# The limit stage takes the same checks as unpack: hex starts 01, is even and lowercase; the stage name is exact.
corrupt limit_dash_hex "0111223344\$" "-"
corrupt limit_odd_hex "010411223344\$" "01041122334"
corrupt limit_bad_stage "^repeat_rounds_over_limit *limit " "repeat_rounds_over_limit limitt "
corrupt limit_unknown_term "too_many|bad_value *0111223344" "too_many|bad_valu 0111223344"
corrupt limit_duplicate_id "^times_rounds_over_limit " "repeat_rounds_over_limit "

# Every id needs its README section: a copy without one new section is rejected and names the id.
sed "s/^## times_rounds_over_limit\$/## times_rounds_over_limit_x/" "$here/README.md" >"$tmp/no_section.md"
if bash "$check" "$here/cases.txt" "$tmp/no_section.md" 2>"$tmp/no_section.err"; then
  echo "no_section: check passed on a README without the section" >&2
  exit 1
fi
grep -q "id 'times_rounds_over_limit' has no '## times_rounds_over_limit' section" "$tmp/no_section.err"
echo "no_section: rejected"
echo "hostile case tests passed"

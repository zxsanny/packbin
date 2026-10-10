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
bool_outside_flags empty_group_outside_flags eq_bool_false repeat_rounds_over_limit times_rounds_over_limit
pack_out_of_range_integer pack_missing_required_value pack_times_list_too_long
pack_times_list_too_short pack_aligned_round_row"

out="$(bash "$check")"
echo "$out"
[[ "$out" == "hostile cases ok: 25" ]]
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

# The pack stage: `bytes` carries the packet hex, `pack_error` carries `-`, and only the pack stage uses either term.
corrupt pack_bytes_dash_hex "01030102020303\$" "-"
corrupt pack_error_with_hex "pack_error  *-\$" "pack_error 01"
corrupt pack_odd_hex "01030102020303\$" "0103010202030"
corrupt pack_hex_not_01 "01030102020303\$" "02030102020303"
corrupt pack_unpack_term "pack_error  *-\$" "short_packet 01"
corrupt unpack_uses_bytes "bad_value|short_packet  *01ff61" "bytes 01ff61"
corrupt unpack_uses_pack_error "short_packet  *01ffffffff61" "pack_error 01ffffffff61"
corrupt construct_uses_pack_error "scheme_error  *-\$" "pack_error -"
corrupt pack_duplicate_id "^pack_times_list_too_short " "pack_times_list_too_long "

# A pack case needs its README section, and the Run by and Not run by lists must name each package exactly once.
corrupt_readme() {
  local name="$1" expr="$2" message="$3"
  sed "$expr" "$here/README.md" >"$tmp/$name.md"
  if bash "$check" "$here/cases.txt" "$tmp/$name.md" 2>"$tmp/$name.err"; then
    echo "$name: check passed on a corrupted README" >&2
    exit 1
  fi
  grep -q "$message" "$tmp/$name.err"
  echo "$name: rejected"
}

corrupt_readme pack_no_section "s/^## pack_aligned_round_row\$/## pack_aligned_round_row_x/" \
  "id 'pack_aligned_round_row' has no '## pack_aligned_round_row' section"
corrupt_readme pack_package_in_neither '/^## pack_aligned_round_row$/,/^## /s/^- Run by: TypeScript, /- Run by: /' \
  "pack case 'pack_aligned_round_row': package TypeScript is named 0 times"
corrupt_readme pack_package_twice '/^## pack_aligned_round_row$/,/^## /s/^- Not run by: none.*/- Not run by: Rust (made up)./' \
  "pack case 'pack_aligned_round_row': package Rust is named 2 times"
corrupt_readme pack_no_not_run_list '/^## pack_aligned_round_row$/,/^## /{/^- Not run by:/d;}' \
  "pack case 'pack_aligned_round_row': section has no '- Not run by:' line"
corrupt_readme pack_no_row_line '/^## pack_aligned_round_row$/,/^## /{/^- Row:/d;}' \
  "pack case 'pack_aligned_round_row': section has no '- Row:' line"

# Every id needs its README section: a copy without one new section is rejected and names the id.
sed "s/^## times_rounds_over_limit\$/## times_rounds_over_limit_x/" "$here/README.md" >"$tmp/no_section.md"
if bash "$check" "$here/cases.txt" "$tmp/no_section.md" 2>"$tmp/no_section.err"; then
  echo "no_section: check passed on a README without the section" >&2
  exit 1
fi
grep -q "id 'times_rounds_over_limit' has no '## times_rounds_over_limit' section" "$tmp/no_section.err"
echo "no_section: rejected"
echo "hostile case tests passed"

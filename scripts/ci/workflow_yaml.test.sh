#!/usr/bin/env bash
# scripts/ci/workflow_yaml.py holds the helpers both ring-wiring checkers use. The wiring tests reach most of them
# through a rejected workflow; this test pins what they do not: how `inspect` quotes a value in a violation message,
# and the edges of the lookups (a missing key, a value of the wrong shape).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
bad() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

# check <label> <wanted> <python expression>: the expression runs under python3 -I with this directory on sys.path,
# as the checkers do, and prints the value that must equal <wanted>.
check() {
  local label="$1" wanted="$2" got
  got="$(python3 -I -c "import re, sys; sys.path.insert(0, sys.argv[1]); from workflow_yaml import *; print($3)" \
    "$here" < /dev/null)" || { bad "$label: the helper raised"; return; }
  [ "$got" = "$wanted" ] || bad "$label: got [$got], wanted [$wanted]"
}

# Act and assert: inspect quotes like the program the checkers replaced
check "inspect quote" '"a\"b"' 'inspect("a\"b")'
check "inspect backslash" '"a\\b"' 'inspect("a\\b")'
check "inspect controls" '"\n\t\r\e\a\b\v\f"' 'inspect("\n\t\r\x1b\x07\x08\x0b\x0c")'
check "inspect interpolation" '"\#{x} \#$y \#@z # w"' 'inspect("#{x} #$y #@z # w")'
check "inspect del" '"\x7F"' 'inspect("\x7f")'
check "inspect unprintable" '"\u0001 \u2028 \u{E0001}"' 'inspect("\x01 \u2028 \U000e0001")'
check "inspect printable" '"é 😀"' 'inspect("é \U0001F600")'
check "inspect scalars" 'nil true false 3' 'inspect(None), inspect(True), inspect(False), inspect(3)'
check "inspect collections" '["a", nil] {"k" => ["v"]}' 'inspect(["a", None]), inspect({"k": ["v"]})'

# Act and assert: the lookups read a missing or misshapen value as None or empty
check "to_s" ' true false 3' 'to_s(None), to_s(True), to_s(False), to_s(3)'
check "first_set" ' a 0 None' 'first_set(None, False, ""), first_set(None, "a"), first_set(False, 0), first_set(None, False)'
check "dig" '7 None None None' 'dig({"a": {"b": 7}}, "a", "b"), dig({"a": 1}, "a", "b"), dig(None, "a"), dig({}, "x")'
check "steps_of" "[{'a': 1}] [] [] []" 'steps_of({"steps": [{"a": 1}, "x", None]}), steps_of({"steps": "x"}), steps_of("job"), steps_of({})'
check "code_lines" "['a b', 'c']" 'code_lines({"run": "  a b  \n# note\n\n\tc\n"})'
check "code_lines without run" '[] []' 'code_lines({}), code_lines({"run": None})'
check "runs" 'True False' 'runs({"run": "x\ny"}, re.compile("y")), runs({"run": "xy"}, re.compile("y"))'

if [ "$failures" -eq 0 ]; then echo "workflow_yaml.test.sh: all checks passed"; fi
exit "$failures"

#!/usr/bin/env bash
# Loop 112 smoke (AZ-4206): one paste, PASS/FAIL per step. Run from the repository root.
set -u
fail=0
work="$(mktemp -d)"
probes=scripts/probes/repeat-followed-by-field
findings=_docs/06_metrics/repeat-followed-by-field_2026-11-12.md
tab="$(printf '\t')"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; cp "$work/step.log" "$work/failed-$(date +%s).log"; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
count() { awk -F'\t' "$1" "$work/run.out" | wc -l | tr -d ' '; }
s1() { # the nine probes run from one command and write nothing into the checkout
  git status --porcelain --ignored > "$work/tree-before"
  limit 900 bash "$probes/run.sh" < /dev/null > "$work/run.out" 2> "$work/run.err"; local rc=$?
  git status --porcelain --ignored > "$work/tree-after"
  echo "exit $rc, $(wc -l < "$work/run.out" | tr -d ' ') lines"
  [ "$rc" -eq 0 ] || { tail -5 "$work/run.err"; return 1; }
  cmp -s "$work/tree-before" "$work/tree-after" || { echo "the run changed the tree:"; diff "$work/tree-before" "$work/tree-after"; return 1; }
}
s2() { # every package, and the Rust heap-free API, reads its control scheme back
  local p
  for p in typescript csharp python rust java cpp go swift dart; do
    grep -q -x "$p${tab}control${tab}built${tab}01090506${tab}same" "$work/run.out" || { echo "no control line that reads back: $p"; return 1; }
  done
  grep -q -x "rust${tab}control-nostd${tab}built${tab}01090506${tab}same" "$work/run.out" || { echo "no control line that reads back: rust nostd"; return 1; }
  echo "10 control lines read back"
}
s3() { # a field after a repeat: built and refused on unpack; two repeats: read back as other values
  local followed elements twice
  followed="$(count '$2 ~ /^(a|d|e-when|e-flags)(-nostd)?$/ && $3 == "built" && $5 ~ /^refused: /')"
  elements="$(count '$2 ~ /^(b|c)$/ && $3 == "built" && $5 ~ /^refused: /')"
  twice="$(count '$2 ~ /^f(-nostd)?$/ && $3 == "built" && $4 == "010506" && $5 ~ /^differs: /')"
  echo "a, d, e-when, e-flags built and refused: $followed of 40; b, c built and refused: $elements of 14; f read back as other values: $twice of 10"
  [ "$followed" -eq 40 ] && [ "$elements" -eq 14 ] && [ "$twice" -eq 10 ]
}
s4() { # the appendix of the findings is this run, line for line
  python3 - "$work/run.out" "$findings" <<'PY'
import sys
rows = []
for line in open(sys.argv[1]):
    cells = [c.replace("|", "\\|") for c in line.rstrip("\n").split("\t")]
    rows.append("| " + " | ".join("`%s`" % c if i >= 2 and c != "-" else c for i, c in enumerate(cells)) + " |")
text = open(sys.argv[2]).read()
# every table line after the heading, less the header row and the separator row
table = [l for l in text[text.index("## Appendix: the run"):].splitlines() if l.startswith("|")][2:]
print("%d lines in the run, %d rows in the appendix" % (len(rows), len(table)))
if rows != table:
    for a, b in zip(rows, table):
        if a != b:
            print("run:   " + a); print("table: " + b); break
    sys.exit(1)
PY
}
s5() { # the rule count: 4 TypeScript test schemes, nothing in the ring drivers' 11 schemes
  limit 600 bash "$probes/rule-count/run.sh" < /dev/null > "$work/count.out" 2> "$work/count.err" || { tail -5 "$work/count.err"; return 1; }
  tail -1 "$work/count.out"
  [ "$(grep -c '^refused' "$work/count.out")" -eq 4 ] \
    && tail -1 "$work/count.out" | grep -q "of them by the ring drivers 11${tab}the rule would refuse 4$" \
    && ! grep '^refused' "$work/count.out" | grep -q 'drivers/'
}
s6() { # the eleven scripts parse and pass shellcheck
  local f
  command -v shellcheck > /dev/null || { echo "shellcheck is not installed"; return 1; }
  for f in "$probes/run.sh" "$probes"/*/run.sh; do bash -n "$f" || return 1; done
  shellcheck "$probes/run.sh" "$probes"/*/run.sh && echo "$(ls "$probes/run.sh" "$probes"/*/run.sh | wc -l | tr -d ' ') scripts clean"
}
s7() { # the follow-up: ten unclaimed specs with their tickets under epic AZ-4209, the contract, AZ-4206 archived
  local n f
  for n in 0 1 2 3 4 5 6 7 8 9; do
    f="$(ls _docs/02_tasks/todo/AZ-421"$n"_repeat_last_*.md)" || return 1
    ! head -3 "$f" | grep -q '^loop:' && grep -q "^\*\*Tracker\*\*: AZ-421$n$" "$f" && grep -q '^\*\*Epic\*\*: AZ-4209$' "$f" \
      && grep -q "^| AZ-421$n | " _docs/02_tasks/_dependencies_table.md || { echo "spec or table row wrong: AZ-421$n"; return 1; }
  done
  test -f _docs/02_tasks/done/AZ-4206_repeat_followed_by_a_field.md && ! test -e _docs/02_tasks/todo/AZ-4206_repeat_followed_by_a_field.md \
    && grep -q 'Producer task\*\*: AZ-4210' _docs/02_document/contracts/library/repeat-last.md \
    && grep -q 'AZ-4219 (C++)' _docs/02_document/contracts/library/repeat-last.md \
    && ! grep -q '| unknown |' _docs/02_task_plans/repeat-must-be-last/scenarios.md \
    && echo "AZ-4210 to AZ-4219 in todo/, AZ-4206 in done/"
}
s8() { # the loop touches only scripts/probes/ and _docs/: no package source, no workflow
  local bad
  bad="$( { git diff --name-only e7d3b4d; git ls-files --others --exclude-standard; } | sort -u | grep -vE '^(scripts/probes/|_docs/)' || true)"
  [ -z "$bad" ] || { echo "$bad"; return 1; }
  echo "$( { git diff --name-only e7d3b4d; git ls-files --others --exclude-standard; } | sort -u | wc -l | tr -d ' ') paths, all under scripts/probes/ or _docs/"
}
step "1 nine probes run from one command, tree unchanged" s1
step "2 every control scheme reads back" s2
step "3 the measured class: refused after a repeat, misread after two" s3
step "4 the findings appendix equals the run" s4
step "5 rule count: 4 TypeScript test schemes, 0 ring schemes" s5
step "6 scripts parse and pass shellcheck" s6
step "7 follow-up specs, contract and archive" s7
step "8 only scripts/probes/ and _docs/ changed" s8
[ "$fail" -eq 0 ] && echo "SMOKE 112: ALL PASS (8/8)" || echo "SMOKE 112: FAILED (step logs kept in $work)"
[ "$fail" -eq 0 ] && rm -rf "$work"
exit "$fail"

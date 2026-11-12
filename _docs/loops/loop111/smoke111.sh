#!/usr/bin/env bash
# Loop 111 smoke (AZ-4205): one paste, PASS/FAIL per step. Run from the repository root.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; cp "$work/step.log" "$work/failed-$(date +%s).log"; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
cs() { # extra dotnet args...
  limit 600 env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo "$@" \
    --filter "FullyQualifiedName~ElementRow|FullyQualifiedName~RowRound" --logger "console;verbosity=normal" < /dev/null > "$work/cs.log" 2>&1
  local rc=$?
  grep -E 'Total tests|Passed:|Failed:' "$work/cs.log"
  [ "$rc" -eq 0 ] && [ "$(grep -c 'Passed Packbin.Tests.ElementRowLowsTests' "$work/cs.log")" -eq 22 ]
}
s1() { cs; }
s2() { cs -p:PackbinTarget=netstandard2.0; }
s3() { # TypeScript writes the hex the C# tests pin for when and times inside an element row
  cat > "$work/ref.ts" <<'EOF'
import { BinaryPacker, eq, group, list, scheme, times, u8, when } from "../typescript/src/index.ts"
const hex = (b: Uint8Array) => Buffer.from(b).toString("hex")
const w: any = scheme(1, list((x: any) => x.items, group((x: any) => x.p, [u8(0, (r: any) => r.mode), when(1, eq(0, 1), [u8(1, (r: any) => r.speed)])])))
const t: any = scheme(1, list((x: any) => x.items, group((x: any) => x.p, [u8(0, (r: any) => r.c), times(1, 0, [u8(1, (r: any) => r.v)])])))
console.log(hex(BinaryPacker.pack(w, { items: [{ mode: 1, speed: 7 }, { mode: 0 }] })))
console.log(hex(BinaryPacker.pack(t, { items: [{ c: 2, v: [5, 6] }, { c: 0, v: [] }] })))
EOF
  mkdir -p .smoke111 && cp "$work/ref.ts" .smoke111/ref.ts
  out="$(limit 60 node --experimental-strip-types --no-warnings .smoke111/ref.ts < /dev/null)"; rc=$?
  rm -rf .smoke111
  echo "$out"
  [ "$rc" -eq 0 ] && [ "$out" = "$(printf '010200010700\n01020002050600')" ] \
    && grep -q '"010200010700"' csharp/tests/ElementRowLowsTests.cs && grep -q '"01020002050600"' csharp/tests/ElementRowLowsTests.cs
}
s4() {
  grep -q 'a `List<E>`, `E\[\]` or `IList<E>` member' README.md \
    && grep -q "but the elements of 'Items' are Mark" README.md \
    && grep -q "but the nested row 'M' is Mark" README.md
}
s5() { # the AZ-4205 commits touch only csharp/, README.md and _docs/
  bad="$(git log --grep='AZ-4205' --name-only --format= | sort -u | grep -vE '^(csharp/|README\.md$|_docs/)' || true)"
  [ -z "$bad" ] || { echo "$bad"; return 1; }
}
s6() { grep -q '^Verdict: CLEAN' _docs/05_security/lite_loop111.md; }
s7() { # AZ-4206 waits unclaimed for a later loop; AZ-4205 is in done/
  f=_docs/02_tasks/todo/AZ-4206_repeat_followed_by_a_field.md
  test -f "$f" && ! head -3 "$f" | grep -q '^loop:' && test -f _docs/02_tasks/done/AZ-4205_csharp_element_row_lows.md
}
step "1 C# element-row and round tests, net10.0 (22 new pass)" s1
step "2 same, netstandard2.0" s2
step "3 TypeScript writes the pinned when/times hex" s3
step "4 README: member types and the two refusal texts" s4
step "5 AZ-4205 commits touch only csharp/, README.md, _docs/" s5
step "6 security lite record: CLEAN" s6
step "7 AZ-4206 unclaimed in todo/, AZ-4205 in done/" s7
[ "$fail" -eq 0 ] && echo "SMOKE 111: ALL PASS" || echo "SMOKE 111: FAILED (step logs kept in $work)"
[ "$fail" -eq 0 ] && rm -rf "$work"
exit "$fail"

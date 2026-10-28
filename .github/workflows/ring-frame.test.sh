#!/usr/bin/env bash
# Self-test of ring-frame.sh (AZ-3338): the ring passes when every driver answers as the reference codec does, and fails,
# naming what is wrong, on a driver that lies, one that accepts tampered input, one that crashes or prints too few lines,
# a corrupted row file and a row with a number outside its range; past 5 mismatch lines it counts the rest. The
# drivers are replaced by a stand-in (RING_FRAME_RUN) that answers with the reference codec, so this needs no toolchain.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
ring="$here/ring-frame.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

cat > "$tmp/fake.py" <<'PY'
import os
import sys

sys.path.insert(0, os.path.join(os.environ["ROOT"], "scripts", "frame"))
import framefmt as ff

lang, cmd, path = sys.argv[1:4]
liar, _, how = os.environ.get("FAKE_LIE", ":").partition(":")
lying = liar == lang


KINDS = ("BadValue", "TooLong", "BufferFull", "ShortPacket", "TagMismatch")


def unhex(token):
    return b"" if token == "-" else bytes.fromhex(token)


def hx(b):
    return b.hex() if len(b) else "-"


if cmd != "frame-batch":
    sys.exit(2)
if lying and how == "crash":
    print("fake driver crash", file=sys.stderr)
    sys.exit(1)
out, bent, bends = [], False, 0
for line in open(path):
    w = line.split()
    if not w:
        continue
    if w[0] == "seal":
        key, epoch, d, tag_len = unhex(w[1]), int(w[2]), int(w[3]), int(w[4])
        msg_id, kind, ad, clear, plain = unhex(w[5]), int(w[6]), unhex(w[7]), unhex(w[8]), unhex(w[9])
        dirs, out_len = ((tuple(int(c) for c in w[10]), int(w[11])) if len(w) > 10 else ((1, 2, 3), None))
        try:
            text = ff.seal(key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, dirs=dirs, out_len=out_len).hex()
        except ff.Fault as x:
            text = x.kind
        if lying and how == "seal" and not bent and text not in KINDS:
            text, bent = text[:-1] + ("0" if text[-1] != "0" else "1"), True
        if lying and how == "writer-prints-word" and not bent:
            text, bent = "TooLong", True
        if lying and how == "dir0-aborts" and d == 0:
            print("fake driver: direction 0 aborts", file=sys.stderr)
            sys.exit(134)
        if lying and how == "unloaded-accepted" and text == "BadValue" and d not in dirs:
            text = "00"
    elif w[0] == "open":
        key, epoch, d, tag_len = unhex(w[1]), int(w[2]), int(w[3]), int(w[4])
        msg_id, kind, ad, clear_len, body = unhex(w[5]), int(w[6]), unhex(w[7]), int(w[8]), unhex(w[9])
        dirs, out_len = ((tuple(int(c) for c in w[10]), int(w[11])) if len(w) > 10 else ((1, 2, 3), None))
        try:
            _, plain, _ = ff.open_frame(key, epoch, d, tag_len, msg_id, kind, ad, clear_len, body, dirs=dirs, out_len=out_len)
            text = hx(plain)
        except ff.Fault as x:
            text = x.kind
        if lying and how == "open" and not bent:
            text, bent = "TagMismatch", True
        if lying and how == "open-permissive" and text in ("TagMismatch", "ShortPacket"):
            text = "00"
        if lying and how == "unloaded-accepted" and text == "BadValue" and d not in dirs:
            text = "00"
        if lying and how == "fit-refused" and out_len is not None and text not in KINDS:
            text = "BufferFull"
        # The first N refused lines opened, or the first N opened lines refused: N mismatches of one reader or one pair.
        if lying and how.startswith("refusals-") and text in KINDS and bends < int(how[9:]):
            text, bends = "00", bends + 1
        if lying and how.startswith("opens-") and text not in KINDS and bends < int(how[6:]):
            text, bends = "TagMismatch", bends + 1
    elif w[0] == "mac":
        key, epoch, label, n, message = unhex(w[1]), int(w[2]), unhex(w[3]), int(w[4]), unhex(w[5])
        try:
            text = ff.mac_tag(key, epoch, label, n, [message]).hex()
        except ff.Fault as x:
            text = x.kind
        if lying and how == "mac-word" and not bent:
            text, bent = "TooLong", True
        if lying and how == "mac" and not bent and text not in KINDS:
            text, bent = text[:-1] + ("0" if text[-1] != "0" else "1"), True
    elif w[0] == "verify":
        key, epoch, label, n, message, tag = unhex(w[1]), int(w[2]), unhex(w[3]), int(w[4]), unhex(w[5]), unhex(w[6])
        text = "valid" if ff.mac_verify(key, epoch, label, [message], tag) else "invalid"
        if lying and how == "verify" and not bent:
            text, bent = "invalid", True
        if lying and how == "verify-permissive":
            text = "valid"
    elif w[0] in ("open-skip", "verify-skip"):
        text = "skip"
    else:
        print("fake: unknown op %s" % w[0], file=sys.stderr)
        sys.exit(1)
    out.append(text)
if lying and how == "short":
    out.pop()
print("\n".join(out))
PY
# shellcheck disable=SC2016 # $FAKE_PY and $@ expand in the script written here, not in this one
printf '#!/usr/bin/env bash\nexec python3 "$FAKE_PY" "$@"\n' > "$tmp/fake.sh"
chmod +x "$tmp/fake.sh"

run() {
  local name="$1" want="$2" needle="$3" rc=0
  shift 3
  env ROOT="$root" FAKE_PY="$tmp/fake.py" RING_FRAME_RUN="$tmp/fake.sh" "$@" bash "$ring" > "$tmp/out.txt" 2>&1 < /dev/null || rc=$?
  if [ "$rc" -ne "$want" ]; then
    echo "FAIL $name: exit $rc, wanted $want"
    sed -n '1,8p;$p' "$tmp/out.txt" | cut -c1-200
    failures=$((failures + 1))
  elif ! grep -qF -- "$needle" "$tmp/out.txt"; then
    echo "FAIL $name: the output has no \"$needle\""
    sed -n '1,8p;$p' "$tmp/out.txt" | cut -c1-200
    failures=$((failures + 1))
  elif grep -q '^Traceback ' "$tmp/out.txt"; then
    echo "FAIL $name: the output holds a Python traceback"
    sed -n '1,8p;$p' "$tmp/out.txt" | cut -c1-200
    failures=$((failures + 1))
  else
    echo "PASS $name"
  fi
}

run honest 0 "ring-frame: 64 pairs, "
if ! grep -q "mismatched: 0$" "$tmp/out.txt"; then
  echo "FAIL honest: the total does not end in \"mismatched: 0\""
  failures=$((failures + 1))
fi
refusal_rows=$(grep -cE '^(open|verify|refuse-seal|refuse-open|refuse-mac) ' "$root/fixtures/frame/ring-cases.txt")
if [ "$(grep -c "^refusals [a-z]*: $refusal_rows rows, 0 mismatched$" "$tmp/out.txt")" -ne 8 ] || [ "$refusal_rows" -lt 2 ]; then
  echo "FAIL honest: not eight lines \"refusals <lang>: $refusal_rows rows, 0 mismatched\""
  failures=$((failures + 1))
fi
run seal-lies 1 "seal gave" FAKE_LIE=java:seal
run open-lies 1 "open gave" FAKE_LIE=go:open
run mac-lies 1 "mac gave" FAKE_LIE=rust:mac
run verify-lies 1 "verify gave" FAKE_LIE=swift:verify
run reader-prints-too-few 1 "printed" FAKE_LIE=csharp:short
# A reader that accepts tampered input, as a package that skips the tag check would (AZ-3341).
run open-permissive 1 "go: E1.ct open gave 00, wanted TagMismatch" FAKE_LIE=go:open-permissive
run verify-permissive 1 "swift: E4.first verify gave valid, wanted invalid" FAKE_LIE=swift:verify-permissive
# A reader that opens with a direction the session did not load, and a writer that aborts on direction 0 (AZ-3354).
run unloaded-direction-accepted 1 "go: R.open.unloaded open gave 00, wanted BadValue" FAKE_LIE=go:unloaded-accepted
run fit-refused 1 "-> go: fit.tag4 open gave BufferFull" FAKE_LIE=go:fit-refused
# A writer that prints a word for a good row is blamed; its readers are not reported as failed (AZ-3355, L-2).
run writer-prints-word 1 "java: E1 seal gave TooLong, wanted 53e9dc75fb459d77" FAKE_LIE=java:writer-prints-word
if grep -q "frame-batch (open) failed" "$tmp/out.txt" || [ "$(grep '^pair ' "$tmp/out.txt" | grep -v '^pair java ' | grep -vc ' 0 mismatched$')" -ne 0 ]; then
  echo "FAIL writer-prints-word: a reader is reported as failed, or a writer other than java has mismatched rows"
  failures=$((failures + 1))
fi
run mac-writer-prints-word 1 "java: E4 mac gave TooLong, wanted 56db9bec" FAKE_LIE=java:mac-word
if grep -q "frame-batch (verify) failed" "$tmp/out.txt" || [ "$(grep '^pair ' "$tmp/out.txt" | grep -v '^pair java ' | grep -vc ' 0 mismatched$')" -ne 0 ]; then
  echo "FAIL mac-writer-prints-word: a reader is reported as failed, or a writer other than java has mismatched rows"
  failures=$((failures + 1))
fi
run dir0-aborts 1 "typescript frame-batch (seal) failed" FAKE_LIE=typescript:dir0-aborts
run driver-crashes 1 "frame-batch (seal) failed" FAKE_LIE=typescript:crash
run one-language 0 "ring-frame: 1 pairs" RING_FRAME_LANGS=python

# No mismatch is hidden (AZ-3356): after 5 lines of a pair or a reader, one line counts the rest; the totals are unchanged.
# shown <header>: the indented lines under the output line that starts with <header>.
shown() {
  awk -v h="$1" 'index($0, h) == 1 { on = 1; next } on && /^    / { print; next } on { exit }' "$tmp/out.txt"
}
# display <name> <header> <last line, or "" for none> <mismatches>
display() {
  local name="$1" header="$2" more="$3" count="$4" lines
  lines="$(shown "$header")"
  if [ "$(printf '%s\n' "$lines" | grep -vc '^    \.\.\. and ')" -ne 5 ] \
    || [ "$(printf '%s\n' "$lines" | grep -c '^    \.\.\. and ')" -ne "$([ -n "$more" ] && echo 1 || echo 0)" ] \
    || { [ -n "$more" ] && [ "$(printf '%s\n' "$lines" | tail -n 1)" != "$more" ]; } \
    || ! grep -q "^$header.*, $count mismatched$" "$tmp/out.txt" \
    || ! grep -qxF "ring-frame: 64 pairs, mismatched: $count" "$tmp/out.txt"; then
    echo "FAIL $name: wanted $count mismatched, 5 lines under \"$header\"${more:+ and \"$more\"}, the same total:"
    grep -F -e "$header" -e "mismatched: " "$tmp/out.txt" | grep -v ' 0 mismatched$' | cut -c1-200
    printf '%s\n' "$lines" | cut -c1-200
    failures=$((failures + 1))
  else
    echo "PASS $name: 5 lines${more:+ and \"$more\"}"
  fi
}
run refusals-7 1 "refusals go: $refusal_rows rows, 7 mismatched" FAKE_LIE=go:refusals-7
display refusals-7 "refusals go: " "    ... and 2 more" 7
run pair-6 1 "pair csharp -> go: " FAKE_LIE=go:opens-6
display pair-6 "pair csharp -> go: " "    ... and 1 more" 6
run refusals-5 1 "refusals go: $refusal_rows rows, 5 mismatched" FAKE_LIE=go:refusals-5
display refusals-5 "refusals go: " "" 5

# A corrupted row file.
corrupt() {
  local expr="$1"
  sed -E "$expr" "$root/fixtures/frame/ring-cases.txt" > "$tmp/ring-cases.txt"
  if cmp -s "$root/fixtures/frame/ring-cases.txt" "$tmp/ring-cases.txt"; then
    echo "FAIL the ring-cases.txt copy is unchanged ($expr)"
    failures=$((failures + 1))
  fi
}
corrupt '/^seal E1 /s/37ff$/37fe/'
run seal-body-changed 1 "disagree with the reference" RING_FRAME_CASES="$tmp/ring-cases.txt"
corrupt '/^mac E4 /s/9bec$/9bed/'
run mac-tag-changed 1 "disagree with the reference" RING_FRAME_CASES="$tmp/ring-cases.txt"
corrupt '/^open E1.ct /s/ TagMismatch$/ ShortPacket/'
run open-name-changed 1 "disagree with the reference" RING_FRAME_CASES="$tmp/ring-cases.txt"
corrupt '/^refuse-seal R.seal.kind16 /s/ BadValue$/ TooLong/'
run refuse-seal-name-changed 1 "R.seal.kind16 expected TooLong, reference gives BadValue" RING_FRAME_CASES="$tmp/ring-cases.txt"
corrupt '/^refuse-mac R.mac.nbad5 /s/ BadValue$/ TooLong/'
run refuse-mac-name-changed 1 "R.mac.nbad5 expected TooLong, reference gives BadValue" RING_FRAME_CASES="$tmp/ring-cases.txt"
corrupt '/^verify E4.first /s/ [0-9a-f]{8} invalid$/ 56db9bec invalid/'
run verify-tag-made-valid 1 "disagree with the reference" RING_FRAME_CASES="$tmp/ring-cases.txt"
# A seal or mac row the reference refuses (AZ-3369): the file line, the case and the error name, not a traceback.
corrupt '/^seal E1 /s/ (00301005e8030000) 4 / \1 16 /'
run seal-refused-by-reference 1 "ring-cases.txt:17: E1 the reference refuses the row: BadValue" RING_FRAME_CASES="$tmp/ring-cases.txt"
corrupt '/^mac E4 /s/ 6e6574 4 / 6e6574 5 /'
run mac-refused-by-reference 1 "ring-cases.txt:41: E4 the reference refuses the row: BadValue" RING_FRAME_CASES="$tmp/ring-cases.txt"
# A number outside the range every driver reads (AZ-3356): the reference would take both rows.
corrupt '/^refuse-seal R.seal.dir4 /s/ 3 4 4 / 3 256 4 /'
run row-dir-256 1 "R.seal.dir4 dir 256 is not decimal digits of 0 to 255" RING_FRAME_CASES="$tmp/ring-cases.txt"
corrupt '/^seal fit.tag4 /s/ 16$/ 65536/'
run row-out-len-65536 1 "fit.tag4 out_len 65536 is not decimal digits of 0 to 65535" RING_FRAME_CASES="$tmp/ring-cases.txt"
{ cat "$root/fixtures/frame/ring-cases.txt"; grep -m1 '^seal E1 ' "$root/fixtures/frame/ring-cases.txt"; } > "$tmp/ring-cases.txt"
run duplicate-id 1 "duplicate id" RING_FRAME_CASES="$tmp/ring-cases.txt"
# A file without tampered rows would pass every permissive reader: the loader refuses it.
grep -v '^open ' "$root/fixtures/frame/ring-cases.txt" > "$tmp/ring-cases.txt"
run no-open-rows 1 "no open rows" RING_FRAME_CASES="$tmp/ring-cases.txt"
grep -v '^verify ' "$root/fixtures/frame/ring-cases.txt" > "$tmp/ring-cases.txt"
run no-verify-rows 1 "no verify rows" RING_FRAME_CASES="$tmp/ring-cases.txt"

echo "---"
if [ "$failures" -gt 0 ]; then
  echo "ring-frame.test: $failures failures"
  exit 1
fi
echo "ring-frame.test: all passed"

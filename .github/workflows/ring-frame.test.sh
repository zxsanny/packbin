#!/usr/bin/env bash
# Self-test of ring-frame.sh (AZ-3338): the ring passes when every driver answers as the reference codec does, and fails,
# naming what is wrong, on a driver that lies, one that accepts tampered input, one that crashes or prints too few lines,
# and a corrupted row file. The
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
out, bent = [], False
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
    elif w[0] == "mac":
        key, epoch, label, n, message = unhex(w[1]), int(w[2]), unhex(w[3]), int(w[4]), unhex(w[5])
        try:
            text = ff.mac_tag(key, epoch, label, n, [message]).hex()
        except ff.Fault as x:
            text = x.kind
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
run dir0-aborts 1 "typescript frame-batch (seal) failed" FAKE_LIE=typescript:dir0-aborts
run driver-crashes 1 "frame-batch (seal) failed" FAKE_LIE=typescript:crash
run one-language 0 "ring-frame: 1 pairs" RING_FRAME_LANGS=python

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

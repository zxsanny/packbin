#!/usr/bin/env bash
# Self-test of ring-ecc.sh (AZ-2689): the ring passes when every driver answers as the reference codec does, and fails,
# naming what is wrong, on a driver that lies, one that crashes or prints too few lines, and a corrupted row file. The
# drivers are replaced by a stand-in (RING_ECC_RUN) that answers with the reference codec, so this needs no toolchain.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
ring="$here/ring-ecc.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

# The stand-in driver: `<lang> ecc-batch <file>`. FAKE_LIE is `<lang>:<how>`: protect (a wrong parity byte for n = 4),
# repair (a refusal where the row is repaired), short (one line too few) or crash (exit 1).
cat > "$tmp/fake.py" <<'PY'
import os
import sys

sys.path.insert(0, os.path.join(os.environ["ROOT"], "scripts", "ecc"))
import eccfmt as e

POS = bytes.fromhex("4001000065cd1d00a3e1110100")
lang, cmd, path = sys.argv[1:4]
liar, _, how = os.environ.get("FAKE_LIE", ":").partition(":")
lying = liar == lang


def unhex(token):
    return b"" if token == "-" else bytes.fromhex(token)


def protect(n):
    if n > e.MAX_PARITY:
        return "bad_parity"
    return e.protect(POS, n).hex()


def repair(n, t, received):
    if n > e.MAX_PARITY:
        return "bad_parity"
    if t > n // 2:
        return "bad_limit"
    if n == 0:
        return "%s 0" % received.hex() if received == POS else ("trailing" if len(received) > len(POS) else "unpack_failed")
    try:
        clear, count = e.decode(received, n, t)
    except e.EccError as x:
        return x.kind
    return "%s %d" % (clear.hex(), count) if len(clear) == 13 and clear[0] == 0x40 else "unpack_failed"


if cmd != "ecc-batch":
    sys.exit(2)
if lying and how == "crash":
    print("fake driver crash", file=sys.stderr)
    sys.exit(1)
out, bent = [], False
for line in open(path):
    w = line.split()
    if not w:
        continue
    if w[0] == "protect":
        text = protect(int(w[1]))
        if lying and how == "protect" and w[1] == "4" and not bent:
            text, bent = text[:-1] + ("0" if text[-1] != "0" else "1"), True
    else:
        text = repair(int(w[1]), int(w[2]), unhex(w[3]))
        if lying and how == "repair" and " " in text and not bent:
            text, bent = "uncorrectable", True
    out.append(text)
if lying and how == "short":
    out.pop()
print("\n".join(out))
PY
# shellcheck disable=SC2016 # $FAKE_PY and $@ expand in the script written here, not in this one
printf '#!/usr/bin/env bash\nexec python3 "$FAKE_PY" "$@"\n' > "$tmp/fake.sh"
chmod +x "$tmp/fake.sh"

# run <name> <want exit: 0|1> <must appear in the output> [VAR=value ...]
run() {
  local name="$1" want="$2" needle="$3" rc=0
  shift 3
  env ROOT="$root" FAKE_PY="$tmp/fake.py" RING_ECC_RUN="$tmp/fake.sh" "$@" bash "$ring" > "$tmp/out.txt" 2>&1 < /dev/null || rc=$?
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

run honest 0 "ring-ecc: 64 pairs, "
if ! grep -q "mismatched rows: 0$" "$tmp/out.txt"; then
  echo "FAIL honest: the total does not end in \"mismatched rows: 0\""
  failures=$((failures + 1))
fi
run writer-lies 1 "java: enc.pos.n4" FAKE_LIE=java:protect
run reader-lies 1 "-> go: " FAKE_LIE=go:repair
run reader-prints-too-few 1 "swift printed" FAKE_LIE=swift:short
run driver-crashes 1 "rust ecc-batch (protect) failed" FAKE_LIE=rust:crash
run one-language 0 "ring-ecc: 1 pairs" RING_ECC_LANGS=python

# A corrupted row file: the reference does not confirm it, so the run stops before it reads any driver result.
corrupt_row() { # file id-regex, a sed expression: change a field of the row
  sed -E "$2" "$root/fixtures/ecc/$1" > "$tmp/$1"
  if cmp -s "$root/fixtures/ecc/$1" "$tmp/$1"; then echo "FAIL the $1 copy is unchanged ($2)"; failures=$((failures + 1)); fi
}
corrupt_row vectors.txt '/^fix fix\.report\.r8 /s/ 2$/ 1/'
run vector-count-changed 1 "disagree with the reference" RING_ECC_VECTORS="$tmp/vectors.txt"
corrupt_row vectors.txt '/^enc enc\.pos\.n4 /s/82$/83/'
run vector-protected-bytes-changed 1 "enc.pos.n4" RING_ECC_VECTORS="$tmp/vectors.txt"
corrupt_row vectors.txt '/^bad bad\.report\.r9 /s/uncorrectable$/short/'
run vector-kind-changed 1 "bad.report.r9" RING_ECC_VECTORS="$tmp/vectors.txt"
corrupt_row ring-cases.txt '/^bad ring\.n1\.p0 /s/uncorrectable$/too_long/'
run case-kind-changed 1 "ring.n1.p0" RING_ECC_CASES="$tmp/ring-cases.txt"
corrupt_row ring-cases.txt '/^fix ring\.n2\.p3 /s/ 1$/ 0/'
run case-count-changed 1 "ring.n2.p3" RING_ECC_CASES="$tmp/ring-cases.txt"
{ cat "$root/fixtures/ecc/ring-cases.txt"; grep -m1 '^fix ring\.intact' "$root/fixtures/ecc/ring-cases.txt"; } > "$tmp/ring-cases.txt"
run case-duplicate-id 1 "duplicate id" RING_ECC_CASES="$tmp/ring-cases.txt"
sed 's/^\(bad ring\.hostile\.n4\.trailing \)0 0/\14 0/' "$root/fixtures/ecc/ring-cases.txt" > "$tmp/ring-cases.txt"
run case-trailing-with-parity 1 "ring.hostile.n4.trailing" RING_ECC_CASES="$tmp/ring-cases.txt"

# ring-cases.txt is what the generator writes (a hand edit, or a generator change without the file, shows here).
python3 -I "$root/scripts/ecc/gen_ring_cases.py" "$tmp/regenerated.txt" > "$tmp/regenerated.log"
if cmp -s "$root/fixtures/ecc/ring-cases.txt" "$tmp/regenerated.txt"; then
  echo "PASS ring-cases.txt is the generator's output"
else
  echo "FAIL ring-cases.txt differs from the output of scripts/ecc/gen_ring_cases.py"
  failures=$((failures + 1))
fi

# The row files hold what the ring needs: every n of the task, the results report rows 7 to 12, and the hostile refusals.
for n in 2 4 8 16; do
  grep -q "^fix ring.fix.n$n.t" "$root/fixtures/ecc/ring-cases.txt" || { echo "FAIL ring-cases.txt has no repair row for n = $n"; failures=$((failures + 1)); }
done
for id in r7 r8 r9 r10 r11 r12; do
  grep -q " [a-z]*\.report\.$id " "$root/fixtures/ecc/vectors.txt" || { echo "FAIL vectors.txt has no report row $id"; failures=$((failures + 1)); }
done
for word in truncation:trunc extension:extend unprotected:unprotected garbage:garbage trailing:trailing toolong:toolong short:short; do
  grep -q "^bad ring.hostile.[a-z0-9.]*${word#*:}" "$root/fixtures/ecc/ring-cases.txt" || { echo "FAIL ring-cases.txt has no ${word%%:*} refusal"; failures=$((failures + 1)); }
done

if [ "$failures" -ne 0 ]; then
  echo "ring-ecc.test.sh: $failures failed"
  exit 1
fi
echo "ring-ecc.test.sh: passed"

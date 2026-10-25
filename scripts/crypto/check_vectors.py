"""Re-derives every row of fixtures/crypto/vectors.txt (AZ-3201): SHA-256 and HMAC-SHA256 with hashlib and hmac,
HKDF-SHA256 per RFC 5869, ChaCha20 with chacha20.py. Usage: check_vectors.py [vectors].
Exit 0 when every row matches and every non-derived row names its source; exit 1 naming each failing row."""
import hashlib
import hmac
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chacha20  # noqa: E402

SOURCE = re.compile(r"^(rfc[0-9]{4}:[0-9a-z.]+|fips180-4:[0-9a-z.-]+|nist:[0-9a-z.-]+|derived:[0-9a-z.-]+)$")
FIELDS = {
    "sha256": ({"digest"}, {"msg", "repeat", "byte"}),
    "hmac256": ({"key", "data", "mac"}, {"truncate"}),
    "hkdf256": ({"ikm", "salt", "info", "len", "prk", "okm"}, set()),
    "chacha-block": ({"key", "nonce", "counter", "block"}, set()),
    "chacha-xor": ({"key", "nonce", "counter", "plain", "cipher"}, set()),
}


def unhex(s):
    return b"" if s == "-" else bytes.fromhex(s)


def hkdf(ikm, salt, info, length):
    prk = hmac.new(salt if salt else bytes(32), ikm, hashlib.sha256).digest()
    okm, prev, i = b"", b"", 1
    while len(okm) < length:
        prev = hmac.new(prk, prev + info + bytes([i]), hashlib.sha256).digest()
        okm += prev
        i += 1
    return prk, okm[:length]


def sha_message(f):
    if "msg" in f:
        return unhex(f["msg"])
    return unhex(f["byte"]) * int(f["repeat"])


def check_row(kind, f):
    """The first mismatch of one row as text, or None."""
    if kind == "sha256":
        got = hashlib.sha256(sha_message(f)).hexdigest()
        return None if got == f["digest"] else "digest is %s" % got
    if kind == "hmac256":
        got = hmac.new(unhex(f["key"]), unhex(f["data"]), hashlib.sha256).digest()
        got = got[:int(f["truncate"])] if "truncate" in f else got
        return None if got.hex() == f["mac"] else "mac is %s" % got.hex()
    if kind == "hkdf256":
        prk, okm = hkdf(unhex(f["ikm"]), unhex(f["salt"]), unhex(f["info"]), int(f["len"]))
        if prk.hex() != f["prk"]:
            return "prk is %s" % prk.hex()
        return None if okm.hex() == f["okm"] else "okm is %s" % okm.hex()
    if kind == "chacha-block":
        got = chacha20.block(unhex(f["key"]), unhex(f["nonce"]), int(f["counter"]))
        return None if got.hex() == f["block"] else "block is %s" % got.hex()
    if kind == "chacha-xor":
        got = chacha20.xor(unhex(f["key"]), unhex(f["nonce"]), int(f["counter"]), unhex(f["plain"]))
        return None if got.hex() == f["cipher"] else "cipher is %s" % got.hex()
    return "unknown primitive"


def check_file(path):
    """(errors, counts per primitive) of a vectors file."""
    errors = []
    counts = {}
    ids = set()
    with open(path) as handle:
        lines = handle.read().splitlines()
    for number, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(" ")
        kind = parts[0]
        rid = "%s %s" % (kind, parts[1] if len(parts) > 1 else "")
        counts[kind] = counts.get(kind, 0) + 1
        if kind not in FIELDS or len(parts) < 3:
            errors.append("%d: %s: unknown primitive or no fields" % (number, rid))
            continue
        if rid in ids:
            errors.append("%d: %s: duplicate row id" % (number, rid))
        ids.add(rid)
        if not SOURCE.match(parts[1]):
            errors.append("%d: %s: the source names no RFC or FIPS section" % (number, rid))
        fields = {}
        for item in parts[2:]:
            name, sep, value = item.partition("=")
            if not sep or name in fields:
                errors.append("%d: %s: bad or repeated field %s" % (number, rid, name))
            fields[name] = value
        need, optional = FIELDS[kind]
        if not need <= set(fields) or not set(fields) <= need | optional:
            errors.append("%d: %s: fields are %s" % (number, rid, sorted(fields)))
            continue
        if kind == "sha256" and ("msg" in fields) == ("repeat" in fields):
            errors.append("%d: %s: needs msg, or repeat with byte" % (number, rid))
            continue
        try:
            problem = check_row(kind, fields)
        except (ValueError, KeyError) as error:
            problem = "unreadable (%s)" % error
        if problem:
            errors.append("%d: %s: %s" % (number, rid, problem))
    for kind in FIELDS:
        if kind not in counts:
            errors.append("no %s rows" % kind)
    return errors, counts


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "fixtures", "crypto", "vectors.txt")
    errors, counts = check_file(path)
    for error in errors:
        print("FAIL " + error)
    if errors:
        return 1
    print("crypto vectors ok: " + ", ".join("%s %d" % (k, counts[k]) for k in FIELDS))
    return 0


if __name__ == "__main__":
    sys.exit(main())

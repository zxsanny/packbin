#!/usr/bin/env python3
"""A second implementation of frame mode written from pack-session.md 2.0.0 alone: it imports nothing from
framefmt.py, rows.py or chacha20.py, and recomputes E1 to E5 and three other rows of fixtures/frame/vectors.txt
(PB-03 AC-2). Python 3.9+, standard library only."""
import hashlib
import hmac
import os
import struct
import sys

DEFAULT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "fixtures", "frame", "vectors.txt")
M = 0xFFFFFFFF


def hk(ikm, salt, info):
    prk = hmac.new(salt, ikm, hashlib.sha256).digest()
    return hmac.new(prk, info + b"\x01", hashlib.sha256).digest()


def rotl(x, n):
    return ((x << n) | (x >> (32 - n))) & M


def chacha_block(key, nonce, ctr):
    s = [0x61707865, 0x3320646E, 0x79622D32, 0x6B206574] + list(struct.unpack("<8I", key)) + [ctr] + \
        list(struct.unpack("<3I", nonce))
    w = s[:]

    def qr(a, b, c, d):
        w[a] = (w[a] + w[b]) & M
        w[d] = rotl(w[d] ^ w[a], 16)
        w[c] = (w[c] + w[d]) & M
        w[b] = rotl(w[b] ^ w[c], 12)
        w[a] = (w[a] + w[b]) & M
        w[d] = rotl(w[d] ^ w[a], 8)
        w[c] = (w[c] + w[d]) & M
        w[b] = rotl(w[b] ^ w[c], 7)

    for _ in range(10):
        for idx in ((0, 4, 8, 12), (1, 5, 9, 13), (2, 6, 10, 14), (3, 7, 11, 15),
                    (0, 5, 10, 15), (1, 6, 11, 12), (2, 7, 8, 13), (3, 4, 9, 14)):
            qr(*idx)
    return struct.pack("<16I", *[(a + b) & M for a, b in zip(w, s)])


def h(s):
    return b"" if s == "-" else bytes.fromhex(s)


def body_of(r):
    salt = b"packbin-frame" + struct.pack("<I", int(r["epoch"]))
    d, tl, kind = int(r["dir"]), int(r["tag_len"]), int(r["kind"])
    k_enc, k_mac = hk(h(r["key"]), salt, bytes([d]) + b"enc"), hk(h(r["key"]), salt, bytes([d]) + b"mac")
    n = h(r["msg_id"]) + bytes([(kind << 4) | d]) + struct.pack("<I", int(r["epoch"]))[:3]
    plain, clear, ad = h(r["plain"]), h(r["clear"]), h(r["ad"])
    stream = b"".join(chacha_block(k_enc, n, i) for i in range(4))
    ct = bytes(a ^ b for a, b in zip(plain, stream))
    mac = hmac.new(k_mac, n + bytes([len(ad)]) + ad + bytes([len(clear)]) + clear + ct, hashlib.sha256).digest()
    return (clear + ct + mac[:tl]), k_enc, k_mac


def mac_of(r):
    k = hk(h(r["key"]), b"packbin-frame" + struct.pack("<I", int(r["epoch"])), b"\x00" + h(r["label"]))
    msg = b"".join(h(p) for p in r["parts"].split("|")) if "parts" in r else h(r["message"])
    return k, hmac.new(k, msg, hashlib.sha256).digest()[: int(r["n"])]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    table = {}
    for line in open(path):
        if line.strip() and not line.startswith("#"):
            r = dict(t.partition("=")[::2] for t in line.split())
            table[r["case"]] = r
    bad = []
    for name in ("E1.seal", "E2.seal", "E3.seal", "E3.seal16", "len.plain236"):
        body, k_enc, k_mac = body_of(table[name])
        if body.hex() != table[name]["body"]:
            bad.append(name)
    for name in ("E1.keys", "E2.keys", "E3.keys"):
        r = table[name]
        salt = b"packbin-frame" + struct.pack("<I", int(r["epoch"]))
        if hk(h(r["key"]), salt, bytes([int(r["dir"])]) + b"enc").hex() != r["k_enc"] or \
                hk(h(r["key"]), salt, bytes([int(r["dir"])]) + b"mac").hex() != r["k_mac"]:
            bad.append(name)
    for name in ("E4.mac", "E5.mac", "mac.len255.parts3"):
        if mac_of(table[name])[1].hex() != table[name]["tag"]:
            bad.append(name)
    for name in ("E4.keys", "E5.keys"):
        if mac_of(dict(table[name], n="4", message="-"))[0].hex() != table[name]["k_label"]:
            bad.append(name)
    # an open row of another kind: the body of prev.ok_previous is the one sealed under (A, 6)
    r = table["prev.ok_previous"]
    sealed = dict(r, key=r["prev_key"], epoch=r["prev_epoch"], clear="-", plain=r["plain"])
    if body_of(sealed)[0].hex() != r["body"]:
        bad.append("prev.ok_previous")
    if bad:
        print("independent check FAILED: " + ", ".join(bad))
        sys.exit(1)
    print("independent check ok: E1 to E5, len.plain236, mac.len255.parts3, prev.ok_previous")


if __name__ == "__main__":
    main()

"""Reference frame mode of pack-session.md 2.0.0: seal, open, replay window and the MAC-only call.
Written from the contract only. Python 3.9+, standard library plus scripts/crypto/chacha20.py.
Results are the error kind names of the contract: BadValue, TooLong, BufferFull, ShortPacket,
TagMismatch, Duplicate, TooOld."""
import hashlib
import hmac
import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "crypto"))
import chacha20  # noqa: E402

MAX_BODY = 255
MAX_EPOCH = 0xFFFFFF
LABEL_PREFIX = b"packbin-frame"
U64 = (1 << 64) - 1


class Fault(Exception):
    def __init__(self, kind):
        super().__init__(kind)
        self.kind = kind


def _hmac(key, data):
    return hmac.new(key, data, hashlib.sha256).digest()


def hkdf(ikm, salt, info, length=32):
    prk = _hmac(salt, ikm)
    out, prev, counter = b"", b"", 1
    while len(out) < length:
        prev = _hmac(prk, prev + info + bytes([counter]))
        out += prev
        counter += 1
    return out[:length]


def _salt(epoch):
    return LABEL_PREFIX + struct.pack("<I", epoch)


def check_load(key, epoch, tag_len=None):
    if len(key) != 32 or not 0 <= epoch <= MAX_EPOCH:
        raise Fault("BadValue")
    if tag_len is not None and tag_len not in (4, 8, 16):
        raise Fault("BadValue")


def keys(key, epoch, d):
    """K_enc(d) and K_mac(d)."""
    check_load(key, epoch)
    if d not in (1, 2, 3):
        raise Fault("BadValue")
    salt = _salt(epoch)
    return hkdf(key, salt, bytes([d]) + b"enc"), hkdf(key, salt, bytes([d]) + b"mac")


def label_key(key, epoch, label):
    """K_label of the MAC-only call."""
    check_load(key, epoch)
    if not 1 <= len(label) <= 32:
        raise Fault("BadValue")
    return hkdf(key, _salt(epoch), b"\x00" + label)


def nonce(msg_id, kind, d, epoch):
    return msg_id + bytes([(kind << 4) | d]) + struct.pack("<I", epoch)[:3]


def _stream(k_enc, n, data):
    return chacha20.xor(k_enc, n, 0, data)


def _tag(k_mac, n, ad, clear, ciphertext, tag_len):
    m = n + bytes([len(ad)]) + ad + bytes([len(clear)]) + clear + ciphertext
    return _hmac(k_mac, m)[:tag_len]


def _args(d, dirs, msg_id, kind, ad):
    if d not in dirs or d not in (1, 2, 3) or kind > 15 or kind < 0 or len(msg_id) != 8:
        raise Fault("BadValue")
    if len(ad) > 255:
        raise Fault("TooLong")


def seal(key, epoch, d, tag_len, msg_id, kind, ad, clear, plain, dirs=(1, 2, 3), out_len=None):
    check_load(key, epoch, tag_len)
    _args(d, dirs, msg_id, kind, ad)
    if len(clear) + len(plain) + tag_len > MAX_BODY:
        raise Fault("TooLong")
    body_len = len(clear) + len(plain) + tag_len
    if out_len is not None and out_len < body_len:
        raise Fault("BufferFull")
    k_enc, k_mac = keys(key, epoch, d)
    n = nonce(msg_id, kind, d, epoch)
    ciphertext = _stream(k_enc, n, plain)
    return clear + ciphertext + _tag(k_mac, n, ad, clear, ciphertext, tag_len)


class Window:
    """Replay window of 64 messages: top and bits; bits 0 is empty."""

    def __init__(self, top=0, bits=0):
        self.top, self.bits = top, bits

    @classmethod
    def parse(cls, text):
        top, bits = text.split(":")
        return cls(int(top, 16), int(bits, 16))

    def text(self):
        return "%x:%x" % (self.top, self.bits)

    def check(self, n):
        if self.bits == 0 or n > self.top:
            return "Fresh"
        if self.top - n >= 64:
            return "TooOld"
        if (self.bits >> (self.top - n)) & 1:
            return "Duplicate"
        return "Fresh"

    def commit(self, n):
        if self.bits == 0:
            self.top, self.bits = n, 1
        elif n > self.top:
            shift = n - self.top
            self.bits = ((self.bits << shift) & U64) if shift < 64 else 0
            self.bits |= 1
            self.top = n
        elif self.top - n < 64:
            self.bits |= 1 << (self.top - n)


def _tags_equal(a, b):
    acc = 0
    for x, y in zip(a, b):
        acc |= x ^ y
    return acc == 0 and len(a) == len(b)


def open_frame(key, epoch, d, tag_len, msg_id, kind, ad, clear_len, body, dirs=(1, 2, 3), prev=None,
               window=None, counter=None, out_len=None):
    """Returns (slot, plain, window_after_text or None); raises Fault. The window is never changed on a fault."""
    check_load(key, epoch, tag_len)
    _args(d, dirs, msg_id, kind, ad)
    if len(body) > MAX_BODY or clear_len > MAX_BODY:
        raise Fault("TooLong")
    if len(body) < clear_len + tag_len:
        raise Fault("ShortPacket")
    plain_len = len(body) - clear_len - tag_len
    if out_len is not None and out_len < plain_len:
        raise Fault("BufferFull")
    work = None
    if window is not None and counter is not None:
        work = Window(window.top, window.bits)
        fresh = work.check(counter)
        if fresh != "Fresh":
            raise Fault(fresh)
    clear, ciphertext, tag = body[:clear_len], body[clear_len:clear_len + plain_len], body[clear_len + plain_len:]
    slots = [("current", key, epoch)]
    if prev is not None:
        slots.append(("previous", prev[0], prev[1]))
    for slot, k, e in slots:
        k_enc, k_mac = keys(k, e, d)
        n = nonce(msg_id, kind, d, e)
        if _tags_equal(_tag(k_mac, n, ad, clear, ciphertext, tag_len), tag):
            plain = _stream(k_enc, n, ciphertext)
            if work is not None:
                work.commit(counter)
            return slot, plain, (work.text() if work is not None else None)
    raise Fault("TagMismatch")


def mac_tag(key, epoch, label, n, parts):
    """The MAC-only tag over a message given in parts."""
    if n not in (4, 8, 16, 32):
        raise Fault("BadValue")
    k = label_key(key, epoch, label)
    return _hmac(k, b"".join(parts))[:n]


def mac_verify(key, epoch, label, parts, tag):
    return _tags_equal(mac_tag(key, epoch, label, len(tag), parts), tag)

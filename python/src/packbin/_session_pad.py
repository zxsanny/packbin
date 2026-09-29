from __future__ import annotations

import hmac
import struct
from hashlib import sha256

_INFO = b"packbin"
_CONSTANTS = (0x61707865, 0x3320646E, 0x79622D32, 0x6B206574)


def hkdf_sha256(ikm: bytes, salt: bytes, length: int) -> bytes:
    prk = hmac.new(salt, ikm, sha256).digest()
    out = bytearray()
    block = b""
    counter = 1
    while len(out) < length:
        block = hmac.new(prk, block + _INFO + bytes([counter]), sha256).digest()
        out.extend(block)
        counter += 1
    return bytes(out[:length])


def _rot(value: int, bits: int) -> int:
    return ((value << bits) | (value >> (32 - bits))) & 0xFFFFFFFF


def _quarter(w: list[int], a: int, b: int, c: int, d: int) -> None:
    w[a] = (w[a] + w[b]) & 0xFFFFFFFF
    w[d] = _rot(w[d] ^ w[a], 16)
    w[c] = (w[c] + w[d]) & 0xFFFFFFFF
    w[b] = _rot(w[b] ^ w[c], 12)
    w[a] = (w[a] + w[b]) & 0xFFFFFFFF
    w[d] = _rot(w[d] ^ w[a], 8)
    w[c] = (w[c] + w[d]) & 0xFFFFFFFF
    w[b] = _rot(w[b] ^ w[c], 7)


def _block(key: bytes, nonce: bytes, counter: int) -> bytes:
    state = [
        _CONSTANTS[0],
        _CONSTANTS[1],
        _CONSTANTS[2],
        _CONSTANTS[3],
        *struct.unpack_from("<8I", key),
        counter & 0xFFFFFFFF,
        *struct.unpack_from("<3I", nonce),
    ]
    work = list(state)
    for _ in range(10):
        _quarter(work, 0, 4, 8, 12)
        _quarter(work, 1, 5, 9, 13)
        _quarter(work, 2, 6, 10, 14)
        _quarter(work, 3, 7, 11, 15)
        _quarter(work, 0, 5, 10, 15)
        _quarter(work, 1, 6, 11, 12)
        _quarter(work, 2, 7, 8, 13)
        _quarter(work, 3, 4, 9, 14)
    return struct.pack("<16I", *((work[i] + state[i]) & 0xFFFFFFFF for i in range(16)))


def xor_pad(key: bytes, packet: int, data: bytearray) -> None:
    nonce = struct.pack("<Q", packet & 0xFFFFFFFFFFFFFFFF) + b"\x00\x00\x00\x00"
    counter = 0
    offset = 0
    while offset < len(data):
        block = _block(key, nonce, counter)
        n = min(64, len(data) - offset)
        for i in range(n):
            data[offset + i] ^= block[i]
        offset += n
        counter = (counter + 1) & 0xFFFFFFFF

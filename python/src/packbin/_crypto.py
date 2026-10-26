"""SHA-256, HMAC-SHA256, HKDF-SHA256 (RFC 5869) and ChaCha20 (RFC 8439), kept for the frame mode port (AZ-3294).

Internal: not in `packbin.__all__`. SHA-256 and HMAC come from the standard library. Every function is checked on the
rows of `fixtures/crypto/vectors.txt` (`tests/test_crypto_vectors.py`).
"""

from __future__ import annotations

import hmac
import struct
from hashlib import sha256 as _sha256

DIGEST_SIZE = 32
KEY_SIZE = 32
NONCE_SIZE = 12
BLOCK_SIZE = 64
_MAX_COUNTER = 0xFFFFFFFF
_MAX_OKM = 255 * DIGEST_SIZE
_CONSTANTS = (0x61707865, 0x3320646E, 0x79622D32, 0x6B206574)


def sha256(data: bytes) -> bytes:
    return _sha256(data).digest()


def hmac_sha256(key: bytes, data: bytes) -> bytes:
    return hmac.new(key, data, _sha256).digest()


def hkdf_extract(salt: bytes, ikm: bytes) -> bytes:
    """The pseudorandom key; an empty salt is the RFC's string of 32 zero bytes."""
    return hmac_sha256(salt if salt else bytes(DIGEST_SIZE), ikm)


def hkdf_expand(prk: bytes, info: bytes, length: int) -> bytes:
    if not 0 <= length <= _MAX_OKM:
        raise ValueError(f"HKDF-SHA256 output length must be 0 to {_MAX_OKM}, got {length}")
    out = bytearray()
    block = b""
    counter = 1
    while len(out) < length:
        block = hmac_sha256(prk, block + info + bytes([counter]))
        out.extend(block)
        counter += 1
    return bytes(out[:length])


def hkdf_sha256(ikm: bytes, salt: bytes, info: bytes, length: int) -> bytes:
    return hkdf_expand(hkdf_extract(salt, ikm), info, length)


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


def _check_key_and_nonce(key: bytes, nonce: bytes) -> None:
    if len(key) != KEY_SIZE:
        raise ValueError(f"ChaCha20 key must be {KEY_SIZE} bytes, got {len(key)}")
    if len(nonce) != NONCE_SIZE:
        raise ValueError(f"ChaCha20 nonce must be {NONCE_SIZE} bytes, got {len(nonce)}")


def chacha20_block(key: bytes, nonce: bytes, counter: int) -> bytes:
    """The 64-byte block of a 32-byte key, a 12-byte nonce and a 32-bit block counter."""
    _check_key_and_nonce(key, nonce)
    if not 0 <= counter <= _MAX_COUNTER:
        raise ValueError(f"ChaCha20 block counter must be 0 to {_MAX_COUNTER}, got {counter}")
    state = [
        _CONSTANTS[0],
        _CONSTANTS[1],
        _CONSTANTS[2],
        _CONSTANTS[3],
        *struct.unpack("<8I", key),
        counter,
        *struct.unpack("<3I", nonce),
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


def chacha20_xor(key: bytes, nonce: bytes, counter: int, data: bytes) -> bytes:
    """`data` XOR the key stream that starts at block `counter` (encrypts and decrypts). A stream that would pass the
    last block counter is refused: a wrapped counter would repeat key stream."""
    _check_key_and_nonce(key, nonce)
    blocks = -(-len(data) // BLOCK_SIZE)
    if counter < 0 or counter + max(blocks, 1) - 1 > _MAX_COUNTER:
        raise ValueError(f"ChaCha20 stream of {blocks} blocks from counter {counter} passes counter {_MAX_COUNTER}")
    out = bytearray(data)
    for index in range(blocks):
        at = index * BLOCK_SIZE
        pad = chacha20_block(key, nonce, counter + index)
        for i in range(min(BLOCK_SIZE, len(out) - at)):
            out[at + i] ^= pad[i]
    return bytes(out)

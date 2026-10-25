"""Pure-Python ChaCha20 of RFC 8439 (96-bit nonce, 32-bit block counter), standard library only.
API: block(key, nonce, counter) -> 64 bytes; xor(key, nonce, counter, data) -> bytes."""
import struct

_MASK = 0xFFFFFFFF
_SIGMA = (0x61707865, 0x3320646E, 0x79622D32, 0x6B206574)


def _rotl(x, n):
    return ((x << n) & _MASK) | (x >> (32 - n))


def _quarter(s, a, b, c, d):
    s[a] = (s[a] + s[b]) & _MASK
    s[d] = _rotl(s[d] ^ s[a], 16)
    s[c] = (s[c] + s[d]) & _MASK
    s[b] = _rotl(s[b] ^ s[c], 12)
    s[a] = (s[a] + s[b]) & _MASK
    s[d] = _rotl(s[d] ^ s[a], 8)
    s[c] = (s[c] + s[d]) & _MASK
    s[b] = _rotl(s[b] ^ s[c], 7)


def block(key, nonce, counter):
    """The 64-byte keystream block of a 32-byte key, a 12-byte nonce and a block counter."""
    if len(key) != 32 or len(nonce) != 12:
        raise ValueError("key must be 32 bytes and nonce 12 bytes")
    if not 0 <= counter <= _MASK:
        raise ValueError("counter must fit 32 bits")
    state = list(_SIGMA) + list(struct.unpack("<8I", key)) + [counter] + list(struct.unpack("<3I", nonce))
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
    return struct.pack("<16I", *[(w + s) & _MASK for w, s in zip(work, state)])


def xor(key, nonce, counter, data):
    """data XOR the keystream that starts at block `counter`."""
    out = bytearray()
    for i in range(0, len(data), 64):
        pad = block(key, nonce, counter + i // 64)
        out.extend(a ^ b for a, b in zip(data[i:i + 64], pad))
    return bytes(out)

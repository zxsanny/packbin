"""Key schedule and MAC helpers of frame mode (internal; the hashing is `_crypto`'s HKDF and the standard library's HMAC)."""

from __future__ import annotations

import hmac
from hashlib import sha256
from typing import Iterable

from packbin import _crypto

MAX_EPOCH = 0xFFFFFF
KEY_SIZE = 32
_SALT_LABEL = b"packbin-frame"


def salt(epoch: int) -> bytes:
    """"packbin-frame" followed by the epoch as a 32-bit little-endian integer (17 bytes)."""
    return _SALT_LABEL + epoch.to_bytes(4, "little")


def start_hmac(key: bytes | bytearray) -> hmac.HMAC:
    """An HMAC-SHA256 that takes its message in pieces (no joined copy)."""
    return hmac.new(key, digestmod=sha256)


def hmac_of(key: bytes | bytearray, parts: Iterable[bytes]) -> bytes:
    mac = start_hmac(key)
    for part in parts:
        mac.update(part)
    return mac.digest()


def tags_equal(left: bytes, right: bytes) -> bool:
    """Compares every byte with no early exit (`hmac.compare_digest`); the lengths are public."""
    return hmac.compare_digest(left, right)


def wipe(buffer: bytearray) -> None:
    """Overwrites the buffer in place (best effort: see `FrameSession` for what the runtime keeps)."""
    buffer[:] = bytes(len(buffer))


class FrameKeys:
    """The keys of one (key, epoch) for the loaded directions: K_enc(d) and K_mac(d), derived once at load."""

    __slots__ = ("epoch", "_enc", "_mac")

    def __init__(self, key: bytes, epoch: int, directions: int) -> None:
        self.epoch = epoch
        self._enc: dict[int, bytearray] = {}
        self._mac: dict[int, bytearray] = {}
        key_salt = salt(epoch)
        for d in (1, 2, 3):
            if directions & (1 << (d - 1)):
                self._enc[d] = bytearray(_crypto.hkdf_sha256(key, key_salt, bytes([d]) + b"enc", 32))
                self._mac[d] = bytearray(_crypto.hkdf_sha256(key, key_salt, bytes([d]) + b"mac", 32))

    def enc(self, direction: int) -> bytearray:
        return self._enc[direction]

    def mac(self, direction: int) -> bytearray:
        return self._mac[direction]

    def arrays(self) -> list[bytearray]:
        return [*self._enc.values(), *self._mac.values()]

    def wipe(self) -> None:
        for array in self.arrays():
            wipe(array)

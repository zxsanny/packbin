from __future__ import annotations

import secrets
from collections.abc import Mapping
from typing import Any, TypeVar

from packbin._errors import ShortPacket, UnpackResult
from packbin._scheme import BinaryPacker, Scheme, _Handler
from packbin._session_pad import hkdf_sha256, xor_pad

T = TypeVar("T")

SEED_SIZE = 32
NONCE_SIZE = 16


def _exact_bytes(value: Any, size: int) -> bytes | None:
    """The bytes of a `bytes`, `bytearray` or `memoryview` of exactly `size` bytes, counted in bytes, as one
    copy to check and use; `None` for anything else, a released view included. A subclass's own `__bytes__` is
    still called by `bytes(value)`."""
    if not isinstance(value, (bytes, bytearray, memoryview)):
        return None
    try:
        raw = bytes(value)
    except ValueError:  # a released memoryview holds no bytes to read
        return None
    return raw if len(raw) == size else None


class PackSession:
    __slots__ = ("_seed", "_send", "_recv", "_send_count", "_recv_count")

    def __init__(self, seed: bytes) -> None:
        if len(seed) != SEED_SIZE:
            raise ValueError(f"seed must be {SEED_SIZE} bytes, got {len(seed)}")
        self._seed: bytearray | None = bytearray(seed)
        self._send: bytes | None = None
        self._recv: bytes | None = None
        self._send_count = 0
        self._recv_count = 0

    @staticmethod
    def load(seed: bytes | bytearray | memoryview) -> PackSession | None:
        raw = _exact_bytes(seed, SEED_SIZE)
        return None if raw is None else PackSession(raw)

    def start(self, nonce: bytes | bytearray | memoryview | None = None) -> bytes | None:
        if self._send is not None or self._seed is None:
            return None
        if nonce is None:
            drawn = secrets.token_bytes(NONCE_SIZE)
            if not self._open(drawn, initiator=True):
                return None
            return drawn
        raw = _exact_bytes(nonce, NONCE_SIZE)
        if raw is None or not self._open(raw, initiator=True):
            return None
        return raw

    def join(self, nonce: bytes | bytearray | memoryview) -> bool:
        raw = _exact_bytes(nonce, NONCE_SIZE)
        return raw is not None and self._open(raw, initiator=False)

    def pack(self, scheme: Scheme[T], row: T | Mapping[str, Any]) -> bytes | None:
        if self._send is None:
            return None
        clear = bytearray(BinaryPacker.pack(scheme, row))
        xor_pad(self._send, self._send_count, clear)
        self._send_count += 1
        return bytes(clear)

    def unpack(
        self,
        data: bytes | bytearray | memoryview,
        *handlers: _Handler[Any],
    ) -> UnpackResult[Any]:
        if self._recv is None:
            return UnpackResult(ok=False, value=None, error=ShortPacket(field="", needed=1, left=0))
        clear = bytearray(data)
        xor_pad(self._recv, self._recv_count, clear)
        self._recv_count += 1
        return BinaryPacker.unpack(bytes(clear), *handlers)

    def _open(self, nonce: bytes, initiator: bool) -> bool:
        if self._seed is None or self._send is not None:
            return False
        both = hkdf_sha256(bytes(self._seed), nonce, SEED_SIZE * 2)
        first = both[:SEED_SIZE]
        second = both[SEED_SIZE:]
        self._send = first if initiator else second
        self._recv = second if initiator else first
        for i in range(len(self._seed)):
            self._seed[i] = 0
        self._seed = None
        return True

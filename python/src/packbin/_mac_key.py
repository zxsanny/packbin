from __future__ import annotations

from collections.abc import Iterable
from types import TracebackType

from packbin import _crypto
from packbin._errors import BadValue
from packbin._frame_args import BytesLike, require_int, snapshot
from packbin._frame_keys import KEY_SIZE, MAX_EPOCH, hmac_of, salt, tags_equal, wipe

_TAG_LENGTHS = (4, 8, 16, 32)


def _pieces(parts: BytesLike | Iterable[BytesLike]) -> list[bytes]:
    """One bytes-like value is one part; any other iterable gives its parts in order."""
    if isinstance(parts, (bytes, bytearray, memoryview)):
        return [bytes(parts)]
    return [snapshot(part, "part") for part in parts]


class MacKey:
    """The MAC-only call of frame mode: a tag without encryption, for a per-hop network check and for key fingerprints.
    `K_label = HKDF(key, "packbin-frame" + epoch, 0x00 + label)` and `tag = first n bytes of HMAC(K_label, message)`, with
    `n` of 4, 8, 16 or 32. The message is passed in parts, hashed piece by piece with no joined copy; the tag does not
    depend on how it is split (one bytes-like value is one part). Make one with `MacKey.derive`; it is a context manager.

    This object holds the 32-byte `K_label` in a `bytearray` (the standard library's HMAC keeps its own pad state, which it
    does not expose), and `close()` overwrites it in place, best effort: CPython and the standard library may have copied
    it, and a key that is never closed stays until the memory is reused (no finalizer). Verification uses
    `hmac.compare_digest` over every byte, a library routine with no promise beyond that.
    """

    __slots__ = ("_key", "_epoch", "_closed")

    def __init__(self, key: bytearray, epoch: int) -> None:
        """Internal: use `MacKey.derive`."""
        self._key = key
        self._epoch = epoch
        self._closed = False

    @property
    def epoch(self) -> int:
        return self._epoch

    @classmethod
    def derive(cls, key: BytesLike, epoch: int, label: BytesLike) -> MacKey | BadValue:
        """The key of a label. `BadValue` for a key that is not 32 bytes, an epoch above 0xFFFFFF or a label that is not 1 to 32 bytes."""
        material, name = snapshot(key, "key"), snapshot(label, "label")
        require_int(epoch, "epoch")
        if len(material) != KEY_SIZE or not 0 <= epoch <= MAX_EPOCH or not 1 <= len(name) <= 32:
            return BadValue("key is not 32 bytes, epoch above 0xFFFFFF, or label not 1 to 32 bytes")
        return cls(bytearray(_crypto.hkdf_sha256(material, salt(epoch), b"\x00" + name, 32)), epoch)

    def tag(self, parts: BytesLike | Iterable[BytesLike], n: int) -> bytes | BadValue:
        """The first `n` bytes of the HMAC of the message. `n` other than 4, 8, 16 or 32, or a closed key, is `BadValue`."""
        require_int(n, "n")
        pieces = _pieces(parts)
        if n not in _TAG_LENGTHS or self._closed:
            return BadValue("tag length not 4, 8, 16 or 32, or closed key")
        return hmac_of(self._key, pieces)[:n]

    def verify(self, parts: BytesLike | Iterable[BytesLike], tag: BytesLike) -> bool:
        """True when `tag` (4, 8, 16 or 32 bytes) is the tag of the message. False for any other length and for a closed key."""
        expected = snapshot(tag, "tag")
        pieces = _pieces(parts)
        if len(expected) not in _TAG_LENGTHS or self._closed:
            return False
        return tags_equal(hmac_of(self._key, pieces)[: len(expected)], expected)

    def close(self) -> None:
        """Overwrites the key (best effort). Every later call is refused."""
        self._closed = True
        wipe(self._key)

    def __enter__(self) -> MacKey:
        return self

    def __exit__(self, kind: type[BaseException] | None, error: BaseException | None, trace: TracebackType | None) -> None:
        self.close()

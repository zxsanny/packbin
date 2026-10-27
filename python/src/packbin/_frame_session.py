from __future__ import annotations

from types import TracebackType

from packbin import _crypto
from packbin._errors import BadValue, BufferFull, Duplicate, ShortPacket, TagMismatch, TooLong, TooOld
from packbin._frame_args import BytesLike, require_int, snapshot, writable
from packbin._frame_keys import KEY_SIZE, MAX_EPOCH, FrameKeys, hmac_of, tags_equal
from packbin._frame_types import (
    FrameConfig,
    FrameDirections,
    FrameOpened,
    FrameSlot,
    Freshness,
    MsgContext,
    is_int,
)
from packbin._replay_window import ReplayWindow

MAX_BODY = 255
_MAX_COUNTER = (1 << 64) - 1
_FULL_DIRECTIONS = 7


class FrameSession:
    """Frame mode of the session (`pack-session.md` 3.0.0): sealed, authenticated frames for links that lose, reorder and
    duplicate messages. A frame body is `clear + ciphertext + tag`: ChaCha20 under a key per (key, epoch, direction), a
    nonce built from the caller's `msg_id`, the `kind`, the direction and the epoch, and a tag that is the first 4, 8 or 16
    bytes of HMAC-SHA256 over the nonce, the associated data, the clear part and the ciphertext. It is the only session of
    the package (ADR-009). Make one with `FrameSession.load`; it is a context manager and `close()` wipes its keys.

    `seal` is deterministic, reads only keys that never change after load, and is safe to call from many threads. `open`
    reads the previous slot once per call; `set_previous`, `clear_previous` and `close` replace or overwrite keys, so call
    them while no `seal` or `open` runs (the rule of the other packages). A `ReplayWindow` is not thread safe either.

    Limits of the runtime: Python `bytes` are immutable, so the derived keys live in `bytearray` objects that `close()`
    overwrites in place, but CPython and the standard library may hold copies that no Python code can reach (the `bytes`
    the HKDF returns before they are copied, the key pads inside every `hmac` object, the caller's own key, interpreter
    temporaries, swapped or core-dumped memory). There is no finalizer: a session that is never closed keeps its keys
    until the memory is reused. The tag compare is `hmac.compare_digest` over every tag byte; it is a library routine
    that promises no early exit, and the interpreter in front of it makes no timing promise of its own. Both are best effort.
    """

    KEY_SIZE = KEY_SIZE
    MAX_BODY = MAX_BODY
    __slots__ = ("_tag_len", "_directions", "_current", "_previous", "_closed")

    def __init__(self, tag_len: int, directions: int, current: FrameKeys) -> None:
        """Internal: use `FrameSession.load`."""
        self._tag_len = tag_len
        self._directions = directions
        self._current = current
        self._previous: FrameKeys | None = None
        self._closed = False

    @property
    def tag_len(self) -> int:
        return self._tag_len

    @property
    def epoch(self) -> int:
        return self._current.epoch

    @classmethod
    def load(cls, key: BytesLike, epoch: int, config: FrameConfig) -> FrameSession | BadValue:
        """Derives the keys of each loaded direction from a 32-byte key and an epoch of at most 0xFFFFFF. Gives `BadValue` for a
        key that is not 32 bytes, an epoch above 0xFFFFFF, a tag length that is not 4, 8 or 16, a `directions` that is not an int (a float or a bool) or a direction bit outside
        `FrameDirections.ALL`. With `FrameDirections.NONE` it gives a session that refuses every `seal` and `open` as `BadValue`."""
        material = snapshot(key, "key")
        require_int(epoch, "epoch")
        if len(material) != KEY_SIZE or not 0 <= epoch <= MAX_EPOCH:
            return BadValue("key is not 32 bytes or epoch above 0xFFFFFF")
        if not is_int(config.tag_len) or config.tag_len not in (4, 8, 16):
            return BadValue("tag length is not 4, 8 or 16")
        directions = config.directions
        if not is_int(directions):
            return BadValue("directions is not an int")
        if directions & ~_FULL_DIRECTIONS:
            return BadValue("direction bit outside up, down and group")
        return cls(config.tag_len, directions, FrameKeys(material, epoch, directions))

    def set_previous(self, key: BytesLike, epoch: int) -> bool:
        """Keeps a previous (key, epoch) that `open` tries when the current key's tag does not match: the key just replaced,
        for frames sealed before the change. Seal never uses it. False (`BadValue`) for a key that is not 32 bytes, an epoch
        above 0xFFFFFF or a closed session. A frame that opens under it commits into the same replay window, so keep it only
        for the changeover and call `clear_previous` when that ends."""
        material = snapshot(key, "key")
        require_int(epoch, "epoch")
        if self._closed or len(material) != KEY_SIZE or not 0 <= epoch <= MAX_EPOCH:
            return False
        replaced = self._previous
        self._previous = FrameKeys(material, epoch, self._directions)
        if replaced is not None:
            replaced.wipe()
        return True

    def clear_previous(self) -> None:
        """Drops the previous (key, epoch) and overwrites its keys."""
        replaced = self._previous
        self._previous = None
        if replaced is not None:
            replaced.wipe()

    def close(self) -> None:
        """Overwrites the keys of both slots (best effort, see the type's docstring). Every later call is refused as `BadValue`."""
        self._closed = True
        self._current.wipe()
        if self._previous is not None:
            self._previous.wipe()

    def __enter__(self) -> FrameSession:
        return self

    def __exit__(self, kind: type[BaseException] | None, error: BaseException | None, trace: TracebackType | None) -> None:
        self.close()

    def seal(
        self,
        direction: int,
        message: MsgContext,
        ad: BytesLike,
        clear: BytesLike,
        plain: BytesLike,
        output: bytearray | memoryview,
    ) -> int | BadValue | TooLong | BufferFull:
        """Seals `clear + plain` into `output` as `clear + ciphertext + tag` and gives the body length. The same inputs give
        the same bytes; the session does not change and the previous key is not used. A direction not loaded, a `kind`
        above 15, a `msg_id` that is not 8 bytes or a closed session is `BadValue`; `ad` above 255 bytes, or
        `clear + plain + tag` above 255, is `TooLong`; an `output` shorter than the body is `BufferFull`. On any refusal
        nothing is written. The body is built apart and copied to `output` last, so `ad`, `clear` and `plain` may be views of
        it (sealing in place gives the same bytes).

        **For one (key, epoch, direction), never seal two different messages with the same `msg_id`.** Reuse breaks the
        confidentiality of both messages, and the library cannot check it (see `MsgContext`). A new epoch derives new keys
        and nonces."""
        require_int(direction, "direction")
        ad_bytes, clear_bytes, plain_bytes = snapshot(ad, "ad"), snapshot(clear, "clear"), snapshot(plain, "plain")
        out = writable(output, "output")
        if not self._call_allowed(direction, message):
            return BadValue("direction not loaded, kind above 15, msg_id not 8 bytes or closed session")
        if len(ad_bytes) > MAX_BODY:
            return TooLong(len(ad_bytes), MAX_BODY)
        length = len(clear_bytes) + len(plain_bytes) + self._tag_len
        if length > MAX_BODY:
            return TooLong(length, MAX_BODY)
        if len(out) < length:
            return BufferFull(length)

        keys = self._current
        nonce = _nonce(message, direction, keys.epoch)
        cipher = _crypto.chacha20_xor(keys.enc(direction), nonce, 0, plain_bytes)
        full = hmac_of(keys.mac(direction), _tag_parts(nonce, ad_bytes, clear_bytes, cipher))
        out[:length] = clear_bytes + cipher + full[: self._tag_len]
        return length

    def open(
        self,
        direction: int,
        message: MsgContext,
        ad: BytesLike,
        body: BytesLike,
        clear_length: int,
        plain: bytearray | memoryview,
        window: ReplayWindow | None = None,
        counter: int = 0,
    ) -> FrameOpened | BadValue | TooLong | ShortPacket | BufferFull | Duplicate | TooOld | TagMismatch:
        """Opens `body` (`clear + ciphertext + tag`, the first `clear_length` bytes clear) in the contract's order: argument
        checks, the replay window (when given, with the message's counter: `Duplicate` or `TooOld` before any hashing), the
        tag with the current key and then once with the previous key (`TagMismatch`), decryption into `plain`, and only then
        the window commit. `plain` and the window are untouched unless the result is a `FrameOpened`.

        A direction not loaded, a `kind` above 15, a `msg_id` that is not 8 bytes, a negative `clear_length`, a `counter`
        outside 0 to 2**64 - 1 when a `window` is given (without one the counter is ignored) or a closed session is `BadValue`; `ad`, `body` or `clear_length` above 255 is `TooLong`
        (before any hashing); a body shorter than `clear_length + tag` is `ShortPacket`; a `plain` shorter than the plaintext
        is `BufferFull`.

        The counter must come from bytes the tag covers, never from an unauthenticated wire field: it is not part of the tag."""
        require_int(direction, "direction")
        require_int(clear_length, "clear_length")
        require_int(counter, "counter")
        if window is not None and not isinstance(window, ReplayWindow):
            raise TypeError(f"window must be a ReplayWindow, got {type(window).__name__}")
        ad_bytes = snapshot(ad, "ad")
        frame = snapshot(body, "body")  # one read: the tag is checked and the text decrypted from the same bytes
        out = writable(plain, "plain")
        if not self._call_allowed(direction, message) or clear_length < 0 or (window is not None and not 0 <= counter <= _MAX_COUNTER):
            return BadValue("direction not loaded, kind above 15, msg_id not 8 bytes, bad length or counter, or closed session")
        if len(ad_bytes) > MAX_BODY:
            return TooLong(len(ad_bytes), MAX_BODY)
        if len(frame) > MAX_BODY:
            return TooLong(len(frame), MAX_BODY)
        if clear_length > MAX_BODY:
            return TooLong(clear_length, MAX_BODY)
        framing = clear_length + self._tag_len
        if len(frame) < framing:
            return ShortPacket("body", framing, len(frame))
        plain_length = len(frame) - framing
        if len(out) < plain_length:
            return BufferFull(plain_length)

        if window is not None:
            freshness = window.check(counter)
            if freshness is Freshness.DUPLICATE:
                return Duplicate()
            if freshness is Freshness.TOO_OLD:
                return TooOld()

        clear = frame[:clear_length]
        cipher = frame[clear_length : clear_length + plain_length]
        tag = frame[clear_length + plain_length :]
        previous = self._previous  # read once: a later set_previous does not change this call
        keys = self._current
        slot = FrameSlot.CURRENT
        if not self._matches(keys, direction, message, ad_bytes, clear, cipher, tag):
            if previous is None or not self._matches(previous, direction, message, ad_bytes, clear, cipher, tag):
                return TagMismatch()
            keys = previous
            slot = FrameSlot.PREVIOUS

        out[:plain_length] = _crypto.chacha20_xor(keys.enc(direction), _nonce(message, direction, keys.epoch), 0, cipher)
        if window is not None:
            window.commit(counter)
        return FrameOpened(slot, clear_length, plain_length)

    def _call_allowed(self, direction: int, message: MsgContext) -> bool:
        if not isinstance(message, MsgContext):
            raise TypeError(f"message must be a MsgContext, got {type(message).__name__}")
        return (
            not self._closed
            and direction in (1, 2, 3)
            and bool(self._directions & (1 << (direction - 1)))
            and 0 <= message.kind <= 15
            and len(message.msg_id) == 8
        )

    def _matches(self, keys: FrameKeys, direction: int, message: MsgContext, ad: bytes, clear: bytes, cipher: bytes, tag: bytes) -> bool:
        nonce = _nonce(message, direction, keys.epoch)
        full = hmac_of(keys.mac(direction), _tag_parts(nonce, ad, clear, cipher))
        return tags_equal(full[: len(tag)], tag)


def _nonce(message: MsgContext, direction: int, epoch: int) -> bytes:
    """msg_id (8) + ((kind << 4) | direction) (1) + epoch as 24 bits (3)."""
    return message.msg_id + bytes([(message.kind << 4) | direction]) + epoch.to_bytes(3, "little")


def _tag_parts(nonce: bytes, ad: bytes, clear: bytes, cipher: bytes) -> tuple[bytes, ...]:
    """M = N + len(ad) + ad + len(clear) + clear + ciphertext, as pieces for the HMAC (no joined copy)."""
    return (nonce, bytes([len(ad)]), ad, bytes([len(clear)]), clear, cipher)

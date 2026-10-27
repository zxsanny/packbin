from __future__ import annotations

import pytest

from packbin import (
    Duplicate,
    FrameConfig,
    FrameDirection,
    FrameDirections,
    FrameOpened,
    FrameSession,
    FrameSlot,
    MsgContext,
    ReplayWindow,
    TagMismatch,
    TooOld,
)
from packbin import _frame_session

# AZ-3294 AC-3: the contract's open order (arguments, replay check, tag with the current key, then the previous key,
# decrypt, commit) and the state after each refusal.

KEY = bytes(range(32))
OLD_KEY = bytes(range(100, 132))
UP = FrameDirection.UP
SENTINEL = 0xA5


def make_session() -> FrameSession:
    session = FrameSession.load(KEY, 5, FrameConfig(8, FrameDirections.ALL))
    assert isinstance(session, FrameSession)
    return session


def message(n: int = 1) -> MsgContext:
    return MsgContext(n.to_bytes(8, "little"), 2)


def seal(session: FrameSession, msg: MsgContext, plain: bytes = b"hello, relay") -> bytes:
    out = bytearray(255)
    length = session.seal(UP, msg, b"ad", b"", plain, out)
    assert isinstance(length, int)
    return bytes(out[:length])


@pytest.fixture
def counted_macs(monkeypatch: pytest.MonkeyPatch) -> list[int]:
    """One entry per HMAC the session starts."""
    calls: list[int] = []
    real = _frame_session.hmac_of

    def spy(key, parts):
        calls.append(1)
        return real(key, parts)

    monkeypatch.setattr(_frame_session, "hmac_of", spy)
    return calls


def test_ac3_a_forged_tag_is_tag_mismatch_and_leaves_the_buffer_and_window_alone(counted_macs: list[int]):
    # Arrange
    session = make_session()
    body = bytearray(seal(session, message()))
    body[-1] ^= 1
    window = ReplayWindow(10, 0b101)
    plain = bytearray([SENTINEL]) * 64
    counted_macs.clear()

    # Act
    result = session.open(UP, message(), b"ad", bytes(body), 0, plain, window, 11)

    # Assert
    assert isinstance(result, TagMismatch)
    assert (window.top, window.bits) == (10, 0b101)
    assert set(plain) == {SENTINEL}
    assert len(counted_macs) == 1


def test_ac3_a_duplicate_is_refused_before_any_mac_is_computed(counted_macs: list[int]):
    # Arrange
    session = make_session()
    body = seal(session, message())
    window = ReplayWindow()
    assert isinstance(session.open(UP, message(), b"ad", body, 0, bytearray(64), window, 7), FrameOpened)
    state = (window.top, window.bits)
    plain = bytearray([SENTINEL]) * 64
    counted_macs.clear()

    # Act
    result = session.open(UP, message(), b"ad", body, 0, plain, window, 7)

    # Assert
    assert isinstance(result, Duplicate)
    assert counted_macs == []
    assert (window.top, window.bits) == state
    assert set(plain) == {SENTINEL}


def test_ac3_a_counter_64_or_more_below_the_top_is_too_old_before_any_mac_is_computed(counted_macs: list[int]):
    # Arrange
    session = make_session()
    body = seal(session, message())
    window = ReplayWindow(100, 1)
    plain = bytearray([SENTINEL]) * 64
    counted_macs.clear()

    # Act
    result = session.open(UP, message(), b"ad", body, 0, plain, window, 36)

    # Assert
    assert isinstance(result, TooOld)
    assert counted_macs == []
    assert (window.top, window.bits) == (100, 1)
    assert set(plain) == {SENTINEL}


def test_ac3_a_frame_under_the_previous_key_opens_with_slot_previous_and_commits():
    # Arrange
    old = FrameSession.load(OLD_KEY, 4, FrameConfig(8, FrameDirections.ALL))
    assert isinstance(old, FrameSession)
    body = seal(old, message())
    session = make_session()
    assert session.set_previous(OLD_KEY, 4)
    window = ReplayWindow()
    plain = bytearray(64)

    # Act
    result = session.open(UP, message(), b"ad", body, 0, plain, window, 3)

    # Assert
    assert result == FrameOpened(FrameSlot.PREVIOUS, 0, 12)
    assert bytes(plain[:12]) == b"hello, relay"
    assert (window.top, window.bits) == (3, 1)


def test_the_previous_key_is_gone_after_clear_previous():
    # Arrange
    old = FrameSession.load(OLD_KEY, 4, FrameConfig(8, FrameDirections.ALL))
    assert isinstance(old, FrameSession)
    body = seal(old, message())
    session = make_session()
    assert session.set_previous(OLD_KEY, 4)
    session.clear_previous()

    # Act
    result = session.open(UP, message(), b"ad", body, 0, bytearray(64))

    # Assert
    assert isinstance(result, TagMismatch)


def test_a_counter_is_committed_only_after_the_frame_opened():
    # Arrange
    session = make_session()
    body = seal(session, message())
    window = ReplayWindow()

    # Act
    first = session.open(UP, message(), b"ad", body, 0, bytearray(64), window, 9)
    second = session.open(UP, message(), b"ad", body, 0, bytearray(64), window, 9)

    # Assert
    assert (type(first), type(second), window.top, window.bits) == (FrameOpened, Duplicate, 9, 1)

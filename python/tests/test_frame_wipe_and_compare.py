from __future__ import annotations

import hmac

import pytest

from packbin import BadValue, FrameConfig, FrameDirection, FrameDirections, FrameSession, MacKey, MsgContext
from packbin import _frame_keys

KEY = bytes([0x42]) * 32
UP = FrameDirection.UP


def make_session(tag: int = 8) -> FrameSession:
    session = FrameSession.load(KEY, 9, FrameConfig(tag, FrameDirections.ALL))
    assert isinstance(session, FrameSession)
    return session


def test_close_zeroes_every_key_of_both_slots_and_the_session_refuses_later_calls():
    # Arrange
    session = make_session()
    assert session.set_previous(KEY, 8)
    arrays = session._current.arrays() + session._previous.arrays()
    message = MsgContext(bytes(8), 1)
    body = bytearray(32)
    assert isinstance(session.seal(UP, message, b"", b"", bytes(4), body), int)
    assert len(arrays) == 12 and all(any(a) for a in arrays)

    # Act
    session.close()
    session.close()

    # Assert
    assert all(not any(a) for a in arrays)
    assert isinstance(session.seal(UP, message, b"", b"", bytes(4), bytearray(32)), BadValue)


def test_the_context_manager_closes_the_session():
    # Arrange and Act
    with make_session() as session:
        arrays = session._current.arrays()

    # Assert
    assert all(not any(a) for a in arrays)


def test_a_closed_mac_key_has_a_zeroed_key():
    # Arrange
    mac = MacKey.derive(KEY, 9, b"net")
    assert isinstance(mac, MacKey)
    array = mac._key
    assert any(array)

    # Act
    mac.close()

    # Assert
    assert not any(array)


def test_replacing_the_previous_slot_zeroes_the_old_one():
    # Arrange
    session = make_session(4)
    assert session.set_previous(KEY, 1)
    old = session._previous.arrays()

    # Act
    assert session.set_previous(KEY, 2)

    # Assert
    assert all(not any(a) for a in old)
    assert any(any(a) for a in session._previous.arrays())


def test_clear_previous_zeroes_the_previous_slot():
    # Arrange
    session = make_session(4)
    assert session.set_previous(KEY, 1)
    old = session._previous.arrays()

    # Act
    session.clear_previous()

    # Assert
    assert all(not any(a) for a in old) and session._previous is None


@pytest.mark.parametrize("at", [-16, -1], ids=["first tag byte", "last tag byte"])
def test_the_open_compare_runs_over_every_tag_byte_with_hmac_compare_digest(monkeypatch: pytest.MonkeyPatch, at: int):
    # Arrange
    session = make_session(16)
    message = MsgContext(bytes(8), 1)
    out = bytearray(64)
    length = session.seal(UP, message, b"", b"", b"text", out)
    assert isinstance(length, int)
    body = bytearray(out[:length])
    body[at] ^= 1
    seen: list[tuple[int, int]] = []
    real = hmac.compare_digest

    def spy(left, right):
        seen.append((len(left), len(right)))
        return real(left, right)

    monkeypatch.setattr(_frame_keys.hmac, "compare_digest", spy)

    # Act
    result = session.open(UP, message, b"", bytes(body), 0, bytearray(64))

    # Assert
    assert type(result).__name__ == "TagMismatch"
    assert seen == [(16, 16)]


def test_the_tag_compare_separates_equal_first_byte_and_last_byte_differences():
    # Arrange
    tag = bytes(range(1, 9))
    first = bytes([tag[0] ^ 0x80]) + tag[1:]
    last = tag[:-1] + bytes([tag[-1] ^ 1])

    # Act and Assert
    assert [_frame_keys.tags_equal(tag, tag), _frame_keys.tags_equal(tag, first), _frame_keys.tags_equal(tag, last), _frame_keys.tags_equal(tag, tag[:7])] == [True, False, False, False]

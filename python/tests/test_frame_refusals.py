from __future__ import annotations

import pytest

from packbin import (
    BadValue,
    BufferFull,
    FrameConfig,
    FrameDirection,
    FrameDirections,
    FrameOpened,
    FrameSession,
    MsgContext,
    ReplayWindow,
    ShortPacket,
    TooLong,
)

KEY = bytes(range(32))
ID = bytes([1, 2, 3, 4, 5, 6, 7, 8])
SENTINEL = 0xA5
UP, DOWN, GROUP = FrameDirection.UP, FrameDirection.DOWN, FrameDirection.GROUP


def make_session(tag: int = 4, dirs: FrameDirections = FrameDirections.ALL) -> FrameSession:
    session = FrameSession.load(KEY, 5, FrameConfig(tag, dirs))
    assert isinstance(session, FrameSession)
    return session


def sentinels(n: int) -> bytearray:
    return bytearray([SENTINEL]) * n


def untouched(buffer: bytearray) -> bool:
    return set(buffer) <= {SENTINEL}


@pytest.mark.parametrize(
    "key, epoch, tag, dirs",
    [
        (KEY, 0x1000000, 4, FrameDirections.ALL),
        (KEY, -1, 4, FrameDirections.ALL),
        *[(KEY, 1, tag, FrameDirections.ALL) for tag in (0, 1, 5, 12, 17, 32, -4)],
        (KEY[:31], 1, 4, FrameDirections.ALL),
        (KEY + b"\0", 1, 4, FrameDirections.ALL),
        (KEY, 1, 4, FrameDirections(8)),
        (KEY, 1, 4, FrameDirections.ALL | FrameDirections(8)),
    ],
)
def test_load_refuses_what_the_contract_calls_bad_value(key: bytes, epoch: int, tag: int, dirs: FrameDirections):
    # Act
    result = FrameSession.load(key, epoch, FrameConfig(tag, dirs))

    # Assert
    assert isinstance(result, BadValue)


def test_load_accepts_the_largest_epoch_and_every_tag_length():
    # Act
    sessions = [FrameSession.load(KEY, 0xFFFFFF, FrameConfig(tag, FrameDirections.ALL)) for tag in (4, 8, 16)]

    # Assert
    assert all(isinstance(s, FrameSession) for s in sessions)


@pytest.mark.parametrize("tag", [4, 8, 16])
def test_load_with_no_direction_gives_a_session_that_refuses_every_seal_and_open(tag: int):
    # Arrange
    none = make_session(tag, FrameDirections.NONE)
    allowed = make_session(tag)
    for direction in (UP, DOWN, GROUP):
        message = MsgContext(ID, 1)
        body = bytearray(32)
        length = allowed.seal(direction, message, b"", b"", bytes(4), body)
        assert isinstance(length, int)
        output, plain, window = sentinels(64), sentinels(64), ReplayWindow(5, 1)

        # Act
        sealed = none.seal(direction, message, b"", b"", bytes(4), output)
        opened = none.open(direction, message, b"", bytes(body[:length]), 0, plain, window, 6)

        # Assert
        assert (type(sealed), type(opened)) == (BadValue, BadValue)
        assert untouched(output) and untouched(plain)
        assert (window.top, window.bits) == (5, 1)


def test_a_direction_not_loaded_is_bad_value_and_nothing_is_written():
    # Arrange
    session = make_session(4, FrameDirections.UP)
    output = sentinels(64)

    # Act
    results = [session.seal(d, MsgContext(ID, 1), b"", b"", b"x", output) for d in (0, 2, 3, 4, -1)]

    # Assert
    assert [type(r) for r in results] == [BadValue] * 5
    assert untouched(output)


@pytest.mark.parametrize("msg_id, kind", [(ID, 16), (ID, -1), (ID[:7], 1), (ID + b"\0", 1), (b"", 1)])
def test_a_bad_kind_or_msg_id_is_bad_value_in_seal_and_open(msg_id: bytes, kind: int):
    # Arrange
    session = make_session()
    output = sentinels(64)

    # Act
    sealed = session.seal(UP, MsgContext(msg_id, kind), b"", b"", b"x", output)
    opened = session.open(UP, MsgContext(msg_id, kind), b"", bytes(8), 0, output)

    # Assert
    assert (type(sealed), type(opened)) == (BadValue, BadValue)
    assert untouched(output)


def test_seal_limits_give_too_long_and_buffer_full_without_writing():
    # Arrange
    session = make_session(4)
    message = MsgContext(ID, 1)
    output = sentinels(300)

    # Act
    long_ad = session.seal(UP, message, bytes(256), b"", b"x", output)
    long_body = session.seal(UP, message, b"", bytes(100), bytes(152), output)
    short = session.seal(UP, message, b"", b"", bytes(20), sentinels(23))
    exact = session.seal(UP, message, b"", bytes(100), bytes(151), output)

    # Assert
    assert long_ad == TooLong(256, 255)
    assert long_body == TooLong(256, 255)
    assert short == BufferFull(24)
    assert exact == 255


def test_open_limits_and_order_of_the_argument_checks():
    # Arrange
    session = make_session(4)
    message = MsgContext(ID, 1)
    plain = sentinels(300)

    # Act
    results = [
        session.open(UP, message, bytes(256), bytes(10), 0, plain),
        session.open(UP, message, b"", bytes(256), 0, plain),
        session.open(UP, message, b"", bytes(10), 256, plain),
        session.open(UP, message, b"", bytes(10), -1, plain),
        session.open(UP, message, b"", bytes(5), 2, plain),
        session.open(UP, message, b"", bytes(30), 0, sentinels(25)),
    ]

    # Assert
    assert results == [TooLong(256, 255), TooLong(256, 255), TooLong(256, 255), BadValue(results[3].reason), ShortPacket("body", 6, 5), BufferFull(26)]
    assert untouched(plain)


def test_a_counter_outside_64_bits_is_bad_value_and_leaves_the_window_alone():
    # Arrange
    session = make_session()
    window = ReplayWindow(3, 1)

    # Act
    result = session.open(UP, MsgContext(ID, 1), b"", bytes(8), 0, bytearray(8), window, 1 << 64)

    # Assert
    assert isinstance(result, BadValue)
    assert (window.top, window.bits) == (3, 1)


def test_a_negative_counter_with_a_window_is_bad_value_without_an_exception_and_leaves_both_alone():
    # Arrange
    session = make_session()
    body = bytearray(32)
    length = session.seal(UP, MsgContext(ID, 1), b"", b"", b"x", body)
    assert isinstance(length, int)
    window = ReplayWindow(3, 1)
    plain = sentinels(8)

    # Act
    result = session.open(UP, MsgContext(ID, 1), b"", bytes(body[:length]), 0, plain, window, -1)

    # Assert
    assert isinstance(result, BadValue)
    assert untouched(plain)
    assert (window.top, window.bits) == (3, 1)


def test_a_negative_counter_without_a_window_is_ignored():
    # Arrange
    session = make_session()
    body = bytearray(32)
    length = session.seal(UP, MsgContext(ID, 1), b"", b"", b"x", body)
    assert isinstance(length, int)
    plain = bytearray(8)

    # Act
    result = session.open(UP, MsgContext(ID, 1), b"", bytes(body[:length]), 0, plain, None, -1)

    # Assert
    assert isinstance(result, FrameOpened)
    assert bytes(plain[:1]) == b"x"


@pytest.mark.parametrize("directions", [3.0, True, "3", None])
def test_load_refuses_a_directions_value_that_is_not_an_int(directions: object):
    # Act
    result = FrameSession.load(KEY, 1, FrameConfig(4, directions))  # type: ignore[arg-type]

    # Assert
    assert isinstance(result, BadValue)


def test_sealing_in_place_gives_the_same_bytes_as_sealing_apart():
    # Arrange
    session = make_session(8)
    message = MsgContext(ID, 3)
    apart = bytearray(64)
    length = session.seal(UP, message, b"ad", b"cl", b"plain text", apart)
    shared = bytearray(b"cl" + b"plain text") + bytearray(64)
    view = memoryview(shared)

    # Act
    in_place = session.seal(UP, message, b"ad", view[:2], view[2:12], shared)

    # Assert
    assert in_place == length
    assert bytes(shared[:length]) == bytes(apart[:length])


def test_a_closed_session_refuses_every_call():
    # Arrange
    session = make_session()
    message = MsgContext(ID, 1)
    body = bytearray(32)
    length = session.seal(UP, message, b"", b"", bytes(4), body)
    session.close()
    output = sentinels(32)

    # Act
    sealed = session.seal(UP, message, b"", b"", bytes(4), output)
    opened = session.open(UP, message, b"", bytes(body[:length]), 0, output)

    # Assert
    assert (type(sealed), type(opened), session.set_previous(KEY, 1)) == (BadValue, BadValue, False)
    assert untouched(output)


def test_set_previous_refuses_a_short_key_and_a_large_epoch():
    # Arrange
    session = make_session()

    # Act and Assert
    assert [session.set_previous(KEY[:31], 1), session.set_previous(KEY, 0x1000000), session.set_previous(KEY, 0xFFFFFF)] == [False, False, True]


def test_a_value_of_the_wrong_python_type_is_a_type_error():
    # Arrange
    session = make_session()

    # Act and Assert
    with pytest.raises(TypeError):
        session.seal(UP, MsgContext(ID, 1), "ad", b"", b"", bytearray(32))  # type: ignore[arg-type]
    with pytest.raises(TypeError):
        session.seal(UP, MsgContext(ID, 1), b"", b"", b"", bytes(32))  # type: ignore[arg-type]
    with pytest.raises(TypeError):
        MsgContext(8, 1)  # type: ignore[arg-type]

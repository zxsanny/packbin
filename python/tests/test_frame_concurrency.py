from __future__ import annotations

import time
from concurrent.futures import ThreadPoolExecutor

import timing_support
from packbin import FrameConfig, FrameDirection, FrameDirections, FrameOpened, FrameSession, MsgContext

THREADS = 8
PER_THREAD = 60


def inputs(thread: int, i: int) -> tuple[MsgContext, bytes, bytes, bytes]:
    msg_id = thread.to_bytes(4, "little") + i.to_bytes(4, "little")
    plain = bytes((thread * 31 + i + k) & 0xFF for k in range(i % 80))
    return MsgContext(msg_id, i % 16), bytes([thread, i]), bytes([i, 7]), plain


def seal_one(session: FrameSession, thread: int, i: int) -> bytes:
    message, ad, clear, plain = inputs(thread, i)
    body = bytearray(255)
    length = session.seal(FrameDirection.GROUP, message, ad, clear, plain, body)
    assert isinstance(length, int)
    return bytes(body[:length])


def test_eight_threads_sealing_the_same_session_give_the_single_thread_bodies():
    # Arrange
    session = FrameSession.load(bytes(32), 3, FrameConfig(8, FrameDirections.ALL))
    assert isinstance(session, FrameSession)
    expected = [[seal_one(session, t, i) for i in range(PER_THREAD)] for t in range(THREADS)]
    limit = timing_support.bound(20)

    # Act
    start = time.perf_counter()
    with ThreadPoolExecutor(THREADS) as pool:
        actual = list(pool.map(lambda t: [seal_one(session, t, i) for i in range(PER_THREAD)], range(THREADS)))
    elapsed = time.perf_counter() - start

    # Assert
    assert actual == expected
    timing_support.assert_within(elapsed, limit, "8 x 60 seals on 8 threads")
    for t in range(THREADS):
        for i in range(PER_THREAD):
            message, ad, clear, plain = inputs(t, i)
            text = bytearray(255)
            opened = session.open(FrameDirection.GROUP, message, ad, actual[t][i], len(clear), text)
            assert isinstance(opened, FrameOpened) and bytes(text[: opened.plain_length]) == plain

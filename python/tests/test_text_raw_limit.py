from __future__ import annotations

import tracemalloc

import pytest

from packbin._text_decode import TextRefusal, decode_text


# AZ-2666 (loop 41 audit, L1): a raw payload is refused for its length before it is copied or decoded.


def test_a_raw_payload_above_65535_bytes_is_refused_for_its_length_before_its_utf8():
    # Arrange: count 65,537 = 81 80 04; the raw prefix, 65,535 letters and a byte that is not UTF-8
    field = bytes((0x81, 0x80, 0x04, 0x10)) + b"a" * 65535 + b"\xff"

    # Act
    with pytest.raises(TextRefusal) as refused:
        decode_text(field, 0)

    # Assert
    assert refused.value.kind == "length"


def test_a_raw_payload_of_the_largest_count_is_refused_without_a_copy():
    # Arrange: count 2,097,151 = ff ff 7f, the raw prefix and 2,097,150 bytes
    field = bytes((0xFF, 0xFF, 0x7F, 0x10)) + b"a" * 2_097_150
    tracemalloc.start()

    # Act
    try:
        with pytest.raises(TextRefusal):
            decode_text(field, 0)
        _, peak = tracemalloc.get_traced_memory()
    finally:
        tracemalloc.stop()

    # Assert
    assert peak < 65536

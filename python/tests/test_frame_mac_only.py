from __future__ import annotations

import pytest

from packbin import BadValue, MacKey
from packbin import _crypto

KEY = bytes([0x22]) * 32
MESSAGE = bytes(range(70))


def derive(epoch: int = 7, label: bytes = b"net") -> MacKey:
    key = MacKey.derive(KEY, epoch, label)
    assert isinstance(key, MacKey)
    return key


def test_the_tag_is_the_first_n_bytes_of_the_hmac_under_the_label_key():
    # Arrange
    k_label = _crypto.hkdf_sha256(KEY, b"packbin-frame" + (7).to_bytes(4, "little"), b"\x00net", 32)
    full = _crypto.hmac_sha256(k_label, MESSAGE)
    mac = derive()

    # Act
    tags = {n: mac.tag(MESSAGE, n) for n in (4, 8, 16, 32)}

    # Assert
    assert tags == {n: full[:n] for n in (4, 8, 16, 32)}


def test_the_tag_does_not_depend_on_how_the_message_is_split():
    # Arrange
    mac = derive()

    # Act
    whole = mac.tag(MESSAGE, 16)
    split = mac.tag([MESSAGE[:1], b"", MESSAGE[1:63], bytearray(MESSAGE[63:])], 16)
    views = mac.tag(iter([memoryview(MESSAGE)[:10], memoryview(MESSAGE)[10:]]), 16)

    # Assert
    assert whole == split == views


@pytest.mark.parametrize("n", [0, 1, 2, 5, 31, 33, -4])
def test_a_tag_length_that_is_not_allowed_is_bad_value(n: int):
    # Act and Assert
    assert isinstance(derive().tag(MESSAGE, n), BadValue)


@pytest.mark.parametrize("label, epoch", [(b"", 1), (bytes(33), 1), (b"net", 0x1000000), (b"net", -1)])
def test_derive_refuses_a_bad_label_or_epoch(label: bytes, epoch: int):
    # Act and Assert
    assert isinstance(MacKey.derive(KEY, epoch, label), BadValue)


def test_derive_refuses_a_key_that_is_not_32_bytes_and_accepts_the_edges():
    # Act and Assert
    assert isinstance(MacKey.derive(KEY[:31], 1, b"net"), BadValue)
    assert isinstance(MacKey.derive(KEY, 0xFFFFFF, bytes(32)), MacKey)
    assert isinstance(MacKey.derive(KEY, 0, b"x"), MacKey)


def test_verify_is_true_for_the_tag_and_false_for_a_changed_byte_or_another_length():
    # Arrange
    mac = derive()
    tag = mac.tag(MESSAGE, 8)
    assert isinstance(tag, bytes)
    first = bytes([tag[0] ^ 0x80]) + tag[1:]
    last = tag[:-1] + bytes([tag[-1] ^ 1])

    # Act
    results = [mac.verify(MESSAGE, tag), mac.verify(MESSAGE, first), mac.verify(MESSAGE, last), mac.verify(MESSAGE, tag[:5]), mac.verify(MESSAGE, b""), mac.verify(MESSAGE[:-1], tag)]

    # Assert
    assert results == [True, False, False, False, False, False]


def test_a_different_epoch_or_label_gives_another_tag():
    # Act
    tags = {derive().tag(MESSAGE, 32), derive(8).tag(MESSAGE, 32), derive(7, b"net2").tag(MESSAGE, 32)}

    # Assert
    assert len(tags) == 3


def test_a_closed_key_refuses_tag_and_verify():
    # Arrange
    mac = derive()
    tag = mac.tag(MESSAGE, 4)
    assert isinstance(tag, bytes)

    # Act
    with mac:
        pass

    # Assert
    assert isinstance(mac.tag(MESSAGE, 4), BadValue)
    assert mac.verify(MESSAGE, tag) is False

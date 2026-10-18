from __future__ import annotations

import pytest

from packbin import Uncorrectable

import ecc_support as support

# AZ-2695 AC-1: the repaired bytes are checked once more against the parity before they are returned. Each word below
# is the position fixture (n = 4) with 3 or 4 wrong bytes: its locator has fewer places than the sequence needs, so a
# repair without that check finds the right number of roots, changes bytes, and hands over a word that is not a code word.

WORDS = [
    (1, "4001008865cd1da5a3e1118a00d4856682"),
    (1, "4001000065cd7a00a3de110100cad26682"),
    (1, "4001000065cde000a3e111010074676628"),
    (2, "400100af65cd1d00a3e111bf90ca856682"),
    (2, "4001000065d31d0037e111d600ca856682"),
    (2, "4001001c65cdee00a3e1116f00ca856682"),
]


@pytest.mark.parametrize(("limit", "word"), WORDS)
def test_a_repair_that_leaves_a_word_that_is_not_a_code_word_is_refused(limit: int, word: str):
    # Arrange
    scheme = support.position_scheme(4)
    received = bytes.fromhex(word)

    # Act
    result = support.read(received, scheme, limit=limit)

    # Assert
    assert (result.ok, result.value, result.error) == (False, None, Uncorrectable())

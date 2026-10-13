from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    ShortPacket,
    bits,
    eq,
    packed,
    sized,
    times,
    u8,
    when,
)


# AZ-2474 (loop 25, Low-1): a value given to a member whose `count` no earlier field wrote is a user error.
# Python used to raise `RuntimeError("count N is missing")`; parity with TypeScript names this a `ValueError`
# with the text `"<member>: count <count_id> was not written"`. Only `pack` is touched; `TypeError` for a wrong
# Python value type stays, and `unpack` is unchanged.
#
# The scheme shape that reaches the raise is already used by AZ-2386 / AZ-2410: a `when` holds the count field
# (`u8(1, "c")`), so a row with `mode == 0` leaves the count unwritten. The counted member (plain, outside
# `flags`) then runs with no written source.


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _plain_counted(member: str) -> Scheme:
    head = (_u8(0, "mode"), when(1, eq(0, 1), _u8(1, "c")))
    node = {
        "bits": lambda: bits(2, lambda row: row["v"], 1),
        "packed": lambda: packed(1, 2, lambda row: row["v"], 1),
        "sized": lambda: sized(2, lambda row: row["v"], 1),
    }[member]()
    return Scheme(1, dict, *head, node)


def _plain_times() -> Scheme:
    head = (_u8(0, "mode"), when(1, eq(0, 1), _u8(1, "c")))
    body = times(2, 1, _u8(2, "pt"))
    return Scheme(1, dict, *head, body)


# ---------------------------------------------------------------------------
# AC-1: pack with no written count raises `ValueError`, not `RuntimeError`.
# ---------------------------------------------------------------------------
@pytest.mark.parametrize("member", ["bits", "packed", "sized"])
def test_ac1_pack_counted_member_raises_valueerror_not_runtimeerror(member: str):
    # Arrange: `mode == 0` leaves the `when` clear, so no field writes the count `c` before the counted member.
    row = {"mode": 0, "c": 3, "v": _value_for(member)}

    # Act / Assert: the raise is `ValueError`, not `RuntimeError`.
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(_plain_counted(member), row)
    assert not isinstance(caught.value, RuntimeError)


def test_ac1_pack_times_with_unwritten_count_raises_valueerror_not_runtimeerror():
    # Arrange: `mode == 0` leaves `c` unwritten; the plain `times` reads it as its count.
    row = {"mode": 0, "c": 1, "pt": [5]}

    # Act / Assert
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(_plain_times(), row)
    assert not isinstance(caught.value, RuntimeError)


# ---------------------------------------------------------------------------
# AC-2: the message is TypeScript's text — the member name, then `: count `, then the count id,
# then ` was not written`. Pinned for every counted-member kind.
# ---------------------------------------------------------------------------
@pytest.mark.parametrize("member", ["bits", "packed", "sized"])
def test_ac2_counted_member_message_matches_typescript_text(member: str):
    # Arrange
    row = {"mode": 0, "c": 3, "v": _value_for(member)}

    # Act
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(_plain_counted(member), row)

    # Assert: the member name is the counted-member's field id ("2"), the count id is "1" (the `u8(1, "c")`).
    assert str(caught.value) == "2: count 1 was not written"


def test_ac2_times_message_matches_typescript_text():
    # Arrange
    row = {"mode": 0, "c": 1, "pt": [5]}

    # Act
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(_plain_times(), row)

    # Assert: the member for `times` is the literal `times` (TypeScript reference), the count id is "1".
    assert str(caught.value) == "times: count 1 was not written"


# ---------------------------------------------------------------------------
# AC-3: a wrong Python value type keeps raising `TypeError`; it is not shadowed by the AC-1 / AC-2 change.
# ---------------------------------------------------------------------------
def test_ac3_wrong_value_type_still_raises_typeerror_not_valueerror():
    # Arrange: `u8(0, "x")` reads row["x"]; a string is the wrong type for a `u8`.
    scheme = Scheme(1, dict, _u8(0, "x"))

    # Act / Assert
    with pytest.raises(TypeError):
        BinaryPacker.pack(scheme, {"x": "a string, not a number"})


# ---------------------------------------------------------------------------
# AC-4: unpack is unchanged — a packet that ends before a counted member's bytes returns a `ShortPacket`
# error, same as before this change. Unpack never raised `RuntimeError("count N is missing")` and does not
# raise `ValueError("count N was not written")` either.
# ---------------------------------------------------------------------------
def test_ac4_unpack_on_short_packet_is_unchanged():
    # Arrange: the on-wire bytes end before the `sized` body can be read (one count byte of 1, zero body bytes).
    scheme = Scheme(1, dict, _u8(0, "n"), sized(1, lambda row: row["b"], 0))

    # Act
    got = BinaryPacker.unpack(bytes([1, 1]), scheme.on(lambda _row: None))

    # Assert: unpack returns a failed result with a `ShortPacket`, not a raised exception.
    assert got.ok is False
    assert isinstance(got.error, ShortPacket)


def _value_for(member: str):
    return b"\x01\x02\x03" if member == "sized" else [1, 0, 1]

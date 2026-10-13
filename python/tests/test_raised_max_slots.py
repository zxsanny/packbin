from __future__ import annotations

from packbin import BinaryPacker, Scheme, ShortPacket, group, times, u8
from packbin import list as list_field

# AZ-2435 (G1 of assessment 22): AZ-2415 AC-3 for Python. The default `max_slots` went from 4 194 304 to 1 048 576
# in loop 22; a scheme that raises the limit back to 4 194 304 still unpacks the old worst packet (F10: 65 535 list
# items, each one `times` round of 64 one-byte names, 4 194 240 slots in all). The default-limit refusal of the same
# packet is also pinned by `test_loop22_parity.py::test_az2415_ac2_...`. These tests allocate a few hundred MB and
# take seconds; the package has no slow marker (`pyproject.toml` declares none), so they run in the default suite.

RAISED = 4_194_304
ITEMS = 65_535
NAMES = 64
PACKET = b"\x01\xff\xff" + (b"\x01" * (NAMES + 1)) * ITEMS


def _f10_scheme() -> Scheme:
    items = group(
        0,
        u8(0, lambda row: row["n"]),
        times(1, 0, *[u8(1 + i, lambda row, i=i: row[f"k{i}"]) for i in range(NAMES)]),
    )
    return Scheme(1, dict, list_field(lambda row: row["items"], items))


def _item() -> dict:
    # The row every item unpacks to at HEAD: the count 1 and a one-round list per name.
    return {"n": 1, **{f"k{i}": [1] for i in range(NAMES)}}


def test_az2435_ac1_with_max_slots_raised_to_4_194_304_the_f10_packet_unpacks_to_the_rows_at_head():
    # Arrange
    seen: list = []
    scheme = _f10_scheme().with_limits(max_slots=RAISED).on(seen.append)

    # Act
    result = BinaryPacker.unpack(PACKET, scheme)

    # Assert
    assert (result.ok, len(seen)) == (True, 1)
    assert seen[0] is result.value
    assert result.value == {"items": [_item()] * ITEMS}


def test_az2435_ac1_the_unpacked_row_packs_back_to_the_same_packet_at_the_raised_limit():
    # Arrange
    scheme = _f10_scheme().with_limits(max_slots=RAISED)
    row = {"items": [_item()] * ITEMS}

    # Act
    packet = BinaryPacker.pack(scheme, row)

    # Assert
    assert packet == PACKET


def test_az2435_ac2_the_default_limit_refuses_the_f10_packet_by_the_slots():
    # Arrange
    seen: list = []
    scheme = _f10_scheme().on(seen.append)

    # Act
    result = BinaryPacker.unpack(PACKET, scheme)

    # Assert: 16 384 items charge 1 048 576 slots; the 16 385th is refused
    assert (Scheme.DEFAULT_MAX_SLOTS, result.ok, seen) == (1_048_576, False, [])
    assert result.error == ShortPacket(field="1", needed=0, left=3_194_814)


def test_az2435_ac2_one_slot_below_the_packet_total_refuses_the_last_item():
    # Arrange: 65 535 x 64 = 4 194 240 slots; one fewer refuses at the last item
    seen: list = []
    scheme = _f10_scheme().with_limits(max_slots=ITEMS * NAMES - 1).on(seen.append)

    # Act
    result = BinaryPacker.unpack(PACKET, scheme)

    # Assert: the refused item's 64 name bytes are left unread
    assert (result.ok, seen) == (False, [])
    assert result.error == ShortPacket(field="1", needed=0, left=NAMES)

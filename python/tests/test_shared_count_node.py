from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, bits, eq, flags, packed, sized, u8, when

# Review finding 4 (loop 22): one `bits`, `packed` or `sized` node object placed in two schemes keeps the count
# source of its own scheme; the second scheme must not change what the first one refuses.


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _scheme(type_number: int, count_name: str, node) -> Scheme:
    return Scheme(type_number, dict, _u8(0, "mode"), when(1, eq(0, 1), _u8(1, count_name)), flags(2, node))


def _shared(member: str):
    value = lambda row: row["v"]  # noqa: E731
    return {
        "bits": lambda: bits(2, value, 1),
        "packed": lambda: packed(1, 2, value, 1, 0),
        "sized": lambda: sized(2, value, 1),
    }[member]()


def _refused(scheme: Scheme, row: dict, count_name: str) -> None:
    with pytest.raises(ValueError, match=f"the count {count_name} is 3 in the row, but no field wrote it"):
        BinaryPacker.pack(scheme, row)


@pytest.mark.parametrize("member", ["bits", "packed", "sized"])
@pytest.mark.parametrize("pack_a_first", [True, False])
def test_two_schemes_sharing_one_node_each_refuse_their_own_count(member: str, pack_a_first: bool) -> None:
    node = _shared(member)
    scheme_a = _scheme(1, "c", node)
    scheme_b = _scheme(2, "other", node)
    row_a = {"mode": 0, "c": 3}
    row_b = {"mode": 0, "other": 3}

    checks = [(scheme_a, row_a, "c"), (scheme_b, row_b, "other")]
    for scheme, row, count_name in checks if pack_a_first else reversed(checks):
        _refused(scheme, row, count_name)
    for scheme, row, count_name in checks:
        _refused(scheme, row, count_name)


def test_shared_node_packs_the_same_bytes_in_both_schemes() -> None:
    node = _shared("sized")
    scheme_a = _scheme(1, "c", node)
    scheme_b = _scheme(2, "other", node)
    assert BinaryPacker.pack(scheme_b, {"mode": 1, "other": 1, "v": b"x"}).hex() == "0201010178"
    assert BinaryPacker.pack(scheme_a, {"mode": 1, "c": 1, "v": b"x"}).hex() == "0101010178"
    assert BinaryPacker.pack(scheme_a, {"mode": 0, "c": 0}).hex() == "010000"

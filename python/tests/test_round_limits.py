from __future__ import annotations

import pytest

import packbin._nodes as nodes
import packbin._pack as pack_module
import packbin._unpack as unpack_module
from packbin import BinaryPacker, Scheme, ShortPacket, eq, group, repeat, times, u8, u32, when
from packbin import dict as dict_field
from packbin import list as list_field


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _repeat_k(type_number: int = 1) -> Scheme:
    return Scheme(type_number, dict, repeat(0, _u8(0, "k")))


def _times_k() -> Scheme:
    return Scheme(1, dict, _u8(0, "n"), times(1, 0, _u8(1, "k")))


def _times_u32() -> Scheme:
    return Scheme(1, dict, u32(0, lambda row: row["n"]), times(1, 0, _u8(1, "k")))


def _three_names() -> Scheme:
    return Scheme(
        1,
        dict,
        repeat(0, _u8(0, "k"), when(1, eq(0, 1), _u8(1, "a"), _u8(2, "b"))),
    )


def _unpack(scheme: Scheme, data: bytes):
    seen: list = []
    result = BinaryPacker.unpack(data, scheme.on(seen.append))
    return result, seen


def _refusal(result, seen, left: int) -> None:
    assert result.ok is False
    assert result.value is None
    assert seen == []
    assert isinstance(result.error, ShortPacket)
    assert (result.error.needed, result.error.left) == (0, left)


def test_ac1_defaults_and_surface():
    base = _repeat_k()

    limited = base.with_limits(max_rounds=10)

    assert (Scheme.DEFAULT_MAX_ROUNDS, Scheme.DEFAULT_MAX_SLOTS) == (65_535, 4_194_304)
    assert (base.max_rounds, base.max_slots) == (65_535, 4_194_304)
    assert (limited.max_rounds, limited.max_slots) == (10, 4_194_304)


def test_ac1_an_omitted_limit_is_the_default_not_the_current_value():
    scheme = _repeat_k().with_limits(max_rounds=10).with_limits(max_slots=20)

    assert (scheme.max_rounds, scheme.max_slots) == (65_535, 20)


def test_ac2_repeat_at_the_default_limit():
    scheme = _repeat_k()

    ok, ok_seen = _unpack(scheme, b"\x01" + b"\x07" * 65_535)
    over, over_seen = _unpack(scheme, b"\x01" + b"\x07" * 65_536)

    assert ok.ok
    assert len(ok_seen) == 1 and len(ok_seen[0]["k"]) == 65_535
    _refusal(over, over_seen, left=1)


def test_ac3_repeat_is_refused_when_the_round_past_the_limit_would_start():
    scheme = _repeat_k().with_limits(max_rounds=3)

    ok, ok_seen = _unpack(scheme, bytes.fromhex("01aabbcc"))
    over, over_seen = _unpack(scheme, bytes.fromhex("01aabbccdd"))

    assert ok.ok
    assert ok_seen == [{"k": [170, 187, 204]}]
    _refusal(over, over_seen, left=1)


@pytest.mark.parametrize(
    "hex_bytes,left",
    [("010409090909", 1), ("0104090909", 0)],
    ids=["round_four_with_a_byte_left", "count_four_three_rounds_present"],
)
def test_ac4_times_is_refused_when_the_round_past_the_limit_would_start(hex_bytes: str, left: int):
    scheme = _times_k().with_limits(max_rounds=3)

    result, seen = _unpack(scheme, bytes.fromhex(hex_bytes))

    _refusal(result, seen, left=left)


def test_ac4_times_inside_the_limit_is_unchanged():
    scheme = _times_k().with_limits(max_rounds=3)

    result, seen = _unpack(scheme, bytes.fromhex("0103090909"))

    assert result.ok
    assert seen == [{"n": 3, "k": [9, 9, 9]}]


@pytest.mark.parametrize("hex_bytes", ["01ff09", "01030909"], ids=["count_255_one_round", "count_3_two_rounds"])
def test_ac4_times_that_runs_out_of_bytes_first_keeps_its_short_read(hex_bytes: str):
    scheme = _times_k().with_limits(max_rounds=3)

    result, seen = _unpack(scheme, bytes.fromhex(hex_bytes))

    assert result.ok is False and seen == []
    assert isinstance(result.error, ShortPacket)
    assert (result.error.needed, result.error.left) == (1, 0)


def test_ac5_times_at_the_default_limit():
    scheme = _times_u32()
    count = lambda n: n.to_bytes(4, "little")  # noqa: E731

    ok, ok_seen = _unpack(scheme, b"\x01" + count(65_535) + b"\x01" * 65_535)
    over, over_seen = _unpack(scheme, b"\x01" + count(65_536) + b"\x01" * 65_536)
    huge_over, huge_over_seen = _unpack(scheme, b"\x01" + count(4_294_967_295) + b"\x01" * 65_536)
    huge_edge, huge_edge_seen = _unpack(scheme, b"\x01" + count(4_294_967_295) + b"\x01" * 65_535)
    lazy, lazy_seen = _unpack(scheme, bytes.fromhex("01ffffffff00"))

    assert ok.ok and len(ok_seen[0]["k"]) == 65_535
    _refusal(over, over_seen, left=1)
    _refusal(huge_over, huge_over_seen, left=1)
    _refusal(huge_edge, huge_edge_seen, left=0)
    assert lazy.ok is False
    assert (lazy.error.needed, lazy.error.left) == (1, 0)


def test_ac6_the_slot_limit_counts_every_name_of_a_round():
    # Three names: the first round of a run costs 9 x 3 slots, each later round 3.
    scheme = _three_names().with_limits(max_slots=30)

    ok, ok_seen = _unpack(scheme, bytes.fromhex("010000"))
    three_rounds, three_seen = _unpack(scheme, bytes.fromhex("01000000"))
    four_rounds, four_seen = _unpack(scheme, bytes.fromhex("0100000000"))

    assert ok.ok
    assert ok_seen == [{"k": [0, 0], "a": [None, None], "b": [None, None]}]
    _refusal(three_rounds, three_seen, left=1)
    _refusal(four_rounds, four_seen, left=2)


@pytest.mark.parametrize(
    "max_slots,refused_left",
    [(11, None), (10, 1), (9, 2)],
    ids=["first_round_nine_then_one_each", "third_round_refused", "second_round_refused"],
)
def test_the_first_round_of_a_run_costs_nine_slots_per_name(max_slots: int, refused_left):
    scheme = _repeat_k().with_limits(max_slots=max_slots)

    result, seen = _unpack(scheme, bytes.fromhex("01aabbcc"))

    if refused_left is None:
        assert result.ok
        assert seen == [{"k": [170, 187, 204]}]
    else:
        _refusal(result, seen, left=refused_left)


@pytest.mark.parametrize(
    "max_slots,refused_left",
    [(20, None), (19, 1)],
    ids=["nine_plus_one_twice", "second_times_refused"],
)
def test_ac7_the_slot_total_is_per_call_and_shared_by_the_fields(max_slots: int, refused_left):
    scheme = Scheme(
        1,
        dict,
        _u8(0, "n"),
        times(1, 0, _u8(1, "k")),
        times(2, 0, _u8(2, "v")),
    ).with_limits(max_rounds=3, max_slots=max_slots)

    result, seen = _unpack(scheme, bytes.fromhex("0102aabbccdd"))

    if refused_left is None:
        assert result.ok
        assert seen == [{"n": 2, "k": [170, 187], "v": [204, 221]}]
    else:
        _refusal(result, seen, left=refused_left)


def test_ac7_the_slot_total_starts_again_on_the_next_call():
    scheme = _repeat_k().with_limits(max_slots=11)

    first, _ = _unpack(scheme, bytes.fromhex("01aabbcc"))
    second, _ = _unpack(scheme, bytes.fromhex("01aabbcc"))

    assert first.ok and second.ok


def test_ac8_a_one_mebibyte_packet_is_refused_at_round_65536():
    names = [_u8(i + 1, f"a{i}") for i in range(36)]
    scheme = Scheme(1, dict, repeat(0, _u8(0, "k"), when(1, eq(0, 1), *names)))

    result, seen = _unpack(scheme, b"\x01" + bytes(1_048_576))

    _refusal(result, seen, left=983_041)


def test_ac9_the_limits_belong_to_the_scheme():
    base = _repeat_k()
    strict = base.with_limits(max_rounds=3)
    other = _repeat_k(type_number=2).with_limits(max_rounds=2)
    data = bytes.fromhex("01aabbccdd")

    kept, kept_seen = _unpack(base, data)
    refused, refused_seen = _unpack(strict, data)
    dispatched = BinaryPacker.unpack(bytes.fromhex("02aabbcc"), base.on(lambda _row: None), other.on(lambda _row: None))

    assert kept.ok and len(kept_seen[0]["k"]) == 4
    _refusal(refused, refused_seen, left=1)
    assert dispatched.ok is False
    assert (dispatched.error.needed, dispatched.error.left) == (0, 1)


@pytest.mark.parametrize(
    "limits,name",
    [
        ({"max_rounds": 0}, "max_rounds"),
        ({"max_rounds": -1}, "max_rounds"),
        ({"max_rounds": 1.5}, "max_rounds"),
        ({"max_rounds": float("nan")}, "max_rounds"),
        ({"max_rounds": float("inf")}, "max_rounds"),
        ({"max_rounds": True}, "max_rounds"),
        ({"max_rounds": None}, "max_rounds"),
        ({"max_slots": 0}, "max_slots"),
        ({"max_slots": "7"}, "max_slots"),
    ],
)
def test_ac10_an_invalid_limit_is_refused_at_construction(limits: dict, name: str):
    with pytest.raises(ValueError, match=name):
        _repeat_k().with_limits(**limits)


def test_ac10_a_very_large_limit_is_valid():
    scheme = _repeat_k().with_limits(max_rounds=2**63, max_slots=2**63)

    result, seen = _unpack(scheme, b"\x01" + b"\x07" * 65_536)

    assert result.ok and len(seen[0]["k"]) == 65_536


def test_with_limits_keeps_the_receiver_and_the_fields():
    base = _repeat_k()

    limited = base.with_limits(max_rounds=3)
    packed = BinaryPacker.pack(limited, {"k": [1, 2]}).hex()

    assert limited is not base
    assert packed == "010102"
    assert base.max_rounds == 65_535


def test_a_repeat_whose_accessor_is_the_row_itself_does_not_raise():
    scheme = Scheme(1, dict, repeat(0, u8(0, lambda row: row)))

    result, seen = _unpack(scheme, bytes.fromhex("0105"))

    assert result.ok
    assert seen == [{}]


def test_two_nodes_of_one_round_that_bind_one_member_share_its_list():
    scheme = Scheme(
        1,
        dict,
        repeat(
            0,
            _u8(0, "k"),
            when(1, eq(0, 1), _u8(1, "v")),
            when(2, eq(0, 2), u8(2, lambda row: row["v"])),
        ),
    )

    result, seen = _unpack(scheme, bytes.fromhex("01" "01" "09" "02" "07" "03"))

    assert result.ok
    assert seen == [{"k": [1, 2, 3], "v": [9, 7, None]}]


def _element_round_scheme(container: str) -> Scheme:
    """Each list or dict element runs a `times` of one round and one name (ids restart at 0 in an element)."""
    element = group(0, _u8(0, "n"), times(1, 0, _u8(1, "k")))
    if container == "list":
        return Scheme(1, dict, list_field(lambda row: row["xs"], element))
    return Scheme(1, dict, dict_field(lambda row: row["d"], element))


def _three_elements(container: str) -> bytes:
    element = bytes.fromhex("0107")
    if container == "list":
        return b"\x01" + (3).to_bytes(2, "little") + element * 3
    entries = b"".join((1).to_bytes(2, "little") + key + element for key in (b"a", b"b", b"c"))
    return b"\x01" + (3).to_bytes(2, "little") + entries


@pytest.mark.parametrize("container", ["list", "dict"])
def test_the_slot_budget_is_shared_with_list_and_dict_elements(container: str):
    data = _three_elements(container)
    fits = _element_round_scheme(container).with_limits(max_slots=27)
    too_small = _element_round_scheme(container).with_limits(max_slots=26)

    ok, ok_seen = _unpack(fits, data)
    refused, refused_seen = _unpack(too_small, data)

    assert ok.ok
    assert len(ok_seen) == 1
    _refusal(refused, refused_seen, left=1)


def test_each_run_in_an_element_pays_for_its_own_lists():
    scheme = _element_round_scheme("list").with_limits(max_slots=9 * 3 - 1)

    result, seen = _unpack(scheme, _three_elements("list"))

    _refusal(result, seen, left=1)


def test_a_round_leaf_list_is_found_once_when_the_scheme_is_built(monkeypatch: pytest.MonkeyPatch):
    scheme = _element_round_scheme("list")

    def fail(*_args, **_kwargs):
        raise AssertionError("round leaves were looked up again")

    monkeypatch.setattr(nodes, "_round_leaves", fail)
    monkeypatch.setattr(unpack_module, "_round_leaves", fail, raising=False)
    monkeypatch.setattr(pack_module, "_round_leaves", fail, raising=False)
    result, _seen = _unpack(scheme, _three_elements("list"))

    assert result.ok
    assert BinaryPacker.pack(scheme, {"xs": [{"n": 1, "k": [7]}]}).hex() == "0101000107"


def test_with_limits_keeps_what_a_subclass_added():
    class Tagged(Scheme):
        def __init__(self, *args):
            super().__init__(*args)
            self.tag = "kept"

    tagged = Tagged(1, dict, repeat(0, _u8(0, "k")))

    limited = tagged.with_limits(max_rounds=3)

    assert isinstance(limited, Tagged)
    assert limited.tag == "kept"
    assert (limited.max_rounds, tagged.max_rounds) == (3, 65_535)

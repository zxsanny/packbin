from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

import packbin
from packbin import BinaryPacker, ShortPacket, Scheme, flag_byte, flags, group, repeat, times, u8, u32, u64, utf8
from packbin import list as list_field

import timing_support

# The rows are the TypeScript reference table `_docs/03_implementation/reference_loop20_budget.md` (AZ-2354,
# rows 1 to 28): same outcome, same member, same numbers in the message.

LIMIT = 16_777_216


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _u32(field_id: int, name: str):
    return u32(field_id, lambda row, name=name: row[name])


def _utf8(field_id: int, name: str):
    return utf8(field_id, lambda row, name=name: row[name])


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def _refusal(scheme: Scheme, row: dict) -> str:
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(scheme, row)
    return str(caught.value)


def _n_k(**limits: int) -> Scheme:
    """`u32 n; times(n) { u8 k }` (rows 17 to 21)."""
    return Scheme(1, dict, _u32(0, "n"), times(1, 0, _u8(1, "k"))).with_limits(**limits)


def _lone_utf8() -> Scheme:
    return Scheme(1, dict, _u32(0, "n"), times(1, 0, _utf8(1, "s")))


def _item_with_times() -> Scheme:
    return Scheme(
        1,
        dict,
        list_field(
            lambda row: row["items"],
            group(0, _u32(0, "n"), times(1, 0, u64(1, lambda row: row["k"]))),
        ),
    )


def _wide_round() -> Scheme:
    return Scheme(1, dict, _u32(0, "n"), times(1, 0, *[_u8(1 + i, f"m{i}") for i in range(65)]))


def _wide_row() -> dict:
    return {"n": 65535, **{f"m{i}": 1 for i in range(65)}}


def test_ac1_row1_a_lone_utf8_under_a_capped_times_is_refused_naming_the_member():
    # Arrange
    row = {"n": 65535, "s": "a" * 65535}

    # Act
    message = _refusal(_lone_utf8(), row)

    # Assert: the field of 65 535 a is 32 772 bytes (compact text); 5 + 511 * 32 772 written, the next append passes
    assert message == "s: the packet would be 16779269 bytes, above the limit of 16777216 bytes"


def test_ac1_row1_pack_takes_under_a_second_and_under_256_mb():
    # Arrange: HEAD takes 4.2 s and 7.3 GB for this row; the child measures its own pack call and peak memory
    code = (
        "import resource, time\n"
        "from packbin import BinaryPacker, Scheme, times, u32, utf8\n"
        "scheme = Scheme(1, dict, u32(0, lambda r: r['n']), times(1, 0, utf8(1, lambda r: r['s'])))\n"
        "row = {'n': 65535, 's': 'a' * 65535}\n"
        "started = time.perf_counter()\n"
        "try:\n"
        "    BinaryPacker.pack(scheme, row)\n"
        "except ValueError:\n"
        "    pass\n"
        "elapsed = time.perf_counter() - started\n"
        "peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss\n"
        f"print(elapsed, peak * {1 if sys.platform == 'darwin' else 1024})\n"
    )

    # Act
    limit = timing_support.bound(1.0)
    # The child finds the package where this process found it (pytest's `pythonpath`, not an installed copy).
    src = str(Path(packbin.__file__).resolve().parent.parent)
    env = {**os.environ, "PYTHONPATH": os.pathsep.join(filter(None, [src, os.environ.get("PYTHONPATH")]))}
    done = subprocess.run(
        [sys.executable, "-c", code], stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60, env=env
    )

    # Assert
    assert done.returncode == 0, done.stderr
    elapsed, peak = (float(part) for part in done.stdout.split())
    timing_support.assert_within(elapsed, limit, "pack of the capped lone utf8 row")
    assert peak < 256 * 1024 * 1024


def test_ac2_row2_an_element_that_holds_a_times_is_refused_by_the_slots_at_the_default_limit():
    # Arrange
    row = {"items": [{"n": 65535, "k": 5}] * 40}

    # Act
    message = _refusal(_item_with_times(), row)

    # Assert: AZ-2415, the default maxSlots 1 048 576 is reached before the bytes budget: item 17, round 17
    assert message == "k: the rounds would hold 1048577 slots, above the limit of 1048576 slots"


def test_ac2_row3_a_raised_budget_packs_the_element_row():
    # Arrange
    scheme = _item_with_times().with_limits(max_slots=2_621_400, max_bytes=33_554_432)
    row = {"items": [{"n": 65535, "k": 5}] * 40}

    # Act
    packed = BinaryPacker.pack(scheme, row)
    result = BinaryPacker.unpack(packed, scheme.on(lambda _row: None))

    # Assert
    assert len(packed) == 20_971_363
    assert packed[:16].hex() == "012800ffff0000050000000000000005"
    assert packed[-16:].hex() == "05000000000000000500000000000000"
    assert result.ok
    assert len(result.value["items"]) == 40
    assert result.value["items"][39] == {"n": 65535, "k": [5] * 65535}


def _item_with_lone_utf8_times() -> Scheme:
    return Scheme(
        1,
        dict,
        list_field(lambda row: row["items"], group(0, _u32(0, "n"), times(1, 0, _utf8(1, "s")))),
    )


def test_ac2_row3_an_element_row_under_the_slots_is_refused_by_the_bytes_budget():
    # Arrange: 16 items of 65 535 rounds, 1 048 560 slots (under the limit), 18 bytes a round
    row = {"items": [{"n": 65535, "s": "q" * 16}] * 16}

    # Act
    message = _refusal(_item_with_lone_utf8_times(), row)

    # Assert
    assert message == "s: the packet would be 16777233 bytes, above the limit of 16777216 bytes"


def test_ac2_row3_a_raised_bytes_budget_packs_the_element_row_that_the_slots_allow():
    # Arrange
    scheme = _item_with_lone_utf8_times().with_limits(max_bytes=33_554_432)
    row = {"items": [{"n": 65535, "s": "q" * 16}] * 16}

    # Act
    packed = BinaryPacker.pack(scheme, row)
    result = BinaryPacker.unpack(packed, scheme.on(lambda _row: None))

    # Assert
    assert len(packed) == 18_874_147
    assert result.ok
    assert len(result.value["items"]) == 16


def test_ac3_row4_a_packet_of_exactly_max_bytes_packs():
    # Arrange
    scheme = Scheme(1, dict, _utf8(0, "s")).with_limits(max_bytes=64)

    # Act
    packed = _pack(scheme, {"s": "q" * 61})

    # Assert
    assert packed == "013e10" + "71" * 61


def test_ac3_row5_one_byte_more_is_refused_naming_the_member():
    # Arrange
    scheme = Scheme(1, dict, _utf8(0, "s")).with_limits(max_bytes=64)

    # Act
    message = _refusal(scheme, {"s": "q" * 62})

    # Assert
    assert message == "s: the packet would be 65 bytes, above the limit of 64 bytes"


def test_ac3_row6_a_repeat_of_exactly_max_bytes_packs():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "k"))).with_limits(max_bytes=64)

    # Act
    packed = _pack(scheme, {"k": [7] * 63})

    # Assert
    assert packed == "01" + "07" * 63


def test_ac3_row7_the_round_that_passes_max_bytes_is_refused():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "k"))).with_limits(max_bytes=64)

    # Act
    message = _refusal(scheme, {"k": [7] * 64})

    # Assert
    assert message == "k: the packet would be 65 bytes, above the limit of 64 bytes"


def test_ac3_row8_the_type_byte_counts_and_a_bare_scheme_packs_at_one_byte():
    # Arrange
    scheme = Scheme(1, dict).with_limits(max_bytes=1)

    # Act / Assert
    assert _pack(scheme, {}) == "01"


def test_ac3_row9_a_field_past_one_byte_is_refused():
    # Arrange
    scheme = Scheme(1, dict, _u8(0, "a")).with_limits(max_bytes=1)

    # Act
    message = _refusal(scheme, {"a": 1})

    # Assert
    assert message == "a: the packet would be 2 bytes, above the limit of 1 bytes"


def test_ac3_row10_a_split_flag_byte_is_refused_at_the_byte():
    # Arrange: a Python flag byte has no name, so the message calls it "flag byte" (the reference names it)
    byte = flag_byte()
    scheme = Scheme(1, dict, byte, byte.bit(_u8(0, "c"))).with_limits(max_bytes=1)

    # Act
    message = _refusal(scheme, {"c": 1})

    # Assert
    assert message == "flag byte: the packet would be 2 bytes, above the limit of 1 bytes"


def test_ac3_row11_a_combined_flags_byte_is_named_by_its_first_member():
    # Arrange
    scheme = Scheme(1, dict, flags(0, _u8(0, "c"))).with_limits(max_bytes=1)

    # Act
    message = _refusal(scheme, {"c": 1})

    # Assert
    assert message == "c: the packet would be 2 bytes, above the limit of 1 bytes"


def test_ac3_row12_a_combined_flags_byte_is_named_through_a_times():
    # Arrange
    scheme = Scheme(1, dict, _u8(0, "n"), flags(1, times(1, 0, _u8(1, "k")))).with_limits(max_bytes=2)

    # Act
    message = _refusal(scheme, {"n": 1, "k": 3})

    # Assert
    assert message == "k: the packet would be 3 bytes, above the limit of 2 bytes"


def test_ac3_row13_a_list_count_prefix_is_refused_naming_the_list():
    # Arrange
    scheme = Scheme(1, dict, list_field(lambda row: row["xs"], u8(0, lambda x: x))).with_limits(max_bytes=2)

    # Act
    message = _refusal(scheme, {"xs": []})

    # Assert
    assert message == "xs: the packet would be 3 bytes, above the limit of 2 bytes"


def test_ac4_row14_a_round_of_65_names_is_refused_before_its_bytes():
    # Arrange
    row = _wide_row()

    # Act
    message = _refusal(_wide_round(), row)

    # Assert: AZ-2415, round index 16 131 (1 048 515 charged, 1 048 520 bytes written)
    assert message == "m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots"


def test_ac4_row15_a_raised_max_slots_packs_and_unpacks():
    # Arrange
    row = _wide_row()
    scheme = _wide_round().with_limits(max_slots=4_259_775)

    # Act
    packed = BinaryPacker.pack(scheme, row)
    result = BinaryPacker.unpack(packed, scheme.on(lambda _row: None))

    # Assert
    assert len(packed) == 4_259_780
    assert packed[:16].hex() == "01ffff00000101010101010101010101"
    assert packed[-16:].hex() == "01" * 16
    assert result.ok
    assert len(result.value["m0"]) == 65535


def test_ac4_row16_the_same_packet_is_refused_by_unpack_at_the_default_limit():
    # Arrange
    packed = BinaryPacker.pack(_wide_round().with_limits(max_slots=4_259_775), _wide_row())

    # Act
    result = BinaryPacker.unpack(packed, _wide_round().on(lambda _row: None))

    # Assert
    # Unpack charges the width pack charges (AZ-2381), so it refuses at the round pack refuses (round index
    # 16 131, 1 048 520 bytes written): the bytes left pin that round
    assert result.ok is False
    assert result.error == ShortPacket(field="1", needed=0, left=3_211_260)


def test_order_row17_a_row_at_both_limits_packs():
    # Arrange
    scheme = _n_k(max_slots=3, max_bytes=8)

    # Act / Assert
    assert _pack(scheme, {"n": 3, "k": 7}) == "0103000000070707"


def test_order_row18_slots_are_checked_before_the_bytes_of_the_round():
    # Arrange
    scheme = _n_k(max_slots=3, max_bytes=8)

    # Act
    message = _refusal(scheme, {"n": 10, "k": 7})

    # Assert
    assert message == "k: the rounds would hold 4 slots, above the limit of 3 slots"


def test_order_row19_bytes_fire_first_when_the_third_round_passes_them():
    # Arrange
    scheme = _n_k(max_slots=3, max_bytes=7)

    # Act
    message = _refusal(scheme, {"n": 10, "k": 7})

    # Assert
    assert message == "k: the packet would be 8 bytes, above the limit of 7 bytes"


def test_order_row20_the_round_cap_fires_before_any_round():
    # Arrange
    scheme = _n_k(max_rounds=5, max_slots=3, max_bytes=8)

    # Act
    message = _refusal(scheme, {"n": 10, "k": 7})

    # Assert
    assert message == "k: the times count is 10, above the limit of 5 rounds"


def test_order_row21_the_count_field_is_checked_when_it_is_written():
    # Arrange
    scheme = _n_k(max_rounds=5, max_slots=3, max_bytes=4)

    # Act
    message = _refusal(scheme, {"n": 10, "k": 7})

    # Assert
    assert message == "n: the packet would be 5 bytes, above the limit of 4 bytes"


def _items_of_times() -> Scheme:
    return Scheme(
        1,
        dict,
        list_field(lambda row: row["items"], group(0, _u8(0, "n"), times(1, 0, _u8(1, "k")))),
    ).with_limits(max_slots=5)


def test_scope_row22_slots_accumulate_across_list_elements():
    # Arrange
    row = {"items": [{"n": 3, "k": 1}, {"n": 3, "k": 2}]}

    # Act
    message = _refusal(_items_of_times(), row)

    # Assert
    assert message == "k: the rounds would hold 6 slots, above the limit of 5 slots"


def test_scope_row23_five_slots_across_two_elements_pack():
    # Arrange
    row = {"items": [{"n": 3, "k": 1}, {"n": 2, "k": 2}]}

    # Act / Assert
    assert _pack(_items_of_times(), row) == "01020003010101020202"


def _repeat_with_group() -> Scheme:
    return Scheme(1, dict, repeat(0, _u8(0, "a"), group(1, _u8(1, "b")))).with_limits(max_slots=5)


def test_width_row24_a_group_name_is_not_charged():
    # Arrange
    row = {"a": [1, 2], "b": [3, 4]}

    # Act / Assert
    assert _pack(_repeat_with_group(), row) == "0101030204"


def test_width_row25_three_rounds_of_width_two_pass_five_slots():
    # Arrange
    row = {"a": [1, 2, 3], "b": [3, 4, 5]}

    # Act
    message = _refusal(_repeat_with_group(), row)

    # Assert
    assert message == "a: the rounds would hold 6 slots, above the limit of 5 slots"


def test_ac5_row26_max_bytes_defaults_to_16_mib_and_a_limit_left_out_is_the_default():
    # Arrange
    base = Scheme(1, dict, _u8(0, "a"))

    # Act
    rounds_only = base.with_limits(max_rounds=9)
    chained = base.with_limits(max_bytes=64).with_limits(max_slots=9)

    # Assert
    assert (Scheme.DEFAULT_MAX_BYTES, base.max_bytes) == (LIMIT, LIMIT)
    assert rounds_only.max_bytes == LIMIT
    assert chained.max_bytes == LIMIT


@pytest.mark.parametrize(
    "value", [0, -1, 1.5, float("nan"), True, "5", None], ids=["0", "-1", "1.5", "nan", "True", "str", "None"]
)
def test_ac5_row27_an_invalid_max_bytes_is_refused_like_the_other_limits(value):
    # Arrange
    scheme = Scheme(1, dict)

    # Act / Assert
    with pytest.raises(ValueError, match=r"^max_bytes must be a whole number of at least 1, got "):
        scheme.with_limits(max_bytes=value)


def test_ac5_row28_the_existing_call_forms_still_work():
    # Arrange
    scheme = _n_k(max_rounds=3, max_slots=3)
    positional = _n_k().with_limits(3, 3)

    # Act / Assert
    assert _pack(scheme, {"n": 3, "k": 7}) == "0103000000070707"
    assert _pack(positional, {"n": 3, "k": 7}) == "0103000000070707"
    assert (scheme.max_rounds, scheme.max_slots, scheme.max_bytes) == (3, 3, LIMIT)

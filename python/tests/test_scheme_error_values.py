from __future__ import annotations

import pytest

from packbin import Scheme, bool as flag_bool, eq, flags, u8, when


class _Hostile:
    def __repr__(self) -> str:
        raise AssertionError("the caller's __repr__ was called")


def _on_flag_scheme(value):
    return Scheme(
        1,
        dict,
        flags(0, flag_bool(0, lambda row: row["on"])),
        when(1, eq(0, value), u8(1, lambda row: row["v"])),
    )


def test_az_2126_error_text_names_the_type_of_an_object_and_never_calls_its_repr():
    with pytest.raises(ValueError) as caught:
        _on_flag_scheme(_Hostile())

    assert "against _Hostile;" in str(caught.value)


@pytest.mark.parametrize(
    "value,shown",
    [(False, "False"), (None, "None"), (1, "1"), ("yes", "'yes'"), (1.5, "1.5")],
)
def test_az_2126_error_text_keeps_the_repr_of_plain_values(value, shown):
    with pytest.raises(ValueError, match=rf"bool field 0 against {shown};"):
        _on_flag_scheme(value)


def test_az_2126_a_list_value_is_named_by_type_not_printed():
    with pytest.raises(ValueError, match=r"against list;"):
        _on_flag_scheme([True])


def test_az_2126_scheme_limits_name_the_type_of_an_object_and_never_call_its_repr():
    with pytest.raises(ValueError, match=r"type number must be 0\.\.255, got _Hostile$"):
        Scheme(_Hostile(), dict, u8(0, lambda row: row["a"]))
    with pytest.raises(ValueError, match=r"max_rounds must be a whole number of at least 1, got _Hostile$"):
        Scheme(1, dict, u8(0, lambda row: row["a"])).with_limits(max_rounds=_Hostile())

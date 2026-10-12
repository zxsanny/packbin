from __future__ import annotations

from pathlib import Path

import pytest

from packbin import Scheme

from hostile_loop21_support import LOOP21_CONSTRUCT_CASES, LOOP21_PACK_CASES
from hostile_loop22_support import LOOP22_CONSTRUCT_CASES, LOOP22_CONSTRUCT_FIELDS, LOOP22_PACK_CASES
from hostile_refusals import CONSTRUCT_REFUSAL, PACK_REFUSAL
from hostile_support import LIMIT_SCHEMES, PACK_CASES, VECTOR_SCHEMES, assert_rejected, error_kind, unpack_guarded
from test_bool_placement import CONSTRUCT_SCHEMES
from test_reference_scope import REFERENCE_VECTORS

CASES = Path(__file__).resolve().parents[2] / "fixtures" / "hostile" / "cases.txt"


def _cases(wanted: str) -> list[tuple[str, set[str], str]]:
    out = []
    for line in CASES.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        case_id, stage, expected, hex_bytes = line.split()
        if stage == wanted:
            out.append((case_id, set(expected.split("|")), hex_bytes))
    return out


UNPACK_CASES = _cases("unpack")
LIMIT_CASES = _cases("limit")
PACK_VECTORS = _cases("pack")
CONSTRUCT_VECTORS = _cases("construct")
ALL_PACK_CASES = {**PACK_CASES, **LOOP21_PACK_CASES, **LOOP22_PACK_CASES}
ALL_CONSTRUCT_BUILDS = {
    **CONSTRUCT_SCHEMES,
    **{case_id: build for case_id, (build, _names) in REFERENCE_VECTORS.items()},
    **LOOP21_CONSTRUCT_CASES,
    **LOOP22_CONSTRUCT_CASES,
}


def test_every_unpack_vector_has_a_declared_scheme():
    assert sorted(case[0] for case in UNPACK_CASES) == sorted(VECTOR_SCHEMES)


@pytest.mark.parametrize("case_id,expected,hex_bytes", UNPACK_CASES, ids=[c[0] for c in UNPACK_CASES])
def test_vector_is_rejected(case_id: str, expected: set[str], hex_bytes: str):
    try:
        scheme = VECTOR_SCHEMES[case_id]()
    except ValueError as exc:
        assert "scheme_error" in expected, f"{case_id}: scheme refused ({exc}), vector accepts {sorted(expected)}"
        assert "allowed only" in str(exc), f"{case_id}: refused for another reason: {exc}"
        return
    result, seen, elapsed = unpack_guarded(scheme, bytes.fromhex(hex_bytes))
    assert_rejected(result, seen, elapsed)
    kind = error_kind(result)
    assert kind in expected, f"{case_id}: returned {kind}, vector accepts {sorted(expected)}"


def test_every_limit_vector_has_a_declared_scheme():
    assert sorted(case[0] for case in LIMIT_CASES) == sorted(LIMIT_SCHEMES)


@pytest.mark.parametrize("case_id,expected,hex_bytes", LIMIT_CASES, ids=[c[0] for c in LIMIT_CASES])
def test_limit_vector_is_refused_by_the_round_limit(case_id: str, expected: set[str], hex_bytes: str):
    scheme = LIMIT_SCHEMES[case_id]()

    result, seen, elapsed = unpack_guarded(scheme, bytes.fromhex(hex_bytes))

    assert_rejected(result, seen, elapsed)
    assert error_kind(result) in expected
    assert (result.error.needed, result.error.left) == (0, 1)


def test_every_pack_vector_has_a_declared_scheme():
    assert sorted(case[0] for case in PACK_VECTORS) == sorted(ALL_PACK_CASES)


def test_every_refused_pack_vector_names_its_rule_and_no_other_does():
    refused = [case_id for case_id, expected, _hex in PACK_VECTORS if expected == {"pack_error"}]

    assert sorted(refused) == sorted(PACK_REFUSAL)


def run_pack_case(case_id: str, expected: set[str], hex_bytes: str, refusals: dict) -> None:
    """The loader's check of one pack case against a rule table; every failure names the case."""
    pack, refusal = ALL_PACK_CASES[case_id]

    if expected == {"bytes"}:
        assert refusal is None, f"{case_id}: the vector gives bytes, the case declares an exception"
        assert pack().hex() == hex_bytes, f"{case_id}: packed other bytes"
        return
    assert expected == {"pack_error"}, f"{case_id}: unknown outcome {sorted(expected)}"
    kind, message = refusals[case_id]
    assert refusal is kind, f"{case_id}: the case declares {refusal}, the rule table {kind}"
    try:
        pack()
    except Exception as exc:  # compared with the rule table below
        assert type(exc) is kind, f"{case_id}: raised {type(exc).__name__}, the rule table names {kind.__name__}"
        assert str(exc) == message, f"{case_id}: refused by another rule"
        return
    raise AssertionError(f"{case_id}: packed, the vector is a pack_error")


@pytest.mark.parametrize("case_id,expected,hex_bytes", PACK_VECTORS, ids=[c[0] for c in PACK_VECTORS])
def test_pack_vector_gives_the_bytes_or_is_refused_by_its_rule(case_id: str, expected: set[str], hex_bytes: str):
    run_pack_case(case_id, expected, hex_bytes, PACK_REFUSAL)


def test_every_construct_vector_has_a_scheme_and_a_rule():
    ids = sorted(case[0] for case in CONSTRUCT_VECTORS)

    assert ids == sorted(ALL_CONSTRUCT_BUILDS) == sorted(CONSTRUCT_REFUSAL)


def run_construct_case(case_id: str, expected: set[str], refusals: dict[str, str]) -> None:
    """The loader's check of one construct case against a rule table; every failure names the case."""
    assert expected == {"scheme_error"}, f"{case_id}: unknown outcome {sorted(expected)}"
    try:
        ALL_CONSTRUCT_BUILDS[case_id]()
    except ValueError as exc:
        assert str(exc) == refusals[case_id], f"{case_id}: refused by another rule"
        return
    raise AssertionError(f"{case_id}: built, the vector is a scheme_error")


@pytest.mark.parametrize("case_id,expected,hex_bytes", CONSTRUCT_VECTORS, ids=[c[0] for c in CONSTRUCT_VECTORS])
def test_construct_vector_is_refused_by_its_rule(case_id: str, expected: set[str], hex_bytes: str):
    run_construct_case(case_id, expected, CONSTRUCT_REFUSAL)


@pytest.mark.parametrize("case_id", sorted(LOOP22_CONSTRUCT_FIELDS))
def test_loop22_construct_scheme_is_refused_by_scheme_too(case_id: str):
    # Arrange: `mode` stands outside the round, which a Python `when` cannot name, so `Scheme` refuses it first.
    fields = LOOP22_CONSTRUCT_FIELDS[case_id]()

    # Act
    with pytest.raises(ValueError) as caught:
        Scheme(1, dict, *fields)

    # Assert
    assert "allowed only if declared earlier in the same scope" in str(caught.value)


# AZ-2418 AC-1: a rule table that is wrong cannot pass. Each test builds one wrong entry here (nothing on disk
# changes) and feeds it to the loader, which must fail naming the case.
_PACK_CASE = "pack_times_list_too_long"
_CONSTRUCT_CASE = "construct_empty_times_body"


def _vector(cases: list[tuple[str, set[str], str]], case_id: str) -> tuple[str, set[str], str]:
    return next(case for case in cases if case[0] == case_id)


@pytest.mark.parametrize(
    "wrong",
    [
        (ValueError, "1: 3 items, times count is 3"),
        (KeyError, PACK_REFUSAL[_PACK_CASE][1]),
    ],
    ids=["wrong_message", "wrong_exception_type"],
)
def test_loader_fails_naming_the_case_when_a_pack_rule_entry_is_wrong(wrong: tuple[type[Exception], str]):
    # Arrange
    case_id, expected, hex_bytes = _vector(PACK_VECTORS, _PACK_CASE)
    refusals = {**PACK_REFUSAL, case_id: wrong}

    # Act
    with pytest.raises(AssertionError) as caught:
        run_pack_case(case_id, expected, hex_bytes, refusals)

    # Assert
    assert str(caught.value).startswith(f"{case_id}:")


def test_loader_fails_naming_the_case_when_a_construct_rule_entry_is_wrong():
    # Arrange
    case_id, expected, _hex = _vector(CONSTRUCT_VECTORS, _CONSTRUCT_CASE)
    refusals = {**CONSTRUCT_REFUSAL, case_id: CONSTRUCT_REFUSAL["construct_empty_repeat_body"]}

    # Act
    with pytest.raises(AssertionError) as caught:
        run_construct_case(case_id, expected, refusals)

    # Assert
    assert str(caught.value).startswith(f"{case_id}:")


def test_loader_passes_the_same_cases_with_the_right_entries():
    # Arrange
    pack_id, pack_expected, pack_hex = _vector(PACK_VECTORS, _PACK_CASE)
    construct_id, construct_expected, _hex = _vector(CONSTRUCT_VECTORS, _CONSTRUCT_CASE)

    # Act / Assert
    run_pack_case(pack_id, pack_expected, pack_hex, PACK_REFUSAL)
    run_construct_case(construct_id, construct_expected, CONSTRUCT_REFUSAL)

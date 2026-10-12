from __future__ import annotations

from pathlib import Path

import pytest

from hostile_loop21_support import LOOP21_CONSTRUCT_CASES, LOOP21_PACK_CASES
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
ALL_PACK_CASES = {**PACK_CASES, **LOOP21_PACK_CASES}
ALL_CONSTRUCT_BUILDS = {
    **CONSTRUCT_SCHEMES,
    **{case_id: build for case_id, (build, _names) in REFERENCE_VECTORS.items()},
    **LOOP21_CONSTRUCT_CASES,
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


@pytest.mark.parametrize("case_id,expected,hex_bytes", PACK_VECTORS, ids=[c[0] for c in PACK_VECTORS])
def test_pack_vector_gives_the_bytes_or_is_refused_by_its_rule(case_id: str, expected: set[str], hex_bytes: str):
    pack, refusal = ALL_PACK_CASES[case_id]

    if expected == {"bytes"}:
        assert refusal is None
        assert pack().hex() == hex_bytes
    else:
        assert expected == {"pack_error"}
        kind, message = PACK_REFUSAL[case_id]
        assert refusal is kind
        with pytest.raises(kind) as caught:
            pack()
        assert type(caught.value) is kind
        assert str(caught.value) == message, f"{case_id}: refused by another rule"


def test_every_construct_vector_has_a_scheme_and_a_rule():
    ids = sorted(case[0] for case in CONSTRUCT_VECTORS)

    assert ids == sorted(ALL_CONSTRUCT_BUILDS) == sorted(CONSTRUCT_REFUSAL)


@pytest.mark.parametrize("case_id,expected,hex_bytes", CONSTRUCT_VECTORS, ids=[c[0] for c in CONSTRUCT_VECTORS])
def test_construct_vector_is_refused_by_its_rule(case_id: str, expected: set[str], hex_bytes: str):
    assert expected == {"scheme_error"}
    with pytest.raises(ValueError) as caught:
        ALL_CONSTRUCT_BUILDS[case_id]()
    assert str(caught.value) == CONSTRUCT_REFUSAL[case_id], f"{case_id}: refused by another rule"

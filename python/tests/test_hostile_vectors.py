from __future__ import annotations

from pathlib import Path

import pytest

from hostile_support import VECTOR_SCHEMES, assert_rejected, error_kind, unpack_guarded

CASES = Path(__file__).resolve().parents[2] / "fixtures" / "hostile" / "cases.txt"


def _unpack_cases() -> list[tuple[str, set[str], str]]:
    out = []
    for line in CASES.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        case_id, stage, expected, hex_bytes = line.split()
        if stage == "unpack":
            out.append((case_id, set(expected.split("|")), hex_bytes))
    return out


UNPACK_CASES = _unpack_cases()


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

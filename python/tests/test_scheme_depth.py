from __future__ import annotations

import sys
import time

import pytest

from packbin import BinaryPacker, Scheme

from scheme_depth_support import DEPTH_REFUSAL, KINDS


def _scheme(kind: str, depth: int) -> tuple[Scheme[dict], dict, str]:
    fields, row, packet = KINDS[kind](depth)
    return Scheme(1, dict, *fields), row, packet


@pytest.mark.parametrize("kind", sorted(KINDS))
def test_scheme_at_256_levels_builds_packs_and_unpacks_at_the_default_recursion_limit(kind: str):
    # AZ-4297 AC-2: no raised recursion limit, no big-stack thread; the bytes are the ones packed before the limit.
    # Arrange
    assert sys.getrecursionlimit() == 1000
    scheme, row, packet = _scheme(kind, 256)
    seen: list[dict] = []

    # Act
    data = BinaryPacker.pack(scheme, row)
    result = BinaryPacker.unpack(data, scheme.on(seen.append))

    # Assert
    assert data.hex() == packet
    assert result.ok
    assert seen == [row]
    assert sys.getrecursionlimit() == 1000


@pytest.mark.parametrize("depth", [257, 1000, 50000])
@pytest.mark.parametrize("kind", sorted(KINDS))
def test_scheme_deeper_than_256_levels_is_refused_when_it_is_built(kind: str, depth: int):
    # AZ-4297 AC-1: the whole text, quickly, and never the interpreter's own RecursionError.
    # Arrange
    started = time.perf_counter()

    # Act
    with pytest.raises(ValueError) as caught:
        _scheme(kind, depth)

    # Assert
    assert type(caught.value) is ValueError
    assert str(caught.value) == DEPTH_REFUSAL
    assert time.perf_counter() - started < 5


@pytest.mark.parametrize("kind", sorted(KINDS))
def test_the_limit_sits_between_256_and_257_levels_of_each_kind(kind: str):
    # AZ-4297 AC-1 boundary: 256 builds, 257 is refused.
    # Arrange / Act
    built = _scheme(kind, 256)[0]
    with pytest.raises(ValueError) as caught:
        _scheme(kind, 257)

    # Assert
    assert isinstance(built, Scheme)
    assert str(caught.value) == DEPTH_REFUSAL


def test_a_deep_scheme_is_refused_before_a_shallower_scheme_error_further_down():
    # AZ-4297 AC-1: the depth is measured first, before any walk that would find the bad field id below it.
    # Arrange
    from packbin import group, u8

    inner = [u8(5, lambda row: row["b"])]
    for _ in range(300):
        inner = [group(0, *inner)]

    # Act
    with pytest.raises(ValueError) as caught:
        Scheme(1, dict, *inner)

    # Assert
    assert str(caught.value) == DEPTH_REFUSAL

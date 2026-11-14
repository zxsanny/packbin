from __future__ import annotations

import sys
import time

import pytest

from packbin import BinaryPacker, Scheme
from packbin._nodes import _validate_depth

from scheme_depth_support import DEPTH_REFUSAL, KINDS
from timing_support import assert_within, bound


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


def _diamond(levels: int):
    from packbin import eq, u8, when

    inner = [u8(1, lambda row: row["b"])]
    for _ in range(levels):
        inner = [when(1, eq(0, 1), *inner, *inner)]
    return inner


def test_a_diamond_of_60_levels_is_answered_within_a_second_never_a_hang():
    # AZ-4306 AC-1: each level holds the next level twice (the same object): 2**60 paths as a tree.
    # Arrange
    from packbin import u8

    top = _diamond(60)
    limit = bound(1)
    started = time.perf_counter()

    # Act: the depth walk alone, then the whole build (the field id rule refuses the repeated u8)
    _validate_depth(top)
    with pytest.raises(ValueError):
        Scheme(1, dict, u8(0, lambda row: row["a"]), *top)

    # Assert
    assert_within(time.perf_counter() - started, limit, "diamond of 60 levels")


def test_a_diamond_of_300_levels_is_still_refused_as_too_deep_within_a_second():
    # AZ-4306 AC-1
    # Arrange
    top = _diamond(300)
    limit = bound(1)
    started = time.perf_counter()

    # Act
    with pytest.raises(ValueError) as caught:
        _validate_depth(top)

    # Assert
    assert str(caught.value) == DEPTH_REFUSAL
    assert_within(time.perf_counter() - started, limit, "diamond of 300 levels")


@pytest.mark.parametrize("shared_first", [True, False])
def test_a_field_reached_shallow_and_again_deeper_is_measured_at_its_deepest(shared_first: bool):
    # AZ-4306 AC-3: a group held at the top and again at the bottom of a chain of whens.
    from packbin import eq, group, u8, when

    def build(whens: int) -> list:
        shared = group(0, u8(0, lambda row: row["v"]))
        inner = [shared]
        for _ in range(whens):
            inner = [when(0, eq(0, 1), *inner)]
        return [shared, *inner] if shared_first else [*inner, shared]

    # Act and assert: 255 whens and the group make 256 levels, 256 whens make 257
    _validate_depth(build(255))
    with pytest.raises(ValueError) as caught:
        _validate_depth(build(256))
    assert str(caught.value) == DEPTH_REFUSAL

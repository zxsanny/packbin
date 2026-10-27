from __future__ import annotations

import pytest

from packbin import Freshness, ReplayWindow

MAX = (1 << 64) - 1


def test_a_new_window_is_empty_and_everything_is_fresh():
    # Arrange
    window = ReplayWindow()

    # Act and Assert
    assert [window.check(0), window.check(5), window.check(MAX)] == [Freshness.FRESH] * 3
    assert (window.top, window.bits) == (0, 0)


def test_check_follows_the_contract_for_duplicates_old_and_newer_counters():
    # Arrange
    window = ReplayWindow()
    for n in (110, 112, 111):
        window.commit(n)

    # Act
    results = [window.check(n) for n in (109, 110, 111, 112, 113, 112 - 64, 112 - 63)]

    # Assert
    assert results == [Freshness.FRESH, Freshness.DUPLICATE, Freshness.DUPLICATE, Freshness.DUPLICATE, Freshness.FRESH, Freshness.TOO_OLD, Freshness.FRESH]
    assert (window.top, window.bits) == (112, 0b111)


def test_check_never_changes_the_state():
    # Arrange
    window = ReplayWindow(50, 0b11)

    # Act
    window.check(50)
    window.check(51)
    window.check(1)

    # Assert
    assert (window.top, window.bits) == (50, 0b11)


def test_commit_shifts_by_the_gap_and_drops_the_bits_that_leave_the_window():
    # Arrange
    window = ReplayWindow()

    # Act
    window.commit(5)
    window.commit(8)
    window.commit(8 + 64)
    first = (window.top, window.bits)
    window.commit(8 + 64 + 63)

    # Assert
    assert first == (72, 1)
    assert (window.top, window.bits) == (135, (1 << 63) | 1)


def test_commit_of_a_counter_64_or_more_behind_is_ignored():
    # Arrange
    window = ReplayWindow(100, 1)

    # Act
    window.commit(36)

    # Assert
    assert (window.top, window.bits) == (100, 1)


def test_the_largest_counter_works():
    # Arrange
    window = ReplayWindow()
    window.commit(MAX)

    # Act
    results = [window.check(MAX), window.check(MAX - 1), window.check(MAX - 64)]

    # Assert
    assert results == [Freshness.DUPLICATE, Freshness.FRESH, Freshness.TOO_OLD]


def test_a_window_restored_with_zero_bits_is_empty():
    # Arrange
    window = ReplayWindow(1000, 0)

    # Act
    fresh = window.check(3)
    window.commit(3)

    # Assert
    assert (fresh, window.top, window.bits) == (Freshness.FRESH, 3, 1)


@pytest.mark.parametrize("args", [(-1, 0), (0, -1), (1 << 64, 0), (0, 1 << 64)])
def test_a_stored_state_outside_64_bits_is_a_value_error(args: tuple[int, int]):
    # Act and Assert
    with pytest.raises(ValueError):
        ReplayWindow(*args)


@pytest.mark.parametrize("counter", [-1, 1 << 64])
def test_a_counter_outside_64_bits_is_a_value_error(counter: int):
    # Arrange
    window = ReplayWindow(5, 1)

    # Act and Assert
    with pytest.raises(ValueError):
        window.check(counter)
    with pytest.raises(ValueError):
        window.commit(counter)
    assert (window.top, window.bits) == (5, 1)

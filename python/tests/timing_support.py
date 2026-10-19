"""Load-aware wall-clock bounds (AZ-2723).

A timing check keeps its nominal bound, written for an idle host, and multiplies it by the load factor: the
mean of five runs of a fixed CPU-bound reference loop in this process, taken right before the timed code, over
the time that loop takes on an idle host. The factor is never below 1 and is capped at 8, so a slowdown of the
code under test that is larger than the cap still fails.
"""

import time

# The best of 100 runs of the loop below on the owner's Mac (Python 3.14, arm64) was 0.0299 s while other sessions
# loaded the host, so an idle host is not faster than this by more than the noise; a busy host only adds time.
REFERENCE_SECONDS = 0.030
MAX_FACTOR = 8.0
_REFERENCE_ITERATIONS = 400_000
_RUNS = 5
# A factor measured less than this long ago answers again (a test file of many short checks pays the loop once).
_FRESH_SECONDS = 0.5
_last: tuple[float, float] = (float("-inf"), 1.0)


def _reference_loop_seconds() -> float:
    start = time.perf_counter()
    acc = 0
    for i in range(_REFERENCE_ITERATIONS):
        acc = (acc * 31 + i) & 0xFFFFFFFF
    return time.perf_counter() - start


def load_factor() -> float:
    """How much slower than an idle host this process runs now, in [1, MAX_FACTOR].

    The mean of five runs of the reference loop, not the best of three: on a host loaded 10 to 15 times over its cores
    (measured, 12 busy `yes` processes beside other sessions) the best of three short runs catches a free time slice
    and reads 1.0 while a one-second section is slowed 1.5 to 3 times; the mean sees the slices that were lost.
    On an idle host both are the same."""
    global _last
    now = time.perf_counter()
    if now - _last[0] < _FRESH_SECONDS:
        return _last[1]
    mean = sum(_reference_loop_seconds() for _ in range(_RUNS)) / _RUNS
    factor = min(MAX_FACTOR, max(1.0, mean / REFERENCE_SECONDS))
    _last = (time.perf_counter(), factor)
    return factor


class Bound(float):
    """The scaled bound in seconds; it also carries the nominal bound and the factor for the failure message."""

    nominal: float
    factor: float

    def __new__(cls, nominal: float, factor: float) -> "Bound":
        scaled = super().__new__(cls, nominal * factor)
        scaled.nominal = nominal
        scaled.factor = factor
        return scaled


def bound(nominal_seconds: float) -> Bound:
    """nominal * load factor, measured now: call it right before the timed section."""
    return Bound(nominal_seconds, load_factor())


def assert_within(elapsed: float, limit: Bound, what: str = "") -> None:
    label = f"{what}: " if what else ""
    assert elapsed <= limit, (
        f"{label}elapsed {elapsed:.3f}s, nominal bound {limit.nominal:.3f}s, "
        f"load factor {limit.factor:.2f}, scaled bound {float(limit):.3f}s"
    )

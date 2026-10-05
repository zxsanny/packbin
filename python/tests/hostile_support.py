from __future__ import annotations

import multiprocessing
import time
from typing import Any

from packbin import (
    BinaryPacker,
    Scheme,
    ShortPacket,
    TrailingBytes,
    UnpackResult,
    bits,
    bool as flag_bool,
    dict as map_field,
    eq,
    flags,
    i8,
    list as list_field,
    packed,
    repeat,
    sized,
    times,
    u8,
    u32,
    utf8,
    when,
)

GUARD_SECONDS = 5.0


def _scheme(*fields: Any) -> Scheme[Any]:
    return Scheme(1, dict, *fields)


def zero_progress_when() -> Scheme[Any]:
    return _scheme(
        u8(0, lambda row: row["k"]),
        repeat(1, when(1, eq(0, 9), u8(1, lambda row: row["v"]))),
    )


def zero_progress_vector_when() -> Scheme[Any]:
    return _scheme(
        u8(0, lambda row: row["mode"]),
        repeat(1, when(1, eq(0, 1), u8(1, lambda row: row["v"]))),
    )


def zero_progress_bool() -> Scheme[Any]:
    return _scheme(repeat(0, flag_bool(0, lambda row: row["on"])))


def sized_by(count_field: Any) -> Scheme[Any]:
    return _scheme(count_field, sized(1, lambda row: row["payload"], 0))


def bits_by(count_field: Any) -> Scheme[Any]:
    return _scheme(count_field, bits(1, lambda row: row["b"], 0))


def packed_by(count_field: Any, bias: int = 0) -> Scheme[Any]:
    return _scheme(count_field, packed(1, 1, lambda row: row["k"], 0, bias))


def times_by(count_field: Any) -> Scheme[Any]:
    return _scheme(count_field, times(1, 0, u8(1, lambda row: row["v"])))


def counter(kind: Any) -> Any:
    return kind(0, lambda row: row["n"])


def times_zero_width(count_field: Any) -> Scheme[Any]:
    return _scheme(
        count_field,
        times(1, 0, when(1, eq(0, 9), u8(1, lambda row: row["v"]))),
    )


def _behind_flag(consumer: Any) -> Scheme[Any]:
    return _scheme(flags(0, u8(0, lambda row: row["n"])), consumer)


def count_behind_clear_flag(consumer: str) -> Scheme[Any]:
    if consumer == "sized":
        return _behind_flag(sized(1, lambda row: row["payload"], 0))
    if consumer == "bits":
        return _behind_flag(bits(1, lambda row: row["b"], 0))
    if consumer == "packed":
        return _behind_flag(packed(2, 1, lambda row: row["k"], 0))
    return _behind_flag(times(1, 0, u8(1, lambda row: row["v"])))


def utf8_name() -> Scheme[Any]:
    return _scheme(utf8(0, lambda row: row["s"]))


def dict_of_u8() -> Scheme[Any]:
    return _scheme(map_field(lambda row: row["d"], u8(0, lambda row: row["v"])))


def list_of_u8() -> Scheme[Any]:
    return _scheme(list_field(lambda row: row["xs"], u8(0, lambda row: row["v"])))


# Scheme each unpack vector in fixtures/hostile/cases.txt names (README: fixtures/hostile/README.md).
VECTOR_SCHEMES = {
    "zero_progress_repeat_bool": zero_progress_bool,
    "zero_progress_repeat_when": zero_progress_vector_when,
    "negative_count": lambda: sized_by(counter(i8)),
    "oversize_count": lambda: sized_by(counter(u32)),
    "oversize_count_times": lambda: times_by(counter(u32)),
    "oversize_list_count": list_of_u8,
    "invalid_utf8": utf8_name,
    "invalid_utf8_dict_key": dict_of_u8,
    "count_behind_clear_flag": lambda: count_behind_clear_flag("sized"),
    "count_behind_clear_flag_bits": lambda: count_behind_clear_flag("bits"),
}


def error_kind(result: UnpackResult[Any]) -> str:
    """Vector error kind for a result. Python has no bad_value type until C15: a
    ShortPacket with needed == 0 stands for it (duplicate-key precedent)."""
    error = result.error
    if isinstance(error, TrailingBytes):
        return "trailing_bytes"
    if isinstance(error, ShortPacket):
        return "bad_value" if error.needed == 0 else "short_packet"
    return type(error).__name__


def unpack_guarded(
    scheme: Scheme[Any], data: bytes, unpack: Any = None
) -> tuple[UnpackResult[Any], list[Any], float]:
    """Unpack in a forked child that is killed after GUARD_SECONDS, so a hang fails
    the test instead of CI and leaves nothing spinning behind."""
    ctx = multiprocessing.get_context("fork")
    run = unpack or BinaryPacker.unpack
    recv, send = ctx.Pipe(duplex=False)

    def work() -> None:
        seen: list[Any] = []
        try:
            outcome: Any = (run(data, scheme.on(seen.append)), seen)
        except BaseException as exc:  # reported to the test below
            outcome = exc
        send.send(outcome)

    child = ctx.Process(target=work, daemon=True)
    start = time.perf_counter()
    child.start()
    send.close()
    got = recv.poll(GUARD_SECONDS)
    elapsed = time.perf_counter() - start
    if not got:
        child.kill()
        child.join()
        raise AssertionError(f"unpack still running after {GUARD_SECONDS}s")
    outcome = recv.recv()
    child.join()
    if isinstance(outcome, BaseException):
        raise AssertionError(f"unpack raised {outcome!r}") from outcome
    result, seen = outcome
    return result, seen, elapsed


def assert_rejected(result: UnpackResult[Any], seen: list[Any], elapsed: float) -> None:
    assert result.ok is False
    assert result.value is None
    assert result.error is not None
    assert seen == []
    assert elapsed < 1.0, f"unpack took {elapsed:.3f}s"

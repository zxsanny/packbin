from __future__ import annotations

from collections.abc import Callable
from typing import Any

Get = Callable[[Any], Any]
Set = Callable[[Any, Any], None]
Acc = Callable[[Any], Any]
_builtin_dict = dict


class _Hit:
    def __init__(self, kind: str, key: Any) -> None:
        self.kind = kind
        self.key = key

    def _bad(self, *_args: Any, **_kwargs: Any) -> Any:
        raise TypeError("accessor must be a member access")

    __add__ = __radd__ = __sub__ = __rsub__ = __mul__ = __bool__ = __getitem__ = __getattr__ = _bad


class _Probe:
    def __getattr__(self, name: str) -> _Hit:
        if name.startswith("__"):
            raise AttributeError(name)
        return _Hit("attr", name)

    def __getitem__(self, key: Any) -> _Hit:
        return _Hit("item", key)


def _marked(get: Get, set_: Set, access: tuple[str, Any]) -> tuple[Get, Set]:
    """`access` is the `(kind, key)` of the accessor. It travels with both closures (a node, `be()` and a flag bit
    reuse them), so the construction checks can name a member and tell attribute access from key access. The
    identity accessor has none."""
    get.access = set_.access = access  # type: ignore[attr-defined]
    return get, set_


def _pair(acc: Acc) -> tuple[Get, Set]:
    probe = _Probe()
    try:
        result = acc(probe)
    except ValueError:
        raise
    except Exception as exc:
        raise ValueError("accessor must be a member access") from exc
    if result is probe:
        return (lambda row: row, lambda _row, _value: None)
    if not isinstance(result, _Hit):
        raise ValueError("accessor must be a member access")
    key = result.key
    if result.kind == "attr":
        return _marked(
            lambda row, key=key: getattr(row, key, None),
            lambda row, value, key=key: setattr(row, key, value),
            ("attr", key),
        )
    return _marked(
        lambda row, key=key: row.get(key) if isinstance(row, _builtin_dict) else row[key],
        lambda row, value, key=key: row.__setitem__(key, value),
        ("item", key),
    )

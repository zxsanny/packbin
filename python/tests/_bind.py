from __future__ import annotations

from typing import Any, Callable


def gs(key: str) -> tuple[Callable[[Any], Any], Callable[[Any, Any], None]]:
    def get(row: Any) -> Any:
        if isinstance(row, dict):
            return row.get(key)
        return getattr(row, key, None)

    def set_(row: Any, value: Any) -> None:
        if isinstance(row, dict):
            row[key] = value
        else:
            setattr(row, key, value)

    return get, set_


def leaf() -> tuple[Callable[[Any], Any], Callable[[Any, Any], None]]:
    return (lambda x: x, lambda _x, _v: None)

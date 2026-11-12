"""Probe of AZ-4242: a list or dict whose element is a row of required members (no flag byte per element). It
builds each shape of ../README.md, packs the values given there and unpacks its own bytes. One line per shape:
package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.

Python has one group, `group(anchor, *fields)`, and the element row of a list or dict is that group. An element
row is always a plain dict: the scheme refuses an attribute accessor (`r.x`) inside an element at build
(`_validate_element_accessors`), so element members are key accessors (`r["x"]`). The row around the list may be
a dict or a class:
  - plain shape names: dict rows (`Scheme(1, dict, ...)`), as TypeScript's objects;
  - suffix "-typed": the same list-3 / dict-2 with a class row around the list (`Scheme(1, Holder, ...)`,
    `lambda r: r.items`); only the outer row differs, the elements stay dicts.
other-row: Python has no row types for an element, so the shape is an element row whose members are declared
with attribute accessors, the members of a class row. nested-other-row: a group shares the row around it, so
there is no nested row to declare members for.

"refused" is an exception raised by a `raise` statement of the package (its own ValueError, TypeError or
KeyError); "threw" is any other exception escaping from the package, with where it came from on stderr.
"""

from __future__ import annotations

import collections
import json
import re
import sys
import traceback
import types
from collections.abc import Callable
from pathlib import Path
from typing import Any

import packbin
from packbin import BinaryPacker, Scheme, UnpackResult, eq, group, times, u8, u32, utf8, when
from packbin import dict as dict_field
from packbin import list as list_field

Row = Any

PACKAGE_DIR = Path(packbin.__file__).resolve().parent


def one_line(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def raised(exc: BaseException) -> str:
    return one_line(f"{type(exc).__name__}: {exc}")


def failure(shape: str, exc: BaseException) -> str:
    """refused when the last frame is a `raise` statement in the package; threw otherwise."""
    frames = traceback.extract_tb(exc.__traceback__)
    last = frames[-1] if frames else None
    if (
        last is not None
        and Path(last.filename).resolve().parent == PACKAGE_DIR
        and (last.line or "").lstrip().startswith("raise")
    ):
        return f"refused: {raised(exc)}"
    where = " < ".join(f"{Path(f.filename).name}:{f.lineno} {f.name}" for f in reversed(frames[-4:]))
    print(f"python {shape}: {raised(exc)} at {where}", file=sys.stderr, flush=True)
    return f"threw: {raised(exc)}"


def plain(value: Any) -> Any:
    if isinstance(value, Holder):
        return {key: item for key, item in vars(value).items() if item is not None}
    if isinstance(value, (tuple, collections.deque)):
        return list(value)
    if isinstance(value, types.MappingProxyType):
        return dict(value)
    raise TypeError(f"no text form for {type(value).__name__}")


def shown(value: Any) -> str:
    """Keys in sorted order, so two rows that hold the same values print the same text."""
    return json.dumps(value, sort_keys=True, separators=(",", ":"), default=plain)


def compared(value: Any) -> Any:
    """The text two rows are compared by: a times that reads no round leaves `v` out of the row unpack returns,
    so an empty `v` and an absent one are the same values."""
    return json.loads(shown(value), object_hook=lambda row: {k: v for k, v in row.items() if not (k == "v" and v == [])})


def read_back(result: UnpackResult[Row], got: list[Row], values: Row) -> str:
    if not got:
        return f"refused: {one_line(repr(result.error))}"
    if compared(got[0]) == compared(values):
        return "same"
    return f"differs: {shown(got[0])}"


def probe(shape: str, build: Callable[[], Scheme[Row]], values: Row) -> None:
    def line(built: str, packed: str, unpacked: str) -> None:
        print("\t".join(["python", shape, built, packed, unpacked]), flush=True)

    try:
        scheme = build()
    except Exception as exc:  # the refusal is the finding
        line(failure(shape, exc), "-", "-")
        return
    try:
        packed = BinaryPacker.pack(scheme, values)
    except Exception as exc:  # the refusal is the finding
        line("built", failure(shape, exc), "-")
        return
    got: list[Row] = []
    try:
        result = BinaryPacker.unpack(packed, scheme.on(got.append))
    except Exception as exc:  # an unpack that raises is the finding
        line("built", packed.hex(), failure(shape, exc))
        return
    try:
        unpacked = read_back(result, got, values)
    except Exception as exc:  # a row the probe cannot compare or print: say so and go on
        unpacked = f"threw: probe: {raised(exc)}"
    line("built", packed.hex(), unpacked)


def na(shape: str, why: str) -> None:
    print("\t".join(["python", shape, f"n/a: {why}", "-", "-"]), flush=True)


class Holder:
    """The class row around a list or dict for the -typed lines."""

    def __init__(self) -> None:
        self.items: Any = None
        self.map: Any = None


# The element row of AZ-4199: four required members, ids 0 to 3.
def comment() -> Any:
    return group(
        0,
        utf8(0, lambda r: r["id"]),
        utf8(1, lambda r: r["text"]),
        u32(2, lambda r: r["authorId"]),
        utf8(3, lambda r: r["author"]),
    )


def c1() -> dict[str, Any]:
    return {"id": "c1", "text": "hi", "authorId": 7, "author": "ann"}


def c2() -> dict[str, Any]:
    return {"id": "c2", "text": "ok", "authorId": 258, "author": "bo"}


def c3() -> dict[str, Any]:
    return {"id": "c3", "text": "yes", "authorId": 1, "author": "cy"}


def listed() -> Scheme[Row]:
    return Scheme(1, dict, list_field(lambda r: r["items"], comment()))


def keyed() -> Scheme[Row]:
    return Scheme(1, dict, dict_field(lambda r: r["map"], comment()))


class ListOfRows(list):  # type: ignore[type-arg]
    """A user subclass of list."""


probe("list-0", listed, {"items": []})
probe("list-1", listed, {"items": [c1()]})
probe("list-3", listed, {"items": [c1(), c2(), c3()]})
probe("dict-2", keyed, {"map": {"b": c2(), "a": c1()}})

# A list field packs a list or a subclass of it, a dict field a dict or a subclass of it (`isinstance` in
# _pack.py); unpack gives a plain list and a plain dict.
probe("coll-list-subclass", listed, {"items": ListOfRows([c1(), c2(), c3()])})
probe("coll-tuple", listed, {"items": (c1(), c2(), c3())})
probe("coll-deque", listed, {"items": collections.deque([c1(), c2(), c3()])})
probe("coll-ordereddict", keyed, {"map": collections.OrderedDict([("b", c2()), ("a", c1())])})
probe("coll-mappingproxy", keyed, {"map": types.MappingProxyType({"b": c2(), "a": c1()})})

# when inside an element row: speed is written only for mode 1.
probe(
    "when",
    lambda: Scheme(
        1,
        dict,
        list_field(
            lambda r: r["items"],
            group(0, u8(0, lambda r: r["mode"]), when(1, eq(0, 1), u8(1, lambda r: r["speed"]))),
        ),
    ),
    {"items": [{"mode": 1, "speed": 7}, {"mode": 0}]},
)

# times inside an element row: c rounds of v.
probe(
    "times",
    lambda: Scheme(
        1,
        dict,
        list_field(
            lambda r: r["items"],
            group(0, u8(0, lambda r: r["c"]), times(1, 0, u8(1, lambda r: r["v"]))),
        ),
    ),
    {"items": [{"c": 2, "v": [5, 6]}, {"c": 0, "v": []}]},
)

# other-row: the element row's members declared with attribute accessors, as for a class row.
probe(
    "other-row",
    lambda: Scheme(
        1,
        dict,
        list_field(
            lambda r: r["items"],
            group(
                0,
                utf8(0, lambda r: r.id),
                utf8(1, lambda r: r.text),
                u32(2, lambda r: r.authorId),
                utf8(3, lambda r: r.author),
            ),
        ),
    ),
    {"items": [c1()]},
)

na("nested-other-row", "a group shares the row and the ids around it: there is no nested row with a row type of its own")

# A required member left out of an element.
probe("null-member", listed, {"items": [{"id": "c1", "authorId": 7, "author": "ann"}]})

# A list that holds a None element.
probe("null-item", listed, {"items": [c1(), None]})


def holder(**members: Any) -> Holder:
    row = Holder()
    for key, value in members.items():
        setattr(row, key, value)
    return row


probe(
    "list-3-typed",
    lambda: Scheme(1, Holder, list_field(lambda r: r.items, comment())),
    holder(items=[c1(), c2(), c3()]),
)
probe(
    "dict-2-typed",
    lambda: Scheme(1, Holder, dict_field(lambda r: r.map, comment())),
    holder(map={"b": c2(), "a": c1()}),
)

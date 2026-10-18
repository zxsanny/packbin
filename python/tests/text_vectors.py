"""Loader of `fixtures/text/vectors.txt` (compact text rows shared by the eight packages).

Row syntax is at the top of the file: `enc id text field`, `alt id text field`, `bad id kind buffer`,
`ref id packet`, `flip id enc-id`; text is the hex of its UTF-8 bytes, `-` is the empty text.
"""

from __future__ import annotations

from pathlib import Path
from typing import NamedTuple

ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "fixtures" / "text" / "vectors.txt"
EMIT_TABLES = ROOT / "scripts" / "text" / "emit_tables.py"


class Row(NamedTuple):
    kind: str
    id: str
    text: str | None
    field: bytes
    refusal: str | None
    target: str | None


def _text(token: str) -> str:
    return "" if token == "-" else bytes.fromhex(token).decode("utf-8")


def _rows() -> list[Row]:
    rows: list[Row] = []
    for line in VECTORS.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        part = line.split(" ")
        kind, row_id = part[0], part[1]
        if kind in ("enc", "alt"):
            rows.append(Row(kind, row_id, _text(part[2]), bytes.fromhex(part[3]), None, None))
        elif kind == "bad":
            rows.append(Row(kind, row_id, None, bytes.fromhex(part[3]) if len(part) > 3 else b"", part[2], None))
        elif kind == "ref":
            rows.append(Row(kind, row_id, None, bytes.fromhex(part[2]), None, None))
        elif kind == "flip":
            rows.append(Row(kind, row_id, None, b"", None, part[2]))
        else:
            raise ValueError(f"vectors.txt: unknown row kind {kind!r}")
    return rows


ROWS = _rows()


def rows(kind: str) -> list[Row]:
    return [row for row in ROWS if row.kind == kind]


def row(row_id: str) -> Row:
    return next(r for r in ROWS if r.id == row_id)

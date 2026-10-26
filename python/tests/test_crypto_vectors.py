from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pytest

from packbin import _crypto

# AZ-3283 AC-2: every row of `fixtures/crypto/vectors.txt` (AZ-3201, PB-02; the row syntax is at the top of the file)
# through the internal crypto module, and copies of the file with one hex digit changed fail on that row only.

VECTORS = Path(__file__).resolve().parents[2] / "fixtures" / "crypto" / "vectors.txt"
COUNTS = {"sha256": 6, "hmac256": 8, "hkdf256": 3, "chacha-block": 6, "chacha-xor": 4}


@dataclass(frozen=True)
class Row:
    primitive: str
    id: str
    fields: dict[str, str]

    def data(self, name: str) -> bytes:
        value = self.fields[name]
        return b"" if value == "-" else bytes.fromhex(value)

    def number(self, name: str) -> int:
        return int(self.fields[name])


def load(path: Path) -> list[Row]:
    rows = []
    for line in path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        primitive, source, *pairs = line.split(" ")
        rows.append(Row(primitive, source, dict(pair.split("=", 1) for pair in pairs)))
    return rows


def _sha256(row: Row) -> tuple[str, str]:
    message = row.data("msg") if "msg" in row.fields else row.data("byte") * row.number("repeat")
    return row.fields["digest"], _crypto.sha256(message).hex()


def _hmac(row: Row) -> tuple[str, str]:
    mac = _crypto.hmac_sha256(row.data("key"), row.data("data"))
    keep = row.number("truncate") if "truncate" in row.fields else len(mac)
    return row.fields["mac"], mac[:keep].hex()


def _hkdf(row: Row) -> tuple[str, str]:
    ikm, salt, info, length = row.data("ikm"), row.data("salt"), row.data("info"), row.number("len")
    prk = _crypto.hkdf_extract(salt, ikm)
    okm = _crypto.hkdf_sha256(ikm, salt, info, length)
    return f"prk={row.fields['prk']} okm={row.fields['okm']}", f"prk={prk.hex()} okm={okm.hex()}"


def _block(row: Row) -> tuple[str, str]:
    block = _crypto.chacha20_block(row.data("key"), row.data("nonce"), row.number("counter"))
    return row.fields["block"], block.hex()


def _cipher(row: Row) -> tuple[str, str]:
    key, nonce, counter, plain = row.data("key"), row.data("nonce"), row.number("counter"), row.data("plain")
    cipher = _crypto.chacha20_xor(key, nonce, counter, plain)
    back = _crypto.chacha20_xor(key, nonce, counter, cipher)
    return row.fields["cipher"], cipher.hex() + ("" if back == plain else " (decrypt differs)")


RUN = {"sha256": _sha256, "hmac256": _hmac, "hkdf256": _hkdf, "chacha-block": _block, "chacha-xor": _cipher}


def mismatch(row: Row) -> str | None:
    """`<primitive> <id>: expected X, got Y` when the module's answer differs from the row, else None."""
    expected, got = RUN[row.primitive](row)
    return None if got == expected else f"{row.primitive} {row.id}: expected {expected}, got {got}"


ROWS = load(VECTORS)


def test_the_file_holds_27_rows_of_the_five_primitives():
    # Arrange
    counts: dict[str, int] = {}

    # Act
    for row in ROWS:
        counts[row.primitive] = counts.get(row.primitive, 0) + 1

    # Assert
    assert (len(ROWS), counts) == (27, COUNTS)


@pytest.mark.parametrize("row", ROWS, ids=[f"{r.primitive} {r.id}" for r in ROWS])
def test_every_row_matches(row: Row):
    # Act
    problem = mismatch(row)

    # Assert
    assert problem is None


def _changed_copy(tmp_path: Path, primitive: str, field: str) -> tuple[Path, str]:
    """A copy of the vectors with the last hex digit of `field` changed in the first `primitive` row, and its id."""
    lines = VECTORS.read_text().splitlines()
    for number, line in enumerate(lines):
        parts = line.split(" ")
        if parts[0] != primitive:
            continue
        at = next(i for i, part in enumerate(parts) if part.startswith(field + "="))
        parts[at] = parts[at][:-1] + ("1" if parts[at][-1] == "0" else "0")
        lines[number] = " ".join(parts)
        copy = tmp_path / "vectors.txt"
        copy.write_text("\n".join(lines) + "\n")
        return copy, f"{primitive} {parts[1]}"
    raise AssertionError(f"no {primitive} row")


@pytest.mark.parametrize(
    "primitive, field",
    [
        ("sha256", "digest"),
        ("hmac256", "mac"),
        ("hkdf256", "prk"),
        ("hkdf256", "okm"),
        ("chacha-block", "block"),
        ("chacha-xor", "cipher"),
    ],
)
def test_a_copy_with_one_hex_digit_changed_fails_on_that_row_only(tmp_path: Path, primitive: str, field: str):
    # Arrange
    copy, changed = _changed_copy(tmp_path, primitive, field)

    # Act
    failing = [f"{row.primitive} {row.id}" for row in load(copy) if mismatch(row) is not None]

    # Assert
    assert failing == [changed]


KEY = bytes(32)
NONCE = bytes(12)


@pytest.mark.parametrize(
    "key, nonce, counter",
    [(bytes(31), NONCE, 0), (bytes(33), NONCE, 0), (KEY, bytes(8), 0), (KEY, NONCE, -1), (KEY, NONCE, 1 << 32)],
    ids=["key31", "key33", "nonce8", "counter-1", "counter2^32"],
)
def test_a_block_of_a_wrong_key_nonce_or_counter_is_refused(key: bytes, nonce: bytes, counter: int):
    # Act and Assert
    with pytest.raises(ValueError):
        _crypto.chacha20_block(key, nonce, counter)


def test_a_stream_that_would_pass_the_last_block_counter_is_refused():
    # Arrange
    last = (1 << 32) - 1

    # Act
    one_block = _crypto.chacha20_xor(KEY, NONCE, last, bytes(64))

    # Assert
    assert one_block == _crypto.chacha20_block(KEY, NONCE, last)
    with pytest.raises(ValueError):
        _crypto.chacha20_xor(KEY, NONCE, last, bytes(65))


def test_hkdf_gives_at_most_255_blocks():
    # Arrange
    prk = _crypto.hkdf_extract(b"", b"\x0b" * 22)

    # Act
    longest = _crypto.hkdf_expand(prk, b"", 255 * 32)

    # Assert
    assert len(longest) == 8160
    with pytest.raises(ValueError):
        _crypto.hkdf_expand(prk, b"", 255 * 32 + 1)

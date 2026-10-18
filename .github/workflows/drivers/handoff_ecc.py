"""The message ECC commands of handoff.py (AZ-2689; contract message-ecc.md).

  ecc-protect <n> <clear hex>       prints the clear position message packed again with n parity bytes, or the error kind
  ecc-repair <n> <t> <hex>          prints the position message repaired (hex, then the repaired count), or the error kind
  ecc-batch <file>                  one line per line of the file: `protect <n> <hex>` or `repair <n> <t> <hex>`

"-" is the empty buffer. The kind names are the ones of fixtures/ecc/vectors.txt (uncorrectable, short, too_long,
bad_parity, bad_limit) plus trailing, type_mismatch and unpack_failed for the walk of the unprotected fields.
"""
from __future__ import annotations

from packbin import BinaryPacker, ShortPacket, TooLong, TrailingBytes, TypeMismatch, Uncorrectable


def _bytes(token: str) -> bytes:
    return b"" if token == "-" else bytes.fromhex(token)


def _kind(result) -> str:
    error = result.error
    if isinstance(error, Uncorrectable):
        return "uncorrectable"
    if isinstance(error, TooLong):
        return "too_long"
    if isinstance(error, ShortPacket):
        return "short" if error.field == "parity" else "unpack_failed"
    if isinstance(error, TrailingBytes):
        return "trailing"
    if isinstance(error, TypeMismatch):
        return "type_mismatch"
    return "unpack_failed"


def _protect(position, n: int, clear: bytes) -> str:
    row = BinaryPacker.unpack(clear, position.on(lambda _row: None))
    if not row.ok or row.value is None:
        return "unpack_failed"
    try:
        scheme = position.with_limits(parity=n)
    except ValueError:
        return "bad_parity"
    return BinaryPacker.pack(scheme, row.value).hex()


def _repair(position, n: int, t: int, received: bytes) -> str:
    try:
        scheme = position.with_limits(parity=n)
    except ValueError:
        return "bad_parity"
    try:
        result = BinaryPacker.unpack(received, scheme.on(lambda _row: None), limit=t)
    except ValueError:
        return "bad_limit"
    if not result.ok or result.value is None:
        return _kind(result)
    return "%s %d" % (BinaryPacker.pack(position, result.value).hex(), result.repaired)


def _line(position, words: list[str]) -> str:
    if words[:1] == ["protect"] and len(words) == 3:
        return _protect(position, int(words[1]), _bytes(words[2]))
    if words[:1] == ["repair"] and len(words) == 4:
        return _repair(position, int(words[1]), int(words[2]), _bytes(words[3]))
    raise ValueError("ecc line: %s" % " ".join(words))


def run_ecc(cmd: str, argv: list[str], position) -> int:
    """`position` is the unprotected position scheme of handoff.py; returns the exit status."""
    if cmd == "ecc-protect" and len(argv) == 3:
        words = ["protect", argv[1], argv[2]]
    elif cmd == "ecc-repair" and len(argv) == 4:
        words = ["repair", argv[1], argv[2], argv[3]]
    elif cmd == "ecc-batch" and len(argv) == 2:
        with open(argv[1], encoding="utf-8") as lines:
            for line in lines:
                if line.strip():
                    print(_line(position, line.split()))
        return 0
    else:
        return 2
    print(_line(position, words))
    return 0

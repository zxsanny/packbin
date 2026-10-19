from __future__ import annotations

from packbin import PackSession, Scheme, TypeMismatch, u8
from packbin import _session_pad

SCHEME = Scheme(0x40, dict, u8(0, lambda row: row["a"]))
SEED = bytes(range(1, 33))
NONCE = bytes.fromhex("01000000000000000000000000000000")


def _pair() -> tuple[PackSession, PackSession]:
    sender, receiver = PackSession.load(SEED), PackSession.load(SEED)
    assert sender is not None and receiver is not None
    assert sender.start(NONCE) == NONCE and receiver.join(NONCE)
    return sender, receiver


def _count_blocks(monkeypatch) -> list[int]:
    calls: list[int] = []
    real = _session_pad._block

    def counting(key, nonce, counter):
        calls.append(counter)
        return real(key, nonce, counter)

    monkeypatch.setattr(_session_pad, "_block", counting)
    return calls


def test_a_payload_of_an_unknown_type_computes_one_pad_block_whatever_its_length(monkeypatch):
    _, receiver = _pair()
    calls = _count_blocks(monkeypatch)
    payload = bytes(range(256)) * 4096  # 1 MiB

    got = receiver.unpack(payload, SCHEME.on(lambda row: None))

    assert got.ok is False
    assert isinstance(got.error, TypeMismatch)
    assert len(calls) == 1


def test_an_unknown_type_reports_the_clear_type_byte_as_before():
    sender, receiver = _pair()
    other = Scheme(0x41, dict, u8(0, lambda row: row["a"]))
    packet = sender.pack(other, {"a": 1})

    got = receiver.unpack(packet, SCHEME.on(lambda row: None))

    assert isinstance(got.error, TypeMismatch)
    assert got.error.actual == 0x41


def test_a_payload_of_a_known_type_computes_every_block_and_gives_the_same_row(monkeypatch):
    sender, receiver = _pair()
    seen: list[dict] = []
    packet = sender.pack(SCHEME, {"a": 5})
    calls = _count_blocks(monkeypatch)

    got = receiver.unpack(packet, SCHEME.on(seen.append))

    assert got.ok is True
    assert seen == [{"a": 5}]
    assert len(calls) == 2  # one block for the type byte, one for the whole 2-byte payload


def test_an_empty_payload_is_still_a_short_packet():
    _, receiver = _pair()

    got = receiver.unpack(b"", SCHEME.on(lambda row: None))

    assert got.ok is False
    assert got.error.needed == 1

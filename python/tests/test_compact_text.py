from __future__ import annotations

import hashlib
import subprocess
import sys
import time
from pathlib import Path

import pytest

from packbin import BinaryPacker, Scheme, ShortPacket, flags, repeat, times, u8, utf8
from packbin import dict as map_field
from packbin import list as list_field
from packbin import _text_tables

import text_vectors
from text_vectors import Row

# AZ-2648: every string position uses the compact text format (contract compact-text 1.0.0); the rows are
# `fixtures/text/vectors.txt`, the same for the eight packages.

TABLES_JSON = text_vectors.ROOT / "fixtures" / "text" / "tables.json"
TABLES_PY = Path(_text_tables.__file__)

ONE = Scheme(1, dict, utf8(0, lambda row: row["s"]))
ONE_THEN_BYTE = Scheme(1, dict, utf8(0, lambda row: row["s"]), u8(1, lambda row: row["n"]))
SENTINEL = 0x5A


def _pack(scheme: Scheme, row: dict) -> bytes:
    return BinaryPacker.pack(scheme, row)


def _unpack(scheme: Scheme, packet: bytes):
    return BinaryPacker.unpack(packet, scheme.on(lambda _row: None))


def _ids(rows: list[Row]) -> list[str]:
    return [row.id for row in rows]


def _count_size(field: bytes) -> int:
    return 1 if field[0] < 0x80 else 2 if field[1] < 0x80 else 3


def test_the_committed_tables_equal_the_emitter_output_and_the_fixture():
    # Arrange
    command = [sys.executable, str(text_vectors.EMIT_TABLES), "python", "--check", str(TABLES_PY)]

    # Act
    done = subprocess.run(command, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60)

    # Assert
    assert done.returncode == 0, done.stdout + done.stderr
    assert _text_tables.TABLES_SHA256 == hashlib.sha256(TABLES_JSON.read_bytes()).hexdigest()


# AC-1, AC-2: the vector rows

ENC = text_vectors.rows("enc")
ALT = text_vectors.rows("alt")
BAD = text_vectors.rows("bad")
REF = text_vectors.rows("ref")
FLIP = text_vectors.rows("flip")


@pytest.mark.parametrize("row", ENC, ids=_ids(ENC))
def test_ac1_pack_gives_the_bytes_of_the_enc_row(row: Row):
    # Arrange
    assert row.text is not None

    # Act
    packet = _pack(ONE, {"s": row.text})

    # Assert
    assert packet == b"\x01" + row.field


@pytest.mark.parametrize("row", ENC + ALT, ids=_ids(ENC + ALT))
def test_ac2_unpack_gives_the_text_of_the_row_and_uses_every_byte(row: Row):
    # Arrange
    packet = b"\x01" + row.field

    # Act
    result = _unpack(ONE, packet)

    # Assert: a byte left over would be TrailingBytes
    assert result.ok, result.error
    assert result.value == {"s": row.text}


# AC-3: every position

USER = Scheme(
    1,
    dict,
    utf8(0, lambda row: row["username"]),
    list_field(lambda row: row["roles"], utf8(0, lambda row: row)),
    map_field(lambda row: row["access"], list_field(lambda row: row["actions"], utf8(0, lambda row: row))),
)
NESTED = Scheme(
    1,
    dict,
    map_field(
        lambda row: row["access"],
        list_field(lambda row: row["rows"], map_field(lambda row: row["fields"], utf8(0, lambda row: row))),
    ),
)
REF_VALUES = {
    "ref.user": (
        USER,
        {
            "username": "zxsanny",
            "roles": ["user", "dispatcher"],
            "access": {
                "channel": ["read"],
                "map": ["read", "gps_fix", "set", "edit"],
                "store": ["read", "write"],
            },
        },
    ),
    "ref.nested": (
        NESTED,
        {"access": {"map": [{"op": "gps_fix"}], "store": [{"op": "read"}, {"op": "write"}]}},
    ),
    "ref.user_ua": (
        USER,
        {
            "username": "Олександр",
            "roles": ["диспетчер", "Оператор"],
            "access": {"карта": ["читати", "правити"], "канал": ["читати"]},
        },
    ),
    "ref.nested_mixed": (
        NESTED,
        {
            "access": {
                "Карта": [{"op": "gps_fix", "note": "увага 48.46, 35.04"}],
                "store": [{"op": "ЧИТАТИ"}],
            }
        },
    ),
}


def test_every_ref_row_has_its_scheme_and_values():
    assert sorted(row.id for row in REF) == sorted(REF_VALUES)


@pytest.mark.parametrize("row", REF, ids=_ids(REF))
def test_ac3_the_ring_packet_is_packed_and_unpacked(row: Row):
    # Arrange
    scheme, values = REF_VALUES[row.id]

    # Act
    packed = _pack(scheme, values)
    result = _unpack(scheme, row.field)

    # Assert
    assert packed == row.field
    assert result.ok, result.error
    assert result.value == values


def test_ac3_a_list_element_and_a_dictionary_key_and_value_list_round_trip():
    # Arrange
    scheme = Scheme(
        1,
        dict,
        list_field(lambda row: row["xs"], utf8(0, lambda row: row)),
        map_field(lambda row: row["d"], utf8(0, lambda row: row)),
    )
    values = {"xs": ["привіт", "", "Hello, World", "😀"], "d": {"я": "a", "b": "Київ"}}

    # Act
    packed = _pack(scheme, values)
    result = _unpack(scheme, packed)

    # Assert
    assert result.ok, result.error
    assert result.value == values


def test_ac3_repeat_and_times_strings_round_trip():
    # Arrange
    by_repeat = Scheme(1, dict, repeat(0, utf8(0, lambda row: row["s"])))
    by_times = Scheme(1, dict, u8(0, lambda row: row["n"]), times(1, 0, utf8(1, lambda row: row["s"])))
    words = ["привіт", "Світе", "ok 48.46"]

    # Act
    repeated = _pack(by_repeat, {"s": words})
    counted = _pack(by_times, {"n": 3, "s": words})

    # Assert
    assert _unpack(by_repeat, repeated).value == {"s": words}
    assert _unpack(by_times, counted).value == {"n": 3, "s": words}
    assert repeated[1:] == b"".join(_pack(ONE, {"s": word})[1:] for word in words)
    assert counted[2:] == repeated[1:]


def test_ac3_an_absent_optional_string_adds_no_byte_and_an_empty_one_adds_one():
    # Arrange
    scheme = Scheme(1, dict, flags(0, utf8(0, lambda row: row["s"])))

    # Act
    absent = _pack(scheme, {"s": None})
    empty = _pack(scheme, {"s": ""})
    some = _pack(scheme, {"s": "я"})

    # Assert
    assert len(empty) == len(absent) + 1
    assert some == empty[:-1] + b"\x02\xa3\x00"
    assert _unpack(scheme, absent).value == {}
    assert _unpack(scheme, empty).value == {"s": ""}
    assert _unpack(scheme, some).value == {"s": "я"}


# AC-4: hostile and damaged payloads


@pytest.mark.parametrize("row", BAD, ids=_ids(BAD))
def test_ac4_a_bad_row_is_refused_naming_the_field_with_no_value(row: Row):
    # Arrange
    packet = b"\x01" + row.field

    # Act
    result = _unpack(ONE, packet)

    # Assert
    assert result.ok is False
    assert result.value is None
    assert isinstance(result.error, ShortPacket)
    assert result.field == "0"


def _flipped_packets(field: bytes):
    start = _count_size(field)
    for bit in range(8 * (len(field) - start)):
        damaged = bytearray(field)
        damaged[start + bit // 8] ^= 0x80 >> (bit % 8)
        yield bit, b"\x01" + bytes(damaged) + bytes((SENTINEL,))


def _enc_field(enc_id: str) -> bytes:
    return text_vectors.row(enc_id).field


def test_ac4_there_are_flip_rows_for_at_least_twenty_fields():
    assert len(FLIP) >= 20


@pytest.mark.parametrize("row", FLIP, ids=_ids(FLIP))
def test_ac4_a_flipped_payload_bit_gives_a_string_or_an_error_and_the_next_byte_is_intact(row: Row):
    # Arrange
    assert row.target is not None
    field = _enc_field(row.target)

    for bit, packet in _flipped_packets(field):
        # Act
        result = _unpack(ONE_THEN_BYTE, packet)

        # Assert
        if result.ok:
            assert result.value is not None, (row.id, bit)
            assert result.value["n"] == SENTINEL, (row.id, bit)
            assert len(result.value["s"].encode("utf-8")) <= 65535, (row.id, bit)
        else:
            assert isinstance(result.error, ShortPacket), (row.id, bit)
            assert result.field == "0", (row.id, bit)


# AC-5: limits and headers


def test_ac5_a_text_of_65535_bytes_is_accepted_and_one_of_65536_is_refused_naming_the_field():
    # Arrange
    text = "a" * 65535

    # Act
    packed = _pack(ONE, {"s": text})
    with pytest.raises(ValueError) as refused:
        _pack(ONE_THEN_BYTE, {"s": "a" * 65536, "n": 1})

    # Assert
    assert _unpack(ONE, packed).value == {"s": text}
    assert str(refused.value) == "0: utf-8 length 65536"


@pytest.mark.parametrize(
    "length,header", [(126, "7f"), (127, "8001")], ids=["payload-127-one-byte-count", "payload-128-two-byte-count"]
)
def test_ac5_the_count_is_one_byte_at_127_and_two_at_128(length: int, header: str):
    # Arrange: q is a rare letter, so the raw payload (0x10 and the text) is what is written
    text = "q" * length

    # Act
    packet = _pack(ONE, {"s": text})

    # Assert
    assert packet.hex().startswith("01" + header + "10" + "71")
    assert len(packet) == 1 + len(header) // 2 + length + 1
    assert _unpack(ONE, packet).value == {"s": text}


def test_ac5_max_bytes_bounds_the_packet_with_the_compact_field():
    # Arrange: the field of "привіт" is 6 bytes
    fits = ONE.with_limits(max_bytes=7)
    tight = ONE.with_limits(max_bytes=6)

    # Act
    packed = _pack(fits, {"s": "привіт"})
    with pytest.raises(ValueError) as refused:
        _pack(tight, {"s": "привіт"})

    # Assert
    assert packed.hex() == "0105a37aa424e0"
    assert str(refused.value) == "s: the packet would be 7 bytes, above the limit of 6 bytes"


# AC-6: invalid UTF-8


@pytest.mark.parametrize(
    "row", [r for r in BAD if r.refusal in ("utf8", "raw")], ids=lambda row: row.id
)
def test_ac6_escape_and_raw_payloads_that_are_not_utf8_are_refused(row: Row):
    # Act
    result = _unpack(ONE, b"\x01" + row.field)

    # Assert
    assert result.ok is False
    assert result.field == "0"


# AC-7: dictionary keys


def test_ac7_both_insertion_orders_give_the_same_bytes_sorted_by_the_utf8_of_the_key():
    # Arrange
    scheme = Scheme(1, dict, map_field(lambda row: row["d"], utf8(0, lambda row: row)))
    keys = ["я", "b", "Київ", "a", "😀", "Zed"]
    forward = {key: "v" for key in keys}
    backward = {key: "v" for key in reversed(keys)}

    # Act
    one = _pack(scheme, {"d": forward})
    two = _pack(scheme, {"d": backward})

    # Assert
    assert one == two
    assert _unpack(scheme, one).value == {"d": forward}
    expected = b"".join(
        _pack(ONE, {"s": key})[1:] + _pack(ONE, {"s": "v"})[1:] for key in sorted(keys, key=lambda k: k.encode("utf-8"))
    )
    assert one == b"\x01" + len(keys).to_bytes(2, "little") + expected


def test_ac7_a_repeated_decoded_key_is_refused():
    # Arrange: two spellings of the key я (the canonical field and an escape for the letter)
    scheme = Scheme(1, dict, map_field(lambda row: row["d"], utf8(0, lambda row: row)))
    canonical = text_vectors.row("enc.hand.one_ua").field
    spelled = text_vectors.row("alt.escape_for_letter").field
    value = text_vectors.row("enc.hand.one_a").field
    packet = b"\x01\x02\x00" + canonical + value + spelled + value

    # Act
    result = _unpack(scheme, packet)

    # Assert
    assert result.ok is False
    assert result.value is None
    assert isinstance(result.error, ShortPacket)


# The decoder is bounded by the payload


def test_a_payload_of_the_worst_symbol_decodes_to_less_than_six_bytes_per_byte_plus_eight():
    # Arrange: start in Russian, 3-bit all-zero code is the letter о (2 UTF-8 bytes); N = 1000, pad 2
    payload = bytes((0x44,)) + bytes(999)
    packet = b"\x01" + bytes((0xE8, 0x07)) + payload

    # Act
    result = _unpack(ONE, packet)

    # Assert
    assert result.ok, result.error
    assert result.value == {"s": "о" * 2664}
    assert len(result.value["s"].encode("utf-8")) <= 6 * len(payload) + 8


def test_a_text_that_grows_past_65535_bytes_is_refused():
    # Arrange: 33,000 letters о are 66,000 bytes: 99,006 bits, N = 12,376, pad 2
    payload = bytes((0x44,)) + bytes(12375)
    count = len(payload)
    packet = b"\x01" + bytes(((count & 0x7F) | 0x80, count >> 7)) + payload

    # Act
    result = _unpack(ONE, packet)

    # Assert
    assert result.ok is False
    assert result.field == "0"


def test_a_lone_surrogate_is_refused_on_pack_as_before():
    with pytest.raises(ValueError):
        _pack(ONE, {"s": "a\ud800"})


# AC-8: speed


def test_ac8_100000_round_trips_of_a_20_character_ukrainian_string_take_at_most_40_seconds():
    # Arrange: two strings in turn, so that the codec's memory of the last string is never used
    texts = ["Добрий день, як справи", "Привіт, світе! Київ 24"]
    assert all(len(text) >= 20 for text in texts)
    reader = ONE.on(lambda _row: None)
    started = time.perf_counter()

    # Act
    for i in range(100_000):
        text = texts[i & 1]
        result = BinaryPacker.unpack(BinaryPacker.pack(ONE, {"s": text}), reader)
        assert result.value["s"] == text
    elapsed = time.perf_counter() - started

    # Assert
    assert elapsed <= 40.0, f"{elapsed:.1f} s"

from __future__ import annotations

import inspect
from dataclasses import dataclass

import pytest

import packbin
from packbin import (
    BinaryPacker,
    Scheme,
    ShortPacket,
    TypeMismatch,
    flags,
    i16,
    i32,
    u8,
    u16,
    utf8,
)

from _bind import gs


@dataclass
class MarkerRow:
    sid: int = 0


@dataclass
class UserModifiedEvent:
    user_id: int = 0
    user_name_change: str = ""
    user_email_change: str = ""
    user_status_change: int = 0


@dataclass
class UserPositionEvent:
    user_id: int = 0
    latitude: int = 0
    longitude: int = 0


@dataclass
class PositionRow:
    sid: int = 0
    lat: int = 0
    lon: int = 0
    profile: int = 0
    heading: int | None = None
    speed: int | None = None
    altitude: int | None = None


MARKER = Scheme(32, MarkerRow, u8(0, *gs("sid")))

MODIFIED = Scheme(
    1,
    UserModifiedEvent,
    i32(0, *gs("user_id")),
    utf8(1, *gs("user_name_change")),
    utf8(2, *gs("user_email_change")),
    u8(3, *gs("user_status_change")),
)

POSITION_EVENT = Scheme(
    2,
    UserPositionEvent,
    i32(0, *gs("user_id")),
    i32(1, *gs("latitude")),
    i32(2, *gs("longitude")),
)

POSITION = Scheme(
    0x40,
    PositionRow,
    u16(0, *gs("sid")),
    i32(1, *gs("lat")),
    i32(2, *gs("lon")),
    u8(3, *gs("profile")),
    flags(
        u16(4, *gs("heading")),
        u8(5, *gs("speed")),
        i16(6, *gs("altitude")),
    ),
)


def test_ac1_scheme_replaces_packet():
    assert not hasattr(packbin, "Packet")
    assert hasattr(packbin, "BinaryPacker")
    assert not hasattr(packbin, "TypeNum")
    assert not hasattr(packbin, "packet")
    assert not hasattr(packbin, "pack")
    assert not hasattr(packbin, "unpack")
    scheme = Scheme(1, MarkerRow, u8(0, *gs("sid")))
    assert scheme._type_number == 1
    raw = BinaryPacker.pack(scheme, MarkerRow(sid=7))
    assert raw == bytes([0x01, 0x07])


def test_ac2_position_row_has_no_type_member():
    row = PositionRow(sid=1, lat=500_000_000, lon=300_000_000, profile=1)
    raw = BinaryPacker.pack(POSITION, row)
    assert raw.hex() == "4001000065cd1d00a3e1110100"
    src = inspect.getsource(PositionRow)
    assert "type" not in src
    assert not hasattr(row, "type")


def test_ac3_known_scheme_checks_leading_byte():
    called = []
    scheme = Scheme(1, MarkerRow, u8(0, *gs("sid")))
    got = BinaryPacker.unpack(bytes([2, 7]), scheme.on(lambda row: called.append(row)))
    assert got.ok is False
    assert got.value is None
    assert isinstance(got.error, TypeMismatch)
    assert got.error.expected == -1
    assert got.error.actual == 2
    assert called == []


def test_ac4_unknown_buffer_calls_matching_handler():
    raw = bytes.fromhex("02070000000800000009000000")
    seen: list[object] = []

    def on_modified(ev: UserModifiedEvent) -> None:
        seen.append(("modified", ev))

    def on_position(ev: UserPositionEvent) -> None:
        seen.append(("position", ev))

    got = BinaryPacker.unpack(raw, MODIFIED.on(on_modified), POSITION_EVENT.on(on_position))
    assert got.ok is True
    assert len(seen) == 1
    assert seen[0][0] == "position"
    ev = seen[0][1]
    assert isinstance(ev, UserPositionEvent)
    assert ev.user_id == 7
    assert ev.latitude == 8
    assert ev.longitude == 9
    assert not hasattr(ev, "type")
    assert BinaryPacker.pack(
        POSITION_EVENT, UserPositionEvent(user_id=7, latitude=8, longitude=9)
    ).hex() == ("02070000000800000009000000")


def test_ac5_unknown_type_number():
    called = []

    def on_modified(ev: UserModifiedEvent) -> None:
        called.append(ev)

    def on_position(ev: UserPositionEvent) -> None:
        called.append(ev)

    got = BinaryPacker.unpack(bytes([9, 0]), MODIFIED.on(on_modified), POSITION_EVENT.on(on_position))
    assert got.ok is False
    assert got.value is None
    assert isinstance(got.error, TypeMismatch)
    assert got.error.actual == 9
    assert called == []


def test_ac6_type_numbers_in_one_call_are_unique():
    other = Scheme(1, MarkerRow, u8(0, *gs("sid")))
    with pytest.raises(ValueError):
        BinaryPacker.unpack(b"\x01\x00", MODIFIED.on(lambda ev: None), other.on(lambda row: None))


def test_scheme_argument_required():
    row = MarkerRow(sid=23)
    with pytest.raises(TypeError):
        BinaryPacker.pack(row)  # type: ignore[call-arg]


def test_type_number_range():
    with pytest.raises(ValueError):
        Scheme(256, MarkerRow, u8(0, *gs("sid")))
    with pytest.raises(ValueError):
        Scheme(-1, MarkerRow, u8(0, *gs("sid")))


def test_empty_buffer_short_packet():
    got = BinaryPacker.unpack(b"", MARKER.on(lambda row: None))
    assert got.ok is False
    assert got.value is None
    assert isinstance(got.error, ShortPacket)
    assert got.error.field == ""
    assert got.error.needed == 1
    assert got.error.left == 0


def test_marker_pack_unpack():
    row = MarkerRow(sid=23)
    raw = BinaryPacker.pack(MARKER, row)
    assert raw.hex() == "2017"
    got = BinaryPacker.unpack(raw, MARKER.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value.sid == 23

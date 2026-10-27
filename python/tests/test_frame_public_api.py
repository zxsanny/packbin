from __future__ import annotations

import enum

import packbin

# AZ-3294 AC-4: the D1 names, spelled as in the other packages (contract pack-session 3.0.0, "Purpose").

TYPES = (
    "FrameSession",
    "FrameConfig",
    "FrameDirection",
    "FrameDirections",
    "FrameSlot",
    "FrameOpened",
    "MsgContext",
    "ReplayWindow",
    "Freshness",
    "MacKey",
)
ERRORS = ("BadValue", "TooLong", "BufferFull", "ShortPacket", "TagMismatch", "Duplicate", "TooOld")


def test_ac4_the_d1_type_names_are_public():
    # Act
    namespace: dict = {}
    exec("from packbin import *", namespace)

    # Assert
    assert [name for name in TYPES if name not in packbin.__all__ or name not in namespace or not hasattr(packbin, name)] == []


def test_ac4_the_frame_error_kinds_are_public_beside_the_existing_ones():
    # Act and Assert
    assert [name for name in ERRORS if name not in packbin.__all__ or not hasattr(packbin, name)] == []
    assert [type(getattr(packbin, name)).__name__ for name in ("TagMismatch", "Duplicate", "TooOld")] == ["type"] * 3


def test_ac4_the_enum_members_are_the_documented_ones():
    # Act and Assert
    assert [m.name for m in packbin.FrameDirection] == ["UP", "DOWN", "GROUP"]
    assert [m.value for m in packbin.FrameDirection] == [1, 2, 3]
    assert issubclass(packbin.FrameDirections, enum.IntFlag)
    assert (packbin.FrameDirections.NONE, packbin.FrameDirections.ALL) == (0, 7)
    assert [m.name for m in packbin.FrameSlot] == ["CURRENT", "PREVIOUS"]
    assert [m.name for m in packbin.Freshness] == ["FRESH", "DUPLICATE", "TOO_OLD"]


def test_the_internal_frame_modules_are_not_public():
    # Act
    namespace: dict = {}
    exec("from packbin import *", namespace)

    # Assert
    assert not [name for name in namespace if name.startswith("_") and name != "__builtins__"]

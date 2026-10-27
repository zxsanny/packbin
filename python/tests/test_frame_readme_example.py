from __future__ import annotations

# The code the README shows for frame mode in Python. The lines between the markers are copied into the README by the docs
# task and checked against it by `scripts/frame/readme-examples.sh`; this test keeps them running and correct.
# The example calls only what `from packbin import ...` brings.


def test_load_seal_open_with_a_window_and_the_mac_only_call():
    # README-BEGIN
    from packbin import (
        Duplicate, FrameConfig, FrameDirection, FrameDirections, FrameOpened, FrameSession, MacKey, MsgContext, ReplayWindow,
    )

    # A 32-byte key shared by the nodes, an epoch (0 to 0xFFFFFF) and a tag of 4, 8 or 16 bytes.
    key = bytes(32)  # use a random key from your key store
    config = FrameConfig(tag_len=4, directions=FrameDirections.UP | FrameDirections.DOWN)
    with FrameSession.load(key, 1, config) as node:  # a BadValue object instead of a session when an argument is out of range
        # msg_id: 8 bytes that are unique per (key, epoch, direction) for every message ever sealed.
        message = MsgContext(bytes([0, 0x30, 0x10, 0x05, 0xE8, 3, 0, 0]), kind=4)
        header = bytes([0, 1, 0, 0x30, 0x10, 0x05, 0xE8, 3, 0, 0, 4])  # authenticated, not sent

        body = bytearray(255)
        length = node.seal(FrameDirection.UP, message, header, b"", b"hello, relay", body)
        # length is the body length (12 + 4 here), or BadValue, TooLong or BufferFull

        # The receiver keeps one ReplayWindow per sender and passes a counter that comes from authenticated bytes.
        window = ReplayWindow()
        plain = bytearray(255)
        opened = node.open(FrameDirection.UP, message, header, body[:length], 0, plain, window, counter=7)
        # opened is a FrameOpened (plain[:opened.plain_length] is the text, opened.slot says which key opened it),
        # or TagMismatch, Duplicate, TooOld, ShortPacket, TooLong, BufferFull or BadValue
        again = node.open(FrameDirection.UP, message, header, body[:length], 0, plain, window, counter=7)  # Duplicate

    # The MAC-only call: a 4-byte network check over a message given in parts.
    with MacKey.derive(key, 1, b"net") as network:
        tag = network.tag([bytes([1, 2, 3, 4]), body[:length]], 4)
        valid = network.verify([bytes([1, 2, 3, 4]), body[:length]], tag)
    # README-END

    assert length == 16
    assert isinstance(opened, FrameOpened)
    assert bytes(plain[: opened.plain_length]) == b"hello, relay"
    assert opened.slot.value == "current"
    assert isinstance(again, Duplicate)
    assert valid is True

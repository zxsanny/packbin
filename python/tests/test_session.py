from __future__ import annotations

import ctypes
from array import array

import pytest

from packbin import BinaryPacker, PackSession, Scheme, flags, i16, i32, u8, u16

CIPHERTEXT_HEX = "b55d0a29c56c203712b241232e"
POSITION_HEX = "4001000065cd1d00a3e1110100"
NONCE = bytes.fromhex("01000000000000000000000000000000")

POSITION = Scheme(
    0x40,
    dict,
    u16(0, lambda row: row["sid"]),
    i32(1, lambda row: row["lat"]),
    i32(2, lambda row: row["lon"]),
    u8(3, lambda row: row["profile"]),
    flags(
        4,
        u16(4, lambda row: row["heading"]),
        u8(5, lambda row: row["speed"]),
        i16(6, lambda row: row["altitude"]),
    ),
)

POSITION_VALUES = {
    "sid": 1,
    "lat": 500_000_000,
    "lon": 300_000_000,
    "profile": 1,
}


def _seed() -> bytes:
    return bytes(range(1, 33))


def _mismatched_bytes(actual: bytes, expected_hex: str) -> int:
    expected = bytes.fromhex(expected_hex)
    return sum(1 for a, b in zip(actual, expected, strict=False) if a != b) + abs(
        len(actual) - len(expected)
    )


def _field_mismatches(row) -> int:
    n = 0
    if row.get("sid") != 1:
        n += 1
    if row.get("lat") != 500_000_000:
        n += 1
    if row.get("lon") != 300_000_000:
        n += 1
    if row.get("profile") != 1:
        n += 1
    for name in ("heading", "speed", "altitude"):
        if name in row and row[name] is not None:
            n += 1
    return n


def test_ac1_ciphertext_matches_csharp():
    opener = PackSession.load(_seed())
    assert opener is not None
    nonce = opener.start(NONCE)
    assert nonce == NONCE
    payload = opener.pack(POSITION, POSITION_VALUES)
    assert payload is not None
    assert len(payload) == 13
    assert payload.hex() == CIPHERTEXT_HEX
    assert _mismatched_bytes(payload, CIPHERTEXT_HEX) == 0


def test_ac2_waiter_recovers_row():
    opener = PackSession.load(_seed())
    waiter = PackSession.load(_seed())
    assert opener is not None
    assert waiter is not None
    assert opener.start(NONCE) == NONCE
    assert waiter.join(NONCE) is True
    payload = opener.pack(POSITION, POSITION_VALUES)
    assert payload is not None
    got = waiter.unpack(payload, POSITION.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert _field_mismatches(got.value) == 0


def test_ac3_clear_pack_unchanged():
    raw = BinaryPacker.pack(POSITION, POSITION_VALUES)
    assert raw.hex() == POSITION_HEX
    assert _mismatched_bytes(raw, POSITION_HEX) == 0


def test_ac4_bad_lengths_create_nothing():
    created = 0
    if PackSession.load(bytes(31)) is not None:
        created += 1
    if PackSession.load(bytes(33)) is not None:
        created += 1
    loaded = PackSession.load(_seed())
    assert loaded is not None
    if loaded.join(bytes(15)):
        created += 1
    if loaded.join(bytes(17)):
        created += 1
    if loaded.start(bytes(15)) is not None:
        created += 1
    assert created == 0
    assert loaded.pack(POSITION, POSITION_VALUES) is None


WRONG_SEED_SIZES = [0, 3, 31, 33]


@pytest.mark.parametrize("size", WRONG_SEED_SIZES)
def test_constructor_rejects_wrong_seed_length(size: int):
    with pytest.raises(ValueError, match="32 bytes"):
        PackSession(bytes(size))


@pytest.mark.parametrize("size", WRONG_SEED_SIZES)
def test_load_returns_none_for_a_wrong_seed_length(size: int):
    assert PackSession.load(bytes(size)) is None


def test_load_and_constructor_open_the_same_session_for_a_32_byte_seed():
    loaded = PackSession.load(_seed())
    built = PackSession(_seed())

    assert loaded is not None
    assert loaded.start(NONCE) == built.start(NONCE) == NONCE
    assert loaded.pack(POSITION, POSITION_VALUES) == built.pack(POSITION, POSITION_VALUES)


def test_ac1_load_of_an_integer_returns_none():
    assert PackSession.load(32) is None  # type: ignore[arg-type]


WRONG_SEEDS = {
    "33": 33,
    "0": 0,
    "true": True,
    "bytes_31": bytes(31),
    "bytes_33": bytes(33),
    "empty_bytes": b"",
    "empty_memoryview": memoryview(b""),
}


@pytest.mark.parametrize("seed", WRONG_SEEDS.values(), ids=WRONG_SEEDS.keys())
def test_ac2_wrong_sizes_and_values_still_return_none(seed):
    assert PackSession.load(seed) is None


NOT_BYTES_LIKE = {
    "str": "a" * 32,
    "none": None,
    "float": 32.0,
    "list": [7] * 32,
    "tuple": tuple(range(32)),
    "range": range(32),
    "array_B": array("B", range(32)),
}


@pytest.mark.parametrize("seed", NOT_BYTES_LIKE.values(), ids=NOT_BYTES_LIKE.keys())
def test_ac3_anything_not_bytes_like_returns_none_and_raises_nothing(seed):
    assert PackSession.load(seed) is None


class _SeedBytes(bytes):
    pass


BYTES_LIKE_SEEDS = {
    "bytes": bytes(range(1, 33)),
    "bytearray": bytearray(range(1, 33)),
    "memoryview": memoryview(bytes(range(1, 33))),
    "strided_memoryview": memoryview(bytes(64))[::2],
    "memoryview_of_32_bit_items": memoryview(array("I", range(8))),
    "bytes_subclass": _SeedBytes(range(1, 33)),
}


@pytest.mark.parametrize("seed", BYTES_LIKE_SEEDS.values(), ids=BYTES_LIKE_SEEDS.keys())
def test_ac4_a_bytes_like_seed_of_32_bytes_opens_a_session(seed):
    assert PackSession.load(seed) is not None


def test_ac4_the_bytes_seed_packs_the_csharp_vector():
    opener = PackSession.load(bytes(range(1, 33)))

    assert opener is not None
    assert opener.start(NONCE) == NONCE
    assert opener.pack(POSITION, POSITION_VALUES).hex() == CIPHERTEXT_HEX


def test_ac5_the_constructor_keeps_its_errors():
    with pytest.raises(TypeError):
        PackSession(32)  # type: ignore[arg-type]
    with pytest.raises(ValueError, match="^seed must be 32 bytes, got 31$"):
        PackSession(bytes(31))


def test_ac3_a_released_memoryview_returns_none_and_raises_nothing():
    released = memoryview(bytes(32))
    released.release()

    assert PackSession.load(released) is None


A_SCHEME = Scheme(1, dict, u8(0, lambda row: row["a"]))


class _NonceBytes(bytes):
    pass


class _NonceBytearray(bytearray):
    pass


class _HasBytes:
    """Not a bytes type: its `__bytes__` must never be called."""

    def __bytes__(self) -> bytes:
        return bytes(range(1, 17))


class _RaisingBytes:
    def __bytes__(self) -> bytes:
        raise RuntimeError("__bytes__ must not be called")


class _HostileObject(_RaisingBytes):
    def __len__(self) -> int:
        raise RuntimeError("__len__ must not be called")


def _released() -> memoryview:
    view = memoryview(bytes(16))
    view.release()
    return view


NOT_A_NONCE = {
    "int_16": 16,
    "int_15": 15,
    "int_0": 0,
    "true": True,
    "list": [1] * 16,
    "tuple": tuple(range(16)),
    "range": range(16),
    "str": "a" * 16,
    "float": 16.0,
    "array_B": array("B", range(16)),
    "ctypes": (ctypes.c_ubyte * 16)(*range(1, 17)),
    "object": object(),
    "dunder_bytes": _HasBytes(),
}


def _opener() -> PackSession:
    session = PackSession.load(_seed())
    assert session is not None
    return session


@pytest.mark.parametrize("nonce", NOT_A_NONCE.values(), ids=NOT_A_NONCE.keys())
def test_az2244_ac1_start_refuses_a_nonce_that_is_not_bytes_like(nonce):
    session = _opener()

    assert session.start(nonce) is None
    assert session.pack(A_SCHEME, {"a": 5}) is None


@pytest.mark.parametrize("nonce", [*NOT_A_NONCE.values(), None], ids=[*NOT_A_NONCE.keys(), "none"])
def test_az2244_ac2_join_refuses_a_nonce_that_is_not_bytes_like(nonce):
    session = _opener()

    assert session.join(nonce) is False
    assert session.unpack(bytes.fromhex("f459"), A_SCHEME.on(lambda row: None)).ok is False


def test_az2244_ac3_a_refused_start_leaves_the_session_closed_and_usable():
    session = _opener()

    refused = session.start(16)
    started = session.start(NONCE)

    assert (refused, started) == (None, NONCE)
    assert session.pack(A_SCHEME, {"a": 5}).hex() == "f459"


def test_az2244_ac3_a_refused_join_leaves_the_session_closed_and_usable():
    opener = _opener()
    waiter = _opener()
    refused = waiter.join(16)
    assert opener.start(NONCE) == NONCE
    received = []

    joined = waiter.join(NONCE)
    got = waiter.unpack(opener.pack(A_SCHEME, {"a": 6}), A_SCHEME.on(received.append))

    assert (refused, joined, got.ok, received) == (False, True, True, [{"a": 6}])


@pytest.mark.parametrize("draw", [lambda s: s.start(), lambda s: s.start(None)], ids=["no_argument", "none"])
def test_az2244_ac4_start_without_a_nonce_still_draws_one(draw):
    session = _opener()

    drawn = draw(session)

    assert (type(drawn), len(drawn)) == (bytes, 16)
    assert session.pack(A_SCHEME, {"a": 5}) is not None


NONCE_1_TO_16 = bytes(range(1, 17))
BYTES_LIKE_NONCES = {
    "bytes": (bytes(16), bytes(16)),
    "bytearray": (bytearray(NONCE_1_TO_16), NONCE_1_TO_16),
    "memoryview": (memoryview(NONCE_1_TO_16), NONCE_1_TO_16),
    "strided_memoryview": (memoryview(bytes(32))[::2], bytes(16)),
    "memoryview_of_32_bit_items": (memoryview(array("I", range(4))), bytes.fromhex("00000000010000000200000003000000")),
    "two_dimensional_memoryview": (memoryview(bytes(16)).cast("B", shape=[4, 4]), bytes(16)),
    "bytes_subclass": (_NonceBytes(NONCE_1_TO_16), NONCE_1_TO_16),
}


@pytest.mark.parametrize("nonce,expected", BYTES_LIKE_NONCES.values(), ids=BYTES_LIKE_NONCES.keys())
def test_az2244_ac5_a_bytes_like_nonce_of_16_bytes_opens_the_session_with_those_bytes(nonce, expected):
    opener = _opener()
    waiter = _opener()
    reference = _opener()
    reference.start(expected)

    started = opener.start(nonce)
    joined = waiter.join(nonce)

    assert (started, joined) == (expected, True)
    assert opener.pack(A_SCHEME, {"a": 5}) == reference.pack(A_SCHEME, {"a": 5})


def test_az2244_ac5_packets_under_known_nonces_are_unchanged():
    zero, ones = _opener(), _opener()
    zero.start(bytes(16))
    ones.start(bytes([1] * 16))

    assert (zero.pack(A_SCHEME, {"a": 5}).hex(), ones.pack(A_SCHEME, {"a": 5}).hex()) == ("518d", "d9b9")


WRONG_LENGTH_NONCES = {
    "bytes_15": bytes(15),
    "bytes_17": bytes(17),
    "empty_bytes": b"",
    "empty_memoryview": memoryview(b""),
    "memoryview_64_bytes_in_16_items": memoryview(array("I", range(16))),
    "zero_dimensional_memoryview": memoryview(b"\x07").cast("B", shape=[]),
}


@pytest.mark.parametrize("nonce", WRONG_LENGTH_NONCES.values(), ids=WRONG_LENGTH_NONCES.keys())
def test_az2244_ac6_a_wrong_length_is_refused_by_start_and_join(nonce):
    assert (_opener().start(nonce), _opener().join(nonce)) == (None, False)


HOSTILE_NONCES = {
    "released_memoryview": _released,
    "dunder_bytes_that_raises": _RaisingBytes,
    "raising_len_and_dunder_bytes": _HostileObject,
}


@pytest.mark.parametrize("make", HOSTILE_NONCES.values(), ids=HOSTILE_NONCES.keys())
def test_az2244_ac7_a_released_view_and_a_hostile_object_are_refused_not_raised(make):
    assert (_opener().start(make()), _opener().join(make())) == (None, False)


def _with_size(size: int, kind: str):
    if kind == "released":
        view = memoryview(bytes(size))
        view.release()
        return view
    if kind == "plain_object":
        return _HostileObject()
    return {
        "bytes_subclass": lambda: _NonceBytes(range(1, size + 1)),
        "two_dimensional": lambda: memoryview(bytes(size)).cast("B", shape=[4, size // 4]),
        "zero_dimensional": lambda: memoryview(b"\x07").cast("B", shape=[]),
        "four_byte_items": lambda: memoryview(array("I", range(size // 4))),
        "strided": lambda: memoryview(bytes(size * 2))[::2],
        "read_only": lambda: memoryview(bytes(size)).toreadonly(),
        "bytearray_view": lambda: memoryview(bytearray(size)),
    }[kind]()


SHAPES = ["released", "plain_object", "bytes_subclass", "two_dimensional", "zero_dimensional", "four_byte_items", "strided", "read_only", "bytearray_view"]


@pytest.mark.parametrize("kind", SHAPES)
def test_az2244_ac8_load_start_and_join_agree(kind):
    loaded = PackSession.load(_with_size(32, kind)) is not None
    started = _opener().start(_with_size(16, kind)) is not None
    joined = _opener().join(_with_size(16, kind))

    assert loaded is started is joined


@pytest.mark.parametrize("base", [_NonceBytes, _NonceBytearray], ids=["bytes", "bytearray"])
def test_az2244_ac8_a_subclass_whose_dunder_bytes_raises_raises_in_all_three(base):
    class Sub(base):
        def __bytes__(self):
            raise RuntimeError("held")

    for call in (PackSession.load, _opener().start, _opener().join):
        with pytest.raises(RuntimeError, match="held"):
            call(Sub(bytes(32)))


@pytest.mark.parametrize("base", [_NonceBytes, _NonceBytearray], ids=["bytes", "bytearray"])
def test_az2244_ac8_a_subclass_whose_dunder_bytes_gives_another_length_is_refused_in_all_three(base):
    class Sub(base):
        def __bytes__(self):
            return bytes(3)

    value = Sub(bytes(32))

    assert (PackSession.load(value), _opener().start(value), _opener().join(value)) == (None, None, False)


@pytest.mark.parametrize("base", [_NonceBytes, _NonceBytearray], ids=["bytes", "bytearray"])
def test_az2244_ac8_a_subclass_whose_dunder_bytes_gives_other_bytes_opens_on_those_bytes(base):
    def holding_zeros_giving(given: bytes):
        class Sub(base):
            def __bytes__(self):
                return given

        return Sub(bytes(len(given)))

    seed = holding_zeros_giving(bytes(range(1, 33)))
    nonce = holding_zeros_giving(NONCE_1_TO_16)

    assert PackSession.load(seed).start(nonce) == NONCE_1_TO_16
    assert _opener().join(nonce) is True


def test_az2244_ac9_an_open_session_refuses_a_second_start_or_join():
    session = _opener()
    session.start(NONCE)

    assert (session.start(16), session.join(16), session.join(NONCE), session.start(NONCE)) == (None, False, False, None)

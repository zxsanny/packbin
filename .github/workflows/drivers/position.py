from packbin import BinaryPacker, Scheme, flags, i16, i32, u8, u16

raw = BinaryPacker.pack(
    Scheme(
        0x40,
        dict,
        u16(0, lambda row: row["sid"]),
        i32(1, lambda row: row["lat"]),
        i32(2, lambda row: row["lon"]),
        u8(3, lambda row: row["profile"]),
        flags(
            u16(4, lambda row: row["heading"]),
            u8(5, lambda row: row["speed"]),
            i16(6, lambda row: row["altitude"]),
        ),
    ),
    {
        "sid": 1,
        "lat": 500_000_000,
        "lon": 300_000_000,
        "profile": 1,
    },
)
print(raw.hex())

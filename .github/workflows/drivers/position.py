from packbin import BinaryPacker, Scheme, flags, i16, i32, u8, u16

def gs(key):
    return (lambda r, k=key: r.get(k), lambda r, v, k=key: r.__setitem__(k, v))

raw = BinaryPacker.pack(
    Scheme(
        0x40,
        dict,
        u16(0, *gs("sid")),
        i32(1, *gs("lat")),
        i32(2, *gs("lon")),
        u8(3, *gs("profile")),
        flags(
            u16(4, *gs("heading")),
            u8(5, *gs("speed")),
            i16(6, *gs("altitude")),
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

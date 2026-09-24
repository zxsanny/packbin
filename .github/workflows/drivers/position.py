from packbin import Scheme, flags, i16, i32, pack, u8, u16

raw = pack(
    Scheme(
        0x40,
        dict,
        u16("sid"),
        i32("lat"),
        i32("lon"),
        u8("profile"),
        flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
    ),
    {
        "sid": 1,
        "lat": 500_000_000,
        "lon": 300_000_000,
        "profile": 1,
    },
)
print(raw.hex())

import { flags, i16, i32, pack, scheme, u16, u8 } from "../../../typescript/src/index.ts";

const bytes = pack(
  scheme(
    0x40,
    u16("sid"),
    i32("lat"),
    i32("lon"),
    u8("profile"),
    flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
  ),
  {
    sid: 1,
    lat: 500_000_000,
    lon: 300_000_000,
    profile: 1,
  },
);

console.log(Buffer.from(bytes).toString("hex"));

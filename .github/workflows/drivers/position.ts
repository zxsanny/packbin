import { flags, i16, i32, pack, packet, u16, u8 } from "../../../typescript/src/index.ts";

const bytes = pack(
  packet([
    u8("type"),
    u16("sid"),
    i32("lat"),
    i32("lon"),
    u8("profile"),
    flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
  ]),
  {
    type: 0x40,
    sid: 1,
    lat: 500_000_000,
    lon: 300_000_000,
    profile: 1,
  },
);

console.log(Buffer.from(bytes).toString("hex"));

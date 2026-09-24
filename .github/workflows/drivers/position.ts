import { BinaryPacker, flags, i16, i32, scheme, u16, u8 } from "../../../typescript/src/index.ts";

type Position = {
  sid: number;
  lat: number;
  lon: number;
  profile: number;
  heading?: number;
  speed?: number;
  altitude?: number;
};

const bytes = BinaryPacker.pack(
  scheme<Position>(
    0x40,
    u16(0, (r) => r.sid),
    i32(1, (r) => r.lat),
    i32(2, (r) => r.lon),
    u8(3, (r) => r.profile),
    flags([
      u16(4, (r) => r.heading),
      u8(5, (r) => r.speed),
      i16(6, (r) => r.altitude),
    ]),
  ),
  {
    sid: 1,
    lat: 500_000_000,
    lon: 300_000_000,
    profile: 1,
  },
);

console.log(Buffer.from(bytes).toString("hex"));

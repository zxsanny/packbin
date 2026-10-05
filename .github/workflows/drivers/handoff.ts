import {
  BinaryPacker,
  PackSession,
  bool,
  dict,
  flags,
  i16,
  i32,
  list,
  scheme,
  u8,
  u16,
  utf8,
} from "../../../typescript/src/index.ts";

type UserRow = {
  username: string;
  roles: string[];
  access: Record<string, string[]>;
};

type NestedRow = {
  access: Record<string, Record<string, string>[]>;
};

const userPacket = scheme<UserRow>(
  1,
  utf8(0, (r) => r.username),
  list(
    (r) => r.roles,
    utf8(0, (s) => s),
  ),
  dict(
    (r) => r.access,
    list(
      (a) => a,
      utf8(0, (s) => s),
    ),
  ),
);

const nestedPacket = scheme<NestedRow>(
  1,
  dict(
    (r) => r.access,
    list(
      (rows) => rows,
      dict(
        (row) => row,
        utf8(0, (s) => s),
      ),
    ),
  ),
);

type BoolFlagRow = { on?: boolean };

// flags { bool on } with on = false: the bit is set only for true, so it packs 0100.
const boolFlagPacket = scheme<BoolFlagRow>(1, flags(0, [bool(0, (r) => r.on)]));

const boolFlagValues: BoolFlagRow = { on: false };

// The same scheme with on = true sets the bit: 0101.
const boolTrueValues: BoolFlagRow = { on: true };

function unpackBoolFlag(cmdName: string, hex: string): BoolFlagRow {
  let row: BoolFlagRow | undefined;
  const result = BinaryPacker.unpack(Buffer.from(hex, "hex"), boolFlagPacket.on((value) => {
    row = value as BoolFlagRow;
  }));
  if (!result.ok || row === undefined) {
    process.stderr.write(`${cmdName}: ${JSON.stringify(result)}\n`);
    process.exit(1);
  }
  return row;
}

const userValues: UserRow = {
  username: "zxsanny",
  roles: ["user", "dispatcher"],
  access: {
    channel: ["read"],
    map: ["read", "gps_fix", "set", "edit"],
    store: ["read", "write"],
  },
};

const nestedValues: NestedRow = {
  access: {
    map: [{ op: "gps_fix" }],
    store: [{ op: "read" }, { op: "write" }],
  },
};

type PositionRow = {
  sid: number;
  lat: number;
  lon: number;
  profile: number;
  heading?: number | null;
  speed?: number | null;
  altitude?: number | null;
};

const positionPacket = scheme<PositionRow>(
  0x40,
  u16(0, (r) => r.sid),
  i32(1, (r) => r.lat),
  i32(2, (r) => r.lon),
  u8(3, (r) => r.profile),
  flags(4, [
    u16(4, (r) => r.heading),
    u8(5, (r) => r.speed),
    i16(6, (r) => r.altitude),
  ]),
);

const positionValues: PositionRow = {
  sid: 1,
  lat: 500_000_000,
  lon: 300_000_000,
  profile: 1,
};

const sessionSeed = Uint8Array.from({ length: 32 }, (_, i) => i + 1);
const sessionNonce = Buffer.from("01000000000000000000000000000000", "hex");

function deepEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (!deepEqual(a[i], b[i])) return false;
    }
    return true;
  }
  if (
    a !== null &&
    b !== null &&
    typeof a === "object" &&
    typeof b === "object" &&
    !Array.isArray(a) &&
    !Array.isArray(b)
  ) {
    const ao = a as Record<string, unknown>;
    const bo = b as Record<string, unknown>;
    const ak = Object.keys(ao).sort();
    const bk = Object.keys(bo).sort();
    if (ak.length !== bk.length) return false;
    for (let i = 0; i < ak.length; i++) {
      if (ak[i] !== bk[i]) return false;
      if (!deepEqual(ao[ak[i]!], bo[bk[i]!])) return false;
    }
    return true;
  }
  return false;
}

const cmd = process.argv[2];

if (cmd === "pack-user") {
  const bytes = BinaryPacker.pack(userPacket, userValues);
  process.stdout.write(Buffer.from(bytes).toString("hex") + "\n");
  process.exit(0);
}

if (cmd === "pack-nested") {
  const bytes = BinaryPacker.pack(nestedPacket, nestedValues);
  process.stdout.write(Buffer.from(bytes).toString("hex") + "\n");
  process.exit(0);
}

if (cmd === "pack-boolflag") {
  const bytes = BinaryPacker.pack(boolFlagPacket, boolFlagValues);
  process.stdout.write(Buffer.from(bytes).toString("hex") + "\n");
  process.exit(0);
}

if (cmd === "pack-booltrue") {
  const bytes = BinaryPacker.pack(boolFlagPacket, boolTrueValues);
  process.stdout.write(Buffer.from(bytes).toString("hex") + "\n");
  process.exit(0);
}

if (cmd === "unpack-user") {
  const hex = process.argv[3] ?? "";
  const bytes = Buffer.from(hex, "hex");
  let row: UserRow | undefined;
  const result = BinaryPacker.unpack(bytes, userPacket.on((value) => {
    row = value as UserRow;
  }));
  if (result.ok && row !== undefined && deepEqual(row, userValues)) process.exit(0);
  process.exit(1);
}

if (cmd === "unpack-nested") {
  const hex = process.argv[3] ?? "";
  const bytes = Buffer.from(hex, "hex");
  let row: NestedRow | undefined;
  const result = BinaryPacker.unpack(bytes, nestedPacket.on((value) => {
    row = value as NestedRow;
  }));
  if (result.ok && row !== undefined && deepEqual(row, nestedValues)) process.exit(0);
  process.exit(1);
}

if (cmd === "unpack-boolflag") {
  const row = unpackBoolFlag(cmd, process.argv[3] ?? "");
  if (row.on === true) {
    process.stderr.write("unpack-boolflag: on is true, expected absent or false\n");
    process.exit(1);
  }
  process.exit(0);
}

if (cmd === "unpack-booltrue") {
  const row = unpackBoolFlag(cmd, process.argv[3] ?? "");
  if (row.on !== true) {
    process.stderr.write(`unpack-booltrue: on is ${String(row.on)}, expected true\n`);
    process.exit(1);
  }
  process.exit(0);
}

if (cmd === "pack-session") {
  const opener = PackSession.load(sessionSeed);
  if (!opener || !opener.start(sessionNonce)) process.exit(1);
  const payload = opener.pack(positionPacket, positionValues);
  if (!payload) process.exit(1);
  process.stdout.write(Buffer.from(payload).toString("hex") + "\n");
  process.exit(0);
}

if (cmd === "unpack-session") {
  const hex = process.argv[3] ?? "";
  const waiter = PackSession.load(sessionSeed);
  if (!waiter || !waiter.join(sessionNonce)) process.exit(1);
  let row: PositionRow | undefined;
  const result = waiter.unpack(Buffer.from(hex, "hex"), positionPacket.on((value) => {
    row = value as PositionRow;
  }));
  if (
    result.ok &&
    row !== undefined &&
    row.sid === 1 &&
    row.lat === 500_000_000 &&
    row.lon === 300_000_000 &&
    row.profile === 1 &&
    (row.heading === undefined || row.heading === null) &&
    (row.speed === undefined || row.speed === null) &&
    (row.altitude === undefined || row.altitude === null)
  ) {
    process.exit(0);
  }
  process.exit(1);
}

process.exit(2);

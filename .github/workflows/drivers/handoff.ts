import {
  BinaryPacker,
  type Field,
  PackSession,
  Scheme,
  bool,
  dict,
  eq,
  flagByte,
  flags,
  group,
  i16,
  i32,
  list,
  repeat,
  scheme,
  u8,
  u16,
  utf8,
  when,
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

type BitWhenRow = { k: number; v?: number };

// A split bit inside a when that is not taken: the bit comes from the row (01), the when is
// tested first on unpack, so v is never read. {k:0, v:5} packs 010001.
const bitWhenFlag = flagByte("m");
const bitWhenPacket = scheme<BitWhenRow>(
  1,
  u8(0, (r) => r.k),
  bitWhenFlag,
  when(1, eq(0, 1), [bitWhenFlag.bit(u8(1, (r) => r.v))]),
);

const bitWhenValues: BitWhenRow = { k: 0, v: 5 };

type Point = { a?: number; b?: number };

const pointFields = (): Field[] => [u8(0, (p: Point) => p.a), u8(1, (p: Point) => p.b)];

// A list of group, a dict of group and a list of flags (AZ-2102, AZ-2239). An absent value is a
// clear flag bit, so the flags item {b: 2} packs its flag byte as 02.
const elementCases: Record<string, { packet: Scheme<Record<string, unknown>>; values: Record<string, unknown> }> = {
  listgroup: {
    packet: scheme(1, list((r: { pts: Point[] }) => r.pts, group((e: { p: Point }) => e.p, pointFields()))),
    values: { pts: [{ a: 1, b: 2 }, { a: 3, b: 4 }] },
  },
  dictgroup: {
    packet: scheme(1, dict((r: { m: Record<string, Point> }) => r.m, group((e: { p: Point }) => e.p, pointFields()))),
    values: { m: { y: { a: 3, b: 4 }, x: { a: 1, b: 2 } } },
  },
  listflags: {
    packet: scheme(
      1,
      list((r: { pts: Point[] }) => r.pts, flags(0, [u8(0, (p: Point) => p.a), u16(1, (p: Point) => p.b)])),
    ),
    values: { pts: [{ a: 1 }, {}, { b: 2 }] },
  },
};

type RoundRow = Record<string, unknown>;

// Aligned rounds: one list entry per round. A bool whose bit is clear and a when that is not
// taken leave the entry absent (undefined).
const roundFlagsPacket = scheme<RoundRow>(
  1,
  repeat(0, [flags(0, [bool(0, (r) => r.on), u8(1, (r) => r.n)])]),
);

const roundFlagsValues: RoundRow = { on: [true, false, true], n: [1, 2, 3] };

const roundWhenPacket = scheme<RoundRow>(
  1,
  repeat(0, [u8(0, (r) => r.k), when(1, eq(0, 1), [u8(1, (r) => r.v)])]),
);

const roundWhenValues: RoundRow = { k: [1, 2], v: [9] };

function unpackRound(cmdName: string, hex: string, packet: Scheme<RoundRow>): RoundRow {
  let row: RoundRow | undefined;
  const result = BinaryPacker.unpack(Buffer.from(hex, "hex"), packet.on((value) => {
    row = value as RoundRow;
  }));
  if (!result.ok || row === undefined) {
    process.stderr.write(`${cmdName}: ${JSON.stringify(result)}\n`);
    process.exit(1);
  }
  return row;
}

function checkRound(
  cmdName: string,
  hex: string,
  packet: Scheme<RoundRow>,
  expected: RoundRow,
): void {
  const row = unpackRound(cmdName, hex, packet);
  if (!deepEqual(row, expected)) {
    process.stderr.write(`${cmdName}: read ${JSON.stringify(row)}, expected ${JSON.stringify(expected)}\n`);
    process.exit(1);
  }
  const again = Buffer.from(BinaryPacker.pack(packet, row)).toString("hex");
  if (again !== hex) {
    process.stderr.write(`${cmdName}: repacked ${again}, expected ${hex}\n`);
    process.exit(1);
  }
  process.exit(0);
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

if (cmd === "pack-bitwhen") {
  const bytes = BinaryPacker.pack(bitWhenPacket, bitWhenValues);
  process.stdout.write(Buffer.from(bytes).toString("hex") + "\n");
  process.exit(0);
}

if (cmd === "pack-roundflags") {
  const bytes = BinaryPacker.pack(roundFlagsPacket, roundFlagsValues);
  process.stdout.write(Buffer.from(bytes).toString("hex") + "\n");
  process.exit(0);
}

if (cmd === "pack-roundwhen") {
  const bytes = BinaryPacker.pack(roundWhenPacket, roundWhenValues);
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

if (cmd === "unpack-bitwhen") {
  const bytes = Buffer.from(process.argv[3] ?? "", "hex");
  let row: BitWhenRow | undefined;
  const result = BinaryPacker.unpack(bytes, bitWhenPacket.on((value) => {
    row = value as BitWhenRow;
  }));
  if (!result.ok || row === undefined) {
    process.stderr.write(`unpack-bitwhen: ${JSON.stringify(result)}\n`);
    process.exit(1);
  }
  if (row.k !== 0 || "v" in row) {
    process.stderr.write(
      `unpack-bitwhen: k is ${String(row.k)}, v is ${String(row.v)}; expected k 0, no v\n`,
    );
    process.exit(1);
  }
  process.exit(0);
}

if (cmd === "unpack-roundflags") {
  checkRound(
    cmd,
    process.argv[3] ?? "",
    roundFlagsPacket,
    { on: [true, undefined, true], n: [1, 2, 3] },
  );
}

if (cmd === "unpack-roundwhen") {
  checkRound(
    cmd,
    process.argv[3] ?? "",
    roundWhenPacket,
    { k: [1, 2], v: [9, undefined] },
  );
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

for (const [kind, { packet, values }] of Object.entries(elementCases)) {
  if (cmd === `pack-${kind}`) {
    process.stdout.write(Buffer.from(BinaryPacker.pack(packet, values)).toString("hex") + "\n");
    process.exit(0);
  }
  if (cmd === `unpack-${kind}` || cmd === `unpack-${kind}-short`) {
    const hex = process.argv[3];
    if (!hex) process.exit(2);
    let row: Record<string, unknown> | undefined;
    const result = BinaryPacker.unpack(Buffer.from(hex, "hex"), packet.on((value) => {
      row = value as Record<string, unknown>;
    }));
    if (cmd === `unpack-${kind}-short`) {
      // A short element is refused and no row reaches the handler.
      if (!result.ok && row === undefined) process.exit(0);
      process.stderr.write(`${cmd}: read ${JSON.stringify(result)} ${JSON.stringify(row)}, expected a refusal\n`);
      process.exit(1);
    }
    if (!result.ok || row === undefined || !deepEqual(row, values)) {
      process.stderr.write(`${cmd}: ${JSON.stringify(result)} read ${JSON.stringify(row)}, expected ${JSON.stringify(values)}\n`);
      process.exit(1);
    }
    process.exit(0);
  }
}

process.exit(2);

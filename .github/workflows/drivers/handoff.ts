import { BinaryPacker, dict, list, scheme, utf8 } from "../../../typescript/src/index.ts";

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

process.exit(2);

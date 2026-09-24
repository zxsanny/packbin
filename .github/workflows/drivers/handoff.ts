import { dict, list, pack, scheme, unpack, utf8 } from "../../../typescript/src/index.ts";

const userPacket = scheme(
  1,
  utf8("username"),
  list("roles", utf8("role")),
  dict("access", list("actions", utf8("action"))),
);

const nestedPacket = scheme(
  1,
  dict("access", list("rows", dict("fields", utf8("value")))),
);

const userValues = {
  username: "zxsanny",
  roles: ["user", "dispatcher"],
  access: {
    channel: ["read"],
    map: ["read", "gps_fix", "set", "edit"],
    store: ["read", "write"],
  },
};

const nestedValues = {
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

function fieldsMatch(result: { ok: true; value: object }, expected: object): boolean {
  return deepEqual(result.value, expected);
}

const cmd = process.argv[2];

if (cmd === "pack-user") {
  const bytes = pack(userPacket, userValues);
  process.stdout.write(Buffer.from(bytes).toString("hex") + "\n");
  process.exit(0);
}

if (cmd === "pack-nested") {
  const bytes = pack(nestedPacket, nestedValues);
  process.stdout.write(Buffer.from(bytes).toString("hex") + "\n");
  process.exit(0);
}

if (cmd === "unpack-user") {
  const hex = process.argv[3] ?? "";
  const bytes = Buffer.from(hex, "hex");
  const result = unpack(userPacket, bytes);
  if (result.ok && fieldsMatch(result, userValues)) process.exit(0);
  process.exit(1);
}

if (cmd === "unpack-nested") {
  const hex = process.argv[3] ?? "";
  const bytes = Buffer.from(hex, "hex");
  const result = unpack(nestedPacket, bytes);
  if (result.ok && fieldsMatch(result, nestedValues)) process.exit(0);
  process.exit(1);
}

process.exit(2);

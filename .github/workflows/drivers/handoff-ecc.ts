// The message ECC commands of handoff.ts (AZ-2689; contract message-ecc.md).
//
//   ecc-protect <n> <clear hex>   prints the clear position message packed again with n parity bytes, or the error kind
//   ecc-repair <n> <t> <hex>      prints the position message repaired (hex, then the repaired count), or the error kind
//   ecc-batch <file>              one line per line of the file: `protect <n> <hex>` or `repair <n> <t> <hex>`
//
// "-" is the empty buffer. The kind names are the ones of fixtures/ecc/vectors.txt (uncorrectable, short, too_long,
// bad_parity, bad_limit) plus trailing, type_mismatch and unpack_failed for the walk of the unprotected fields.
import { readFileSync } from "node:fs";
import { BinaryPacker, type Scheme, type SchemeHandler } from "../../../typescript/src/index.ts";

const bytesOf = (token: string): Uint8Array => new Uint8Array(Buffer.from(token === "-" ? "" : token, "hex"));
const hexOf = (b: Uint8Array): string => Buffer.from(b).toString("hex");

function kindOf(result: Record<string, unknown>): string {
  if (result.kind === "uncorrectable" || result.kind === "too_long") return String(result.kind);
  if ("field" in result) {
    if (result.field === "parity") return "short";
    return result.field === "" && result.needed === 0 ? "trailing" : "unpack_failed";
  }
  return "actual" in result ? "type_mismatch" : "unpack_failed";
}

function protect(position: Scheme<object>, n: number, clear: Uint8Array): string {
  let row: object | undefined;
  const read = BinaryPacker.unpack(clear, position.on((r) => (row = r)));
  if (!read.ok || row === undefined) return "unpack_failed";
  let protectedScheme: Scheme<object>;
  try {
    protectedScheme = position.withLimits({ parity: n });
  } catch (e) {
    if (e instanceof RangeError) return "bad_parity";
    throw e;
  }
  return hexOf(BinaryPacker.pack(protectedScheme, row));
}

function repair(position: Scheme<object>, n: number, t: number, received: Uint8Array): string {
  let protectedScheme: Scheme<object>;
  try {
    protectedScheme = position.withLimits({ parity: n });
  } catch (e) {
    if (e instanceof RangeError) return "bad_parity";
    throw e;
  }
  let row: object | undefined;
  let result;
  try {
    result = BinaryPacker.unpackRepair(received, t, protectedScheme.on((r) => (row = r)) as SchemeHandler<object>);
  } catch (e) {
    if (e instanceof RangeError) return "bad_limit";
    throw e;
  }
  if (!result.ok || row === undefined) return kindOf(result as Record<string, unknown>);
  return `${hexOf(BinaryPacker.pack(position, row))} ${result.repaired ?? 0}`;
}

function line(position: Scheme<object>, words: string[]): string {
  if (words[0] === "protect" && words.length === 3) return protect(position, Number(words[1]), bytesOf(words[2]!));
  if (words[0] === "repair" && words.length === 4) {
    return repair(position, Number(words[1]), Number(words[2]), bytesOf(words[3]!));
  }
  throw new Error(`ecc line: ${words.join(" ")}`);
}

// Returns the exit status; `position` is the unprotected position scheme of handoff.ts.
export function runEcc(cmd: string, argv: string[], position: Scheme<object>): number {
  if (cmd === "ecc-protect" && argv.length === 2) {
    console.log(line(position, ["protect", argv[0]!, argv[1]!]));
    return 0;
  }
  if (cmd === "ecc-repair" && argv.length === 3) {
    console.log(line(position, ["repair", argv[0]!, argv[1]!, argv[2]!]));
    return 0;
  }
  if (cmd === "ecc-batch" && argv.length === 1) {
    for (const text of readFileSync(argv[0]!, "utf8").split("\n")) {
      if (text.trim() !== "") console.log(line(position, text.trim().split(/\s+/)));
    }
    return 0;
  }
  return 2;
}

// The frame commands of handoff.ts (AZ-3338; contract pack-session 3.0.0, frame mode).
//
//   frame-batch <file>   one line per line of the file: seal, open, mac, verify
import { readFileSync } from "node:fs";
import {
  FrameConfig,
  FrameOpened,
  FrameSession,
  MacKey,
  MsgContext,
} from "../../../typescript/src/index.ts";

// A token that is not hex (a bad digit, an odd length) or a missing field is an error of the line, never a zero or a cut.
const bytesOf = (token: string | undefined): Uint8Array => {
  if (token === undefined || !/^([0-9a-fA-F]{2})*$|^-$/.test(token)) throw new Error(`bad hex: ${token}`);
  return new Uint8Array(token === "-" ? [] : Buffer.from(token, "hex"));
};

// A number is decimal digits only (no sign, space or `_`) and at most top, or the line is malformed.
const BYTE = 255, LENGTH = 65535, EPOCH = 4294967295;
const numberOf = (token: string | undefined, top: number): number => {
  if (token === undefined || !/^[0-9]+$/.test(token) || Number(token) > top) {
    throw new Error(`bad number: ${token} (digits of 0 to ${top})`);
  }
  return Number(token);
};

const hexOf = (b: Uint8Array): string =>
  b.length ? Buffer.from(b).toString("hex") : "-";

type FrameErr = { ok: false; kind: string };

function errKind(result: object): string {
  if ("kind" in result) return String((result as FrameErr).kind);
  if ("field" in result) return "short"; // the short-packet value of the package has a field, not a kind
  return "error";
}

const KIND_MAP: Record<string, string> = {
  bad_value: "BadValue",
  too_long: "TooLong",
  buffer_full: "BufferFull",
  short: "ShortPacket",
  tag_mismatch: "TagMismatch",
  duplicate: "Duplicate",
  too_old: "TooOld",
};

function mapKind(result: object): string {
  const raw = errKind(result);
  return KIND_MAP[raw] ?? raw;
}

// The optional trailing fields of a seal or open line: the directions loaded (digits 1 to 3) and the output buffer size.
function loaded(words: string[]): [number, number] {
  const digits = words[9] ?? "123";
  if (!/^[123]+$/.test(digits)) throw new Error(`bad dirs: ${digits}`);
  const size = words[10] === undefined ? 300 : numberOf(words[10], LENGTH);
  return [[...digits].reduce((mask, digit) => mask | (1 << (Number(digit) - 1)), 0), size];
}

function seal(words: string[]): string {
  const [key, epoch, d, tagLen] = [bytesOf(words[0]), numberOf(words[1], EPOCH), numberOf(words[2], BYTE), numberOf(words[3], BYTE)];
  const [msgId, kind, ad, clear, plain] = [bytesOf(words[4]), numberOf(words[5], BYTE), bytesOf(words[6]), bytesOf(words[7]), bytesOf(words[8])];
  const [directions, size] = loaded(words);
  const session = FrameSession.load(key, epoch, new FrameConfig(tagLen, directions));
  if (session === null) return "BadValue";
  const out = new Uint8Array(size);
  const result = session.seal(d, new MsgContext(msgId, kind), ad, clear, plain, out);
  if (!result.ok) return mapKind(result);
  return hexOf(out.subarray(0, result.length));
}

function open(words: string[]): string {
  const [key, epoch, d, tagLen] = [bytesOf(words[0]), numberOf(words[1], EPOCH), numberOf(words[2], BYTE), numberOf(words[3], BYTE)];
  const [msgId, kind, ad, clearLen, body] = [bytesOf(words[4]), numberOf(words[5], BYTE), bytesOf(words[6]), numberOf(words[7], LENGTH), bytesOf(words[8])];
  const [directions, size] = loaded(words);
  const session = FrameSession.load(key, epoch, new FrameConfig(tagLen, directions));
  if (session === null) return "BadValue";
  const out = new Uint8Array(size);
  const result = session.open(d, new MsgContext(msgId, kind), ad, body, clearLen, out);
  if (result instanceof FrameOpened || (result as { ok: boolean }).ok) {
    const opened = result as FrameOpened;
    return hexOf(out.subarray(0, opened.plainLength));
  }
  return mapKind(result as object);
}

function mac(words: string[]): string {
  const [key, epoch, label, n, message] = [bytesOf(words[0]), numberOf(words[1], EPOCH), bytesOf(words[2]), numberOf(words[3], BYTE), bytesOf(words[4])];
  const mk = MacKey.derive(key, epoch, label);
  if (mk === null) return "BadValue";
  const result = mk.tag([message], n);
  if (!result.ok) return mapKind(result);
  return hexOf(result.tag);
}

function verify(words: string[]): string {
  const [key, epoch, label, n, message, tag] = [bytesOf(words[0]), numberOf(words[1], EPOCH), bytesOf(words[2]), numberOf(words[3], BYTE), bytesOf(words[4]), bytesOf(words[5])];
  const mk = MacKey.derive(key, epoch, label);
  if (mk === null) return "BadValue";
  return mk.verify([message], tag) ? "valid" : "invalid";
}

function line(words: string[]): string {
  if (words[0] === "seal") return seal(words.slice(1));
  if (words[0] === "open") return open(words.slice(1));
  if (words[0] === "mac") return mac(words.slice(1));
  if (words[0] === "verify") return verify(words.slice(1));
  if (words[0] === "open-skip" || words[0] === "verify-skip") return "skip";
  throw new Error(`unknown word ${words[0]}`);
}

export function runFrame(cmd: string, argv: string[]): number {
  if (cmd === "frame-batch" && argv.length === 1) {
    const texts = readFileSync(argv[0]!, "utf8").split("\n");
    for (const [index, text] of texts.entries()) {
      if (text.trim() === "") continue;
      try {
        console.log(line(text.trim().split(/\s+/)));
      } catch (error) {
        console.error(`frame line ${index + 1}: ${(error as Error).message}`);
        return 1;
      }
    }
    return 0;
  }
  return 2;
}

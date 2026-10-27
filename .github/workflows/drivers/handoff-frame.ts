// The frame commands of handoff.ts (AZ-3338; contract pack-session 3.0.0, frame mode).
//
//   frame-batch <file>   one line per line of the file: seal, open, mac, verify
import { readFileSync } from "node:fs";
import {
  FrameConfig,
  FrameDirections,
  FrameOpened,
  FrameSession,
  MacKey,
  MsgContext,
} from "../../../typescript/src/index.ts";

const bytesOf = (token: string): Uint8Array =>
  new Uint8Array(token === "-" ? [] : Buffer.from(token, "hex"));

const hexOf = (b: Uint8Array): string =>
  b.length ? Buffer.from(b).toString("hex") : "-";

type FrameErr = { ok: false; kind: string };

function errKind(result: object): string {
  if ("kind" in result) return String((result as FrameErr).kind);
  return "error";
}

const KIND_MAP: Record<string, string> = {
  bad_value: "BadValue",
  too_long: "TooLong",
  buffer_full: "BufferFull",
  short: "ShortPacket",
  tag_mismatch: "TagMismatch",
};

function mapKind(result: object): string {
  const raw = errKind(result);
  return KIND_MAP[raw] ?? raw;
}

function seal(words: string[]): string {
  const [key, epoch, d, tagLen] = [bytesOf(words[0]!), Number(words[1]), Number(words[2]), Number(words[3])];
  const [msgId, kind, ad, clear, plain] = [bytesOf(words[4]!), Number(words[5]), bytesOf(words[6]!), bytesOf(words[7]!), bytesOf(words[8]!)];
  const session = FrameSession.load(key, epoch, new FrameConfig(tagLen, new FrameDirections(1 << (d - 1))));
  if (session === null) return "BadValue";
  const out = new Uint8Array(300);
  const result = session.seal(d, new MsgContext(msgId, kind), ad, clear, plain, out);
  if (!result.ok) return mapKind(result);
  return hexOf(out.subarray(0, result.length));
}

function open(words: string[]): string {
  const [key, epoch, d, tagLen] = [bytesOf(words[0]!), Number(words[1]), Number(words[2]), Number(words[3])];
  const [msgId, kind, ad, clearLen, body] = [bytesOf(words[4]!), Number(words[5]), bytesOf(words[6]!), Number(words[7]), bytesOf(words[8]!)];
  const session = FrameSession.load(key, epoch, new FrameConfig(tagLen, new FrameDirections(1 << (d - 1))));
  if (session === null) return "BadValue";
  const out = new Uint8Array(300);
  const result = session.open(d, new MsgContext(msgId, kind), ad, body, clearLen, out);
  if (result instanceof FrameOpened || (result as { ok: boolean }).ok) {
    const opened = result as FrameOpened;
    return hexOf(out.subarray(0, opened.plainLength));
  }
  return mapKind(result as object);
}

function mac(words: string[]): string {
  const [key, epoch, label, n, message] = [bytesOf(words[0]!), Number(words[1]), bytesOf(words[2]!), Number(words[3]), bytesOf(words[4]!)];
  const mk = MacKey.derive(key, epoch, label);
  if (mk === null) return "BadValue";
  const result = mk.tag([message], n);
  if (!result.ok) return mapKind(result);
  return hexOf(result.tag);
}

function verify(words: string[]): string {
  const [key, epoch, label, n, message, tag] = [bytesOf(words[0]!), Number(words[1]), bytesOf(words[2]!), Number(words[3]), bytesOf(words[4]!), bytesOf(words[5]!)];
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
  throw new Error(`frame line: ${words[0]}`);
}

export function runFrame(cmd: string, argv: string[]): number {
  if (cmd === "frame-batch" && argv.length === 1) {
    for (const text of readFileSync(argv[0]!, "utf8").split("\n")) {
      if (text.trim() !== "") console.log(line(text.trim().split(/\s+/)));
    }
    return 0;
  }
  return 2;
}

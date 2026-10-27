import { readFileSync } from "node:fs"
import {
  FrameConfig,
  FrameSession,
  MacKey,
  MsgContext,
  ReplayWindow,
  type FrameDirections,
} from "../../src/index.ts"
import { access } from "../../src/frame-access.ts"

// Replays the rows of fixtures/frame/vectors.txt through the public API (contract pack-session 3.0.0, frame mode).
// A row's input fields build the call, every output field of the row is compared with what the call gave.

export const SENTINEL = 0xa5
export const FIXTURE = new URL("../../../fixtures/frame/vectors.txt", import.meta.url)

export type Row = Map<string, string>

export function load(text: string): Row[] {
  const rows: Row[] = []
  for (const line of text.split("\n")) {
    if (line === "" || line.startsWith("#")) continue
    const row: Row = new Map()
    for (const token of line.split(" ")) {
      const at = token.indexOf("=")
      row.set(token.slice(0, at), token.slice(at + 1))
    }
    rows.push(row)
  }
  return rows
}

export const loadFixture = (): Row[] => load(readFileSync(FIXTURE, "utf8"))

export const caseOf = (row: Row): string => get(row, "case")
export const opOf = (row: Row): string => get(row, "op")

export function get(row: Row, name: string): string {
  const value = row.get(name)
  if (value === undefined) throw new Error(`${row.get("case")}: no ${name}=`)
  return value
}

export const hex = (bytes: Uint8Array): string => (bytes.length === 0 ? "-" : Buffer.from(bytes).toString("hex"))
export const unhex = (text: string): Uint8Array => (text === "-" ? new Uint8Array(0) : Uint8Array.from(Buffer.from(text, "hex")))
export const bytes = (row: Row, name: string): Uint8Array => unhex(get(row, name))
export const int = (row: Row, name: string): number => Number(get(row, name))

export function kindName(result: { ok: boolean }): string {
  if (result.ok) return "Ok"
  const names: Record<string, string> = {
    bad_value: "BadValue",
    too_long: "TooLong",
    buffer_full: "BufferFull",
    tag_mismatch: "TagMismatch",
    duplicate: "Duplicate",
    too_old: "TooOld",
  }
  const kind = (result as { kind?: string }).kind
  if (kind === undefined) return "field" in result ? "ShortPacket" : "other"
  return names[kind] ?? `other:${kind}`
}

export const windowText = (window: ReplayWindow): string => `${window.top.toString(16)}:${window.bits.toString(16)}`

export function directionsOf(row: Row): FrameDirections {
  let set = 0
  for (const c of row.get("dirs") ?? "123") set |= 1 << (c.charCodeAt(0) - "1".charCodeAt(0))
  return set
}

export const loadSession = (row: Row): FrameSession | null =>
  FrameSession.load(bytes(row, "key"), int(row, "epoch"), new FrameConfig(row.has("tag_len") ? int(row, "tag_len") : 4, directionsOf(row)))

export const contextOf = (row: Row): MsgContext => new MsgContext(bytes(row, "msg_id"), int(row, "kind"))

const OUTPUTS: Record<string, string[]> = {
  keys: ["k_enc", "k_mac", "k_label"],
  seal: ["body", "result"],
  open: ["result", "slot", "plain", "window_after"],
  mac: ["tag", "valid", "result"],
  replay: ["results", "states"],
}

// The output fields the call gave for the row; a row with an error result gives `result` only.
export function run(row: Row): Map<string, string> {
  switch (opOf(row)) {
    case "keys":
      return runKeys(row)
    case "seal":
      return runSeal(row)
    case "open":
      return runOpen(row)
    case "mac":
      return runMac(row)
    case "replay":
      return runReplay(row)
    default:
      throw new Error(`unknown op ${opOf(row)}`)
  }
}

// Every mismatch of every row, as "case field: expected X, got Y".
export function mismatches(rows: Iterable<Row>): string[] {
  const problems: string[] = []
  for (const row of rows) {
    const got = run(row)
    for (const name of OUTPUTS[opOf(row)] ?? []) {
      const expected = row.get(name)
      if (expected === undefined) continue
      const value = got.get(name)
      if (value === undefined) problems.push(`${caseOf(row)} ${name}: the row has it and the call gave none`)
      else if (value !== expected) problems.push(`${caseOf(row)} ${name}: expected ${expected}, got ${value}`)
    }
  }
  return problems
}

function runKeys(row: Row): Map<string, string> {
  const epoch = int(row, "epoch")
  if (row.has("label")) {
    const mac = MacKey.derive(bytes(row, "key"), epoch, bytes(row, "label"))
    return new Map([["k_label", mac === null ? "BadValue" : hex(access.macKeyBytes!(mac))]])
  }
  const dir = int(row, "dir")
  const session = FrameSession.load(bytes(row, "key"), epoch, new FrameConfig(4, 1 << (dir - 1)))
  if (session === null) return new Map([["k_enc", "BadValue"], ["k_mac", "BadValue"]])
  const keys = access.currentKeys!(session)
  return new Map([["k_enc", hex(keys.enc(dir))], ["k_mac", hex(keys.mac(dir))]])
}

function runSeal(row: Row): Map<string, string> {
  const session = loadSession(row)
  if (session === null) return new Map([["result", "BadValue"]])
  const buffer = new Uint8Array(row.has("out_len") ? int(row, "out_len") : 300).fill(SENTINEL)
  const result = session.seal(int(row, "dir"), contextOf(row), bytes(row, "ad"), bytes(row, "clear"), bytes(row, "plain"), buffer)
  session.close()
  if (result.ok) return new Map([["body", hex(buffer.subarray(0, result.length))]])
  const wrote = buffer.some((b) => b !== SENTINEL) ? " (a refused seal wrote bytes)" : ""
  return new Map([["result", kindName(result) + wrote]])
}

function runOpen(row: Row): Map<string, string> {
  const got = new Map<string, string>()
  let window: ReplayWindow | undefined
  if (row.has("window")) {
    const [top, bits] = get(row, "window").split(":")
    window = new ReplayWindow(BigInt(`0x${top}`), BigInt(`0x${bits}`))
  }
  const before = window === undefined ? undefined : windowText(window)
  let session = loadSession(row)
  if (session !== null && row.has("prev_key") && !session.setPrevious(bytes(row, "prev_key"), int(row, "prev_epoch"))) {
    session.close()
    session = null
  }
  if (session === null) {
    got.set("result", "BadValue")
  } else {
    const buffer = new Uint8Array(row.has("out_len") ? int(row, "out_len") : 300).fill(SENTINEL)
    const counter = row.has("counter") ? BigInt(get(row, "counter")) : 0n
    const result = session.open(int(row, "dir"), contextOf(row), bytes(row, "ad"), bytes(row, "body"), int(row, "clear_len"), buffer, window, counter)
    session.close()
    got.set("result", kindName(result))
    if (result.ok) {
      got.set("slot", result.slot === "Current" ? "current" : "previous")
      got.set("plain", hex(buffer.subarray(0, result.plainLength)))
    } else {
      if (buffer.some((b) => b !== SENTINEL)) got.set("result", got.get("result") + " (a refused open wrote bytes)")
      if (window !== undefined && windowText(window) !== before) got.set("result", got.get("result") + " (a refused open changed the window)")
    }
  }
  if (window !== undefined) got.set("window_after", windowText(window))
  return got
}

function runMac(row: Row): Map<string, string> {
  const mac = MacKey.derive(bytes(row, "key"), int(row, "epoch"), bytes(row, "label"))
  if (mac === null) return new Map([["result", "BadValue"]])
  const parts = row.has("parts") ? get(row, "parts").split("|").map(unhex) : [bytes(row, "message")]
  try {
    if (row.has("verify")) return new Map([["valid", String(mac.verify(parts, bytes(row, "verify")))]])
    const made = mac.tag(parts, int(row, "n"))
    return new Map(made.ok ? [["tag", hex(made.tag)]] : [["result", kindName(made)]])
  } finally {
    mac.close()
  }
}

function runReplay(row: Row): Map<string, string> {
  const window = new ReplayWindow()
  const results: string[] = []
  const states: string[] = []
  for (const step of get(row, "steps").split(",")) {
    const colon = step.indexOf(":")
    const n = BigInt(step.slice(colon + 1))
    if (step.startsWith("check")) results.push(window.check(n))
    else {
      window.commit(n)
      states.push(windowText(window))
    }
  }
  return new Map([["results", results.join(",")], ["states", states.length === 0 ? "-" : states.join(",")]])
}

// The worked examples E1 to E3 of the contract as open inputs, read from their rows of the fixture.
export type Example = {
  name: string
  key: Uint8Array
  epoch: number
  direction: number
  tagLength: number
  msgId: Uint8Array
  kind: number
  ad: Uint8Array
  clearLength: number
  body: Uint8Array
  plain: Uint8Array
}

export function worked(): Example[] {
  const rows = loadFixture()
  return ["E1", "E2", "E3"].map((name) => {
    const row = rows.find((r) => caseOf(r) === `${name}.open`)!
    return {
      name,
      key: bytes(row, "key"),
      epoch: int(row, "epoch"),
      direction: int(row, "dir"),
      tagLength: int(row, "tag_len"),
      msgId: bytes(row, "msg_id"),
      kind: int(row, "kind"),
      ad: bytes(row, "ad"),
      clearLength: int(row, "clear_len"),
      body: bytes(row, "body"),
      plain: bytes(row, "plain"),
    }
  })
}

export const contextFor = (e: Example): MsgContext => new MsgContext(e.msgId, e.kind)

export function sessionFor(e: Example, key?: Uint8Array, epoch?: number): FrameSession {
  return FrameSession.load(key ?? e.key, epoch ?? e.epoch, new FrameConfig(e.tagLength, 7))!
}

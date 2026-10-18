import { readFileSync } from "node:fs"
import { BinaryPacker, flags, i16, i32, scheme, u8, u16, type DispatchResult, type SchemeHandler } from "../../src/index.ts"
import type { Scheme } from "../../src/index.ts"

export type Position = {
  sid: number
  lat: number
  lon: number
  profile: number
  heading?: number | null
  speed?: number | null
  altitude?: number | null
}

export const positionHex = "4001000065cd1d00a3e1110100"
export const positionValue: Position = { sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1 }

// The position fixture as a scheme that declares `parity` parity bytes.
export function positionScheme(parity: number): Scheme<Position> {
  return scheme<Position>(
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
  ).withLimits({ parity })
}

export const bytesOf = (hex: string): Uint8Array => new Uint8Array(Buffer.from(hex === "-" ? "" : hex, "hex"))
export const hexOf = (b: Uint8Array): string => Buffer.from(b).toString("hex")

export type EccRow = { kind: string; id: string; args: string[] }

// The rows of fixtures/ecc/vectors.txt (row syntax at the top of that file).
export const eccRows: EccRow[] = readFileSync(new URL("../../../fixtures/ecc/vectors.txt", import.meta.url), "utf8")
  .split("\n")
  .filter((line) => line.trim() !== "" && !line.startsWith("#"))
  .map((line) => {
    const f = line.split(" ")
    return { kind: f[0]!, id: f[1]!, args: f.slice(2) }
  })

// A copy of `message` with the byte at each position XORed by the matching non-zero value.
export function corrupt(message: Uint8Array, positions: number[], values: number[]): Uint8Array {
  const out = Uint8Array.from(message)
  positions.forEach((p, i) => {
    out[p] = out[p]! ^ values[i]!
  })
  return out
}

// `count` distinct positions below `size` and as many non-zero XOR values, drawn from `next`.
export function pick(next: () => number, size: number, count: number): { positions: number[]; values: number[] } {
  const positions: number[] = []
  while (positions.length < count) {
    const p = Math.floor(next() * size)
    if (!positions.includes(p)) positions.push(p)
  }
  return { positions, values: positions.map(() => 1 + Math.floor(next() * 255)) }
}

// Runs one unpack of the position scheme and returns what the handler saw.
export function unpackPosition(
  message: Uint8Array,
  parity: number,
  limit: number,
): { result: DispatchResult; rows: Position[] } {
  const rows: Position[] = []
  const handler = positionScheme(parity).on((r) => rows.push(r)) as SchemeHandler<object>
  return { result: BinaryPacker.unpackRepair(message, limit, handler), rows }
}

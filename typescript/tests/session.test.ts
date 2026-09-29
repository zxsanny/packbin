import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  PackSession,
  flags,
  i16,
  i32,
  scheme,
  u8,
  u16,
} from "../src/index.ts"

const clearHex = "4001000065cd1d00a3e1110100"
const cipherHex = "b55d0a29c56c203712b241232e"
const nonceHex = "01000000000000000000000000000000"

type Position = {
  sid: number
  lat: number
  lon: number
  profile: number
  heading?: number | null
  speed?: number | null
  altitude?: number | null
}

const position = scheme<Position>(
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
)

const positionValue: Position = {
  sid: 1,
  lat: 500_000_000,
  lon: 300_000_000,
  profile: 1,
}

function seed(): Uint8Array {
  return Uint8Array.from({ length: 32 }, (_, i) => i + 1)
}

function toHex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("hex")
}

function mismatchedBytes(a: Uint8Array, b: Uint8Array): number {
  const n = Math.max(a.length, b.length)
  let bad = 0
  for (let i = 0; i < n; i++) {
    if ((a[i] ?? -1) !== (b[i] ?? -1)) bad++
  }
  return bad
}

function fieldMismatches(row: Position): number {
  let n = 0
  if (row.sid !== 1) n++
  if (row.lat !== 500_000_000) n++
  if (row.lon !== 300_000_000) n++
  if (row.profile !== 1) n++
  if (row.heading !== undefined && row.heading !== null) n++
  if (row.speed !== undefined && row.speed !== null) n++
  if (row.altitude !== undefined && row.altitude !== null) n++
  return n
}

describe("session", () => {
  it("AC-1 opener pack matches C# ciphertext", () => {
    const opener = PackSession.load(seed())
    assert.ok(opener)
    const nonce = Buffer.from(nonceHex, "hex")
    assert.ok(opener!.start(nonce))
    const payload = opener!.pack(position, positionValue)
    assert.ok(payload)
    assert.equal(payload!.length, 13)
    assert.equal(toHex(payload!), cipherHex)
    assert.equal(mismatchedBytes(payload!, Buffer.from(cipherHex, "hex")), 0)
  })

  it("AC-2 waiter recovers the five fields", () => {
    const bytes = seed()
    const opener = PackSession.load(bytes)
    const waiter = PackSession.load(bytes)
    assert.ok(opener)
    assert.ok(waiter)
    const nonce = Buffer.from(nonceHex, "hex")
    assert.ok(opener!.start(nonce))
    assert.equal(waiter!.join(nonce), true)
    const payload = opener!.pack(position, positionValue)
    assert.ok(payload)
    let got: Position | undefined
    const result = waiter!.unpack(payload!, position.on((value) => {
      got = value as Position
    }))
    assert.equal(result.ok, true)
    assert.ok(got)
    assert.equal(fieldMismatches(got!), 0)
  })

  it("AC-3 clear pack is unchanged", () => {
    const bytes = BinaryPacker.pack(position, positionValue)
    assert.equal(toHex(bytes), clearHex)
    assert.equal(mismatchedBytes(bytes, Buffer.from(clearHex, "hex")), 0)
  })

  it("AC-4 bad lengths create nothing", () => {
    let created = 0
    if (PackSession.load(new Uint8Array(31)) !== null) created++
    if (PackSession.load(new Uint8Array(33)) !== null) created++
    const loaded = PackSession.load(seed())
    assert.ok(loaded)
    if (loaded!.join(new Uint8Array(15))) created++
    if (loaded!.join(new Uint8Array(17))) created++
    assert.equal(created, 0)
  })
})

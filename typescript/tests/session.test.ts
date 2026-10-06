import assert from "node:assert/strict"
import { describe, it } from "node:test"
import vm from "node:vm"
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

const oneU8 = scheme<{ a: number }>(1, u8(0, (r) => r.a))
const oneU8Row = { a: 0 }
const zeroKeyed = "5781"
const seedKeyed = "d9bc"
const nonce = Buffer.from(nonceHex, "hex")
const nonceOnes = new Uint8Array(16).fill(1)

function asSeed(value: unknown): Uint8Array {
  return value as Uint8Array
}

function firstPacket(loaded: PackSession | null): string {
  assert.ok(loaded)
  assert.ok(loaded!.start(nonceOnes))
  const packet = loaded!.pack(oneU8, oneU8Row)
  assert.ok(packet)
  return toHex(packet!)
}

describe("session load takes only a Uint8Array (AZ-2243)", () => {
  it("AZ-2243 AC-1 a text, a plain list or an object with a length is not a seed", () => {
    // Arrange
    const values = [
      "a".repeat(32),
      "0123456789abcdef0123456789abcdef",
      { length: 32 },
      new Array(32).fill("x"),
      new Array(32).fill(7),
    ]

    // Act
    const loaded = values.map((v) => PackSession.load(asSeed(v)))

    // Assert
    assert.deepEqual(loaded, [null, null, null, null, null])
  })

  it("AZ-2243 AC-2 another typed array or buffer is not a seed", () => {
    // Arrange
    const values = [
      new Uint16Array(32).fill(0x0107),
      new Int8Array(32),
      new Uint8ClampedArray(32),
      new Uint32Array(8),
      new DataView(new ArrayBuffer(32)),
      new ArrayBuffer(32),
      new SharedArrayBuffer(32),
    ]

    // Act
    const loaded = values.map((v) => PackSession.load(asSeed(v)))

    // Assert
    assert.deepEqual(loaded, [null, null, null, null, null, null, null])
  })

  it("AZ-2243 AC-3 a value that threw returns null and runs no caller code", () => {
    // Arrange
    let touched = 0
    const trap = () => {
      touched++
      return undefined
    }
    const values = [
      null,
      undefined,
      32,
      true,
      new Proxy(new Uint8Array(32), {}),
      new Proxy(new Uint8Array(32), { get: trap, getPrototypeOf: trap, has: trap }),
      Object.create(Uint8Array.prototype),
      {
        get length(): number {
          touched++
          throw new Error("boom")
        },
      },
      { length: 32, [Symbol.toStringTag]: "Uint8Array" },
    ]

    // Act
    const loaded = values.map((v) => PackSession.load(asSeed(v)))

    // Assert
    assert.deepEqual(loaded, values.map(() => null))
    assert.equal(touched, 0)
  })

  it("AZ-2243 AC-4 a Uint8Array of 32 bytes still opens a session", () => {
    // Arrange
    class Sub extends Uint8Array {}
    const otherRealm = vm.runInNewContext("new Uint8Array(32)") as Uint8Array
    const cases: [string, Uint8Array, string][] = [
      ["Uint8Array 1..32", seed(), seedKeyed],
      ["Buffer 1..32", Buffer.from(seed()), seedKeyed],
      ["Buffer.alloc", Buffer.alloc(32), zeroKeyed],
      ["subarray", new Uint8Array(64).subarray(8, 40), zeroKeyed],
      ["subclass", new Sub(32), zeroKeyed],
      ["shared memory", new Uint8Array(new SharedArrayBuffer(32)), zeroKeyed],
      ["other realm", otherRealm, zeroKeyed],
    ]

    // Act
    const packed = cases.map(([, bytes]) => firstPacket(PackSession.load(bytes)))

    // Assert
    assert.equal(otherRealm instanceof Uint8Array, false)
    assert.deepEqual(packed, cases.map(([, , hex]) => hex))
  })

  it("AZ-2243 AC-4 a subarray, a Buffer and an other-realm seed pack the position vector", () => {
    // Arrange
    const inner = new Uint8Array(64)
    inner.set(seed(), 8)
    const otherRealm = vm.runInNewContext(
      "Uint8Array.from({ length: 32 }, (_, i) => i + 1)",
    ) as Uint8Array
    const seeds = [inner.subarray(8, 40), Buffer.from(seed()), otherRealm]

    // Act
    const packed = seeds.map((bytes) => {
      const opener = PackSession.load(bytes)
      assert.ok(opener)
      assert.ok(opener!.start(nonce))
      return toHex(opener!.pack(position, positionValue)!)
    })

    // Assert
    assert.deepEqual(packed, [cipherHex, cipherHex, cipherHex])
  })

  it("AZ-2243 AC-5 a wrong size still returns null", () => {
    // Arrange
    const detached = new Uint8Array(32)
    structuredClone(detached.buffer, { transfer: [detached.buffer] })
    const values = [new Uint8Array(31), new Uint8Array(33), new Uint8Array(0), detached]

    // Act
    const loaded = values.map((v) => PackSession.load(v))

    // Assert
    assert.equal(detached.length, 0)
    assert.deepEqual(loaded, [null, null, null, null])
  })

  it("AZ-2243 AC-6 start and join keep their results", () => {
    // Arrange
    const fresh = (): PackSession => PackSession.load(seed())!
    const typeError = (message: string) => ({ name: "TypeError", message })
    const stillClosed = (s: PackSession): boolean =>
      toHex(s.start(new Uint8Array(16).fill(1))!) === "01".repeat(16)

    // Act and Assert
    let s = fresh()
    assert.throws(() => s.start(asSeed("a".repeat(16))), typeError('"key" expected Uint8Array, got type=string'))
    assert.ok(stillClosed(s))
    s = fresh()
    assert.throws(() => s.start(asSeed(null)), typeError("Cannot read properties of null (reading 'length')"))
    assert.ok(stillClosed(s))
    s = fresh()
    assert.equal(s.start(asSeed(new ArrayBuffer(16))), null)
    assert.ok(stillClosed(s))
    s = fresh()
    assert.equal(s.start(new Uint8Array(15)), null)
    assert.ok(stillClosed(s))
    s = fresh()
    assert.throws(() => s.join(asSeed({ length: 16 })), typeError('"key" expected Uint8Array, got type=object'))
    assert.ok(stillClosed(s))
    s = fresh()
    assert.equal(s.join(new Uint8Array(15)), false)
    assert.ok(stillClosed(s))
    s = fresh()
    assert.throws(() => s.join(asSeed(null)), typeError("Cannot read properties of null (reading 'length')"))
    assert.ok(stillClosed(s))
  })
})

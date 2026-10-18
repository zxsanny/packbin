import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  PackSession,
  Scheme,
  bytes,
  scheme,
  u8,
  u16,
  utf8,
  type DispatchResult,
  type SchemeHandler,
} from "../src/index.ts"
import { protect } from "../src/ecc.ts"
import { random } from "./support/random.ts"
import { corrupt, hexOf, pick, positionHex, positionScheme, positionValue, type Position } from "./support/ecc.ts"

const nonce = Buffer.from("01000000000000000000000000000000", "hex")
const cipherHex = "b55d0a29c56c203712b241232e"

function pair(): { opener: PackSession; waiter: PackSession } {
  const seed = Uint8Array.from({ length: 32 }, (_, i) => i + 1)
  const opener = PackSession.load(seed)!
  const waiter = PackSession.load(seed)!
  assert.ok(opener.start(nonce))
  assert.equal(waiter.join(nonce), true)
  return { opener, waiter }
}

function receive(s: PackSession, message: Uint8Array, limit: number, parity: number): { result: DispatchResult; rows: Position[] } {
  const rows: Position[] = []
  const handler = positionScheme(parity).on((r) => rows.push(r)) as SchemeHandler<object>
  return { result: s.unpackRepair(message, limit, handler), rows }
}

describe("message ECC scheme setting", () => {
  it("EC-1 a scheme declares no parity bytes unless it is told to, and withLimits keeps the count it was given", () => {
    // Act
    const plain = scheme<Position>(1, u8(0, (r) => r.sid))
    const protectedScheme = plain.withLimits({ parity: 4 })

    // Assert
    assert.equal(plain.parity, 0)
    assert.equal(protectedScheme.parity, 4)
    assert.equal(protectedScheme.withLimits({ maxBytes: 100 }).parity, 4)
  })

  it("EC-3 the invalid-scheme error names the count and 32 when the scheme is built", () => {
    // Act
    const build = () => new Scheme(1, [u8(0, (r: Position) => r.sid)], { parity: 33 })

    // Assert
    assert.throws(build, /parity.*33|33.*parity/)
    assert.throws(build, /32/)
  })
})

describe("message ECC session", () => {
  it("EC-10 the payload is the padded clear message plus n bytes; the parity covers the padded bytes", () => {
    // Arrange
    const { opener } = pair()

    // Act
    const payload = opener.pack(positionScheme(4), positionValue)!

    // Assert
    assert.equal(payload.length, 13 + 4)
    assert.equal(hexOf(payload.subarray(0, 13)), cipherHex)
    assert.deepEqual(payload, protect(payload.slice(0, 13), 4))
  })

  it("EC-10 a session with a scheme of 0 parity bytes keeps the payload as long as the clear message", () => {
    // Arrange
    const { opener, waiter } = pair()

    // Act
    const payload = opener.pack(positionScheme(0), positionValue)!
    const got = receive(waiter, payload, 0, 0)

    // Assert
    assert.equal(hexOf(payload), cipherHex)
    assert.deepEqual(got.result, { ok: true })
    assert.equal(got.rows.length, 1)
  })

  it("EC-10 n = 4: two wrong bytes are repaired before the pad is removed and the row is recovered", () => {
    // Arrange
    const { opener, waiter } = pair()
    const payload = opener.pack(positionScheme(4), positionValue)!

    // Act
    const got = receive(waiter, corrupt(payload, [2, 15], [0x80, 0x21]), 2, 4)

    // Assert
    assert.deepEqual(got.result, { ok: true, repaired: 2 })
    assert.deepEqual(got.rows, [positionValue])
  })

  it("EC-10 n = 4, t = 2: three wrong bytes are refused, then the next payload from the sender is read", () => {
    // Arrange
    const { opener, waiter } = pair()
    const first = opener.pack(positionScheme(4), positionValue)!
    const second = opener.pack(positionScheme(4), { ...positionValue, sid: 9 })!

    // Act
    const refused = receive(waiter, corrupt(first, [1, 5, 11], [1, 2, 3]), 2, 4)
    const next = receive(waiter, second, 2, 4)

    // Assert
    assert.deepEqual(refused.result, { ok: false, kind: "uncorrectable" })
    assert.equal(refused.rows.length, 0)
    assert.deepEqual(next.result, { ok: true, repaired: 0 })
    assert.equal(next.rows[0]!.sid, 9)
  })

  it("EC-10 a limit above n / 2 throws before the receive index moves", () => {
    // Arrange
    const { opener, waiter } = pair()
    const payload = opener.pack(positionScheme(4), positionValue)!

    // Act
    const run = () => receive(waiter, payload, 3, 4)
    const after = receive(waiter, payload, 2, 4)

    // Assert
    assert.throws(run, RangeError)
    assert.deepEqual(after.result, { ok: true, repaired: 0 })
  })

  it("EC-4 a message above the limit is refused and the send index does not move", () => {
    // Arrange
    const { opener } = pair()
    const big = scheme<{ b: Uint8Array }>(0, bytes(0, (r) => r.b, 222)).withLimits({ parity: 32 })

    // Act
    const refuse = () => opener.pack(big, { b: new Uint8Array(222) })
    const first = opener.pack(positionScheme(0), positionValue)!

    // Assert
    assert.throws(refuse, RangeError)
    assert.equal(hexOf(first), cipherHex)
  })

  it("EC-10 the protected payload read by the unprotected session unpack is refused, not thrown", () => {
    // Arrange
    const { opener, waiter } = pair()
    const payload = opener.pack(positionScheme(4), positionValue)!

    // Act
    const got = receive(waiter, payload, 0, 0)

    // Assert
    assert.equal(got.result.ok, false)
    assert.equal(got.rows.length, 0)
  })
})

describe("message ECC compact text", () => {
  type Note = { id: number; text: string; tail: number }
  const note = scheme<Note>(0x21, u8(0, (r) => r.id), utf8(1, (r) => r.text), u16(2, (r) => r.tail)).withLimits({ parity: 4 })
  const row: Note = { id: 7, text: "packbin ecc 0123456789", tail: 4660 }

  function read(message: Uint8Array, limit: number): { result: DispatchResult; rows: Note[] } {
    const rows: Note[] = []
    const result = BinaryPacker.unpackRepair(message, limit, note.on((r) => rows.push(r)) as SchemeHandler<object>)
    return { result, rows }
  }

  it("EC-11 n = 4: any 2 wrong bytes anywhere return the original row and the original string", () => {
    // Arrange
    const message = BinaryPacker.pack(note, row)
    const next = random(11)
    let cases = 0
    let wrong = 0

    // Act
    for (let a = 0; a < message.length; a++) {
      for (let b = a + 1; b < message.length; b++) {
        for (let k = 0; k < 6; k++) {
          const values = [1 + Math.floor(next() * 255), 1 + Math.floor(next() * 255)]
          const { result, rows } = read(corrupt(message, [a, b], values), 2)
          cases++
          if (!(result.ok && rows.length === 1 && rows[0]!.text === row.text && rows[0]!.id === 7 && rows[0]!.tail === 4660)) wrong++
        }
      }
    }

    // Assert
    assert.ok(cases > 1000)
    assert.equal(wrong, 0)
  })

  it("EC-11 detect only: a wrong byte in the string payload is refused and the handler does not run", () => {
    // Arrange
    const message = BinaryPacker.pack(note, row)

    // Act
    const { result, rows } = read(corrupt(message, [4], [0x10]), 0)

    // Assert
    assert.deepEqual(result, { ok: false, kind: "uncorrectable" })
    assert.equal(rows.length, 0)
  })
})

describe("message ECC dispatch", () => {
  const types = [0x11, 0x12, 0x13]
  const schemes = types.map((t) => scheme<{ a: number; b: number }>(t, u16(0, (r) => r.a), u8(1, (r) => r.b)).withLimits({ parity: 4 }))

  it("EC-16 1,000 seeded cases with the type byte among 1 to 2 wrong bytes reach the right handler only", () => {
    // Arrange
    const next = random(16)
    const calls = [0, 0, 0]
    const handlers = schemes.map((s, i) => s.on(() => calls[i]!++) as SchemeHandler<object>)
    let wrongHandlers = 0
    let missed = 0

    // Act
    for (let i = 0; i < 1000; i++) {
      const which = i % 3
      const message = BinaryPacker.pack(schemes[which]!, { a: i, b: which })
      const extra = pick(next, message.length - 1, i % 2).positions.map((p) => p + 1)
      const positions = [0, ...extra]
      const values = positions.map(() => 1 + Math.floor(next() * 255))
      calls.fill(0)
      const result = BinaryPacker.unpackRepair(corrupt(message, positions, values), 2, ...handlers)
      if (!result.ok || result.repaired !== positions.length) missed++
      calls.forEach((c, j) => {
        if (c !== (j === which ? 1 : 0)) wrongHandlers++
      })
    }

    // Assert
    assert.equal(missed, 0)
    assert.equal(wrongHandlers, 0)
  })

  it("EC-16 handlers with different parity counts are refused, naming both counts, before the handler runs", () => {
    // Arrange
    let ran = 0
    const two = scheme<{ a: number }>(0x21, u8(0, (r) => r.a)).withLimits({ parity: 2 })
    const message = BinaryPacker.pack(schemes[0]!, { a: 1, b: 2 })
    const run = () =>
      BinaryPacker.unpackRepair(message, 0, schemes[0]!.on(() => ran++) as SchemeHandler<object>, two.on(() => ran++) as SchemeHandler<object>)
    const withPlain = () =>
      BinaryPacker.unpack(message, schemes[0]!.on(() => ran++) as SchemeHandler<object>, scheme<{ a: number }>(0x22, u8(0, (r) => r.a)).on(() => ran++) as SchemeHandler<object>)

    // Assert
    assert.throws(run, /4.*2/)
    assert.throws(withPlain, /4.*0/)
    assert.equal(ran, 0)
  })

  it("EC-16 a plain dispatch of schemes without parity is unchanged", () => {
    // Arrange
    const plain = scheme<{ a: number }>(0x31, u8(0, (r) => r.a))
    let got = -1

    // Act
    const result = BinaryPacker.unpack(BinaryPacker.pack(plain, { a: 5 }), plain.on((r) => (got = r.a)) as SchemeHandler<object>)

    // Assert
    assert.deepEqual(result, { ok: true })
    assert.equal(got, 5)
  })
})

describe("message ECC hostile bytes", () => {
  it("unpack of 30,000 seeded buffers and near misses returns a result and never throws", () => {
    // Arrange
    const next = random(99)
    const handler = positionScheme(16).on(() => undefined) as SchemeHandler<object>
    const valid = BinaryPacker.pack(positionScheme(16), positionValue)
    let results = 0

    // Act
    for (let i = 0; i < 30_000; i++) {
      const size = i % 3 === 0 ? Math.floor(next() * 300) : valid.length
      const buffer = new Uint8Array(size)
      for (let k = 0; k < size; k++) buffer[k] = i % 3 === 2 && k < valid.length ? valid[k]! : Math.floor(next() * 256)
      if (i % 3 === 2 && size > 0) buffer[Math.floor(next() * size)] ^= 1 + Math.floor(next() * 255)
      const limit = i % 9
      if (BinaryPacker.unpackRepair(buffer, limit, handler) !== undefined) results++
    }

    // Assert
    assert.equal(results, 30_000)
  })

  it("the position fixture with 0 parity bytes is still the golden clear message", () => {
    // Act
    const packed = BinaryPacker.pack(positionScheme(0), positionValue)

    // Assert
    assert.equal(hexOf(packed), positionHex)
  })
})

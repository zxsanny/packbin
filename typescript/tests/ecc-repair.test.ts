import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, bytes, scheme } from "../src/index.ts"
import { protect, repair } from "../src/ecc.ts"
import { random } from "./support/random.ts"
import { corrupt, pick, positionScheme, positionValue, unpackPosition, type Position } from "./support/ecc.ts"

const same = (rows: Position[]): boolean => rows.length === 1 && JSON.stringify(rows[0]) === JSON.stringify(positionValue)

describe("message ECC repair", () => {
  it("EC-5 n = 2: every position and every wrong value of the 15 bytes is repaired", () => {
    // Arrange
    const message = BinaryPacker.pack(positionScheme(2), positionValue)
    assert.equal(message.length, 15)
    let failures = 0
    let cases = 0

    // Act
    for (let p = 0; p < message.length; p++) {
      for (let v = 1; v <= 255; v++) {
        const { result, rows } = unpackPosition(corrupt(message, [p], [v]), 2, 1)
        cases++
        if (!(result.ok && result.repaired === 1 && same(rows))) failures++
      }
    }

    // Assert
    assert.equal(cases, 15 * 255)
    assert.equal(failures, 0)
  })

  for (const [n, seed] of [[4, 4], [8, 8], [16, 16]] as const) {
    it(`EC-5 n = ${n}: 1,000 seeded cases of up to ${n / 2} wrong bytes are repaired`, () => {
      // Arrange
      const next = random(seed)
      const message = BinaryPacker.pack(positionScheme(n), positionValue)
      const t = n / 2
      let failures = 0

      // Act
      for (let i = 0; i < 1000; i++) {
        const count = 1 + (i % t)
        const { positions, values } = pick(next, message.length, count)
        const { result, rows } = unpackPosition(corrupt(message, positions, values), n, t)
        if (!(result.ok && result.repaired === count && same(rows))) failures++
      }

      // Assert
      assert.equal(failures, 0)
    })
  }

  it("EC-5 a wrong byte counts once however many of its bits differ", () => {
    // Arrange
    const message = BinaryPacker.pack(positionScheme(2), positionValue)

    // Act
    const { result, rows } = unpackPosition(corrupt(message, [6], [0xff]), 2, 1)

    // Assert
    assert.deepEqual(result, { ok: true, repaired: 1 })
    assert.ok(same(rows))
  })

  it("EC-5 repair leaves the caller's buffer as it was", () => {
    // Arrange
    const message = corrupt(BinaryPacker.pack(positionScheme(4), positionValue), [3, 9], [0x55, 0x01])
    const before = Uint8Array.from(message)

    // Act
    const { result } = unpackPosition(message, 4, 2)

    // Assert
    assert.equal(result.ok, true)
    assert.deepEqual(message, before)
  })

  it("EC-6 n = 4, t = 1: 10,000 seeded cases of 2 or 3 wrong bytes are all refused with no row", () => {
    // Arrange
    const next = random(61)
    const message = BinaryPacker.pack(positionScheme(4), positionValue)
    let accepted = 0
    let wrongRows = 0

    // Act
    for (let i = 0; i < 10_000; i++) {
      const { positions, values } = pick(next, message.length, 2 + (i % 2))
      const { result, rows } = unpackPosition(corrupt(message, positions, values), 4, 1)
      if (result.ok) accepted++
      else assert.deepEqual(result, { ok: false, kind: "uncorrectable" })
      wrongRows += rows.length
    }

    // Assert
    assert.equal(accepted, 0)
    assert.equal(wrongRows, 0)
  })

  it("EC-6 n = 4, t = 0: 10,000 seeded cases of 1 to 4 wrong bytes are all refused with no row", () => {
    // Arrange
    const next = random(60)
    const message = BinaryPacker.pack(positionScheme(4), positionValue)
    let accepted = 0
    let wrongRows = 0

    // Act
    for (let i = 0; i < 10_000; i++) {
      const { positions, values } = pick(next, message.length, 1 + (i % 4))
      const { result, rows } = unpackPosition(corrupt(message, positions, values), 4, 0)
      if (result.ok) accepted++
      wrongRows += rows.length
    }

    // Assert
    assert.equal(accepted, 0)
    assert.equal(wrongRows, 0)
  })

  it("EC-7 n = 2, t = 0: at most 12 of 200,000 random buffers are accepted", () => {
    // Arrange
    const next = random(7)
    const buffer = new Uint8Array(15)
    let accepted = 0

    // Act
    for (let i = 0; i < 200_000; i++) {
      for (let k = 0; k < buffer.length; k++) buffer[k] = Math.floor(next() * 256)
      if (repair(buffer, 2, 0).ok) accepted++
    }

    // Assert
    assert.ok(accepted <= 12, `accepted ${accepted}`)
  })

  it("EC-14 n = 4, t = 0: 10,000 seeded cases of removed or added tail bytes are refused with no row", () => {
    // Arrange
    const next = random(14)
    const message = BinaryPacker.pack(positionScheme(4), positionValue)
    let accepted = 0
    let wrongRows = 0

    // Act
    for (let i = 0; i < 10_000; i++) {
      const k = 1 + (i % 3)
      const changed =
        i % 2 === 0
          ? message.slice(0, message.length - k)
          : Uint8Array.from([...message, ...Array.from({ length: k }, () => Math.floor(next() * 256))])
      const { result, rows } = unpackPosition(changed, 4, 0)
      if (result.ok) accepted++
      wrongRows += rows.length
    }

    // Assert
    assert.equal(accepted, 0)
    assert.equal(wrongRows, 0)
  })

  it("EC-14 a trailing zero byte, a dropped last byte and a last parity byte of 00 are refused", () => {
    // Arrange
    const message = BinaryPacker.pack(positionScheme(4), positionValue)
    const trailingZero = Uint8Array.from([...message, 0])
    const dropped = message.slice(0, message.length - 1)
    let zeroParity: Uint8Array | null = null
    for (let sid = 0; zeroParity === null && sid < 65_536; sid++) {
      const candidate = BinaryPacker.pack(positionScheme(4), { ...positionValue, sid })
      if (candidate[candidate.length - 1] === 0) zeroParity = candidate
    }
    assert.ok(zeroParity)

    // Act
    const results = [trailingZero, dropped, Uint8Array.from([...zeroParity!, 0]), zeroParity!.slice(0, zeroParity!.length - 1)].map(
      (m) => unpackPosition(m, 4, 0),
    )
    const intact = unpackPosition(zeroParity!, 4, 0)

    // Assert
    for (const r of results) {
      assert.equal(r.result.ok, false)
      assert.equal(r.rows.length, 0)
    }
    assert.deepEqual(intact.result, { ok: true, repaired: 0 })
  })

  it("EC-14 the unprotected 13-byte message read by an n = 4 scheme is refused with no row", () => {
    // Arrange
    const clear = BinaryPacker.pack(positionScheme(0), positionValue)

    // Act
    const detect = unpackPosition(clear, 4, 0)
    const repairing = unpackPosition(clear, 4, 2)

    // Assert
    assert.deepEqual(detect.result, { ok: false, kind: "uncorrectable" })
    assert.equal(repairing.result.ok, false)
    assert.equal(detect.rows.length + repairing.rows.length, 0)
  })

  it("EC-14 a scheme without parity given a protected message returns the trailing-bytes error", () => {
    // Arrange
    const message = BinaryPacker.pack(positionScheme(4), positionValue)

    // Act
    const { result, rows } = unpackPosition(message, 0, 0)

    // Assert
    assert.deepEqual(result, { ok: false, field: "", needed: 0, left: 4 })
    assert.equal(rows.length, 0)
  })

  it("EC-4 a buffer above 254 bytes is refused as too_long with no row", () => {
    // Act
    const { result, rows } = unpackPosition(new Uint8Array(255), 4, 2)

    // Assert
    assert.deepEqual(result, { ok: false, kind: "too_long", length: 255, limit: 254 })
    assert.equal(rows.length, 0)
  })

  it("EC-4 n = 32: a clear message of 222 bytes is packed, 223 is refused naming both numbers", () => {
    // Arrange
    const big = (size: number) => scheme<{ b: Uint8Array }>(0, bytes(0, (r) => r.b, size - 1)).withLimits({ parity: 32 })
    const fits = big(222)
    const over = big(223)

    // Act
    const packed = BinaryPacker.pack(fits, { b: new Uint8Array(221).fill(7) })
    const refuse = () => BinaryPacker.pack(over, { b: new Uint8Array(222).fill(7) })

    // Assert
    assert.equal(packed.length, 254)
    assert.throws(refuse, (e: unknown) => e instanceof RangeError && e.message.includes("223") && e.message.includes("222"))
  })

  it("EC-13 repair of a 254-byte message with 16 parity bytes and 8 wrong bytes: 1,000 times within 1 s, packing too", () => {
    // Arrange
    const clear = Uint8Array.from({ length: 238 }, (_, i) => (i * 37 + 11) & 0xff)
    const message = protect(clear, 16)
    const wrong = corrupt(message, [0, 30, 60, 90, 120, 180, 220, 253], [1, 2, 3, 4, 5, 6, 7, 8])
    let repaired = 0
    const unpackStart = performance.now()

    // Act
    for (let i = 0; i < 1000; i++) {
      const got = repair(wrong, 16, 8)
      if (got.ok && got.repaired === 8) repaired++
    }
    const unpackMs = performance.now() - unpackStart
    const packStart = performance.now()
    let last = message
    for (let i = 0; i < 1000; i++) last = protect(clear, 16)
    const packMs = performance.now() - packStart

    // Assert
    assert.equal(repaired, 1000)
    assert.deepEqual(last, message)
    assert.ok(unpackMs <= 1000, `repair loop ${unpackMs} ms`)
    assert.ok(packMs <= 1000, `pack loop ${packMs} ms`)
  })
})

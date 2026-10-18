import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, scheme, utf8, type DispatchResult } from "../src/index.ts"
import { decodeText, encodeText } from "../src/text.ts"
import { random } from "./support/random.ts"
import { hexOf, vectorRows } from "./support/text-vectors.ts"

const one = scheme<{ s: string }>(1, utf8(0, (r) => r.s))
const bytes = (h: string): Uint8Array => new Uint8Array(Buffer.from(h, "hex"))
const packed = (s: string): string => hexOf(BinaryPacker.pack(one, { s }))

function unpackText(packet: Uint8Array): { result: DispatchResult; text?: string } {
  let text: string | undefined
  const result = BinaryPacker.unpack(packet, one.on((r) => {
    text = r.s
  }))
  return { result, text }
}

describe("compact text codec properties", () => {
  const pool = [
    ..."абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'",
    ..."абвгдеёжзийклмнопрстуфхцчшщъыьэюя",
    ..."abcdefghijklmnopqrstuvwxyz'",
    ..."АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯЁЪЫЭ",
    ..."ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    ..." 0123456789,.-:!?;()\"%/@+=*#&_$\n",
    "é", "ß", "中", "😀", "\u0000", "\ufeff", "\u0301", "\u2019",
  ]

  function sample(rand: () => number): string {
    const n = Math.floor(rand() * 40)
    let out = ""
    let from = 0
    for (let i = 0; i < n; i++) {
      if (rand() < 0.15) from = Math.floor(rand() * (pool.length - 12))
      out += pool[(from + Math.floor(rand() * 30)) % pool.length]!
    }
    return out
  }

  it("a text round-trips, and a text under 128 UTF-8 bytes is at most 2 bytes larger than its UTF-8", () => {
    // Arrange
    const rand = random(35)
    const failures: string[] = []

    // Act
    for (let i = 0; i < 4000; i++) {
      const text = sample(rand)
      const field = encodeText(text, "s")
      const back = decodeText(field, 0)
      const utf8Length = Buffer.byteLength(text)
      if (!back.ok || back.value !== text || back.next !== field.length) failures.push(`round trip ${JSON.stringify(text)}`)
      if (utf8Length < 128 && field.length > 2 + utf8Length) failures.push(`size ${JSON.stringify(text)}`)
    }

    // Assert
    assert.deepEqual(failures, [])
  })

  it("a lone surrogate is written as the U+FFFD the UTF-8 encoder writes", () => {
    // Arrange
    const texts = ["a\ud800b", "\udc00", "x\ud83d", "😀\ud83d", "\ude00\ud83d"]

    // Act / Assert
    for (const text of texts) {
      const same = text.replace(/[\ud800-\udbff](?![\udc00-\udfff])|(?<![\ud800-\udbff])[\udc00-\udfff]/g, "�")
      assert.equal(packed(text), packed(same), JSON.stringify(text))
      assert.equal(unpackText(bytes(packed(text))).text, same)
    }
  })

  it("random and damaged buffers never throw, read past the payload or decode past 6 bytes a payload byte plus 8", () => {
    // Arrange
    const rand = random(36)
    const valid = vectorRows.flatMap((r) => (r.kind === "enc" ? [r.field] : []))
    let decoded = 0

    // Act
    for (let i = 0; i < 30_000; i++) {
      let buf: Uint8Array
      if (i % 2 === 0) {
        buf = Uint8Array.from({ length: 1 + Math.floor(rand() * 40) }, () => Math.floor(rand() * 256))
        buf[0] = 1 + Math.floor(rand() * (buf.length - 1 || 1))
      } else {
        buf = Uint8Array.from(valid[Math.floor(rand() * valid.length)]!)
        buf[Math.floor(rand() * buf.length)]! ^= 1 << Math.floor(rand() * 8)
      }
      const got = decodeText(buf, 0)
      if (!got.ok) continue
      decoded++
      assert.ok(got.next <= buf.length)
      assert.ok(Buffer.byteLength(got.value) <= 6 * (got.next - 1) + 8)
    }

    // Assert
    assert.ok(decoded > 1000, `${decoded} buffers decoded`)
  })

  it("a text longer than 65 535 UTF-8 bytes in a compact payload is refused as it grows", () => {
    // Arrange
    const payload = new Uint8Array(30_000)
    const count = Uint8Array.of(0xb0, 0xea, 0x01)
    const field = new Uint8Array(count.length + payload.length)
    field.set(count)
    field.set(payload, count.length)

    // Act
    const got = decodeText(field, 0)

    // Assert
    assert.equal(got.ok, false)
    if (!got.ok) assert.equal(got.kind, "length")
  })
})

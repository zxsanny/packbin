import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, PackSession, scheme, u8 } from "../src/index.ts"

type Row = { a: number }
const layout = scheme<Row>(0x40, u8(0, (r) => r.a))
const nonce = Buffer.from("01000000000000000000000000000000", "hex")

function pair(): { sender: PackSession; receiver: PackSession } {
  const seed = Uint8Array.from({ length: 32 }, (_, i) => i + 1)
  const sender = PackSession.load(seed)!
  const receiver = PackSession.load(seed)!
  assert.ok(sender.start(nonce))
  assert.equal(receiver.join(nonce), true)
  return { sender, receiver }
}

const wrong: [string, unknown][] = [
  ["string", "abc"],
  ["number", 1_000_000_000],
  ["null", null],
  ["undefined", undefined],
  ["plain array", [1, 2, 3]],
  ["Int8Array", new Int8Array(4)],
  ["DataView", new DataView(new ArrayBuffer(4))],
  ["object claiming to be an ArrayBuffer", { [Symbol.toStringTag]: "ArrayBuffer", byteLength: 2 }],
]

describe("payload type of unpack (AZ-2722, F19)", () => {
  for (const [name, payload] of wrong) {
    it(`session unpack refuses a ${name} and keeps the receive index`, () => {
      const { sender, receiver } = pair()
      const packet = sender.pack(layout, { a: 7 })!
      let seen: Row | undefined

      assert.throws(() => receiver.unpack(payload as Uint8Array, layout.on(() => {})), TypeError)
      const got = receiver.unpack(packet, layout.on((r) => {
        seen = r as Row
      }))

      assert.deepEqual(got, { ok: true })
      assert.deepEqual(seen, { a: 7 })
    })

    it(`BinaryPacker.unpack refuses a ${name}`, () => {
      assert.throws(() => BinaryPacker.unpack(payload as Uint8Array, layout.on(() => {})), TypeError)
    })
  }

  it("still accepts a Uint8Array, a Buffer and an ArrayBuffer", () => {
    for (const make of [(b: Uint8Array) => b, (b: Uint8Array) => Buffer.from(b), (b: Uint8Array) => b.slice().buffer]) {
      const { sender, receiver } = pair()
      let seen: Row | undefined
      const got = receiver.unpack(make(sender.pack(layout, { a: 9 })!), layout.on((r) => {
        seen = r as Row
      }))
      assert.deepEqual(got, { ok: true })
      assert.deepEqual(seen, { a: 9 })
    }
  })
})

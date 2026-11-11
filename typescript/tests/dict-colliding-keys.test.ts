import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, dict, list, scheme, u8 } from "../src/index.ts"

// Two keys that differ only in unpaired surrogates are one key on the wire (each half is written as U+FFFD), and
// unpack refuses a repeated key, so pack refuses them: it never writes a packet its own unpack cannot read (AZ-4168).
// The packets below were written by this package before the check, and Dart (loop 100) gives the same bytes.

type Row = { d: Record<string, number> }

const layout = scheme<Row>(1, dict((r) => r.d, u8(0, (x) => x.v)))
const MESSAGE = "d: two keys are the same once an unpaired surrogate is written as U+FFFD"

const hex = (b: Uint8Array): string => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("")

function unpack(bytes: Uint8Array): { ok: boolean; keys?: string[] } {
  let row: Row | undefined
  const result = BinaryPacker.unpack(bytes, layout.on((r) => {
    row = r as Row
  }))
  return { ok: result.ok === true, keys: row ? Object.keys(row.d) : undefined }
}

describe("dictionary keys that collide once a lone surrogate is U+FFFD (AZ-4168)", () => {
  const collisions: [string, Record<string, number>][] = [
    ["a lone high and a lone low half", { "\ud800": 1, "\udc00": 2 }],
    ["U+FFFD and a lone high half", { "�": 1, "\ud800": 2 }],
    ["three keys, two collide", { a: 1, "\ud800": 2, "\udc00": 3 }],
    ["a reversed pair and two U+FFFD", { "\udc00\ud800": 1, "��": 2 }],
  ]
  for (const [name, d] of collisions) {
    it(`refuses ${name}, naming the dictionary`, () => {
      assert.throws(() => BinaryPacker.pack(layout, { d }), (e: unknown) => e instanceof RangeError && e.message === MESSAGE)
    })
  }

  it("refuses a colliding dictionary that is a list element, naming the list's dictionary", () => {
    const inList = scheme<{ xs: Record<string, number>[] }>(1, list((r) => r.xs, dict((x) => x, u8(0, (y) => y.v))))
    assert.throws(
      () => BinaryPacker.pack(inList, { xs: [{ "\ud800": 1, "\udc00": 2 }] }),
      (e: unknown) => e instanceof RangeError && /two keys are the same once an unpaired surrogate/.test(e.message),
    )
  })

  const unchanged: [string, Record<string, number>, string][] = [
    ["a lone high half and U+FFFF", { "\ud800": 1, "￿": 2 }, "0102000410efbfbd010410efbfbf02"],
    ["a and a lone high half", { a: 1, "\ud800": 2 }, "010200021061010410efbfbd02"],
    ["one lone high half", { "\ud800": 1 }, "0101000410efbfbd01"],
    ["a pair and a lone low half", { "\u{10000}": 1, "\udc00": 2 }, "0102000410efbfbd020510f090808001"],
  ]
  for (const [name, d, packet] of unchanged) {
    it(`packs ${name} to the bytes it always wrote`, () => {
      assert.equal(hex(BinaryPacker.pack(layout, { d })), packet)
    })
  }

  it("never writes a packet its own unpack refuses (20,000 seeded dictionaries)", () => {
    // mulberry32: a fixed seed, so a failure replays
    let seed = 20261111
    const next = (): number => {
      seed = (seed + 0x6d2b79f5) | 0
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
    const alphabet = ["a", "z", "\ud800", "\udbff", "\udc00", "\udfff", "�", "￿", "\u{1f600}", ""]
    const swap = (s: string): string => new TextDecoder().decode(new TextEncoder().encode(s))
    let written = 0
    let refused = 0
    for (let n = 0; n < 20000; n++) {
      const d: Record<string, number> = {}
      for (let k = 1 + Math.floor(next() * 4); k > 0; k--) {
        let key = ""
        for (let u = Math.floor(next() * 4); u > 0; u--) key += alphabet[Math.floor(next() * alphabet.length)]
        d[key] = 1 + Math.floor(next() * 200)
      }
      const swapped = Object.keys(d).map(swap)
      const collides = new Set(swapped).size !== swapped.length
      let packet: Uint8Array | undefined
      try {
        packet = BinaryPacker.pack(layout, { d })
      } catch (e) {
        assert.ok(e instanceof RangeError && e.message === MESSAGE, `unexpected refusal for ${JSON.stringify(Object.keys(d))}`)
      }
      if (packet === undefined) {
        assert.ok(collides, `refused without a collision: ${JSON.stringify(Object.keys(d))}`)
        refused++
        continue
      }
      assert.ok(!collides, `wrote a colliding dictionary: ${JSON.stringify(Object.keys(d))}`)
      const back = unpack(packet)
      assert.ok(back.ok, `its own unpack refused ${hex(packet)}`)
      assert.deepEqual([...back.keys!].sort(), [...swapped].sort())
      written++
    }
    assert.ok(written > 5000 && refused > 500, `${written} written, ${refused} refused`)
  })
})

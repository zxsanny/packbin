import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, dict, scheme, u8 } from "../src/index.ts"
import { compareUtf8 } from "../src/kinds.ts"

type Row = { d: Record<string, number> }

const layout = scheme<Row>(1, dict((x) => x.d, u8(0, (x) => x.v)))

// A raw-form key field: count, start byte 0x10, then the UTF-8 bytes (short keys only).
function keyField(text: string): number[] {
  const raw = Array.from(new TextEncoder().encode(text))
  assert.ok(raw.length < 100)
  return [raw.length + 1, 0x10, ...raw]
}

function packet(...keys: string[]): Uint8Array {
  return Uint8Array.from([1, keys.length & 0xff, keys.length >> 8, ...keys.flatMap((k) => [...keyField(k), 0])])
}

function unpack(bytes: Uint8Array): { result: ReturnType<typeof BinaryPacker.unpack>; row: Row | undefined } {
  let row: Row | undefined
  const result = BinaryPacker.unpack(bytes, layout.on((r) => {
    row = r as Row
  }))
  return { result, row }
}

describe("dict keys strictly ascending (AZ-2713)", () => {
  const accepted: [string, string[]][] = [
    ["ascending", ["a", "b"]],
    ["prefix first", ["a", "ab"]],
    ["empty then a", ["", "a"]],
    ["fullwidth tilde then supplementary", ["z", "～", "\u{10000}"]],
    ["private use, fullwidth tilde, supplementary", ["", "～", "\u{10000}"]],
  ]
  for (const [name, keys] of accepted) {
    it(`accepts ${name}`, () => {
      const { result, row } = unpack(packet(...keys))
      assert.deepEqual(result, { ok: true })
      assert.deepEqual(Object.keys(row!.d), keys)
    })
  }

  const refused: [string, string[]][] = [
    ["descending", ["b", "a"]],
    ["repeated", ["a", "a"]],
    ["a prefix after its longer key", ["ab", "a"]],
    ["supplementary before fullwidth tilde", ["\u{10000}", "～"]],
    ["a repeat after a gap", ["a", "b", "a"]],
  ]
  for (const [name, keys] of refused) {
    it(`refuses ${name} with the dict-key error`, () => {
      const { result, row } = unpack(packet(...keys))
      assert.deepEqual(result, { ok: false, field: "d", needed: 0, left: 0 })
      assert.equal(row, undefined)
    })
  }

  it("refuses one key in two byte forms", () => {
    const { result } = unpack(Buffer.from("01020002106100" + "02c90000", "hex"))
    assert.deepEqual(result, { ok: false, field: "d", needed: 0, left: 0 })
  })

  it("compares like the bytes the encoder sorts by", () => {
    const keys = ["\u{10000}", "～", "", "b", "a", "ab", "", "\u{1f600}", "퟿", "￿"]
    const enc = new TextEncoder()
    const byBytes = [...keys].sort((x, y) => {
      const a = enc.encode(x)
      const b = enc.encode(y)
      for (let i = 0; i < Math.min(a.length, b.length); i++) if (a[i] !== b[i]) return a[i]! - b[i]!
      return a.length - b.length
    })
    assert.deepEqual([...keys].sort(compareUtf8), byBytes)
  })

  it("accepts what pack writes for supplementary and BMP keys", () => {
    const d = { "\u{10000}": 3, "～": 2, b: 1, a: 0 }
    const { result, row } = unpack(BinaryPacker.pack(layout, { d }))
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(Object.entries(row!.d), [["a", 0], ["b", 1], ["～", 2], ["\u{10000}", 3]])
  })

  it("unpacks 65535 ascending keys, packed by the package, within a second", () => {
    const d: Record<string, number> = {}
    for (let n = 0; n < 65535; n++) d[`key${String(n).padStart(5, "0")}`] = n & 0xff
    const bytes = BinaryPacker.pack(layout, { d })
    const reference = referenceSeconds()
    const start = performance.now()
    const { result, row } = unpack(bytes)
    const elapsed = (performance.now() - start) / 1000
    assert.deepEqual(result, { ok: true })
    assert.equal(Object.keys(row!.d).length, 65535)
    // 1 s on a quiet machine; the bound grows with the load a reference loop sees in this process.
    const bound = Math.max(1, reference / 0.03)
    assert.ok(elapsed <= bound, `elapsed ${elapsed.toFixed(3)} s, bound ${bound.toFixed(3)} s (reference ${reference.toFixed(3)} s)`)
  })
})

function referenceSeconds(): number {
  let best = Infinity
  for (let i = 0; i < 3; i++) {
    const start = performance.now()
    const keys: string[] = []
    for (let n = 0; n < 65535; n++) keys.push(`key${String(n).padStart(5, "0")}`)
    keys.sort(compareUtf8)
    best = Math.min(best, (performance.now() - start) / 1000)
  }
  return best
}

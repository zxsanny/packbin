import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  bool,
  eq,
  flags,
  i32,
  list,
  scheme,
  u8,
  u16,
  when,
} from "../src/index.ts"

class MarkerRow {
  sid = 0
  lat = 0
  lon = 0
  kind = 0
  kindId: number | null = null
  title = 0
  hidden: boolean | null = null
  delta: boolean | null = null
}

const MarkerScheme = scheme<MarkerRow>(
  0x20,
  u16(0, (x) => x.sid),
  i32(1, (x) => x.lat),
  i32(2, (x) => x.lon),
  u8(3, (x) => x.kind),
  when(eq(3, 1), [u16(4, (x) => x.kindId)]),
  u16(5, (x) => x.title),
  flags([bool(6, (x) => x.hidden), bool(7, (x) => x.delta)]),
)

const ac1Hex = "2001000065cd1d00a3e111010000000000"

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

describe("field id binding", () => {
  it("AC-1 member names are not the wire names", () => {
    const row = new MarkerRow()
    row.sid = 1
    row.lat = 500_000_000
    row.lon = 300_000_000
    row.kind = 1
    row.kindId = 0
    row.title = 0
    const bytes = BinaryPacker.pack(MarkerScheme, row)
    assert.equal(toHex(bytes), ac1Hex)
    assert.equal(Object.prototype.hasOwnProperty.call(row, "Lat"), false)
    assert.equal(Object.prototype.hasOwnProperty.call(row, "lat"), true)
    let back: MarkerRow | undefined
    const result = BinaryPacker.unpack(bytes, MarkerScheme.on((value) => {
      back = value as MarkerRow
    }))
    assert.equal(result.ok, true)
    assert.equal(back!.lat, 500_000_000)
    assert.equal(back!.sid, 1)
    assert.equal(back!.lon, 300_000_000)
    assert.equal(back!.kind, 1)
    assert.equal(back!.kindId, 0)
    assert.equal(back!.title, 0)
  })

  it("AC-2 sibling references use the order", () => {
    const withKind = new MarkerRow()
    withKind.sid = 1
    withKind.lat = 500_000_000
    withKind.lon = 300_000_000
    withKind.kind = 1
    withKind.kindId = 40
    withKind.title = 7
    const hit = BinaryPacker.pack(MarkerScheme, withKind)
    assert.equal(toHex(hit), "2001000065cd1d00a3e111012800070000")
    let backHit: MarkerRow | undefined
    const hitResult = BinaryPacker.unpack(hit, MarkerScheme.on((value) => {
      backHit = value as MarkerRow
    }))
    assert.equal(hitResult.ok, true)
    assert.equal(backHit!.kindId, 40)

    const miss = new MarkerRow()
    miss.sid = 1
    miss.lat = 500_000_000
    miss.lon = 300_000_000
    miss.kind = 0
    miss.title = 7
    const omitted = BinaryPacker.pack(MarkerScheme, miss)
    assert.equal(toHex(omitted), "2001000065cd1d00a3e11100070000")
    assert.equal(omitted.length, hit.length - 2)
    let backMiss: MarkerRow | undefined
    const missResult = BinaryPacker.unpack(omitted, MarkerScheme.on((value) => {
      backMiss = value as MarkerRow
    }))
    assert.equal(missResult.ok, true)
    assert.equal(backMiss!.kindId, undefined)
  })

  it("AC-3 flags use child accessors", () => {
    const row = new MarkerRow()
    row.sid = 1
    row.lat = 500_000_000
    row.lon = 300_000_000
    row.kind = 0
    row.title = 7
    row.hidden = true
    row.delta = null
    const bytes = BinaryPacker.pack(MarkerScheme, row)
    assert.equal(toHex(bytes), "2001000065cd1d00a3e11100070001")
    assert.equal(bytes[bytes.length - 1], 0x01)
    let back: MarkerRow | undefined
    const result = BinaryPacker.unpack(bytes, MarkerScheme.on((value) => {
      back = value as MarkerRow
    }))
    assert.equal(result.ok, true)
    assert.equal(back!.hidden, true)
    assert.equal(back!.delta, undefined)
  })

  it("AC-4 nested row type has its own ids", () => {
    type Parent = { sid: number; items: number[] }
    const layout = scheme<Parent>(
      0x20,
      u16(0, (r) => r.sid),
      list(
        (r) => r.items,
        u16(0, (id) => id),
      ),
    )
    const bytes = BinaryPacker.pack(layout, { sid: 1, items: [9, 10] })
    assert.equal(toHex(bytes), "200100020009000a00")
    let back: Parent | undefined
    const result = BinaryPacker.unpack(bytes, layout.on((value) => {
      back = value as Parent
    }))
    assert.equal(result.ok, true)
    assert.equal(back!.sid, 1)
    assert.deepEqual(back!.items, [9, 10])
  })

  it("AC-5 order must match the number", () => {
    assert.throws(() => {
      scheme(1, i32(2, (r: { lat: number }) => r.lat))
    })
    assert.throws(() => {
      scheme(
        1,
        u16(0, (r: { sid: number }) => r.sid),
        i32(2, (r: { lat: number }) => r.lat),
      )
    })
  })

  it("AC-6 AC-1 bytes match", () => {
    const row = new MarkerRow()
    row.sid = 1
    row.lat = 500_000_000
    row.lon = 300_000_000
    row.kind = 1
    row.kindId = 0
    row.title = 0
    const a = BinaryPacker.pack(MarkerScheme, row)
    const b = BinaryPacker.pack(MarkerScheme, row)
    assert.equal(toHex(a), ac1Hex)
    assert.equal(mismatchedBytes(a, b), 0)
    assert.equal(mismatchedBytes(a, Buffer.from(ac1Hex, "hex")), 0)
  })
})

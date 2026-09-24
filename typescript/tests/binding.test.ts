import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  bool,
  eq,
  flags,
  i32,
  list,
  pack,
  scheme,
  u8,
  u16,
  unpack,
  when,
} from "../src/index.ts"

class MarkerRow {
  Sid = 0
  Lat = 0
  Lon = 0
  Kind = 0
  KindId: number | null = null
  Title = 0
  Hidden: boolean | null = null
  Delta: boolean | null = null
}

const MarkerScheme = scheme<MarkerRow>(
  0x20,
  u16(0, (x) => x.Sid),
  i32(1, (x) => x.Lat),
  i32(2, (x) => x.Lon),
  u8(3, (x) => x.Kind),
  when(eq(3, 1), [u16(4, (x) => x.KindId)]),
  u16(5, (x) => x.Title),
  flags([bool(6, (x) => x.Hidden), bool(7, (x) => x.Delta)]),
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
    row.Sid = 1
    row.Lat = 500_000_000
    row.Lon = 300_000_000
    row.Kind = 1
    row.KindId = 0
    row.Title = 0
    const bytes = pack(MarkerScheme, row)
    assert.equal(toHex(bytes), ac1Hex)
    assert.equal(Object.prototype.hasOwnProperty.call(row, "lat"), false)
    assert.equal(Object.prototype.hasOwnProperty.call(row, "Lat"), true)
    const back = unpack(MarkerScheme, bytes, MarkerRow)
    assert.equal(back.ok, true)
    if (!back.ok) return
    assert.equal(back.value.Lat, 500_000_000)
    assert.equal(back.value.Sid, 1)
    assert.equal(back.value.Lon, 300_000_000)
    assert.equal(back.value.Kind, 1)
    assert.equal(back.value.KindId, 0)
    assert.equal(back.value.Title, 0)
  })

  it("AC-2 sibling references use the order", () => {
    const withKind = new MarkerRow()
    withKind.Sid = 1
    withKind.Lat = 500_000_000
    withKind.Lon = 300_000_000
    withKind.Kind = 1
    withKind.KindId = 40
    withKind.Title = 7
    const hit = pack(MarkerScheme, withKind)
    assert.equal(toHex(hit), "2001000065cd1d00a3e111012800070000")
    const backHit = unpack(MarkerScheme, hit, MarkerRow)
    assert.equal(backHit.ok, true)
    if (!backHit.ok) return
    assert.equal(backHit.value.KindId, 40)

    const miss = new MarkerRow()
    miss.Sid = 1
    miss.Lat = 500_000_000
    miss.Lon = 300_000_000
    miss.Kind = 0
    miss.Title = 7
    const omitted = pack(MarkerScheme, miss)
    assert.equal(toHex(omitted), "2001000065cd1d00a3e11100070000")
    assert.equal(omitted.length, hit.length - 2)
    const backMiss = unpack(MarkerScheme, omitted, MarkerRow)
    assert.equal(backMiss.ok, true)
    if (!backMiss.ok) return
    assert.equal(backMiss.value.KindId, null)
  })

  it("AC-3 flags use child accessors", () => {
    const row = new MarkerRow()
    row.Sid = 1
    row.Lat = 500_000_000
    row.Lon = 300_000_000
    row.Kind = 0
    row.Title = 7
    row.Hidden = true
    row.Delta = null
    const bytes = pack(MarkerScheme, row)
    assert.equal(toHex(bytes), "2001000065cd1d00a3e11100070001")
    assert.equal(bytes[bytes.length - 1], 0x01)
    const back = unpack(MarkerScheme, bytes, MarkerRow)
    assert.equal(back.ok, true)
    if (!back.ok) return
    assert.equal(back.value.Hidden, true)
    assert.equal(back.value.Delta, null)
  })

  it("AC-4 nested row type has its own ids", () => {
    type Parent = { Sid: number; Items: number[] }
    const layout = scheme<Parent>(
      0x20,
      u16(0, (r) => r.Sid),
      list(
        (r) => r.Items,
        u16(0, (id) => id),
      ),
    )
    const bytes = pack(layout, { Sid: 1, Items: [9, 10] })
    assert.equal(toHex(bytes), "200100020009000a00")
    const back = unpack(layout, bytes)
    assert.equal(back.ok, true)
    if (!back.ok) return
    assert.equal(back.value.Sid, 1)
    assert.deepEqual(back.value.Items, [9, 10])
  })

  it("AC-5 order must match the number", () => {
    assert.throws(() => {
      scheme(1, i32(2, (r: { Lat: number }) => r.Lat))
    })
    assert.throws(() => {
      scheme(
        1,
        u16(0, (r: { Sid: number }) => r.Sid),
        i32(2, (r: { Lat: number }) => r.Lat),
      )
    })
  })

  it("AC-6 AC-1 bytes match", () => {
    const row = new MarkerRow()
    row.Sid = 1
    row.Lat = 500_000_000
    row.Lon = 300_000_000
    row.Kind = 1
    row.KindId = 0
    row.Title = 0
    const a = pack(MarkerScheme, row)
    const b = pack(MarkerScheme, row)
    assert.equal(toHex(a), ac1Hex)
    assert.equal(mismatchedBytes(a, b), 0)
    assert.equal(mismatchedBytes(a, Buffer.from(ac1Hex, "hex")), 0)
  })
})

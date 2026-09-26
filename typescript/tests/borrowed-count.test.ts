import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  bool,
  eq,
  flags,
  i32,
  packed,
  scheme,
  times,
  u8,
  u16,
  when,
} from "../src/index.ts"

function toHex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("hex")
}

const ROUTE_HEX =
  "3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101"

type RouteRow = {
  sid: number
  name: number
  unit?: number
  straight?: boolean
  routeId?: number
  count: number
  kinds: number[]
  lat: number
  lon: number
  mask?: number[]
}

const route = scheme<RouteRow>(
  0x34,
  u16(0, (r) => r.sid),
  u16(1, (r) => r.name),
  flags([
    u16(2, (r) => r.unit),
    bool(3, (r) => r.straight),
    u16(4, (r) => r.routeId),
  ]),
  u8(5, (r) => r.count),
  packed(2, 6, (r) => r.kinds, 5),
  times(5, [i32(7, (r) => r.lat), i32(8, (r) => r.lon)]),
  when(eq(3, true), [packed(1, 9, (r) => r.mask, 5, -1)]),
)

describe("borrowed-count fields", () => {
  it("width 2 four values are one byte", () => {
    type KindRow = { n: number; kinds: number[] }
    const layout = scheme<KindRow>(
      1,
      u8(0, (r) => r.n),
      packed(2, 1, (r) => r.kinds, 0),
    )
    const raw = BinaryPacker.pack(layout, { n: 4, kinds: [0, 1, 2, 3] })
    assert.equal(toHex(raw.subarray(2)), "e4")
    let got: KindRow | undefined
    const result = BinaryPacker.unpack(raw, layout.on((value) => {
      got = value as KindRow
    }))
    assert.equal(result.ok, true)
    assert.deepEqual(got!.kinds, [0, 1, 2, 3])
  })

  it("width 1 bias minus one writes eight bits or none", () => {
    type KindRow = { n: number; kinds: number[] }
    const layout = scheme<KindRow>(
      1,
      u8(0, (r) => r.n),
      packed(1, 1, (r) => r.kinds, 0, -1),
    )
    const eight = BinaryPacker.pack(layout, {
      n: 9,
      kinds: [1, 1, 1, 1, 1, 1, 1, 1],
    })
    assert.equal(toHex(eight.subarray(2)), "ff")
    const none = BinaryPacker.pack(layout, { n: 1, kinds: [] })
    assert.equal(none.length - 2, 0)
    let got: KindRow | undefined
    const result = BinaryPacker.unpack(none, layout.on((value) => {
      got = value as KindRow
    }))
    assert.equal(result.ok, true)
    assert.deepEqual(got!.kinds, [])
  })

  it("length mismatch names the field", () => {
    type KindRow = { n: number; kinds: number[] }
    const layout = scheme<KindRow>(
      1,
      u8(0, (r) => r.n),
      packed(2, 1, (r) => r.kinds, 0),
    )
    let produced: Uint8Array | null = null
    assert.throws(
      () => {
        produced = BinaryPacker.pack(layout, { n: 2, kinds: [1] })
      },
      (err: unknown) =>
        err instanceof RangeError && String(err.message).includes("kinds"),
    )
    assert.equal(produced, null)
  })

  it("times stops so the next field is read", () => {
    type TailRow = { n: number; lat: number; lon: number; tail: number }
    const layout = scheme<TailRow>(
      1,
      u8(0, (r) => r.n),
      times(0, [i32(1, (r) => r.lat), i32(2, (r) => r.lon)]),
      u8(3, (r) => r.tail),
    )
    const raw = BinaryPacker.pack(layout, {
      n: 2,
      lat: [10, 30] as unknown as number,
      lon: [20, 40] as unknown as number,
      tail: 7,
    })
    assert.equal(toHex(raw.subarray(1)), "020a000000140000001e0000002800000007")
    let got: TailRow | undefined
    const result = BinaryPacker.unpack(raw, layout.on((value) => {
      got = value as TailRow
    }))
    assert.equal(result.ok, true)
    assert.equal(got!.tail, 7)
    assert.deepEqual(got!.lat as unknown as number[], [10, 30])
    assert.deepEqual(got!.lon as unknown as number[], [20, 40])
  })

  it("route matches fixture and rejects a short tail", () => {
    const raw = Uint8Array.from(Buffer.from(ROUTE_HEX, "hex"))
    let got: RouteRow | undefined
    const result = BinaryPacker.unpack(raw, route.on((value) => {
      got = value as RouteRow
    }))
    assert.equal(result.ok, true)
    assert.equal(got!.sid, 16)
    assert.equal(got!.name, 21)
    assert.equal(got!.unit, undefined)
    assert.equal(got!.straight, true)
    assert.equal(got!.routeId, 45)
    assert.equal(got!.count, 2)
    assert.deepEqual(got!.kinds, [1, 3])
    assert.deepEqual(got!.lat as unknown as number[], [500000000, 500010000])
    assert.deepEqual(got!.lon as unknown as number[], [300000000, 300010000])
    assert.deepEqual(got!.mask, [1])

    const packedAgain = BinaryPacker.pack(route, got!)
    assert.equal(toHex(packedAgain), ROUTE_HEX)

    let shortRan = false
    const short = BinaryPacker.unpack(raw.subarray(0, 24), route.on(() => {
      shortRan = true
    }))
    assert.equal(short.ok, false)
    if (short.ok) return
    assert.equal(short.field, "lon")
    assert.equal(short.needed, 4)
    assert.equal(short.left, 2)
    assert.equal(
      Object.keys(short).filter(
        (k) => k !== "ok" && k !== "field" && k !== "needed" && k !== "left",
      ).length,
      0,
    )
    assert.equal(shortRan, false)
  })
})

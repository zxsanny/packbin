import { spawnSync } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  flags,
  i16,
  i32,
  scheme,
  u8,
  u16,
  utf8,
} from "../src/index.ts"

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, "../..")
const goldenHex = readFileSync(join(root, "fixtures/golden.hex"), "utf8").trim()
const expectedHex = "4001000065cd1d00a3e1110100"

class UserModifiedEvent {
  userId = 0
  userNameChange = ""
  userEmailChange = ""
  userStatusChange = 0
}

class UserPositionEvent {
  userId = 0
  latitude = 0
  longitude = 0
}

const ModifiedScheme = scheme<UserModifiedEvent>(
  1,
  i32(0, (r) => r.userId),
  utf8(1, (r) => r.userNameChange),
  utf8(2, (r) => r.userEmailChange),
  u8(3, (r) => r.userStatusChange),
)

const PositionScheme = scheme<UserPositionEvent>(
  2,
  i32(0, (r) => r.userId),
  i32(1, (r) => r.latitude),
  i32(2, (r) => r.longitude),
)

type Position = {
  sid: number
  lat: number
  lon: number
  profile: number
  heading?: number
  speed?: number
  altitude?: number
}

const position = scheme<Position>(
  0x40,
  u16(0, (r) => r.sid),
  i32(1, (r) => r.lat),
  i32(2, (r) => r.lon),
  u8(3, (r) => r.profile),
  flags([
    u16(4, (r) => r.heading),
    u8(5, (r) => r.speed),
    i16(6, (r) => r.altitude),
  ]),
)

function toHex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("hex")
}

describe("scheme", () => {
  it("AC-1 entry is BinaryPacker", () => {
    const source = readFileSync(join(here, "../src/index.ts"), "utf8")
    const fields = readFileSync(join(here, "../src/fields.ts"), "utf8")
    const walker = readFileSync(join(here, "../src/walker.ts"), "utf8")
    assert.equal(/\bBinaryPacker\b/.test(source), true)
    assert.equal(/\bexport function pack\b/.test(source), false)
    assert.equal(/\bexport function unpack\b/.test(source), false)
    for (const blob of [source, fields, walker]) {
      assert.equal(/\bPacket\b/.test(blob), false)
      assert.equal(/\btypeNum\b/.test(blob), false)
    }
    const s = scheme(32, u8(0, (r: { sid: number }) => r.sid))
    assert.equal(s.typeNumber, 32)
    assert.equal(toHex(BinaryPacker.pack(s, { sid: 23 })), "2017")
  })

  it("AC-2 position golden has no type member", () => {
    class PositionRow {
      sid = 1
      lat = 500_000_000
      lon = 300_000_000
      profile = 1
    }
    const row = new PositionRow()
    assert.equal("type" in row, false)
    const bytes = BinaryPacker.pack(position, row)
    assert.equal(toHex(bytes), expectedHex)
    assert.equal(toHex(bytes), goldenHex)
    let back: Position | undefined
    const result = BinaryPacker.unpack(bytes, position.on((value) => {
      back = value as Position
    }))
    assert.equal(result.ok, true)
    assert.ok(back)
    assert.equal("type" in back!, false)
    assert.equal(Object.prototype.hasOwnProperty.call(back!, "type"), false)
  })

  it("AC-3 known scheme checks the leading byte", () => {
    const layout = scheme(1, u8(0, (r: { sid: number }) => r.sid))
    let ran = false
    const got = BinaryPacker.unpack(
      Uint8Array.of(2, 23),
      layout.on(() => {
        ran = true
      }),
    )
    assert.equal(got.ok, false)
    if (got.ok) return
    assert.equal(got.actual, 2)
    assert.equal(ran, false)
    assert.equal(
      Object.keys(got).filter((k) => k !== "ok" && k !== "actual").length,
      0,
    )
  })

  it("AC-4 unknown buffer calls the matching handler", () => {
    const row = new UserPositionEvent()
    row.userId = 7
    row.latitude = 8
    row.longitude = 9
    const bytes = BinaryPacker.pack(PositionScheme, row)
    assert.equal(toHex(bytes), "02070000000800000009000000")

    let modified = 0
    let positionHits = 0
    let seen: UserPositionEvent | null = null
    const result = BinaryPacker.unpack(
      bytes,
      ModifiedScheme.on(() => {
        modified++
      }),
      PositionScheme.on((ev) => {
        positionHits++
        seen = ev
      }),
    )
    assert.equal(result.ok, true)
    assert.equal(modified, 0)
    assert.equal(positionHits, 1)
    assert.ok(seen)
    assert.equal(seen!.userId, 7)
    assert.equal(seen!.latitude, 8)
    assert.equal(seen!.longitude, 9)
    assert.equal("type" in seen!, false)
  })

  it("AC-5 unknown type number", () => {
    let modified = 0
    let positionHits = 0
    const result = BinaryPacker.unpack(
      Uint8Array.of(9),
      ModifiedScheme.on(() => {
        modified++
      }),
      PositionScheme.on(() => {
        positionHits++
      }),
    )
    assert.equal(result.ok, false)
    if (result.ok) return
    assert.equal(result.actual, 9)
    assert.equal("expected" in result && result.expected !== undefined, false)
    assert.equal(modified, 0)
    assert.equal(positionHits, 0)
  })

  it("AC-6 type numbers in one call are unique", () => {
    assert.throws(() => {
      BinaryPacker.unpack(
        Uint8Array.of(1),
        ModifiedScheme.on(() => {}),
        scheme<UserModifiedEvent>(1, i32(0, (r) => r.userId)).on(() => {}),
      )
    })
  })

  it("scheme argument is required", () => {
    const fixtureDir = join(here, "compile-fail")
    assert.equal(existsSync(join(fixtureDir, "pack-without-scheme.ts")), true)
    assert.equal(existsSync(join(fixtureDir, "tsconfig.json")), true)
    const tscJs = join(here, "../node_modules/typescript/lib/tsc.js")
    assert.equal(existsSync(tscJs), true, "typescript must be installed under typescript/")
    const result = spawnSync(process.execPath, [tscJs, "-p", fixtureDir], {
      encoding: "utf8",
    })
    assert.notEqual(
      result.status,
      0,
      `expected tsc failure, exit=${result.status}\n${result.stdout}\n${result.stderr}`,
    )
  })
})

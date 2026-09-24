import { spawnSync } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  flags,
  i16,
  i32,
  pack,
  scheme,
  u8,
  u16,
  unpack,
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
  i32("userId"),
  utf8("userNameChange"),
  utf8("userEmailChange"),
  u8("userStatusChange"),
)

const PositionScheme = scheme<UserPositionEvent>(
  2,
  i32("userId"),
  i32("latitude"),
  i32("longitude"),
)

const position = scheme(
  0x40,
  u16("sid"),
  i32("lat"),
  i32("lon"),
  u8("profile"),
  flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
)

const positionValue = {
  sid: 1,
  lat: 500_000_000,
  lon: 300_000_000,
  profile: 1,
}

function toHex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("hex")
}

describe("scheme", () => {
  it("AC-1 Packet and BinaryPacker are absent", () => {
    const source = readFileSync(join(here, "../src/index.ts"), "utf8")
    const fields = readFileSync(join(here, "../src/fields.ts"), "utf8")
    const walker = readFileSync(join(here, "../src/walker.ts"), "utf8")
    for (const blob of [source, fields, walker]) {
      assert.equal(/\bPacket\b/.test(blob), false)
      assert.equal(/\bBinaryPacker\b/.test(blob), false)
      assert.equal(/\btypeNum\b/.test(blob), false)
    }
    const s = scheme(32, u8("sid"))
    assert.equal(s.typeNumber, 32)
    assert.equal(toHex(pack(s, { sid: 23 })), "2017")
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
    const bytes = pack(position, row)
    assert.equal(toHex(bytes), expectedHex)
    assert.equal(toHex(bytes), goldenHex)
    const back = unpack(position, bytes)
    assert.equal(back.ok, true)
    if (!back.ok) return
    assert.equal("type" in back.value, false)
    assert.equal(Object.prototype.hasOwnProperty.call(back.value, "type"), false)
  })

  it("AC-3 known scheme checks the leading byte", () => {
    const layout = scheme(1, u8("sid"))
    const got = unpack(layout, Uint8Array.of(2, 23))
    assert.equal(got.ok, false)
    if (got.ok) return
    assert.equal("expected" in got, true)
    if (!("expected" in got)) return
    assert.equal(got.expected, 1)
    assert.equal(got.actual, 2)
    assert.equal(
      Object.keys(got).filter(
        (k) => k !== "ok" && k !== "expected" && k !== "actual",
      ).length,
      0,
    )
  })

  it("AC-4 unknown buffer calls the matching handler", () => {
    const row = new UserPositionEvent()
    row.userId = 7
    row.latitude = 8
    row.longitude = 9
    const bytes = pack(PositionScheme, row)
    assert.equal(toHex(bytes), "02070000000800000009000000")

    let modified = 0
    let position = 0
    let seen: UserPositionEvent | null = null
    const result = unpack(
      bytes,
      ModifiedScheme.on(() => {
        modified++
      }),
      PositionScheme.on((ev) => {
        position++
        seen = ev
      }),
    )
    assert.equal(result.ok, true)
    assert.equal(modified, 0)
    assert.equal(position, 1)
    assert.ok(seen)
    assert.equal(seen!.userId, 7)
    assert.equal(seen!.latitude, 8)
    assert.equal(seen!.longitude, 9)
    assert.equal("type" in seen!, false)
  })

  it("AC-5 unknown type number", () => {
    let modified = 0
    let position = 0
    const result = unpack(
      Uint8Array.of(9),
      ModifiedScheme.on(() => {
        modified++
      }),
      PositionScheme.on(() => {
        position++
      }),
    )
    assert.equal(result.ok, false)
    if (result.ok) return
    assert.equal(result.actual, 9)
    assert.equal("expected" in result && result.expected !== undefined, false)
    assert.equal(modified, 0)
    assert.equal(position, 0)
  })

  it("AC-6 type numbers in one call are unique", () => {
    assert.throws(() => {
      unpack(
        Uint8Array.of(1),
        ModifiedScheme.on(() => {}),
        scheme<UserModifiedEvent>(1, i32("userId")).on(() => {}),
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

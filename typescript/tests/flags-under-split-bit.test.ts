import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  flagByte,
  flags,
  group,
  i16,
  i32,
  scheme,
  u8,
  u16,
  type Field,
} from "../src/index.ts"
import { ACCESSORS, NAMES, random, type Name } from "./support/random.ts"

type Row = Record<string, unknown>

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")
const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

function unpack(layout: Scheme<Row>, wire: string | Uint8Array): { result: unknown; row: Row | undefined } {
  let row: Row | undefined
  const bytes = typeof wire === "string" ? Buffer.from(wire, "hex") : wire
  const result = BinaryPacker.unpack(bytes, layout.on((r) => {
    row = r as Row
  }))
  return { result, row }
}

// The scheme of the spec: a split flag bit holds a group that holds a flags.
function splitBit(): Scheme<Row> {
  const fb = flagByte("m")
  return scheme<Row>(
    1,
    fb,
    fb.bit(group((x) => x.g, [u8(0, (x) => x.a), flags(1, [u8(1, (x) => x.c)])])),
  )
}

const flagsInFlags = () => scheme<Row>(1, flags(0, [flags(0, [u8(0, (x) => x.c)])]))

describe("flags under a split flag bit and flags directly inside flags", () => {
  it("AC-1 flags in a group under a split bit are packed", () => {
    // Arrange
    const layout = splitBit()

    // Act
    const wire = hex(BinaryPacker.pack(layout, { g: { a: 1, c: 2 } }))

    // Assert
    assert.equal(wire, "0101010102")
  })

  it("AC-2 unpack then repack gives the same row and bytes", () => {
    // Arrange
    const layout = splitBit()

    // Act
    const { result, row } = unpack(layout, "0101010102")
    const again = hex(BinaryPacker.pack(layout, row!))

    // Assert
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(row, { a: 1, c: 2 })
    assert.equal(again, "0101010102")
  })

  it("AC-3 absent values stay absent", () => {
    // Arrange
    const layout = splitBit()

    // Act
    const partial = hex(BinaryPacker.pack(layout, { g: { a: 1 } }))
    const empty = hex(BinaryPacker.pack(layout, {}))

    // Assert
    assert.deepEqual([partial, empty], ["01010100", "0100"])
  })

  it("AC-4 a missing required member in a present group is still named", () => {
    // Arrange
    const layout = splitBit()

    // Act
    const nested = () => BinaryPacker.pack(layout, { g: { c: 2 } })
    const flat = () => BinaryPacker.pack(layout, { c: 2 })

    // Assert
    assert.throws(nested, new RangeError("missing a"))
    assert.throws(flat, new RangeError("missing a"))
  })

  it("AC-5 flags directly inside flags are packed", () => {
    // Arrange
    const layout = flagsInFlags()

    // Act
    const present = hex(BinaryPacker.pack(layout, { c: 2 }))
    const absent = hex(BinaryPacker.pack(layout, {}))

    // Assert
    assert.deepEqual([present, absent], ["01010102", "0100"])
  })

  it("AC-5 flags inside flags unpack and repack to the same bytes", () => {
    // Arrange
    const layout = flagsInFlags()

    // Act
    const { row } = unpack(layout, "01010102")
    const again = hex(BinaryPacker.pack(layout, row!))

    // Assert
    assert.deepEqual(row, { c: 2 })
    assert.equal(again, "01010102")
  })

  it("flags three deep are packed and read back", () => {
    // Arrange
    const layout = scheme<Row>(1, flags(0, [flags(0, [flags(0, [u8(0, (x) => x.c)])])]))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { c: 9 }))
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(wire, "0101010109")
    assert.deepEqual(row, { c: 9 })
  })

  it("a split bit that holds flags directly packs them", () => {
    // Arrange
    const fb = flagByte("m")
    const layout = scheme<Row>(1, fb, fb.bit(flags(0, [u8(0, (x) => x.c)])))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { c: 3 }))
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(wire, "01010103")
    assert.deepEqual(row, { c: 3 })
  })

  it("two flags in one group under a split bit each keep their own flag byte", () => {
    // Arrange
    const fb = flagByte("m")
    const layout = scheme<Row>(
      1,
      fb,
      fb.bit(group((x) => x.g, [flags(0, [u8(0, (x) => x.c)]), flags(1, [u8(1, (x) => x.d)])])),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { c: 1, d: 2 }))
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(wire, "010101010102")
    assert.deepEqual(row, { c: 1, d: 2 })
  })

  it("AC-7 the position golden bytes are unchanged", () => {
    // Arrange
    const golden = readFileSync(join(root, "fixtures/golden.hex"), "utf8").trim()
    const position = scheme<Row>(
      0x40,
      u16(0, (x) => x.sid),
      i32(1, (x) => x.lat),
      i32(2, (x) => x.lon),
      u8(3, (x) => x.profile),
      flags(4, [u16(4, (x) => x.heading), u8(5, (x) => x.speed), i16(6, (x) => x.altitude)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(position, { sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1 }))

    // Assert
    assert.equal(wire, golden)
  })
})

// A seeded generator over the two shapes: schemes with a split bit holding a group that holds flags, and
// flags inside flags, with random values present. Every name is its own accessor, drawn once.
type Gen = { rand: () => number; unused: Name[]; leaves: string[] }
type Scope = { next: number }

function name(gen: Gen): Name {
  return gen.unused.shift()!
}

function leaf(gen: Gen, scope: Scope): Field {
  const n = name(gen)
  gen.leaves.push(n)
  const id = scope.next++
  return gen.rand() < 0.5 ? u8(id, ACCESSORS[n]) : u16(id, ACCESSORS[n])
}

// Optional members: a `flags` holds leaves, a nested `flags` or an unanchored group of its own.
function optional(gen: Gen, scope: Scope, depth: number): Field {
  const anchor = scope.next
  const members: Field[] = []
  const count = 1 + Math.floor(gen.rand() * 2)
  for (let i = 0; i < count; i++) {
    const pick = gen.rand()
    const room = gen.unused.length > 7
    if (room && depth > 0 && pick < 0.35) members.push(optional(gen, scope, depth - 1))
    else if (room && depth > 0 && pick < 0.6) members.push(owned(gen, depth - 1))
    else members.push(leaf(gen, scope))
  }
  return flags(anchor, members)
}

// An unanchored group counts its field ids from 0. It holds an optional member or a nested group, and
// sometimes a required leaf, so a group can hold nothing but flags.
function owned(gen: Gen, depth: number): Field {
  const own: Scope = { next: 0 }
  const label = name(gen)
  const members: Field[] = []
  if (gen.rand() < 0.4) members.push(leaf(gen, own))
  members.push(optional(gen, own, depth))
  return group(ACCESSORS[label], members)
}

function generate(rand: () => number): { layout: Scheme<Row>; leaves: string[] } {
  const gen: Gen = { rand, unused: [...NAMES], leaves: [] }
  if (rand() < 0.5) {
    const fb = flagByte("m")
    return { layout: scheme<Row>(1, fb, fb.bit(owned(gen, 2))), leaves: gen.leaves }
  }
  const top: Scope = { next: 0 }
  return { layout: scheme<Row>(1, optional(gen, top, 2)), leaves: gen.leaves }
}

describe("flags under a split bit and inside flags: repack identity fuzz", () => {
  it("AC-6 no accepted packet changes its row on repack", () => {
    // Arrange
    const rand = random(2183)
    let accepted = 0
    let changed = 0

    for (let n = 0; n < 400; n++) {
      const { layout } = generate(rand)
      for (let p = 0; p < 60; p++) {
        const wire = new Uint8Array(1 + Math.floor(rand() * 8))
        wire[0] = 1
        for (let i = 1; i < wire.length; i++) wire[i] = Math.floor(rand() * 4) === 0 ? 255 : Math.floor(rand() * 256)

        // Act
        const first = unpack(layout, wire)
        if ((first.result as { ok: boolean }).ok !== true) continue
        accepted++
        const again = unpack(layout, BinaryPacker.pack(layout, first.row!))
        if (JSON.stringify(first.row) !== JSON.stringify(again.row)) changed++
      }
    }

    // Assert
    assert.ok(accepted > 1000, `only ${accepted} packets were accepted`)
    assert.equal(changed, 0)
  })

  it("AC-6 a row with random values present packs to bytes that read back as the row", () => {
    // Arrange
    const rand = random(2184)
    let packed = 0
    let refused = 0
    let broken = 0

    for (let n = 0; n < 600; n++) {
      const { layout, leaves } = generate(rand)
      for (let r = 0; r < 20; r++) {
        const row: Row = {}
        for (const leaf of leaves) if (rand() < 0.5) row[leaf] = Math.floor(rand() * 200)

        // Act
        let wire: Uint8Array
        try {
          wire = BinaryPacker.pack(layout, row)
        } catch (e) {
          // A group that holds a value but not its required leaf is refused, naming the leaf.
          assert.ok(e instanceof RangeError && /^missing \w$/.test(e.message), String(e))
          refused++
          continue
        }
        packed++
        const back = unpack(layout, wire)
        const same = JSON.stringify(back.row, Object.keys(row).sort()) === JSON.stringify(row, Object.keys(row).sort())
        if ((back.result as { ok: boolean }).ok !== true || !same) broken++
        if (hex(BinaryPacker.pack(layout, back.row!)) !== hex(wire)) broken++
      }
    }

    // Assert
    assert.ok(packed > 2000, `only ${packed} rows were packed`)
    assert.ok(refused > 0)
    assert.equal(broken, 0)
  })
})

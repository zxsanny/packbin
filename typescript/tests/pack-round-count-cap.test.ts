import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, Scheme, flags, scheme, times, u8, u16, u32, type DispatchResult } from "../src/index.ts"

type Row = Record<string, unknown>

const refusal = (run: () => unknown): string => {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

const timesK = (limits = {}): Scheme<Row> =>
  new Scheme<Row>(1, [u32(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.k)])], limits)

function unpack(layout: Scheme<Row>, bytes: Uint8Array): { result: DispatchResult; row?: Row } {
  let row: Row | undefined
  const result = BinaryPacker.unpack(bytes, layout.on((r) => { row = r as Row }))
  return { result, row }
}

describe("AZ-2329 pack refuses a times count above maxRounds", () => {
  it("AC-1 a count one past the limit with a lone scalar is refused naming the first body member", () => {
    // Arrange
    const layout = timesK()

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { n: Scheme.DefaultMaxRounds + 1, k: 7 }))

    // Assert
    assert.equal(message, "k: the times count is 65536, above the limit of 65535 rounds")
  })

  it("AC-1 a 4-billion count with a lone scalar is refused at once, before any round", () => {
    // Arrange
    const layout = timesK()
    const before = Date.now()

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { n: 4_000_000_000, k: 7 }))

    // Assert
    assert.match(message, /^k: the times count is 4000000000, above the limit of 65535 rounds$/)
    assert.ok(Date.now() - before < 1000, "the refusal does not loop over the rounds")
  })

  it("AC-1 a count over the limit with no value is refused by the limit, not by the missing value", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(timesK(), { n: 70_000 }))

    // Assert
    assert.match(message, /^k: the times count is 70000, above the limit of 65535 rounds$/)
  })

  it("AC-1 a lowered limit lowers what can be packed", () => {
    // Arrange
    const layout = timesK({ maxRounds: 3 })

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { n: 4, k: 7 }))

    // Assert
    assert.equal(message, "k: the times count is 4, above the limit of 3 rounds")
    assert.equal(Buffer.from(BinaryPacker.pack(layout, { n: 3, k: 7 })).toString("hex"), "0103000000070707")
  })

  it("AC-1 the limit holds for a times that is a member of flags", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u32(0, (x) => x.n),
      flags(1, [times(1, 0, [u8(1, (x) => x.k)]), u16(2, (x) => x.h)]),
    )

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { n: 65_536, k: 7, h: 1 }))

    // Assert
    assert.match(message, /^k: the times count is 65536, above the limit of 65535 rounds$/)
  })

  it("AC-2 a count at the limit packs and round-trips", () => {
    // Arrange
    const layout = timesK()

    // Act
    const wire = BinaryPacker.pack(layout, { n: Scheme.DefaultMaxRounds, k: 7 })
    const { result, row } = unpack(layout, wire)

    // Assert
    assert.equal(wire.length, 5 + Scheme.DefaultMaxRounds)
    assert.deepEqual(result, { ok: true })
    assert.equal((row!.k as number[]).length, Scheme.DefaultMaxRounds)
    assert.deepEqual(BinaryPacker.pack(layout, row!), wire)
  })

  it("AC-3 a scheme that raised maxRounds packs a larger count", () => {
    // Arrange
    const layout = timesK({ maxRounds: 70_000 })

    // Act
    const wire = BinaryPacker.pack(layout, { n: 70_000, k: 7 })

    // Assert
    assert.equal(wire.length, 5 + 70_000)
    assert.deepEqual(unpack(layout, wire).result, { ok: true })
  })

  it("AC-3 withLimits gives the copy its own limit", () => {
    // Arrange
    const base = timesK()
    const raised = base.withLimits({ maxRounds: 70_000 })

    // Act
    const raisedWire = BinaryPacker.pack(raised, { n: 66_000, k: 7 })

    // Assert
    assert.equal(raisedWire.length, 5 + 66_000)
    refusal(() => BinaryPacker.pack(base, { n: 66_000, k: 7 }))
  })
})

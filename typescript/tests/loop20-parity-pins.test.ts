import assert from "node:assert/strict"
import { describe, it } from "node:test"
import ts from "typescript"
import { BinaryPacker, eq, flagByte, flags, scheme, times, u8, when, type Scheme } from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const refusal = (run: () => unknown): string => {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

// AZ-2356: a split bit whose times count is written after the flag byte.
function countAfterByte(): Scheme<Row> {
  const fb = flagByte("fb")
  return scheme<Row>(1, fb, u8(0, (x) => x.n), fb.bit(times(1, 0, [u8(1, (x) => x.pt)])))
}

// AZ-2360: a combined flags whose first member is the count of its second.
const combinedCount = (): Scheme<Row> =>
  scheme<Row>(1, flags(0, [u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.pt)])]))

// AZ-2363: a times inside a when inside a split bit; its count n sits under a when that is false for mode 1.
function timesInWhen(): Scheme<Row> {
  const fb = flagByte("fb")
  return scheme<Row>(
    1,
    u8(0, (x) => x.mode),
    when(1, eq(0, 9), [u8(1, (x) => x.n)]),
    fb,
    fb.bit(when(2, eq(0, 1), [times(2, 1, [u8(2, (x) => x.pt)])])),
  )
}

const DROPPED_SPLIT =
  "pt: a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte"

describe("AZ-2356 a split count of 0 written after the byte", () => {
  it("AC-1 with a list of values is refused naming the member", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(countAfterByte(), { n: 0, pt: [5, 6] }))

    // Assert
    assert.equal(message, "pt: 2 items, times count 0")
  })

  it("AC-2 with a lone scalar packs zero rounds", () => {
    // Act
    const wire = hex(BinaryPacker.pack(countAfterByte(), { n: 0, pt: 5 }))

    // Assert
    assert.equal(wire, "010000")
  })
})

describe("AZ-2360 a combined flags times whose count is skipped", () => {
  it("AC-1 with values is refused naming the member", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(combinedCount(), { pt: [5, 6] }))

    // Assert
    assert.equal(
      message,
      "pt: a value is given, but the count of its times is not written, so its bit is clear; write the count before the times",
    )
  })

  it("AC-1 a lone scalar is a value too", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(combinedCount(), { pt: 5 }))

    // Assert
    assert.match(message, /^pt: a value is given/)
  })

  it("AC-2 with no values, or an empty list, the bit packs clear as before", () => {
    // Act
    const none = hex(BinaryPacker.pack(combinedCount(), {}))
    const empty = hex(BinaryPacker.pack(combinedCount(), { pt: [] }))
    const counted = hex(BinaryPacker.pack(combinedCount(), { n: 2, pt: [5, 6] }))

    // Assert
    assert.deepEqual([none, empty, counted], ["0100", "0100", "0103020506"])
  })

  it("a times under a when inside combined flags is refused the same way; a false when stays silent", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.mode),
      flags(1, [u8(1, (x) => x.n), when(2, eq(0, 1), [times(2, 1, [u8(2, (x) => x.pt)])])]),
    )

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { mode: 1, pt: [5] }))
    const falseCondition = hex(BinaryPacker.pack(layout, { mode: 0, pt: [5] }))

    // Assert
    assert.match(message, /^pt: a value is given, but the count of its times is not written/)
    assert.equal(falseCondition, "010000")
  })
})

describe("AZ-2363 a times inside a when inside a split bit, its count never written", () => {
  it("AC-1 with values is refused naming the member", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(timesInWhen(), { mode: 1, pt: [5, 6] }))

    // Assert
    assert.equal(message, DROPPED_SPLIT)
  })

  it("AC-1 the same with the when condition written after the byte", () => {
    // Arrange
    const fb = flagByte("fb")
    const layout = scheme<Row>(
      1,
      fb,
      u8(0, (x) => x.mode),
      when(1, eq(0, 9), [u8(1, (x) => x.n)]),
      fb.bit(when(2, eq(0, 1), [times(2, 1, [u8(2, (x) => x.pt)])])),
    )

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { mode: 1, pt: [5, 6] }))
    const noValues = hex(BinaryPacker.pack(layout, { mode: 1 }))
    const falseCondition = hex(BinaryPacker.pack(layout, { mode: 2, pt: [5, 6] }))

    // Assert
    assert.equal(message, DROPPED_SPLIT)
    assert.deepEqual([noValues, falseCondition], ["010001", "010002"])
  })
})

describe("AZ-2359 a numeric enum member in a u8 slot", () => {
  it("AC-1 packs the integer's byte: a TypeScript numeric enum is a plain number at runtime", async () => {
    // Arrange: the enum as tsc emits it (node's type stripping cannot run enum syntax).
    const js = ts.transpileModule("export enum Level { Low = 7, High = 200 }", {
      compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
    }).outputText
    const { Level } = (await import(`data:text/javascript,${encodeURIComponent(js)}`)) as {
      Level: Record<string, number>
    }
    const layout = scheme<Row>(1, u8(0, (x) => x.level))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { level: Level.High }))

    // Assert
    assert.equal(typeof Level.High, "number")
    assert.equal(wire, "01c8")
  })

  it("AC-1 a string enum member is not a number and is refused naming the field", async () => {
    // Arrange
    const js = ts.transpileModule('export enum Mode { Fast = "fast" }', {
      compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
    }).outputText
    const { Mode } = (await import(`data:text/javascript,${encodeURIComponent(js)}`)) as {
      Mode: Record<string, string>
    }

    // Act
    const message = refusal(() => BinaryPacker.pack(scheme<Row>(1, u8(0, (x) => x.level)), { level: Mode.Fast }))

    // Assert
    assert.equal(message, "level: expected a number for u8, got string")
  })
})

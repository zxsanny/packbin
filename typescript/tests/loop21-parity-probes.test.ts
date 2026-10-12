import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bits,
  eq,
  flagByte,
  flags,
  packed,
  sized,
  times,
  u8,
  u16,
  when,
  type Field,
} from "../src/index.ts"

// Loop 21 parity rows U4 (AZ-2384), U6 (AZ-2386) and U7 (AZ-2387) for TypeScript, pinned as the reference
// rows of `_docs/03_implementation/reference_loop21_slots.md`.

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const pack = (layout: Scheme<Row>, row: Row): string => hex(BinaryPacker.pack(layout, row))

const refusal = (run: () => unknown): string => {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

const DROPPED_BEFORE_BYTE =
  "pt: a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte"

// U4: u8 n written after the flag byte; bit 0 { times(n) { u8 pt } }; bit 1 { u16 heading }.
function splitCountAfterByte(): Scheme<Row> {
  const fb = flagByte("fb")
  return new Scheme<Row>(1, [
    fb,
    u8(0, (x) => x.n),
    fb.bit(times(1, 0, [u8(1, (x) => x.pt)])),
    fb.bit(u16(2, (x) => x.heading)),
  ])
}

describe("AZ-2384 U4 a split-bit times with count above 0 after the byte and an absent body packs a clear bit", () => {
  it("AC-1 the body absent packs flag 02, n = 2, heading", () => {
    // Act
    const wire = pack(splitCountAfterByte(), { n: 2, heading: 90 })

    // Assert
    assert.equal(wire, "0102025a00")
  })

  it("AC-1 the body [] packs the same bytes", () => {
    // Act
    const wire = pack(splitCountAfterByte(), { n: 2, pt: [], heading: 90 })

    // Assert
    assert.equal(wire, "0102025a00")
  })

  it("AC-1 count 0 after the byte with the body absent packs a clear bit too", () => {
    // Act
    const wire = pack(splitCountAfterByte(), { n: 0, heading: 90 })

    // Assert
    assert.equal(wire, "0102005a00")
  })

  it("AC-2 the body present is refused: the count is written after the byte that decides the bit", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(splitCountAfterByte(), { n: 2, pt: [5, 6], heading: 90 }))

    // Assert
    assert.equal(message, DROPPED_BEFORE_BYTE)
  })
})

// U6: u8 mode; when mode == 1 { u8 c }; split byte; bit 0 { times(c) { u8 pt } }; bit 1 { u16 heading }.
function countBehindWhen(): Scheme<Row> {
  const fb = flagByte("fb")
  return new Scheme<Row>(1, [
    u8(0, (x) => x.mode),
    when(1, eq(0, 1), [u8(1, (x) => x.c)]),
    fb,
    fb.bit(times(2, 1, [u8(2, (x) => x.pt)])),
    fb.bit(u16(3, (x) => x.heading)),
  ])
}

const COUNT_NOT_WRITTEN = (n: number): string =>
  `pt: the count c is ${n} in the row, but no field wrote it (the when that holds it is clear), so its times reads no round; give the count 0, leave it out, or make the when hold`

describe("AZ-2386 U6 a count above 0 behind a clear when, with no rounds, is refused", () => {
  it("AC-1 count 1, body absent: refused naming the member, no bytes (packed 0100025a00 before)", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(countBehindWhen(), { mode: 0, c: 1, heading: 90 }))

    // Assert
    assert.equal(message, COUNT_NOT_WRITTEN(1))
  })

  it("AC-1 count 1, body []: refused the same way", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(countBehindWhen(), { mode: 0, c: 1, pt: [], heading: 90 }))

    // Assert
    assert.equal(message, COUNT_NOT_WRITTEN(1))
  })

  it("AC-1 count 2 in the combined flags form is refused the same way", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [
      u8(0, (x) => x.mode),
      when(1, eq(0, 1), [u8(1, (x) => x.c)]),
      flags(2, [times(2, 1, [u8(2, (x) => x.pt)]), u16(3, (x) => x.heading)]),
    ])

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { mode: 0, c: 2, heading: 90 }))

    // Assert
    assert.equal(message, COUNT_NOT_WRITTEN(2))
  })

  it("AC-1 a bigint count above 0 is refused too", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(countBehindWhen(), { mode: 0, c: 3n, heading: 90 }))

    // Assert
    assert.equal(message, COUNT_NOT_WRITTEN(3))
  })

  it("AC-2 count 0 and the count left out pack as before", () => {
    // Act
    const zero = pack(countBehindWhen(), { mode: 0, c: 0, heading: 90 })
    const left = pack(countBehindWhen(), { mode: 0, heading: 90 })

    // Assert
    assert.equal(zero, "0100025a00")
    assert.equal(left, "0100025a00")
  })

  it("AC-2 values given with the count never written keep their own error", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(countBehindWhen(), { mode: 0, c: 2, pt: [5, 6], heading: 90 }))

    // Assert
    assert.equal(message, DROPPED_BEFORE_BYTE)
  })

  it("AC-2 a holding when packs the rounds as before", () => {
    // Act
    const wire = pack(countBehindWhen(), { mode: 1, c: 1, pt: [5], heading: 90 })

    // Assert
    assert.equal(wire, "01010103055a00")
  })

  it("AC-2 a plain times behind a clear when is refused at any count, as before", () => {
    // Arrange
    const plain = new Scheme<Row>(1, [
      u8(0, (x) => x.mode),
      when(1, eq(0, 1), [u8(1, (x) => x.c)]),
      times(2, 1, [u8(2, (x) => x.pt)]),
      u16(3, (x) => x.heading),
    ])

    // Act
    const one = refusal(() => BinaryPacker.pack(plain, { mode: 0, c: 1, heading: 90 }))
    const zero = refusal(() => BinaryPacker.pack(plain, { mode: 0, c: 0, heading: 90 }))

    // Assert
    assert.equal(one, "times: count c was not written")
    assert.equal(zero, "times: count c was not written")
  })
})

// U7: u8 mode; when mode == 1 { u8 c }; then bits / packed / sized counted by c.
const kinds: { kind: string; member: () => Field; value: unknown; setHex: string; splitSetHex: string }[] = [
  { kind: "bits", member: () => bits(2, (x) => x.v, 1), value: [1, 0, 1], setHex: "01010305", splitSetHex: "0101030105" },
  { kind: "packed", member: () => packed(1, 2, (x) => x.v, 1), value: [1, 0, 1], setHex: "01010305", splitSetHex: "0101030105" },
  {
    kind: "sized",
    member: () => sized(2, (x) => x.v, 1),
    value: new Uint8Array([1, 2, 3]),
    setHex: "010103010203",
    splitSetHex: "01010301010203",
  },
]

for (const { kind, member, value, setHex, splitSetHex } of kinds) {
  const head = (): Field[] => [u8(0, (x) => x.mode), when(1, eq(0, 1), [u8(1, (x) => x.c)])]
  const plain = (): Scheme<Row> => new Scheme<Row>(1, [...head(), member()])
  const split = (): Scheme<Row> => {
    const fb = flagByte("fb")
    return new Scheme<Row>(1, [...head(), fb, fb.bit(member())])
  }
  const combined = (): Scheme<Row> => new Scheme<Row>(1, [...head(), flags(2, [member()])])

  describe(`AZ-2387 U7 a ${kind} count behind a clear when`, () => {
    it("AC-1 plain, split bit and combined flags refuse the value, naming the member", () => {
      // Act
      const messages = [plain(), split(), combined()].map((layout) =>
        refusal(() => BinaryPacker.pack(layout, { mode: 0, c: 3, v: value })),
      )

      // Assert
      assert.deepEqual(messages, ["v: count c was not written", "v: count c was not written", "v: count c was not written"])
    })

    it("AC-2 a holding when packs as before", () => {
      // Act
      const wires = [pack(plain(), { mode: 1, c: 3, v: value }), pack(split(), { mode: 1, c: 3, v: value })]

      // Assert
      assert.deepEqual(wires, [setHex, splitSetHex])
    })

    it("with no value given and count 3, a split bit or combined flags is refused since loop 22 (U11, packed 010000 before)", () => {
      // Act
      const messages = [split(), combined()].map((layout) => refusal(() => BinaryPacker.pack(layout, { mode: 0, c: 3 })))

      // Assert
      assert.deepEqual(messages, [
        "v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold",
        "v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold",
      ])
    })

    it("with no value given and count 0, a split bit or combined flags still packs a clear bit", () => {
      // Act
      const wires = [pack(split(), { mode: 0, c: 0 }), pack(combined(), { mode: 0, c: 0 })]

      // Assert
      assert.deepEqual(wires, ["010000", "010000"])
    })
  })
}

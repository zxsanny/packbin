import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, dict, group, list, scheme, u32, utf8 } from "../src/index.ts"

// AZ-4199: a list or dict whose element is a nested row of required members writes the members one after another, with
// no flag byte per element. The C# and Dart packages pin the same hex for the same scheme.

type Comment = { id: string; text: string; authorId: number; author: string }
type Frame = { items: Comment[]; map: Record<string, Comment> }

const hex = (bytes: Uint8Array): string => Buffer.from(bytes).toString("hex")

const members = () => [
  utf8(0, (x: any) => x.id),
  utf8(1, (x: any) => x.text),
  u32(2, (x: any) => x.authorId),
  utf8(3, (x: any) => x.author),
]

const c1: Comment = { id: "c1", text: "hi", authorId: 7, author: "ann" }
const c2: Comment = { id: "c2", text: "ok", authorId: 258, author: "bo" }
const c3: Comment = { id: "c3", text: "yes", authorId: 1, author: "cy" }

const empty = "010000"
const one = "010100" + "03106331" + "022aaa" + "07000000" + "03c91980"
const three =
  "010300" +
  "03106331" + "022aaa" + "07000000" + "03c91980" +
  "03106332" + "03106f6b" + "02010000" + "0310626f" +
  "03106333" + "03cb2200" + "01000000" + "03106379"
const mapped =
  "010200" +
  "021061" + "03106331" + "022aaa" + "07000000" + "03c91980" +
  "021062" + "03106332" + "03106f6b" + "02010000" + "0310626f"

describe("a list or dict of nested rows writes no flag byte per element", () => {
  const listed = scheme<Frame>(1, list((x) => x.items, group((x: any) => x.p, members())))

  for (const [name, items, wire] of [
    ["0 rows", [], empty],
    ["1 row", [c1], one],
    ["3 rows", [c1, c2, c3], three],
  ] as const) {
    it(`AZ-4199 ${name} pack to the pinned bytes and unpack equal`, () => {
      // Arrange
      const row = { items: [...items], map: {} }

      // Act
      const raw = BinaryPacker.pack(listed, row)
      let got: Frame | undefined
      const err = BinaryPacker.unpack(raw, listed.on((value) => { got = value }))

      // Assert
      assert.equal(hex(raw), wire)
      assert.equal(err.ok, true)
      assert.deepEqual(got?.items, items)
    })
  }

  it("AZ-4199 a dict of nested rows packs the keys in order, then the members", () => {
    // Arrange
    const keyed = scheme<Frame>(1, dict((x) => x.map, group((x: any) => x.p, members())))

    // Act
    const raw = BinaryPacker.pack(keyed, { items: [], map: { b: c2, a: c1 } })

    // Assert
    assert.equal(hex(raw), mapped)
  })
})

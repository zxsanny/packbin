// Probe of AZ-4242: a list or dict whose element is a row of required members (no flag byte per element). It
// builds each shape of ../README.md, packs the values given there and unpacks its own bytes. One line per shape:
// package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
// TypeScript is the reference: its bytes are the ones the other packages are compared with.
import {
  BinaryPacker,
  dict,
  eq,
  group,
  list,
  scheme,
  times,
  u8,
  u32,
  utf8,
  when,
  type Field,
  type Scheme,
} from "../../../../typescript/src/index.ts"

type Row = Record<string, unknown>

function oneLine(text: string): string {
  return text.replace(/\s+/g, " ").trim()
}

function refusal(e: unknown): string {
  return `refused: ${oneLine(e instanceof Error ? `${e.name}: ${e.message}` : String(e))}`
}

function hex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("")
}

// Keys in sorted order and an absent entry as null, so two rows that hold the same values print the same text.
// With `forCompare`, a name whose list is empty is left out: `times` of zero rounds unpacks to no key at all.
function shown(value: unknown, forCompare = false): string {
  return JSON.stringify(value, (_key, v: unknown) => {
    if (v === undefined) return null
    if (typeof v === "bigint") return Number(v)
    if (v !== null && typeof v === "object" && !Array.isArray(v)) {
      const entries = Object.entries(v as Row).filter(([, e]) => !(forCompare && Array.isArray(e) && e.length === 0))
      return Object.fromEntries(entries.sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)))
    }
    return v
  })
}

function probe(shape: string, build: () => Scheme<Row>, values: Row, expected: Row = values): void {
  const line = (b: string, p: string, u: string) => console.log(["typescript", shape, b, p, u].join("\t"))
  let s: Scheme<Row>
  try {
    s = build()
  } catch (e) {
    line(refusal(e), "-", "-")
    return
  }
  let packed: Uint8Array
  try {
    packed = BinaryPacker.pack(s, values)
  } catch (e) {
    line("built", refusal(e), "-")
    return
  }
  let got: Row | undefined
  let result: unknown
  try {
    result = BinaryPacker.unpack(
      packed,
      s.on((row) => {
        got = row
      }),
    )
  } catch (e) {
    line("built", hex(packed), `threw: ${oneLine(String(e))}`)
    return
  }
  if (got === undefined) {
    line("built", hex(packed), `refused: ${oneLine(shown(result))}`)
    return
  }
  line("built", hex(packed), shown(got, true) === shown(expected, true) ? "same" : `differs: ${shown(got)}`)
}

const na = (shape: string, why: string) => console.log(["typescript", shape, `n/a: ${why}`, "-", "-"].join("\t"))

// The element row of AZ-4199: four required members, ids 0 to 3.
const comment = (): Field =>
  group((r: Row) => r.p, [
    utf8(0, (r: Row) => r.id),
    utf8(1, (r: Row) => r.text),
    u32(2, (r: Row) => r.authorId),
    utf8(3, (r: Row) => r.author),
  ])

const c1 = { id: "c1", text: "hi", authorId: 7, author: "ann" }
const c2 = { id: "c2", text: "ok", authorId: 258, author: "bo" }
const c3 = { id: "c3", text: "yes", authorId: 1, author: "cy" }

const listed = () => scheme<Row>(1, list((r: Row) => r.items, comment()))
const keyed = () => scheme<Row>(1, dict((r: Row) => r.map, comment()))

probe("list-0", listed, { items: [] })
probe("list-1", listed, { items: [c1] })
probe("list-3", listed, { items: [c1, c2, c3] })
probe("dict-2", keyed, { map: { b: c2, a: c1 } })

// A TypeScript list field reads any array: there is no other collection type to name.
na("coll", "a list field takes a JavaScript array and a dict field an object; no other collection type")

// when inside an element row: speed is written only for mode 1.
probe(
  "when",
  () =>
    scheme<Row>(
      1,
      list(
        (r: Row) => r.items,
        group((r: Row) => r.p, [u8(0, (r: Row) => r.mode), when(1, eq(0, 1), [u8(1, (r: Row) => r.speed)])]),
      ),
    ),
  { items: [{ mode: 1, speed: 7 }, { mode: 0 }] },
)

// times inside an element row: c rounds of v.
probe(
  "times",
  () =>
    scheme<Row>(
      1,
      list(
        (r: Row) => r.items,
        group((r: Row) => r.p, [u8(0, (r: Row) => r.c), times(1, 0, [u8(1, (r: Row) => r.v)])]),
      ),
    ),
  { items: [{ c: 2, v: [5, 6] }, { c: 0, v: [] }] },
)

na("other-row", "no row types: a member reads any object by its accessor")
na("nested-other-row", "no row types: a member reads any object by its accessor")

// A required member left out of an element.
probe("null-member", listed, { items: [{ id: "c1", authorId: 7, author: "ann" }] })

// A list that holds a null element.
probe("null-item", listed, { items: [c1, null] })

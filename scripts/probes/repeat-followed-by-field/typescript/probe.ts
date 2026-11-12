// Probe of AZ-4206: a repeat that is not the last thing a packet reads. It builds each shape of
// ../README.md, packs the values given there and unpacks its own bytes. One line per shape:
// package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
import {
  BinaryPacker,
  dict,
  eq,
  flags,
  group,
  list,
  repeat,
  scheme,
  u8,
  when,
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
// With `forCompare`, a name whose list is empty is left out: a repeat of zero rounds unpacks to no key at all.
function shown(value: unknown, forCompare = false): string {
  return JSON.stringify(value, (_key, v: unknown) => {
    if (v === undefined) return null
    if (v instanceof Uint8Array) return Array.from(v)
    if (typeof v === "bigint") return Number(v)
    if (v !== null && typeof v === "object" && !Array.isArray(v)) {
      const entries = Object.entries(v as Row).filter(([, e]) => !(forCompare && Array.isArray(e) && e.length === 0))
      return Object.fromEntries(entries.sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)))
    }
    return v
  })
}

function probe(shape: string, build: () => Scheme<Row>, values: Row): void {
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
  let verdict: string
  try {
    verdict = shown(got, true) === shown(values, true) ? "same" : `differs: ${shown(got)}`
  } catch (e) {
    verdict = `threw: probe: ${oneLine(String(e))}`
  }
  line("built", hex(packed), verdict)
}

// control: the repeat is the last thing read.
probe(
  "control",
  () => scheme<Row>(1, u8(0, (r: Row) => r.x), repeat(1, [u8(1, (r: Row) => r.v)])),
  { x: 9, v: [5, 6] },
)

// a: a field after a repeat, top level.
probe(
  "a",
  () => scheme<Row>(1, repeat(0, [u8(0, (r: Row) => r.v)]), u8(1, (r: Row) => r.x)),
  { v: [5, 6], x: 9 },
)

// b: a repeat inside a list element row, two items.
probe(
  "b",
  () =>
    scheme<Row>(
      1,
      list(
        (r: Row) => r.items,
        group((r: Row) => r.item, [u8(0, (r: Row) => r.mode), repeat(1, [u8(1, (r: Row) => r.v)])]),
      ),
    ),
  { items: [{ mode: 1, v: [5] }, { mode: 2, v: [] }] },
)

// c: a repeat inside a dict element row, two entries.
probe(
  "c",
  () =>
    scheme<Row>(
      1,
      dict(
        (r: Row) => r.d,
        group((r: Row) => r.item, [u8(0, (r: Row) => r.mode), repeat(1, [u8(1, (r: Row) => r.v)])]),
      ),
    ),
  { d: { a: { mode: 1, v: [5] }, b: { mode: 2, v: [] } } },
)

// d: a repeat inside a nested row (a group without an anchor), then a field. TypeScript rows are flat, so
// the members of the group are given under their own names; the group numbers its fields from 0 itself.
probe(
  "d",
  () =>
    scheme<Row>(1, group((r: Row) => r.m, [repeat(0, [u8(0, (r: Row) => r.v)])]), u8(0, (r: Row) => r.x)),
  { v: [5, 6], x: 9 },
)

// e-when: a repeat under a when that is taken, then a field.
probe(
  "e-when",
  () =>
    scheme<Row>(
      1,
      u8(0, (r: Row) => r.k),
      when(1, eq(0, 1), [repeat(1, [u8(1, (r: Row) => r.v)])]),
      u8(2, (r: Row) => r.x),
    ),
  { k: 1, v: [5, 6], x: 9 },
)

// e-flags: a repeat under flags, then a field.
probe(
  "e-flags",
  () => scheme<Row>(1, flags(0, [repeat(0, [u8(0, (r: Row) => r.v)])]), u8(1, (r: Row) => r.x)),
  { v: [5, 6], x: 9 },
)

// f: a repeat after a repeat. The second repeat's bytes are read as rounds of the first.
probe(
  "f",
  () => scheme<Row>(1, repeat(0, [u8(0, (r: Row) => r.v)]), repeat(1, [u8(1, (r: Row) => r.w)])),
  { v: [5], w: [6] },
)

// TypeScript only: two schemes that read back for the rows given here before loop 113. The rule of loop 113
// (AZ-4211) reads the scheme, not a row, so it refuses them too.

// x-one-item: shape b with one item, so the repeat is the last thing read.
probe(
  "x-one-item",
  () =>
    scheme<Row>(
      1,
      list(
        (r: Row) => r.items,
        group((r: Row) => r.item, [u8(0, (r: Row) => r.mode), repeat(1, [u8(1, (r: Row) => r.v)])]),
      ),
    ),
  { items: [{ mode: 1, v: [5, 6] }] },
)

// x-exclusive-when: the field after the repeat sits under a when that cannot hold together with the repeat's.
probe(
  "x-exclusive-when",
  () =>
    scheme<Row>(
      1,
      u8(0, (r: Row) => r.k),
      when(1, eq(0, 1), [repeat(1, [u8(1, (r: Row) => r.v)])]),
      when(2, eq(0, 2), [u8(2, (r: Row) => r.x)]),
    ),
  { k: 1, v: [5, 6] },
)

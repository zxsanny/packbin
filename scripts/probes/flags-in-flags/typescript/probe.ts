// Probe of AZ-4251: a `flags` that is a direct member of a `flags`. It builds scheme S of ../README.md,
// packs each shape's values and unpacks its own bytes. One line per shape: package, shape, build,
// pack, unpack (tab separated). It asserts nothing: it prints what happens.
import { BinaryPacker, bool, flags, scheme, u8, type Scheme } from "../../../../typescript/src/index.ts"

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
function shown(value: unknown): string {
  return JSON.stringify(value, (_key, v: unknown) => {
    if (v === undefined) return null
    if (v !== null && typeof v === "object" && !Array.isArray(v)) {
      return Object.fromEntries(Object.entries(v as Row).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)))
    }
    return v
  })
}

// The values two rows are compared by: a member with no value (null or undefined) is absent, and so is
// `b = false`, which leaves the bit clear as an absent `b` does (README §Bool).
function present(row: Row): Row {
  return Object.fromEntries(
    Object.entries(row).filter(([key, v]) => v !== undefined && v !== null && !(key === "b" && v === false)),
  )
}

// S: flags(flags(u8 x), bool b). The ids number straight through: the inner flags and x are 0, b is 1.
function build(): Scheme<Row> {
  return scheme<Row>(1, flags(0, [flags(0, [u8(0, (r: Row) => r.x)]), bool(1, (r: Row) => r.b)]))
}

function probe(shape: string, values: Row): void {
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
    verdict = shown(present(got)) === shown(present(values)) ? "same" : `differs: ${shown(got)}`
  } catch (e) {
    verdict = `threw: probe: ${oneLine(String(e))}`
  }
  line("built", hex(packed), verdict)
}

probe("both", { x: 9, b: true })
probe("x-only", { x: 9 })
probe("b-only", { b: true })
probe("none", {})

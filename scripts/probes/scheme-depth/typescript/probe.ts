// Probe of AZ-4291: what happens when a scheme is nested very deep. Usage: node probe.ts <shape> <depth>
// with shape `when` or `group`. It prints one tab-separated line: package, shape-depth, build, pack, unpack.
// It asserts nothing: it prints what happens. The scheme is built in a loop, innermost first, so the probe
// itself never recurses.
//
// group form: the unanchored `group(acc, fields)` inside another one, D deep, the innermost holding `u8 b`.
// TypeScript rows are flat, so the value is `{b: 7}` whatever the depth and it packs `01 07`. Every group
// needs a name of its own (a name in two places of one flat row is refused), so the accessors are made
// from source text, `r.g<i>`; the package reads a member name from the accessor's source. The anchored
// form `group(anchor, acc, fields)` was not used: it shares the ids of the row around it, so a chain of
// them would need an id per level for one `u8` and says nothing more about depth.
import { BinaryPacker, eq, group, scheme, u8, when, type Field, type Scheme } from "../../../../typescript/src/index.ts"

type Row = Record<string, unknown>

const MAX_HEX = 80

function oneLine(text: string): string {
  return text.replace(/\s+/g, " ").trim()
}

function stackError(e: unknown): boolean {
  return e instanceof RangeError && /call stack/i.test(e.message)
}

function failure(e: unknown): string {
  if (stackError(e)) return `threw: ${(e as Error).name}`
  if (e instanceof Error && e.name !== "Error" && e.name !== "RangeError" && e.name !== "TypeError") {
    // not the package's own errors: an unexpected raw error type
    return `threw: ${e.name}`
  }
  return `refused: ${oneLine(e instanceof Error ? `${e.name}: ${e.message}` : String(e)).slice(0, 120)}`
}

function hex(bytes: Uint8Array): string {
  const text = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("")
  return text.length > MAX_HEX ? `${text.slice(0, 40)}...(${bytes.length} bytes)` : text
}

function buildWhen(depth: number): Scheme<Row> {
  let inner: Field[] = [u8(1, (r: Row) => r.b)]
  for (let i = 0; i < depth; i++) inner = [when(1, eq(0, 1), inner)]
  return scheme<Row>(1, u8(0, (r: Row) => r.a), ...inner)
}

function buildGroup(depth: number): Scheme<Row> {
  let inner: Field[] = [u8(0, (r: Row) => r.b)]
  for (let i = 0; i < depth; i++) {
    const accessor = new Function("r", `return r.g${i}`) as (r: Row) => unknown
    inner = [group(accessor, inner)]
  }
  return scheme<Row>(1, ...inner)
}

function same(a: Row, b: Row): boolean {
  const ka = Object.keys(a).sort()
  const kb = Object.keys(b).sort()
  return ka.length === kb.length && ka.every((k, i) => k === kb[i] && a[k] === b[k])
}

function shown(row: Row): string {
  return oneLine(JSON.stringify(row, (_k, v: unknown) => (typeof v === "bigint" ? Number(v) : v))).slice(0, 120)
}

function main(): void {
  const [shape, depthText] = process.argv.slice(2)
  const depth = Number(depthText)
  if ((shape !== "when" && shape !== "group") || !Number.isInteger(depth) || depth < 1) {
    console.error("usage: node probe.ts <when|group> <depth>")
    process.exit(2)
  }
  const line = (b: string, p: string, u: string) => console.log(["typescript", `${shape}-${depth}`, b, p, u].join("\t"))
  const values: Row = shape === "when" ? { a: 1, b: 7 } : { b: 7 }

  let s: Scheme<Row>
  try {
    s = shape === "when" ? buildWhen(depth) : buildGroup(depth)
  } catch (e) {
    line(failure(e), "-", "-")
    return
  }
  let packed: Uint8Array
  try {
    packed = BinaryPacker.pack(s, values)
  } catch (e) {
    line("built", failure(e), "-")
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
    line("built", hex(packed), failure(e))
    return
  }
  if (got === undefined) {
    line("built", hex(packed), `refused: ${oneLine(JSON.stringify(result)).slice(0, 120)}`)
    return
  }
  line("built", hex(packed), same(got, values) ? "same" : `differs: ${shown(got)}`)
}

main()

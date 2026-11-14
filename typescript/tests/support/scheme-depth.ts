import { dict, eq, flags, bool, group, list, repeat, scheme, times, u8, when, type Field, type Scheme } from "../../src/index.ts"

// Chains of one container kind, written by a loop innermost first, so the test itself never recurses.
// Contract scheme-depth 1.0.0: a path of 256 containers builds and a path of 257 is refused.
export type Row = Record<string, unknown>

export const DEPTH_REFUSAL = "scheme nested too deep: more than 256 levels; the limit is 256"

// The package reads a member name from the accessor's source text, so each name is made from source.
const named = (name: string) => new Function("r", `return r.${name}`) as (r: Row) => unknown

export type Chain = {
  name: string
  build: (depth: number) => Scheme<Row>
  // The value and the packet of a chain `depth` deep.
  row: (depth: number) => Row
  hex: string
}

const nest = (depth: number, start: unknown, wrap: (inner: unknown) => unknown): unknown => {
  let v = start
  for (let i = 1; i < depth; i++) v = wrap(v)
  return v
}

// u8 a (id 0), `depth` nested `when(a == 1, ...)`, innermost u8 b (id 1): the shape of the loop 125 probe.
export const whenChain = (depth: number): Scheme<Row> => {
  let inner: Field[] = [u8(1, named("b"))]
  for (let i = 0; i < depth; i++) inner = [when(1, eq(0, 1), inner)]
  return scheme<Row>(1, u8(0, named("a")), ...inner)
}

// `depth` unanchored groups, one member name per level (a name twice in one flat row is refused), innermost u8 b.
export const groupChain = (depth: number): Scheme<Row> => {
  let inner: Field[] = [u8(0, named("b"))]
  for (let i = 0; i < depth; i++) inner = [group(named(`g${i}`), inner)]
  return scheme<Row>(1, ...inner)
}

const elementChain = (make: typeof list, depth: number): Scheme<Row> => {
  let element: Field = u8(0, named("v"))
  for (let i = 0; i < depth; i++) element = make(named("xs"), element)
  return scheme<Row>(1, element)
}

// `depth` nested flags, each holding the next, the innermost a bool.
export const flagsChain = (depth: number): Scheme<Row> => {
  let inner: Field = bool(0, named("on"))
  for (let i = 0; i < depth; i++) inner = flags(0, [inner])
  return scheme<Row>(1, inner)
}

// depth - 1 nested whens and a round holding u8 b at the bottom: `depth` containers on the path.
const roundChain = (round: (body: Field[]) => Field, depth: number): Scheme<Row> => {
  let inner: Field[] = [round([u8(1, named("b"))])]
  for (let i = 1; i < depth; i++) inner = [when(1, eq(0, 1), inner)]
  return scheme<Row>(1, u8(0, named("a")), ...inner)
}

export const CHAINS: Chain[] = [
  { name: "when", build: whenChain, row: () => ({ a: 1, b: 7 }), hex: "010107" },
  { name: "group", build: groupChain, row: () => ({ b: 7 }), hex: "0107" },
  {
    name: "list element rows",
    build: (d) => elementChain(list, d),
    row: (d) => ({ xs: nest(d, [7], (v) => [v]) }),
    // The type byte, a two-byte count of 1 per level, the innermost item u8 7.
    hex: "01" + "0100".repeat(256) + "07",
  },
  {
    name: "dict element rows",
    build: (d) => elementChain(dict, d),
    row: (d) => ({ xs: nest(d, { k: 7 }, (v) => ({ k: v })) }),
    // The type byte, per level a count of 1 and the key "k" (length 02 10 6b as the dict writes it), the innermost value u8 7.
    hex: "01" + "010002106b".repeat(256) + "07",
  },
  { name: "flags", build: flagsChain, row: () => ({ on: true }), hex: "01" + "01".repeat(256) },
  {
    name: "repeat round body",
    build: (d) => roundChain((body) => repeat(1, body), d),
    row: () => ({ a: 1, b: [7, 8] }),
    hex: "01010708",
  },
  {
    name: "times round body",
    build: (d) => roundChain((body) => times(1, 0, body), d),
    row: () => ({ a: 1, b: [7] }),
    hex: "010107",
  },
]

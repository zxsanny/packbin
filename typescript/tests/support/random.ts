// Seeded generators for the property tests: the same seed gives the same schemes and rows.
export function random(seed: number): () => number {
  let s = seed >>> 0
  return () => {
    s = (s + 0x6d2b79f5) >>> 0
    let t = s
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

type Row = Record<string, unknown>

// A member name is read from the accessor's source text, so each name needs a literal accessor.
export const NAMES = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"] as const
export type Name = (typeof NAMES)[number]
export const ACCESSORS: Record<Name, (x: Row) => unknown> = {
  a: (x) => x.a,
  b: (x) => x.b,
  c: (x) => x.c,
  d: (x) => x.d,
  e: (x) => x.e,
  f: (x) => x.f,
  g: (x) => x.g,
  h: (x) => x.h,
  i: (x) => x.i,
  j: (x) => x.j,
  k: (x) => x.k,
  l: (x) => x.l,
}

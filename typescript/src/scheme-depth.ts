import type { Field } from "./fields.ts"

// A scheme is refused when it nests deeper than this many containers on one path (contract scheme-depth 1.0.0).
export const MAX_SCHEME_DEPTH = 256

// The largest number of containers on one path from the top down: a when, flags, repeat, times or group, and the
// element row of a list or dict. A flag bit is its field, not a level. Run first when a scheme is built, before any
// walk that recurses, and without recursing itself: an explicit stack, stopped at the first path past the limit.
// A field held by two parents (the same object) is walked again only when reached deeper than before, so the cost
// is that of the distinct fields whatever the sharing (a diamond of D levels is 2^D tree paths).
export function validateSchemeDepth(fields: Field[]): void {
  measureSchemeDepth(fields)
}

export function measureSchemeDepth(fields: Field[]): number {
  const nodes: Field[] = []
  const levels: number[] = []
  for (const f of fields) {
    nodes.push(f)
    levels.push(0)
  }
  const deepest = new Map<Field, number>()
  let max = 0
  while (nodes.length > 0) {
    const f = nodes.pop()!
    const level = levels.pop()!
    const seen = deepest.get(f)
    if (seen !== undefined && seen >= level) continue
    deepest.set(f, level)
    switch (f.kind) {
      case "when":
      case "repeat":
      case "times":
      case "flags":
      case "group":
        if (level + 1 > MAX_SCHEME_DEPTH) throw tooDeep()
        max = Math.max(max, level + 1)
        for (const child of f.fields) {
          nodes.push(child)
          levels.push(level + 1)
        }
        break
      case "list":
      case "dict":
        if (level + 1 > MAX_SCHEME_DEPTH) throw tooDeep()
        max = Math.max(max, level + 1)
        nodes.push(f.element)
        levels.push(level + 1)
        break
      case "flagBit":
        nodes.push(f.field)
        levels.push(level)
        break
    }
  }
  return max
}

export function tooDeep(): RangeError {
  return new RangeError(`scheme nested too deep: more than ${MAX_SCHEME_DEPTH} levels; the limit is ${MAX_SCHEME_DEPTH}`)
}

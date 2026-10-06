import { FLAG_BITS, fieldName, type Field } from "./fields.ts"

// A split flag bit reads the flag byte of its own scope, and only after that byte: the top
// level, a repeat or times round, a list or dict element, or a `when` body (which also sees
// the bytes read before it in the scope around it). A byte that comes later, sits in a
// `when`, or sits in another round or element is never read for the bit.
//
// Each read of a flag byte gets an id of its own, and its bits are numbered by their place in
// the scheme: bit 0 is the first bit that follows the read, as in the combined form. A handle
// can be read again and shared by other schemes; the copies returned here belong to this scheme.
type Read = { id: symbol; name: string; taken: number }

export function bindFlagBits(fields: Field[]): Field[] {
  // The bits met so far per flag byte, in any scope: the number a bit with no byte to follow is named by.
  const met = new Map<symbol, number>()

  const bindAll = (list: Field[], seen: Map<symbol, Read>): Field[] =>
    list.map((f) => bindOne(f, seen))

  const bindOne = (f: Field, seen: Map<symbol, Read>): Field => {
    switch (f.kind) {
      case "flagByte": {
        const read = { id: Symbol(f.name), name: f.name, taken: 0 }
        seen.set(f.id, read)
        return { ...f, id: read.id }
      }
      case "flagBit": {
        const read = seen.get(f.flagId)
        const before = met.get(f.flagId) ?? 0
        met.set(f.flagId, before + 1)
        if (read === undefined) {
          throw new RangeError(
            `flag bit ${before} (${fieldName(f.field)}): its flag byte is not read earlier in the same scope`,
          )
        }
        if (read.taken === FLAG_BITS) {
          throw new RangeError(
            `flag byte "${read.name}": ninth bit (${fieldName(f.field)}); a flag byte holds ${FLAG_BITS} bits`,
          )
        }
        const bit = read.taken++
        return { ...f, flagId: read.id, bit, field: bindOne(f.field, new Map(seen)) }
      }
      case "flags":
        // Combined form: the members are not flattened yet; each is checked on its own.
        return { ...f, fields: f.fields.map((member) => bindOne(member, new Map(seen))) }
      case "group":
        return { ...f, fields: bindAll(f.fields, seen) }
      case "when":
        return { ...f, fields: bindAll(f.fields, new Map(seen)) }
      case "repeat":
      case "times":
        return { ...f, fields: bindAll(f.fields, new Map()) }
      case "list":
      case "dict":
        return { ...f, element: bindOne(f.element, new Map()) }
      default:
        return f
    }
  }

  return bindAll(fields, new Map())
}

// A bool or an empty group is a presence mark: it has no bytes, only a flag bit. It is
// allowed only as the field of a flag bit or a direct member of `flags`; anywhere else
// (top level, a non-empty group, `when`, `repeat`, `times`, a list or dict element) it
// would always read as true.
export function validatePresenceMarks(fields: Field[], onFlagBit = false): void {
  for (const f of fields) {
    const mark =
      f.kind === "bool" ? "bool" : f.kind === "group" && f.fields.length === 0 ? "empty group" : null
    if (mark !== null && !onFlagBit) {
      throw new RangeError(
        `${mark} ${fieldName(f)}: allowed only directly inside flags or a flag bit; move it into flags`,
      )
    }
    switch (f.kind) {
      case "flagBit":
        validatePresenceMarks([f.field], true)
        break
      case "flags":
        validatePresenceMarks(f.fields, true)
        break
      case "group":
      case "when":
      case "repeat":
      case "times":
        validatePresenceMarks(f.fields)
        break
      case "list":
      case "dict":
        validatePresenceMarks([f.element])
        break
    }
  }
}

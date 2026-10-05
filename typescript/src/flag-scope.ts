import { fieldName, type Field } from "./fields.ts"

// A split flag bit reads the flag byte of its own scope, and only after that byte: the top
// level, a repeat or times round, a list or dict element, or a `when` body (which also sees
// the bytes read before it in the scope around it). A byte that comes later, sits in a
// `when`, or sits in another round or element is never read for the bit.
export function validateFlagScopes(fields: Field[], seen: Set<symbol> = new Set()): void {
  for (const f of fields) {
    switch (f.kind) {
      case "flagByte":
        seen.add(f.id)
        break
      case "flagBit":
        if (!seen.has(f.flagId)) {
          throw new RangeError(
            `flag bit ${f.bit} (${fieldName(f.field)}): its flag byte is not read earlier in the same scope`,
          )
        }
        validateFlagScopes([f.field], new Set(seen))
        break
      case "flags":
        // Combined form: the members are not flattened yet; each is checked on its own.
        for (const member of f.fields) validateFlagScopes([member], new Set(seen))
        break
      case "group":
        validateFlagScopes(f.fields, seen)
        break
      case "when":
        validateFlagScopes(f.fields, new Set(seen))
        break
      case "repeat":
      case "times":
        validateFlagScopes(f.fields)
        break
      case "list":
      case "dict":
        validateFlagScopes([f.element])
        break
    }
  }
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

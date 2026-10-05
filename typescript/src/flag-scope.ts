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

import type { Field } from "./fields.ts"

// An anchored group has no object of its own: it reads its members from the row around it, and a list
// or dict item is a value, not that row, so every pack would throw `missing <member>`. A list or dict
// is refused when its element is one, wherever the list or dict stands (inside a list or dict element
// too). The group in an unanchored group element is fine: the element's row holds it.
export function validateElementKinds(fields: Field[]): void {
  for (const f of fields) {
    switch (f.kind) {
      case "list":
      case "dict":
        if (f.element.kind === "group" && f.element.anchor !== undefined) {
          throw new RangeError(
            `${f.kind} ${f.name}: element is an anchored group (${f.element.name}); use a group without an anchor`,
          )
        }
        validateElementKinds([f.element])
        break
      case "when":
      case "flags":
      case "group":
      case "repeat":
      case "times":
        validateElementKinds(f.fields)
        break
      case "flagBit":
        validateElementKinds([f.field])
        break
    }
  }
}

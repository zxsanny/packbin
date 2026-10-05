import type { Field } from "./fields.ts"

// A row is one flat map: the members of a group are merged into the row beside the group's own
// name, so a name used inside an unanchored group and anywhere else would have one value overwrite
// the other. Every name must belong to one place: the top level or one unanchored group (an
// anchored group, `when`, `flags`, `repeat` and `times` share the place around them, so two `when`
// branches may still write the same member). A group's own name belongs to the place around it.
export function validateMemberNames(fields: Field[]): void {
  const places = new Map<string, number>()
  let groups = 0

  const declare = (name: string, place: number): void => {
    const first = places.get(name)
    if (first === undefined) places.set(name, place)
    else if (first !== place) {
      throw new RangeError(
        `member ${name}: declared inside a group and outside it; a group's members are flattened into the row, so one would overwrite the other`,
      )
    }
  }

  const walk = (list: Field[], place: number): void => {
    for (const f of list) {
      switch (f.kind) {
        case "int":
        case "float":
        case "bytes":
        case "bool":
        case "utf8":
        case "sized":
        case "bits":
        case "packed":
        case "list":
        case "dict":
          declare(f.name, place)
          break
        case "u2":
          for (const slot of f.slots) declare(slot.name, place)
          break
        case "group":
          declare(f.name, place)
          walk(f.fields, f.anchor === undefined ? ++groups : place)
          break
        case "when":
        case "flags":
        case "repeat":
        case "times":
          walk(f.fields, place)
          break
        case "flagBit":
          walk([f.field], place)
          break
        case "flagByte":
          break
      }
    }
  }

  walk(fields, 0)
}

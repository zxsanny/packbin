import { itemGroup, type Field } from "./fields.ts"

// A row is one flat map: the members of a group are merged into the row beside the group's own
// name, so a name used inside an unanchored group and anywhere else would have one value overwrite
// the other. Every name must belong to one place: the top level or one unanchored group (an
// anchored group, `when`, `flags`, `repeat` and `times` share the place around them, so two `when`
// branches may still write the same member). A group's own name belongs to the place around it.
// A place holds one value per name, so a name declared twice in one place is refused too, unless
// one of the two sits under a `when` (the branches of a chain may share a member).
// A list or dict element is a row of its own: it gets a namespace of its own, with the same rules.
export function validateMemberNames(fields: Field[]): void {
  const places = new Map<string, { place: number; always: boolean }>()
  let groups = 0

  const declare = (name: string, place: number, conditional: boolean): void => {
    const first = places.get(name)
    if (first === undefined) {
      places.set(name, { place, always: !conditional })
    } else if (first.place !== place) {
      throw new RangeError(
        `member ${name}: declared inside a group and outside it; a group's members are flattened into the row, so one would overwrite the other`,
      )
    } else if (!conditional) {
      if (first.always) {
        throw new RangeError(
          `member ${name}: declared twice in one scope; a row holds one value per name, so one would be lost`,
        )
      }
      first.always = true
    }
  }

  const walk = (list: Field[], place: number, conditional: boolean): void => {
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
          declare(f.name, place, conditional)
          break
        case "list":
        case "dict":
          declare(f.name, place, conditional)
          validateMemberNames(itemGroup(f.element)?.fields ?? [f.element])
          break
        case "u2":
          for (const slot of f.slots) declare(slot.name, place, conditional)
          break
        case "group":
          declare(f.name, place, conditional)
          walk(f.fields, f.anchor === undefined ? ++groups : place, conditional)
          break
        case "when":
          walk(f.fields, place, true)
          break
        case "flags":
        case "repeat":
        case "times":
          walk(f.fields, place, conditional)
          break
        case "flagBit":
          walk([f.field], place, conditional)
          break
        case "flagByte":
          break
      }
    }
  }

  walk(fields, 0, false)
}

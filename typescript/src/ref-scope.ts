import type { Field } from "./fields.ts"

type Source = { name: string; integer: boolean }
type Scope = Map<number, Source>
type Referring = Extract<Field, { kind: "when" | "sized" | "bits" | "packed" | "times" }>

// The name `bindReferences` filled in. A field no Scheme bound has none, and must not read a
// value by a missing name.
export function refName(f: Referring): string {
  const { ref } = f as typeof f & { ref?: string }
  if (ref === undefined) throw new RangeError(`${f.kind}: reference is not bound`)
  return ref
}

// A copy of `f` that carries the name; the exported `Field` type has no `ref`.
function bound<F extends Field>(f: F, ref: string): F {
  return { ...f, ref }
}

// An `eq` id, or the count id of `sized`, `bits`, `packed` and `times`, names a value field read
// earlier in the same scope: the top level, a `repeat` or `times` body, a list or dict element,
// or an unanchored group. `flags`, flag bits, an anchored group and `when` share the scope
// around them; a nested scope is closed in both directions. The scheme keeps a copy of each
// reference field with the name filled in, so pack and unpack never look an id up.
export function bindReferences(fields: Field[]): Field[] {
  return bindAll(fields, new Map())
}

function bindAll(fields: Field[], scope: Scope): Field[] {
  return fields.map((f) => bind(f, scope))
}

function declare(scope: Scope, id: number, name: string, integer = false): void {
  scope.set(id, { name, integer })
}

function resolve(
  scope: Scope,
  owner: string,
  ownerId: number,
  role: string,
  id: number,
  integer: boolean,
): string {
  const source = scope.get(id)
  if (source === undefined) {
    throw new RangeError(
      `${owner} ${ownerId}: ${role} names field id ${id}, which is not declared earlier in the same scope`,
    )
  }
  if (integer && !source.integer) {
    throw new RangeError(
      `${owner} ${ownerId}: ${role} names field id ${id} (${source.name}), which is not an integer`,
    )
  }
  return source.name
}

function bind(f: Field, scope: Scope): Field {
  switch (f.kind) {
    case "int":
      declare(scope, f.id, f.name, true)
      return f
    case "float":
    case "bytes":
    case "bool":
    case "utf8":
      declare(scope, f.id, f.name)
      return f
    case "u2":
      for (const slot of f.slots) declare(scope, slot.id, slot.name, true)
      return f
    case "sized":
    case "bits":
    case "packed": {
      const ref = resolve(scope, f.kind, f.id, "count", f.countId, true)
      declare(scope, f.id, f.name)
      return bound(f, ref)
    }
    case "when": {
      const ref = resolve(scope, "when", f.anchor, "eq", f.fieldId, false)
      return bound({ ...f, fields: bindAll(f.fields, scope) }, ref)
    }
    case "times": {
      const ref = resolve(scope, "times", f.anchor, "count", f.countId, true)
      return bound({ ...f, fields: bindAll(f.fields, new Map()) }, ref)
    }
    case "repeat":
      return { ...f, fields: bindAll(f.fields, new Map()) }
    case "group":
      return { ...f, fields: bindAll(f.fields, f.anchor === undefined ? new Map() : scope) }
    case "flags":
      return { ...f, fields: bindAll(f.fields, scope) }
    case "flagBit":
      return { ...f, field: bind(f.field, scope) }
    case "list":
    case "dict":
      return { ...f, element: bind(f.element, new Map()) }
    case "flagByte":
      return f
  }
}

# Acceptance criteria — C# element row Lows (loop 111)

Inherited project baseline: `_docs/00_problem/acceptance_criteria.md` (wire format unchanged, every package reads every other's bytes). The criteria below are the feature's own.

| id | criterion | measure |
|----|-----------|---------|
| AC-1 | A list member typed `E[]` or `IList<E>` takes the element-row form in `Fields<T>.List` and in the static `Field.List` | 0, 1 and 3 items pack to the same hex as the `List<E>` form (`010000`, the AZ-4199 `One` and `Three` fixtures) and unpack to an array / list of 0, 1 and 3 rows equal to the input; 3 of 3 counts per member type |
| AC-1b | A dict member typed `IDictionary<string, E>` takes the element-row form in `Fields<T>.Dict` and in the static `Field.Dict` | packs to the AZ-4199 `Map` hex and unpacks to 2 equal rows |
| AC-2 | An element-row member declared for a type that is neither the element row type nor a base type of it is refused when the scheme is built | `ArgumentException` from the `Scheme` constructor whose message names the member and both types (`'Z' is declared for row type Other, but ... Mark`); 0 `InvalidCastException` from `Pack`; list and dict both |
| AC-2b | The same check in a nested row (a `Group` without anchor) | same refusal for `Field.Group<Nest, Mark?>(x => x.M, Field.U8<Other>(0, o => o.Z))`; a member declared for a base type of the nested row still builds and round-trips |
| AC-3 | `when` inside an element row | element row `(u8 mode, when(mode == 1, u8 speed))`, items `{1, 7}`, `{0}` packs to `010200010700` (TypeScript's bytes, measured loop 111) and unpacks to `{1, 7}`, `{0, 0}` |
| AC-3b | `times` inside an element row | element row `(u8 c, times(1, c, u8 v))`, items `{2, [5, 6]}`, `{0, []}` packs to `01020002050600` (TypeScript's bytes) and unpacks equal |
| AC-4 | Nothing else moves | 0 bytes differ in existing fixtures and golden vectors; the whole C# suite passes on `net10.0` and `netstandard2.0` (5,363 tests before this loop plus the new ones); every README C# example still compiles |
| AC-5 | README C# List section | names the accepted member types of the row form (`List<E>`, `E[]`, `IList<E>`; `Dictionary<string, E>`, `IDictionary<string, E>`) and that a member declared for another row type is refused when the scheme is built |

Out of scope lines: `problem.md` § Out of scope. Owner decision (4): the repeat class is its own task in `_docs/02_tasks/todo/`.

# Contract: a scheme is nested at most 256 levels deep

**Component**: library
**Producer task**: AZ-4294 (hostile cases and README text)
**Consumer tasks**: AZ-4295 (TypeScript), AZ-4296 (C#), AZ-4297 (Python), AZ-4298 (Java), AZ-4299 (Go), AZ-4300 (Swift), AZ-4301 (Dart), AZ-4302 (Rust), AZ-4303 (C++)
**Version**: 1.0.1
**Status**: frozen (owner decision D18, 2026-11-14: "Shared limit (256)"); implemented in loop 126
**Last Updated**: 2026-11-14

## Purpose

No package limited how deep a scheme may nest. Loop 125 (`_docs/06_metrics/scheme-depth-probe_2026-11-14.md`) built a chain of nested `when`s and of nested groups in all nine packages: TypeScript, Python, Dart and Java threw a raw language stack error (Python between 400 and 500 levels, TypeScript by 1,500), C#, C++, Rust and Swift crashed the process at 50,000 levels, Go and Swift did not finish 5,000 nested groups in 60 seconds, and Rust's heap-free API did not finish 5,000 `when`s. None refused with its own error. One limit, checked before the scheme is walked, replaces all of that.

## Rule

A scheme is refused when it is built if its nesting depth is above **256**.

**Nesting depth** of a scheme is the largest number of container fields on one path from the top of the scheme down to any field. A container is a `when`, a `flags` (and a flag bit that holds members), a group (anchored, or a nested row without an anchor), the element row of a `list` or `dict`, and the body of a `repeat` or `times` round. A path of 256 containers builds; a path of 257 is refused. An empty innermost container counts as a level, so the depth does not depend on whether the last container holds a field.

**Counting (1.0.1).** A `when`, a `flags`, an anchored or unanchored group, a nested row, a `repeat` and a `times` each count one level. A `list` or `dict` counts one level (its element row); an element that is itself a container counts by its own kind, so `list(group(...))` is two levels and `list(u8)` is one. A flag bit that holds one field or several adds no level of its own (the `flags` above it counted). The rule was set by the TypeScript and Dart tasks of loop 126 and holds in all nine packages; it matters only for chains that mix kinds at the 256 / 257 boundary.

Examples (type number 1, `u8 a` then the chain, innermost `u8 b`):

| scheme | depth | outcome |
|--------|-------|---------|
| `u8 a`, 256 nested `when(a == 1, ...)`, innermost `u8 b` | 256 | builds; `{a: 1, b: 7}` packs `010107` |
| the same with 257 `when`s | 257 | refused |
| 256 nested groups, innermost `u8 b` = 7 | 256 | builds; packs `0107` |
| the same with 257 groups | 257 | refused |

### Refusal

- When: at scheme construction, first, before any walk that recurses over the scheme, in every way the package has to build a scheme (typed rows and map rows, the `constexpr` and the run-time form in C++, the map form and the heap-free `validate` in Rust). Never at pack or unpack.
- How: the depth is measured without recursion (an explicit stack or a counter over a flat table), so a 50,000-level scheme costs time proportional to its size and no stack.
- Kind: the package's scheme error, the same kind its other scheme rules use (the `scheme_error` outcome of `fixtures/hostile/README.md`).
- Text, where the package's scheme errors carry a text: `scheme nested too deep: more than 256 levels; the limit is 256`. A package that already prefixes its scheme errors (a field id, a scheme name) keeps its prefix.
- Nothing is packed and no partial scheme is returned.

### What stays

- A scheme at 256 levels builds, packs and unpacks with the bytes it had before: every container kind the package can nest (`when`, group or nested row, list and dict element rows) must do so at 256 with the default stack of the host and no raised recursion limit. A package that cannot is a blocker to report, not a reason to lower the limit alone.
- Rust's own `MAX_FIELDS` (32,768) of the heap-free API stays; its refusal text is that API's own.
- No wire change; the existing tests that use a scheme of up to a handful of levels are unchanged.

## Shared cases

`fixtures/hostile/cases.txt` (AZ-4294): `construct_depth_when_257`, `construct_depth_group_257` (`construct`, `scheme_error`), `pack_depth_when_256` (`pack`, `bytes`, `010107`), `pack_depth_group_256` (`pack`, `bytes`, `0107`). Each package writes the chains with a loop in its loader.

## Change Log

| Version | Date | Change | Author |
|---------|------|--------|--------|
| 1.0.0 | 2026-11-14 | First version: limit 256, refused at build (D18) | loop 126 |
| 1.0.1 | 2026-11-14 | Counting paragraph: a list or dict counts one level plus its element's own kind; a flag bit adds none | loop 126 |

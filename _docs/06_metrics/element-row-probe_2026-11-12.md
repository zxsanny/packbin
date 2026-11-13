# Findings: lists and dicts whose element is a row, six packages (AZ-4242)

Measured on 2026-11-12 in loop 116, package sources of `cd4156a`, on the project's Mac (arm64). Two runs of `bash scripts/probes/element-row/run.sh`: 168 lines each, exit 0, 54 s and 46 s (host load 6 to 56), byte-identical. Every cell below is from that run (the probe prints it again on any checkout). Tools: Node 22.23.0, javac 21.0.2, Python 3.13.7, Rust 1.98.1, Apple clang 21.0.0, Go 1.27 (in `golang:1.27`), Swift 6.4.2.

## What this is about

An element row is a list or dict element that is a row of required members, written one after another with no flag byte (AZ-4199). C# had three defects in this form, fixed in loops 109 and 111: (1) some collection member types could not use it, (2) a member declared for another row type built and then threw a raw `InvalidCastException` out of pack and unpack, (3) `when` and `times` inside an element row were untested. TypeScript wrote the reference bytes. This probe asks the same questions of Java, Go, Swift, Rust (both APIs), Python and C++. C# (fixed) and Dart (pins the AZ-4199 bytes since loop 109) were not probed.

## Result

`ok` = builds, packs TypeScript's bytes, reads back the values. `R` = the package's own refusal. **`T`** = a raw exception that is not the package's error. `—` = the package has no such shape (no row types, no null). `X` = the element-row form does not exist in the package (the scheme with a row element is refused at build, or cannot be packed).

| shape | TypeScript | Java | Go | Swift | Python | Rust map | Rust nostd | C++ bound | C++ unbound |
|-------|-----------|------|----|-------|--------|----------|------------|-----------|-------------|
| `list-0`, `list-1`, `list-3`, `dict-2` | ok | ok | ok | ok | ok | X (1) | X (1) | X (2) | X (3) |
| `when` in an element row | ok | ok | ok | ok | ok | X | X | X | X (4) |
| `times` in an element row | ok | ok | ok | ok | ok | X | X | X | X (4) |
| `other-row` (member of another row type in an element row) | — | **T** (5) | R at build | R at build | R at build (6) | — | — | does not compile | does not compile |
| `nested-other-row` | — | **T** (5) | R at build | R at build | — | — | — | does not compile | — |
| `null-member` | R `missing text` | R `1: expected string` (7) | R `missing text` | R `missing text` | R `1: expected str` (7) | X | X | — | — |
| `null-item` | R | R | R | R | **T** (8) | X | X | — | — |

Every byte that was written equals TypeScript's: `list-0` `010000`, `list-1` `010100…`, `list-3` `010300…`, `dict-2` `010200…`, `when` `010200010700`, `times` `01020002050600` (the full hex is in the probe output and in the README of the probe). No package wrote other bytes.

### Collection member types (`coll-*` lines)

| package | builds and gives TypeScript's bytes | refused, with the package's own error | raw exception |
|---------|-------------------------------------|---------------------------------------|---------------|
| Java (typed rows) | `ArrayList`, `HashMap` | array, `Set` (at pack: `list: expected list`) | **`LinkedList`, `TreeMap`: pack works, unpack throws `ClassCastException`** (9) |
| Go typed | `[]E`, `[]*E`, named slice, `map[string]E`, `map[string]*E`, named map, named string key | `[N]E`, `*[]E`, `[]any`, `any` member, `map[int]E` (at build) | — |
| Go map form | any slice of maps, maps with string-kind keys | array, a non-map item, `map[int]any` (at pack) | — |
| Swift typed | `[E]`, `[E]?`, `[E?]`, `[String: E]`, `[String: E]?`, `[String: E?]` | `ContiguousArray`, `ArraySlice`, `Set`, `[Any]`, `Substring` / `Int` keys (at build) | — |
| Swift map form | `[[String: Any]]`, `NSArray`, `NSDictionary`, `[AnyHashable: Any]` with string keys | `ContiguousArray`, `ArraySlice`, `Set`, struct items, non-string keys (at pack) | — |
| Python | `list` and subclasses, `dict` and subclasses (`OrderedDict`) | `tuple`, `deque`, `MappingProxyType` (at pack) | — |
| Rust, C++ | the element-row form does not exist (X) | C++ bound list: only `packbin::Array<T, N>` compiles (`std::vector`, `std::array`, C arrays, `std::list` stop at a static assertion); bound dict: `std::map` / `std::unordered_map` refused at build | — |

## Notes

1. Rust map API: `MapScheme::new` refuses a row element by its documented panic (`list "items" cannot carry element "comment": an element is one integer, float, bytes, utf8, list or dict, or a u2 with one name`, `rust/src/field/integrity.rs`); the heap-free API answers `SchemeInvalid` (`rust/src/nostd/check.rs`). The typed `Scheme<T>` has no list or dict of rows. A `u16` count plus `times(anchor, count, [members])` writes exactly the `list-3` bytes in both APIs (checked in a scratch run); there is no row-valued dict.
2. C++ bound: `bind_element` (`cpp/include/packbin/table.hpp`) marks a group element `SchemeInvalid`.
3. C++ unbound `list(element)`: builds, pack refuses with `BadValue` (`item_count` in `cpp/src/core/pack.cpp`, no member to count). Its unpack reads TypeScript's `list-0`, `list-1`, `list-3` and `dict-2` bytes in full (checked by the probe on stderr).
4. C++: a `when` condition or a `times` count must name a bound field (`find_ref`, `cpp/include/packbin/order.hpp`) and every field of an element is unbound, so C++ cannot read TypeScript's `010200010700` or `01020002050600` at all.
5. **Java defect (the C# AZ-4205 class).** A member declared for another row class builds; pack throws a raw `ClassCastException` (`Comment cannot be cast to Other`) from the unchecked cast of `Access.get` (`java/src/main/java/packbin/Access.java`). There is no build-time check of a member's row type: the accessors are erased lambdas, so Java cannot see the declared type the way Go (`go/places.go`) and Swift (`Place.swift`) do. The same throw comes from a nested row.
6. Python has no row types; a member written with an attribute accessor inside an element row is refused at build (`_require_key_accessor`, `python/src/packbin/_validate.py`), the nearest shape.
7. Java and Python name a missing member by its id (`1: expected string`, `1: expected str`); TypeScript, Go and Swift by its name (`missing text`). Low. Fixed in loop 121 (AZ-4257, AZ-4258): Python and Java `Map` rows say `missing text`; Java typed rows say `missing utf8 1` (an accessor lambda has no name).
8. **Python defect.** A `None` item in a list of rows reaches the element's key accessor (`row[key]`) and escapes as `TypeError: 'NoneType' object is not subscriptable`; Java, Go, Swift and TypeScript refuse it with their own error (`an item has no value` in Go).
9. **Java defect (the C# AZ-4205 collection class).** Unpack always hands the setter a new `ArrayList` (`Containers.java`, list unpack) or `LinkedHashMap` (dict unpack), so a typed member declared as another `List` or `Map` type (`LinkedList`, `TreeMap`) packs and then throws `ClassCastException` in unpack. The unpack path is shared by every list and dict, so the same throw is likely for a list of numbers (not probed). Arrays and `Set` members build and are refused at pack, not at build.

## Defects and the decision for the class

The class C# had is present in Java (notes 5 and 9) and, in a smaller form, in Python (note 8); Go and Swift are free of it (both refuse at build what C# now refuses); Rust and C++ have no element-row form at all, so they cannot have the defects but also cannot write or (Rust; C++ for `when` / `times`) read a packet the other seven packages write.

- **Python null item** (note 8): a raw `TypeError` where every other package refuses. Clear fix, no choice to make: a queue item (`python-null-item-in-element-row`).
- **Java** (notes 5, 9): a raw `ClassCastException` out of pack or unpack. How to remove it is a choice (a row class given to the element-row builder and checked at build, a check at pack that turns the cast into the package's error, or unpack building the declared collection type): decision `D10` in `_docs/OPERATOR_TODO.md`, then one task.
- **Rust and C++ have no element-row form**: scope, not a defect: decision `D11`.
- **Error texts** (note 7): Low, a queue item (`missing-member-message-by-name-java-python`).

## Appendix: probe output

The 168 lines are printed by `bash scripts/probes/element-row/run.sh` on the checkout; they are not copied here. Per package: TypeScript 11, Java 22, Go 35, Swift 39, Python 17, Rust 22, C++ 22.

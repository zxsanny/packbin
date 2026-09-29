# Ripple log — loop 8

The six packages do not import each other. An anchor on one language's constructors does not stale another language's callers.

- `_docs/02_document/components/01_csharp_package/description.md` — scheme construction now fails on a gap, a repeated id, or a bad anchor (`csharp/Packbin.cs` `SchemeOrder`)
- `_docs/02_document/components/02_typescript_package/description.md` — same check (`typescript/src/fields.ts`)
- `_docs/02_document/components/03_python_package/description.md` — same check (`python/src/packbin/_nodes.py`)
- `_docs/02_document/components/04_rust_package/description.md` — same check, plus a reference that is not yet walked (`rust/src/field/order.rs`)
- `_docs/02_document/components/05_cpp_package/description.md` — same check (`cpp/src/field.cpp`)
- `_docs/02_document/components/06_java_package/description.md` — same check (`java/src/main/java/packbin/SchemeOrder.java`)
- `_docs/02_document/data_model.md` — a continuing group takes an anchor that is not written
- `_docs/01_solution/schema.md` and README.md — already state the failure rule (`c91a83c`)

No cross-package import matched `repeat`, `when`, `times`, `flags`, or `group`.

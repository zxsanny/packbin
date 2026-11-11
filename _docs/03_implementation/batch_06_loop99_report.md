# Batch 6 report — loop 99 (Dart package)

Task: AZ-4148 dart_docs (3).

README: Dart section (install, typed and map examples, rows, errors as values and thrown, limits, concurrency, 64-bit rule, native only), Dart rows in both ECC tables, the frame example, data-type spelling, Untrusted input notes, nine packages. Package files `dart/README.md`, `dart/CHANGELOG.md` (0.1.0), `dart/example/packbin_example.dart`. 8 README examples compile and run in tests (`dart/test/readme/`), each must print the hex the README shows; the first line equals `fixtures/golden.hex`; a changed hex, a missing output block and a block that does not compile each fail (negative tests). `scripts/frame/readme-examples.sh` 9 of 9 pass. The nine-language documents under `_docs/02_document/` (component 09, module layout, glossary, three contracts with no version bump, system flows, epics, interaction risks, tests docs) and five fixture READMEs name Dart.

`dart pub publish --dry-run` on a scratch copy: 0 errors, 0 warnings, so `PACKBIN_DART_STRICT=1` can be switched on by the release task. The 27 exported names without doc comments were documented by the parent (frame types and results, `Condition`); the whole suite is 1,887 tests, format 0 changed, analyze 0 issues.

## Discovered during implementation

| finding | handling | clear/unclear |
|---------|----------|---------------|
| the git install form works with `dart pub add` only against a local clone; GitHub `dev` and `main` hold no `dart/` until the push | README says the git form is the interim install | unclear: only works after the push |
| README and `dart/README.md` say Dart is "from the repository until" the first pub.dev version | the owner edits both lines after the first publish | unclear: owner |
| `parity_differences.md` row 12 says an unpacked group with a set bit and no value is `{}`; a member-less `groupOf` mark unpacks as `true` in a map row | README says `true` for a mark | unclear: fix the row |
| the pub archive ships `test/` and `tool/` (195 KB) | a `.pubignore` could drop them | unclear |
| enabling `public_member_api_docs` would flag about 165 internal `lib/src` members | not enabled | unclear |
| stale "eight packages" wording outside this task's write set: python docstrings (4 files), `fixtures/hostile/README.md:295`, four workflow test/comment lines, `_dependencies_table.md` | listed | clear |

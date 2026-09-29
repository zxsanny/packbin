# Batch Report

**Batch**: 1
**Tasks**: AZ-2010, AZ-2011, AZ-2012, AZ-2013, AZ-2014, AZ-2015, AZ-2016
**Date**: 2026-09-29

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2010_csharp_anchor | Done | csharp, Position.cs | csharp suite PASS | None |
| AZ-2011_typescript_anchor | Done | typescript, position.ts | typescript suite PASS | None |
| AZ-2012_python_anchor | Done | python, position.py | python suite PASS | None |
| AZ-2013_rust_scheme_order | Done | rust, rust driver | rust suite PASS | None |
| AZ-2014_cpp_anchor | Done | cpp, position.cpp | cpp suite PASS | None |
| AZ-2015_java_anchor | Done | java, Position.java | java suite PASS | None |
| AZ-2016_order_sentence | Done | schema.md, README.md | docs only | None |

## Code Review Verdict: PASS

`_docs/03_implementation/reviews/batch_01_loop8_review.md`

## Test Suite

CI-parity: PASS — `bash .github/workflows/run-suite.sh` for csharp, typescript, python, rust, cpp, and java. C++ used `PACKBIN_CXX_SYSROOT` from `xcrun --show-sdk-path`.

- csharp: passed
- typescript: passed
- python: 40 passed
- rust: 47 passed
- cpp: all tests passed
- java: All tests passed, Scheme tests passed, Field id binding tests passed
- Failed: 0

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A nested group (child row whose ids restart at 0) has no parent anchor. A group whose children continue the parent counter takes the anchor. | AZ-2010 scope | C#, TypeScript, and Java keep the nested overload without an anchor. Python, C++, and Rust groups continue the parent counter, so they take the anchor. | clear |
| 2 | An empty Rust group still occupies one value slot after the anchor check, because that node is the flag bool. | AZ-2013 | The anchor must equal that slot. The slot is still consumed once. Wire bytes stay the same. | clear |

## Commit

`[AZ-2010] [AZ-2013] [AZ-2016] State field order on the scheme`

Loop: 8

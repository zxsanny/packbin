# Scheme depth probe (AZ-4291, loop 125)

Probe: `scripts/probes/scheme-depth/run.sh` (nine packages, 60 lines, 303 s on this Mac, exit 0) at HEAD `97c3fcf` plus the probe files. Shapes: `when-D` (u8 `a`, D nested `when(a == 1, ...)`, innermost u8 `b`; packs `01 01 07`) and `group-D` (D nested groups, innermost u8 `b`; packs `01 07`) at D = 1,000, 5,000 and 50,000, one process per case. Rust and Swift ran as release builds (a debug build overflows earlier: set `PROBE_PROFILE=debug`). Rust prints a second set for its heap-free API (`-nostd`). Group forms: a group without an anchor in C#, Java (map row), Go, Swift and Dart; TypeScript and Python nest unanchored / anchored groups that share one row; Rust and C++ nest an anchored group inside an anchored group.

## Finding, in one line

**No package has a depth limit and none refuses a deep scheme with its own error** (one exception below). What happens instead depends on the package: a raw language stack error at build (TypeScript, Python, Dart, Java) or at unpack (Java), a process crash at build (C#, C++, Rust map API, Swift), or a build that does not end in 60 s (Go and Swift: nested groups; Rust nostd: `when`).

## Per package

| package | largest depth that works (of 1,000 / 5,000 / 50,000) | what happens above it |
|---|---|---|
| python | below 1,000 (ad hoc: 400 works, 500 fails) | `RecursionError` at build, `_validate_order` (`python/src/packbin/_validate.py:160`): the default recursion limit |
| typescript | 1,000 (ad hoc: 1,500 fails) | `RangeError` (call stack) at build, `validateFieldIds` (`typescript/src/fields.ts:339,348`) |
| dart | 1,000 | `StackOverflowError` at build (the loop 113 finding, both shapes) |
| java | `when` 1,000 and `group` 1,000; `when-5000` builds and packs, its unpack throws `StackOverflowError` | `StackOverflowError`; the line of `group-5000` changed between two runs (build or unpack): 5,000 is at the edge and the point depends on JIT state |
| go | `when` 50,000; `group` 1,000 | `group-5000` never ends: `NewScheme` is stuck in `foreignNames` (`go/places.go:207-241`, the path is copied at each level; 1.4 GiB at 20,000). No stack error |
| swift | `when` 5,000; `group` 1,000 | `when-50000`: SIGSEGV in `Scheme(1, fields)` (10,000 works, 20,000 crashes). `group-5000` takes over 60 s: build cost cubic in depth (1.2 s at 1,000, 10.5 s at 2,000, 35.8 s at 3,000) |
| rust (map API) | 5,000 | SIGABRT "thread has overflowed its stack" inside `MapScheme::new` at 50,000 (at 20,000 build passes and pack overflows; 10,000 works) |
| rust (nostd) | `when` 1,000 and `group` 5,000 | `SchemeInvalid` at 50,000: the package's own limit `MAX_FIELDS = 32768` (`rust/src/nostd/scheme.rs:5`, `check.rs:27-28`), the one refusal found. `when-5000` takes over 60 s (2,000 took 22 s) |
| cpp | 5,000 | SIGSEGV at build at 50,000: `packbin::detail::resolve` calls itself (`cpp/include/packbin/order.hpp:243,279`), as do `check_subtree` (58) and `check_shape` (318) |
| csharp | 5,000 | .NET stack overflow at build at 50,000, in `SchemeOrder.Walk` (`csharp/SchemeOrder.cs`) |

## Full table

| package | shape | depth | outcome | probe line (build / pack / unpack) |
|---|---|---|---|---|
| typescript | when | 1000 | works | `built` / `010107` / `same` |
| typescript | when | 5000 | raw stack error at build | `threw: RangeError` / `-` / `-` |
| typescript | when | 50000 | raw stack error at build | `threw: RangeError` / `-` / `-` |
| typescript | group | 1000 | works | `built` / `0107` / `same` |
| typescript | group | 5000 | raw stack error at build | `threw: RangeError` / `-` / `-` |
| typescript | group | 50000 | raw stack error at build | `threw: RangeError` / `-` / `-` |
| java | when | 1000 | works | `built` / `010107` / `same` |
| java | when | 5000 | raw stack error at unpack | `built` / `010107` / `threw: StackOverflowError` |
| java | when | 50000 | raw stack error at build | `threw: StackOverflowError` / `-` / `-` |
| java | group | 1000 | works | `built` / `0107` / `same` |
| java | group | 5000 | raw stack error at build | `threw: StackOverflowError` / `-` / `-` |
| java | group | 50000 | raw stack error at build | `threw: StackOverflowError` / `-` / `-` |
| go | when | 1000 | works | `built` / `010107` / `same` |
| go | when | 5000 | works | `built` / `010107` / `same` |
| go | when | 50000 | works | `built` / `010107` / `same` |
| go | group | 1000 | works | `built` / `0107` / `same` |
| go | group | 5000 | hang (60 s limit) | `crashed: exit 124` / `-` / `-` |
| go | group | 50000 | hang (60 s limit) | `crashed: exit 124` / `-` / `-` |
| swift | when | 1000 | works | `built` / `010107` / `same` |
| swift | when | 5000 | works | `built` / `010107` / `same` |
| swift | when | 50000 | process crash | `crashed: signal 11` / `-` / `-` |
| swift | group | 1000 | works | `built` / `0107` / `same` |
| swift | group | 5000 | hang (60 s limit) | `crashed: timeout` / `-` / `-` |
| swift | group | 50000 | process crash | `crashed: signal 11` / `-` / `-` |
| rust | when | 1000 | works | `built` / `010107` / `same` |
| rust | when | 5000 | works | `built` / `010107` / `same` |
| rust | when | 50000 | process crash | `crashed: signal 6` / `-` / `-` |
| rust | group | 1000 | works | `built` / `0107` / `same` |
| rust | group | 5000 | works | `built` / `0107` / `same` |
| rust | group | 50000 | process crash | `crashed: signal 6` / `-` / `-` |
| rust | when-nostd | 1000 | works | `built` / `010107` / `same` |
| rust | when-nostd | 5000 | hang (60 s limit) | `crashed: timeout` / `-` / `-` |
| rust | when-nostd | 50000 | refused (own error) | `refused: Fault { error: SchemeInvalid, offset: 0, field: -1, needed: 32768 }` / `-` / `-` |
| rust | group-nostd | 1000 | works | `built` / `0107` / `same` |
| rust | group-nostd | 5000 | works | `built` / `0107` / `same` |
| rust | group-nostd | 50000 | refused (own error) | `refused: Fault { error: SchemeInvalid, offset: 0, field: -1, needed: 32768 }` / `-` / `-` |
| python | when | 1000 | raw stack error at build | `threw: RecursionError` / `-` / `-` |
| python | when | 5000 | raw stack error at build | `threw: RecursionError` / `-` / `-` |
| python | when | 50000 | raw stack error at build | `threw: RecursionError` / `-` / `-` |
| python | group | 1000 | raw stack error at build | `threw: RecursionError` / `-` / `-` |
| python | group | 5000 | raw stack error at build | `threw: RecursionError` / `-` / `-` |
| python | group | 50000 | raw stack error at build | `threw: RecursionError` / `-` / `-` |
| cpp | when | 1000 | works | `built` / `010107` / `same` |
| cpp | when | 5000 | works | `built` / `010107` / `same` |
| cpp | when | 50000 | process crash | `crashed: signal 11` / `-` / `-` |
| cpp | group | 1000 | works | `built` / `0107` / `same` |
| cpp | group | 5000 | works | `built` / `0107` / `same` |
| cpp | group | 50000 | process crash | `crashed: signal 11` / `-` / `-` |
| csharp | when | 1000 | works | `built` / `010107` / `same` |
| csharp | when | 5000 | works | `built` / `010107` / `same` |
| csharp | when | 50000 | process crash | `crashed: signal 6` / `-` / `-` |
| csharp | group | 1000 | works | `built` / `0107` / `same` |
| csharp | group | 5000 | works | `built` / `0107` / `same` |
| csharp | group | 50000 | process crash | `crashed: signal 6` / `-` / `-` |
| dart | when | 1000 | works | `built` / `010107` / `same` |
| dart | when | 5000 | raw stack error at build | `threw: StackOverflowError` / `-` / `-` |
| dart | when | 50000 | raw stack error at build | `threw: StackOverflowError` / `-` / `-` |
| dart | group | 1000 | works | `built` / `0107` / `same` |
| dart | group | 5000 | raw stack error at build | `threw: StackOverflowError` / `-` / `-` |
| dart | group | 50000 | raw stack error at build | `threw: StackOverflowError` / `-` / `-` |

Stable on two further runs: every line except Java `group-5000` (above). The two timeouts that sit near the 60 s limit (Swift `group-5000`, Rust nostd `when-5000`) and Go's (printed `crashed: exit 124`: a Go program ignores the alarm signal of `case.sh`, so the Go probe runs each case under `timeout 55`) can move on a faster or slower host.

## The class and the decision (D9)

Real schemes nest a handful of levels; the weakest package (Python) stops working between 400 and 500 levels, TypeScript, Dart and Java between 1,000 and 5,000, the rest above 5,000. The failures are the same defect: the build (and in Java the unpack) recurses once per level and the host's stack ends the process or throws a language error that is not the package's error type. A hand-written scheme is not untrusted input, so this is Medium at most; it matters only because every package says `schemeError` for the other bad schemes.

Options for the owner (new row D18): **A** one limit on nesting for all nine, refused at build with the package's scheme error and one shared text, the limit well under Python's ceiling (for example 256 levels); also ends the Go, Swift and Rust-nostd slowdowns. **B** make every walk iterative (nine packages; the slow ones in Go and Swift need their own fix; large). **C** leave it to the host stack and say so in the README. Recommended: **A**: smallest change that gives every package a typed refusal, a limit is one check at one place per package, reversible until the next release tag. The follow-up work is the queue item `scheme-depth-limit-all-nine`, blocked on D18.

# Feature assessment — loop 125 (AZ-4291, scheme depth probe)

verdict: COMPLETE
assess_round: 0

Intent (queue item `dart-deep-when-chain-stack-overflow`, decision D9 option A): measure how every package behaves for a very deep scheme, show the answer per package, and give the owner one decision for the class.

| intent angle | spec / source | covered by | status |
|--------------|---------------|-----------|--------|
| a 5,000 and a 50,000 deep chain of `when`s in each package | AC-1, `problem.md` | `when-D` lines of all nine, plus 1,000 | covered |
| the same for groups | AC-1 | `group-D` lines of all nine (form per package named in the README and source) | covered |
| build outcome and error type | AC-1, AC-2 | build field: built / refused / threw / crashed | covered |
| pack and unpack of the deep packet | AC-1 | pack and unpack fields (Java unpack overflow found) | covered |
| a crash must not end the run | AC-2 | `case.sh` per-process, 60 s limit; Go under `timeout 55` | covered |
| findings table per package | AC-3 | `_docs/06_metrics/scheme-depth-probe_2026-11-14.md` | covered |
| a package that dies with a raw stack error gets a task | queue item text | one class item `scheme-depth-limit-all-nine` (blocked on D18), packages named in it | covered (one item, as the owner gets one decision) |
| one decision for the class | queue item text | D18 with options and recommendation | covered |
| angle found while implementing: nested groups hang in Go and Swift, Rust nostd `when` is slow, Rust nostd has its own 32,768-field limit | — | recorded in the findings and in the follow-up item | covered |
| not in scope | `problem.md` | a limit or any package change; scheme width; depth of packet values | excluded |

Gap-clear: none. Gap-unclear: none.

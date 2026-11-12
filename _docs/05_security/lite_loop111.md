# Security lite — loop 111

Diff: `05bdc52..HEAD` without `_docs/` (6 files, 411 added, 20 removed; 351 of the added lines are the test file `csharp/tests/ElementRowLowsTests.cs`): AZ-4205, C# element-row overloads and the build-time row-type check in `SchemeOrder.cs`, README text.

| Trigger | Hit | Note |
|---|---|---|
| T1 sensitive path | no | only `csharp/*.cs`, a test file and `README.md` |
| T2 sensitive content | no | grep of the added lines: 0 hits |
| T3 size | no | 4 source files, about 60 non-test lines, 3 points |
| T4 dependencies | no | no `*.csproj`, lockfile or image changed |
| T5 carried finding | no | no open finding of `security_report.md` names `Field.cs`, `Fields.cs`, `FieldAccess.cs` or `SchemeOrder.cs` |
| T6 stale audit | no | not a ship loop, 3 points |
| T7 lite concern | no | checks below found nothing above Low |

Checks on the changed lines:
- Untrusted input: none reaches the change. The check runs once in the `Scheme` constructor on the author's field list; the pack and unpack walkers are unchanged. It removes a raw `InvalidCastException` that `Unpack` threw for a misdeclared scheme (an author error, any input), now refused at build.
- Injection, output encoding, authn/authz, outbound, edge config: not applicable (library builders, no I/O, no process, no network).
- Secrets and logs: none; the new message names the member and two type names only.
- Error handling: no `catch` added; refusals are `ArgumentException` at scheme build, as the existing top-level rule.
- Input limits: the new array, `IList<E>` and `IDictionary<string, E>` members go through the existing `CollectionShape` and the existing count and slot limits of the list and dict readers.

Verdict: CLEAN. Lows: none.

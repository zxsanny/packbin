# Scenarios — csharp-java-lone-surrogate-keys

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A caller packs a dictionary whose keys differ only in unpaired surrogates (C# or Java) | confirmed | pack throws, naming the dictionary; no bytes | CJ-1, CJ-3, CJ-5 | intake |
| S2 | A Java caller packs a text or key with a lone surrogate | confirmed | U+FFFD (`EF BF BD`) is written, as TypeScript, Dart and C#; the packet reads back with U+FFFD | CJ-4 | intake |
| S3 | A Java caller packs "?" and a lone half as two keys | confirmed | two distinct keys, readable: `?` then U+FFFD | CJ-4 | intake |
| S4 | A caller packs a dictionary with no lone surrogate | confirmed | the same bytes as before, in both packages | CJ-2, CJ-4 | intake |
| S5 | The same dictionary is a list element or a dict value | confirmed | the same refusal (one code path in each package) | CJ-1, CJ-3 | intake |
| S6 | Python, Go, Rust or Swift | out-of-scope | they already refuse or cannot hold a lone surrogate (loop 102) | — | intake |

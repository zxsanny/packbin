# Security lite — loop 120 (AZ-4255)

diff: `git diff 352ae3d..HEAD -- . ':(exclude)_docs'` (java `Walker.java`, `Containers.java`, `CollectionTypeTest.java`, `PackbinTest.java`, `README.md`)

| # | trigger | hit |
|---|---------|-----|
| T1 | sensitive path | no |
| T2 | sensitive content | no: 9 pattern matches, all the substring `hash` in the class name `LinkedHashMap` (imports, comments, a message, a test); not a trigger |
| T3 | size | no: 2 points, 2 non-test source files, about 30 non-test lines |
| T4 | dependencies | no |
| T5 | carried finding touched | no |
| T6 | stale audit | no (full audit loop 118, 2026-11-13) |
| T7 | lite concern | no |

Checks on changed lines: the new `catch (ClassCastException)` runs only after the caller's own setter fails, on unpack of a list or dict; it rethrows every cast failure whose message is not the one about the collection unpack created, so nothing is swallowed; the new `IllegalArgumentException` carries the original as its cause and text of the package only (no value of the packet). Unpack of untrusted bytes is unchanged up to the setter call; no new input, no allocation beyond the exception.

verdict: CLEAN

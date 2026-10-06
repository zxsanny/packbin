# Interaction risks

## Flows and seams

| Flow | Seam | What crosses |
|------|------|----------------|
| F1 Pack | caller → package | a value |
| F2 Unpack | caller → package | bytes |
| F3 Publish | the six packages, via the golden fixture | the hex |
| F3 Publish | Actions → the six registries | one package per language in the tag |
| F4 Session | opener → waiter | 16 bytes, then a payload the same length as clear pack |

## Risks

| Risk | Outcome | AC | Owner |
|------|---------|----|-------|
| The six languages write different bytes for the same list | mismatch count is 0, or the tag publishes nothing | AC-3, AC-14 | AZ-1875 and each package |
| Unpack returns part of a short buffer | value count is 0, and the next pack still matches the golden hex | AC-8 | each package |
| A clear flag is stored as 0 | a present 0 is written; absence adds 0 bytes | AC-4, AC-5 | each package |
| A language missing from the tag still publishes | that registry receives 0 packages | AC-15 | AZ-1875 |
| The crates.io token (and the NuGet key) is exchanged before the whole build phase; if it expires before the upload, earlier registries are published and crates.io is not | a partial release; re-running the tag with a fresh token finishes it. Token lifetime and cold-runner build time are unmeasured, watch both on the first real tag and split `publish.yml` into build, exchange and upload if the build nears 10 minutes (loop 14 assessment U1, batch 3 review finding 1) | accepted, no AC | AZ-2096 |
| A session payload is dropped | the next unpack on that direction is not the sent row | pack-session AC-4 | each package |

The dropped-payload row is accepted: the library adds no tag. The token-lifetime row is accepted in loop 14 and has no AC. Each other material risk already has a numeric AC.

## Pending Step 2

These risks land on each language package task:

| Risk | AC | Owner |
|------|----|-------|
| This package's position bytes differ from the fixture | AC-3 | each package |
| Unpack returns part of a short buffer | AC-8 | each package |
| A clear flag is stored as 0 | AC-4, AC-5 | each package |

Strings, lists, and dictionaries:

| Risk | AC | Owner |
|------|----|-------|
| A string count includes its own 2 bytes, so the next field starts inside the text | AZ-1938 AC-1 | AZ-1938 |
| A list count consumes the following field | AZ-1939 AC-3 | AZ-1939 |
| A dictionary pair count is read as a byte length | AZ-1940 AC-1, AZ-1940 AC-3 | AZ-1940 |
| Two languages agree with a fixture but not with each other on a nested map | AZ-1941 AC-1, AZ-1941 AC-2 | AZ-1941 |

## Deferred

None.

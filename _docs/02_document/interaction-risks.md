# Interaction risks

## Flows and seams

| Flow | Seam | What crosses |
|------|------|----------------|
| F1 Pack | caller → package | a value |
| F2 Unpack | caller → package | bytes |
| F3 Publish | the six packages, via the golden fixture | the hex |
| F3 Publish | Actions → the six registries | one package per language in the tag |

## Risks

| Risk | Outcome | AC | Owner |
|------|---------|----|-------|
| The six languages write different bytes for the same list | mismatch count is 0, or the tag publishes nothing | AC-3, AC-14 | AZ-1875 and each package |
| Unpack returns part of a short buffer | value count is 0, and the next pack still matches the golden hex | AC-8 | each package |
| A clear flag is stored as 0 | a present 0 is written; absence adds 0 bytes | AC-4, AC-5 | each package |
| A language missing from the tag still publishes | that registry receives 0 packages | AC-15 | AZ-1875 |

No new acceptance criterion. Each material risk already has a numeric AC.

## Pending Step 2

These risks land on each language package task:

| Risk | AC | Owner |
|------|----|-------|
| This package's position bytes differ from the fixture | AC-3 | each package |
| Unpack returns part of a short buffer | AC-8 | each package |
| A clear flag is stored as 0 | AC-4, AC-5 | each package |

## Deferred

None.

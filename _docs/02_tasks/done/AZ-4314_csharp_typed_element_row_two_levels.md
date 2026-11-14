---
loop: 128
branch: dev
---

# C#: a typed list or dict of rows counts two levels in the depth rule (D20)

**Task**: AZ-4314_csharp_typed_element_row_two_levels
**Name**: C#: a typed list or dict of rows counts two levels in the depth rule (D20)
**Description**: C# counts the element-row group of a typed list or dict as a level, as every other package and the C# map form do.
**Complexity**: 1 point
**Dependencies**: AZ-4296 (done)
**Component**: csharp, contract scheme-depth.md
**Tracker**: AZ-4314
**Epic**: AZ-4133

## Problem
`csharp/SchemeOrder.cs` `LevelsOf` gave a group that is the element row of a list or dict (`Binding.Member.IsElementRow`) 0 levels, so a typed list of rows was one level; the contract (1.0.2) says a list counts one level plus its element's own kind, and the other eight packages and the C# map form count two.

## Acceptance Criteria
**AC-1** Given 128 typed `list` levels (and `dict`), when built, then they build; 129 are refused with the contract text.
**AC-2** Given the C# suite, when run, then it passes; the typed 256-level pack and unpack tests use 128 typed levels.
**AC-3** Given the contract, when read, then 1.0.3 states that a typed list of rows is two levels in every form.

## Constraints
No packet change; no other package changes.

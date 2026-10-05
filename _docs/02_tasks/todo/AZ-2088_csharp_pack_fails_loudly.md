# C# pack fails loudly instead of dropping values; the scheme owns its field list

**Task**: AZ-2088_csharp_pack_fails_loudly
**Name**: C# loud pack errors and immutable scheme
**Description**: C# pack throws for a missing required value, a field bound to another row type and a float `when` that cannot be compared; a scheme copies its fields and never mutates shared `Field`/`Condition` objects.
**Complexity**: 3 points
**Dependencies**: AZ-2087_csharp_forward_refs (same resolver in `SchemeOrder`), AZ-2079_csharp_bool_rule_flag_limit (presence rule for flag bits)
**Component**: csharp
**Tracker**: AZ-2088
**Epic**: AZ-2069

## Problem

Each probe below was reproduced against a copy of the sources at `d108141` unless marked "code reading".

### Defect 1 — a missing value outside a flag bit is silently left out
- `csharp/Walker.cs:262-272` `PackScalar` and `:246-254` `PackBytes` return without writing when the value is absent (`IsPresent`, `:39-40`). The packet gets shorter and the peer misreads every later field.
- Probe: `new Scheme<NullRow>(1, Field.U16<NullRow>(0, x => x.Heading), Field.U8<NullRow>(1, x => x.Tail))`, `NullRow { ushort? Heading; byte Tail; }`, row `{ Tail = 7 }` → **`01 07`**: Heading's 2 bytes are missing and no error is raised. The peer reads `07` plus the next byte as Heading.
- Inside `Repeat`/`Times`: lists of unequal length make later rounds miss values (`SliceValues`, `Walker.cs:223-244`). These are silently omitted too (code reading). `Times` with a list shorter than its count does the same (`Walker.Counted.cs:179-188`).
- Absent `List`/`Dict`/`Sized` throw `KeyNotFoundException` (`Walker.Counted.cs:257,299,12`), not an error that names the field (code reading).
- Java throws `IllegalArgumentException: missing field <id>` (`Walker.java:223-224`); Python and TypeScript raise as well.

### Defect 2 — a field declared on another row type is silently left out
- `Scheme<T>(int, params Field[])` (`Packbin.cs:8-15`) accepts any `Field`. `Field.U16<OtherRow>(…)` records only the member **name** (`Field.cs:218-219`), and values are looked up by name.
- Probe: `new Scheme<NullRow>(1, Field.U16<BoolRow>(0, x => x.Other), Field.U8<NullRow>(1, x => x.Tail))` → constructs; `{ Tail = 7 }` packs **`01 07`**. `Other` does not exist on `NullRow`, so it is skipped with no error.
- An existing test already mixes row types by accident: `FieldIdBindingTests.cs:131-133` builds `Scheme<PointsRow>` with `Field.U16<MarkerRow>(0, x => x.Sid)`. It passes only because both rows have a member named `Sid`.

### Defect 3 — `when` on a float throws
- `Walker.cs:443-451` `ValuesEqual` compares numbers with `Convert.ToDecimal` (line 448), which throws for NaN, ±∞ and |x| > 7.9·10²⁸.
- Probe: `new Scheme<FloatRow>(1, Field.F64<FloatRow>(0, x => x.F), Field.When(1, Condition.Eq(0, 1.0), Field.U8<FloatRow>(1, x => x.B)))`, `{ F = double.NaN, B = 1 }` → **`OverflowException`** from `Pack`. Unpack throws the same.
- Java compares floats with `Double.compare` (`Walker.java:416-427`).

### Defect 4 — the scheme does not own its fields; construction mutates shared objects
- `Packbin.cs:14` stores the caller's `params Field[]` array as `Fields`. The caller can replace elements after validation.
- `SchemeOrder.ResolveField` writes `Condition.FieldName` (`Packbin.cs:275` → `:68`) and `Field.CountName` (`:284`, `:289` → `Field.cs:84`) on objects the caller may reuse. Reusing one `Condition.Eq(0, …)` or one counted `Field` in two schemes where id 0 names different members re-binds the **first** scheme to the second scheme's member name (code reading).
- Java copies the list (`Scheme.java:20`) and resolves by id at run time, so it is not affected.

## Outcome

- Pack throws `ArgumentException` naming the field (member name and order id) whenever a field that is walked has no value. The exceptions:
  - a direct flag-bit child: absence means bit clear;
  - a field inside a `when` whose condition is false (it is not walked).
- Repeat children must hold lists of equal length, and `times` lists must have exactly `count` items. Otherwise `ArgumentException`.
- `new Scheme<T>(…)` throws `ArgumentException` when any field (at any depth, outside list/dict elements and nested rows, which bind their own row types) was declared for a row type other than `T`.
- `when` on floats never throws. Floats compare as `double` with the same result as Java's rule (`Double.compare` semantics: NaN equals NaN, −0.0 ≠ 0.0).
- A scheme copies its field list, and no `Field` or `Condition` changes after construction. One field or condition can safely be reused in many schemes.

## Scope

### Included
- Absence checks in pack for every value kind; repeat/times length checks.
- Declaring row type recorded per `Field` and checked by `Scheme<T>`.
- Float comparison in `ValuesEqual`.
- Scheme-local storage of resolved count/condition bindings (or id-based lookup) instead of mutating `Field`/`Condition`.
- Fix of the mixed-type test `FieldIdBindingTests.Ac4_NestedRowTypeHasOwnIds` (use `Field.U16<PointsRow>`).

### Excluded
- Nested rows and list/dict element binding (task 23).
- Error labels (C15). Messages may name both member and id.
- Removing public `Bound<T>` (C22, undecided).

## Acceptance Criteria

**AC-1: Missing required value throws**
Given `U16 Heading` (`ushort?`, not in flags) and `U8 Tail`
When `{ Tail = 7 }` is packed
Then `ArgumentException` names `Heading`, and no bytes are returned.

**AC-2: Flag-bit absence still allowed**
Given the golden position scheme with `Heading/Speed/Altitude` in `Flags`
When the golden row is packed
Then `4001000065cd1d00a3e1110100` (unchanged).

**AC-3: Repeat/times lengths checked**
Given `Repeat(0, I32 Lat, I32 Lon)` with `Lat = [1,2]`, `Lon = [3]`, and `Times(1, 0, I32 Lat, I32 Lon)` with `N = 2`, `Lat = [10]`
When packed
Then `ArgumentException` for each, naming the short list.

**AC-4: Absent list/dict/sized names the field**
Given a `List`, `Dict` or `Sized` member that is `null` outside flags
When packed
Then `ArgumentException` naming the field (not `KeyNotFoundException`).

**AC-5: Foreign row type rejected**
Given `new Scheme<NullRow>(1, Field.U16<BoolRow>(0, x => x.Other), …)`
When constructed
Then `ArgumentException` naming `BoolRow` and `NullRow`. Schemes built: 0.

**AC-6: Float `when` never throws**
Given `F64 F` and `When(1, Eq(0, 1.0), U8 B)`
When rows with `F` = NaN, +∞, 1e30 and 1.0 are packed and unpacked
Then no exception. Only `F = 1.0` writes `B`, and each packet round-trips.

**AC-7: Scheme owns its fields**
Given a `Field[]` passed to `new Scheme<T>(1, array)`
When the caller then replaces `array[0]`
Then the scheme still packs the original layout.

**AC-8: Shared condition and field are not re-bound**
Given one `Condition.Eq(0, (byte)1)` used by scheme S1 (id 0 = `Kind`) and scheme S2 (id 0 = `Mode`), with S2 built after S1
When S1 packs a row with `Kind = 1`
Then the `when` group is written, exactly as when S1 is the only scheme.

**AC-9: Existing bytes unchanged**
Given all existing tests (with the mixed-type test corrected) and the golden/route fixtures
When the suite runs
Then all pass with identical bytes.

## Non-Functional Requirements

**Performance**
- AC-10 ≤ 1 s. The type check runs only at construction.

**Reliability**
- Pack either returns bytes the peer can read, or throws. It never returns a short packet silently.

## Unit Tests

AC-1, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8 must fail first.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | probe `NullRow { Tail = 7 }` | `ArgumentException`; today `0107` |
| AC-2 | `SchemeTests.Ac2_RowHasNoTypeMember` | golden hex |
| AC-3 | repeat `Lat=[1,2]`, `Lon=[3]` | `ArgumentException` |
| AC-3 | times `N=2`, `Lat=[10]`, `Lon=[20,40]` | `ArgumentException` |
| AC-4 | `ListRow { Xs = null }` with `Field.List` | `ArgumentException` naming `Xs` |
| AC-5 | probe foreign `BoolRow.Other` field | `ArgumentException` at construction |
| AC-6 | probe `FloatRow { F = NaN }` | no exception; `B` not written; round-trip |
| AC-6 | `F = 1.0` | `B` written |
| AC-7 | mutate the caller array after construction | bytes unchanged |
| AC-8 | shared `Condition` across two schemes (rows `KindRow`, `ModeRow`) | S1 behaves as if alone |
| AC-9 | full C# suite | green |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-9 | `fixtures/golden.hex`, `language-pair.sh` | C# ↔ other languages | 0 mismatched bytes | AC-3 (project) |

## Constraints

- ADR-001: no shared checker with Java.
- No wire change for packets that were valid. Only calls that produced unreadable packets now throw.
- `Field.*<T>` factories and `Fields<T>` keep their signatures. Recording the declaring type is internal.

## Risks & Mitigation

**Risk 1: Callers relying on silent omission of a nullable non-flag field**
- *Risk*: their peers already misread those packets.
- *Mitigation*: the exception message suggests putting the field under `Flags` when it is optional.

**Risk 2: Dictionary pack path**
- *Risk*: `Pack(scheme, IReadOnlyDictionary)` (used by tests and the C# language-pair driver) now throws for keys it used to skip.
- *Mitigation*: run `language-pair.sh` and the driver cases in CI before merging.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Float equality semantics (NaN = NaN, −0.0 ≠ 0.0) chosen to match Java. TS/Python/Rust/C++ may differ; a cross-language rule is not specified in `schema.md`. | C15 / docs | open | Low |
| Behavior change: pack throws where it silently dropped data. A public-API behavior change, but every affected packet was unreadable. | user | accepted-risk | Medium |
| `FieldIdBindingTests.Ac4` uses a field of `MarkerRow` in a `PointsRow` scheme; it must be corrected, not deleted. | implementer | open | Low |

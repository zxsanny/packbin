using System.Collections;

namespace Packbin;

internal static partial class Walker
{
    private static void PackFlags(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        buffer.Reserve(1, FirstName(field) ?? "flags");
        var at = buffer.Count;
        buffer.Add(0);
        byte flags = 0;
        for (var i = 0; i < field.Children.Length; i++)
        {
            var inner = field.Children[i].Inner!;
            if (!BitOn(values, inner, seen))
            {
                RequireNoValuesForSkippedCount(inner, values, seen);
                RequireNoStrandedCount(inner, values, seen);
                continue;
            }
            flags |= (byte)(1 << i);
            PackBitField(inner, values, buffer, seen);
        }
        buffer.Set(at, flags);
    }

    // A times whose count was skipped writes no round, so a bit left clear for it would drop the values given for it.
    private static void RequireNoValuesForSkippedCount(Field inner, IReadOnlyDictionary<string, object?> values, Scope seen)
    {
        if (ValueOfSkippedCount(inner, values, seen) is { } name)
            throw new ArgumentException(
                $"'{name}': a value is given, but the count of its times is not written, so its bit is clear; "
                + "write the count before the times");
    }

    // The first member given a value (not null, not an empty list) under a times whose count was not written. A `when`
    // whose condition is false drops its body by design, as it does anywhere else in `flags`.
    private static string? ValueOfSkippedCount(Field field, IReadOnlyDictionary<string, object?> values, Scope seen)
    {
        switch (field.Type)
        {
            case Field.Kind.Times:
                if (seen.TryGetValue(field.CountName, out var count) && count is not null)
                    return null;
                return GivenInRound(field, values, value => value is not IList { Count: 0 });
            case Field.Kind.FlagBit:
                return ValueOfSkippedCount(field.Inner!, values, seen);
            case Field.Kind.When when !ConditionHolds(field.Pred!, seen):
                return null;
            case Field.Kind.When:
            case Field.Kind.Flags:
            case Field.Kind.Group when !field.NestedRow:
                return field.Children.Select(child => ValueOfSkippedCount(child, values, seen)).FirstOrDefault(name => name is not null);
            default:
                return null;
        }
    }

    private static void PackFlagByte(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        var flags = field.FlagOwner!.Compute(values, seen);
        seen.SetFlagByte(field.FlagOwner!, flags);
        buffer.Reserve(1, field.FlagOwner!.BitInners.Select(FirstName).FirstOrDefault(n => n is not null) ?? "flag byte");
        buffer.Add(flags);
    }

    // The first name a flag byte's members declare, depth-first: C# has no name for the byte itself. A `repeat`, `times`,
    // `when` and `flags` have none of their own, so their members are looked into.
    private static string? FirstName(Field field)
    {
        switch (field.Type)
        {
            case Field.Kind.FlagBit:
                return FirstName(field.Inner!);
            case Field.Kind.Flags:
            case Field.Kind.When:
            case Field.Kind.Repeat:
            case Field.Kind.Times:
                return field.Children.Select(FirstName).FirstOrDefault(n => n is not null);
            case Field.Kind.U2:
                return field.Names[0];
            default:
                return field.Name.Length > 0 ? field.Name : null;
        }
    }

    private static void PackFlagBit(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        if ((seen.FlagByte(field.FlagOwner!) & (1 << field.BitIndex)) == 0)
        {
            RequireNoDroppedBody(field.Inner!, values, seen);
            return;
        }
        PackBitField(field.Inner!, values, buffer, seen);
    }

    // A split flag byte decides its bits where it is written, on the values written before it. A clear bit whose body
    // would still be written now is a packet pack cannot give: a `when` whose condition holds on the values written since
    // the byte (its source is written after it), or a `times` that has a value in the row and a count that is above zero
    // (written after the byte) or was skipped. A `when` whose condition is false, or one whose source was never
    // written, drops its body by design, as it does in the combined `flags` form, and packs without a word. So does a
    // `times` whose count is zero and whose value is a lone scalar; a list of values under a zero count is refused, as
    // a `times` outside a split bit refuses it.
    private static void RequireNoDroppedBody(Field bit, IReadOnlyDictionary<string, object?> values, Scope seen)
    {
        var dropped = DroppedBody(bit, values, seen);
        if (dropped is var (name, reason))
            throw new ArgumentException($"'{name}' has a value, but its flag bit is clear: {reason}");
        RequireNoStrandedCount(bit, values, seen);
    }

    private static (string Name, string Reason)? DroppedBody(Field bit, IReadOnlyDictionary<string, object?> values, Scope seen)
    {
        switch (bit.Type)
        {
            case Field.Kind.When:
                var given = ConditionHolds(bit.Pred!, seen) ? FirstGiven(values, bit.Children, seen) : null;
                return given is null ? null : (given, "the condition that decides the bit is written after the flag byte");
            case Field.Kind.Times:
                var counted = seen.TryGetValue(bit.CountName, out var count) && count is not null;
                if (counted && BorrowedCount(bit, seen) == 0)
                {
                    // A lone value has no round to be dropped from; a list with items holds rounds the count denies.
                    var listed = GivenInRound(bit, values, value => value is IList { Count: > 0 });
                    return listed is null ? null : (listed, "the times count is 0, so it takes no values");
                }
                // An empty list is no body: nothing is dropped from it (AZ-2384).
                var body = GivenInRound(bit, values, value => value is not IList { Count: 0 });
                return body is null
                    ? null
                    : (body, counted
                        ? "the count that decides the bit is written after the flag byte"
                        : "the count that decides the bit was skipped");
            case Field.Kind.FlagBit:
                return DroppedBody(bit.Inner!, values, seen);
            case Field.Kind.Group or Field.Kind.Flags when !bit.NestedRow:
                foreach (var child in bit.Children)
                {
                    if (DroppedBody(child, values, seen) is { } found)
                        return found;
                }
                return null;
            default:
                return null;
        }
    }

    private static string? FirstGiven(IReadOnlyDictionary<string, object?> values, IEnumerable<Field> fields, Scope seen)
    {
        foreach (var field in fields)
        {
            var name = field.Type switch
            {
                Field.Kind.When when !ConditionHolds(field.Pred!, seen) => null,
                Field.Kind.When or Field.Kind.Flags or Field.Kind.Group when !field.NestedRow =>
                    FirstGiven(values, field.Children, seen),
                Field.Kind.FlagBit => FirstGiven(values, [field.Inner!], seen),
                Field.Kind.Times or Field.Kind.Repeat => GivenInRound(field, values),
                Field.Kind.U2 => field.Names.FirstOrDefault(n => IsPresent(values, n)),
                _ => (IsGroupValue(field) || field.Type == Field.Kind.Group) && IsPresent(values, field.Name) ? field.Name : null,
            };
            if (name is not null)
                return name;
        }
        return null;
    }

    private static object? UnpackFlags(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values)
    {
        if (bytes.Length - offset < 1)
            return new ShortPacket(field.Name, 1, bytes.Length - offset);
        var flags = bytes[offset++];
        if (field.Name.Length > 0)
            values[field.Name] = flags;
        foreach (var bit in field.Children)
        {
            var err = UnpackFlagBit(bit, flags, bytes, ref offset, values);
            if (err is not null)
                return err;
        }
        return null;
    }

    private static object? UnpackFlagByte(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values)
    {
        if (bytes.Length - offset < 1)
            return new ShortPacket(field.Name, 1, bytes.Length - offset);
        var flags = bytes[offset++];
        if (field.Name.Length > 0)
            values[field.Name] = flags;
        values.SetFlagByte(field.FlagOwner!, flags);
        return null;
    }

    private static object? UnpackFlagBit(
        Field field,
        byte flags,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values)
    {
        if ((flags & (1 << field.BitIndex)) == 0)
            return null;
        return UnpackField(field.Inner!, bytes, ref offset, values, repeatLists: false);
    }
}

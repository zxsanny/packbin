namespace Packbin;

internal static partial class Walker
{
    private static void PackFlags(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer,
        Scope seen)
    {
        var at = buffer.Count;
        buffer.Add(0);
        byte flags = 0;
        for (var i = 0; i < field.Children.Length; i++)
        {
            var inner = field.Children[i].Inner!;
            if (!BitOn(values, inner, seen))
                continue;
            flags |= (byte)(1 << i);
            PackBitField(inner, values, buffer, seen);
        }
        buffer[at] = flags;
    }

    private static void PackFlagByte(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer,
        Scope seen)
    {
        var flags = field.FlagOwner!.Compute(values, seen);
        seen.SetFlagByte(field.FlagOwner!, flags);
        buffer.Add(flags);
    }

    private static void PackFlagBit(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer,
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
    // the byte (its source is written after it), or a `times` that has a value in the row (its count is written after
    // the byte or was skipped). A `when` whose condition is false drops its body by design, as it does in the combined
    // `flags` form, and packs without a word.
    private static void RequireNoDroppedBody(Field bit, IReadOnlyDictionary<string, object?> values, Scope seen)
    {
        var name = DroppedBody(bit, values, seen);
        if (name is not null)
            throw new ArgumentException(
                $"'{name}' has a value, but its flag bit is clear: the condition or count that decides the bit is written "
                + "after the flag byte or was skipped");
    }

    private static string? DroppedBody(Field bit, IReadOnlyDictionary<string, object?> values, Scope seen) =>
        bit.Type switch
        {
            Field.Kind.When => ConditionHolds(bit.Pred!, seen) ? FirstGiven(values, bit.Children, seen) : null,
            Field.Kind.Times => RoundNames(bit, packing: true).FirstOrDefault(name => IsPresent(values, name)),
            Field.Kind.Group when !bit.NestedRow =>
                bit.Children.Select(child => DroppedBody(child, values, seen)).FirstOrDefault(name => name is not null),
            _ => null,
        };

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
                Field.Kind.Times or Field.Kind.Repeat => RoundNames(field, packing: true).FirstOrDefault(n => IsPresent(values, n)),
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

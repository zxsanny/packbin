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
            RequireNoDroppedBody(field.Inner!, values);
            return;
        }
        PackBitField(field.Inner!, values, buffer, seen);
    }

    // A split flag byte decides its bits where it is written, on the values written before it. A clear bit of a `when`
    // or `times` that still has a value in the row (its condition or count is false, was skipped, or is written after the
    // byte) would drop that value without a word, and pack could not give a packet its own unpack accepts.
    private static void RequireNoDroppedBody(Field bit, IReadOnlyDictionary<string, object?> values)
    {
        var name = DroppedBody(bit, values);
        if (name is not null)
            throw new ArgumentException(
                $"'{name}' has a value, but its flag bit is clear: the condition or count that decides the bit is false, "
                + "missing, or written after the flag byte");
    }

    private static string? DroppedBody(Field bit, IReadOnlyDictionary<string, object?> values) =>
        bit.Type switch
        {
            Field.Kind.When => FirstGiven(values, bit.Children),
            Field.Kind.Times => RoundNames(bit, packing: true).FirstOrDefault(name => IsPresent(values, name)),
            Field.Kind.Group when !bit.NestedRow => bit.Children.Select(child => DroppedBody(child, values)).FirstOrDefault(name => name is not null),
            _ => null,
        };

    private static string? FirstGiven(IReadOnlyDictionary<string, object?> values, IEnumerable<Field> fields)
    {
        foreach (var field in fields)
        {
            var name = field.Type switch
            {
                Field.Kind.When or Field.Kind.Flags or Field.Kind.Group when !field.NestedRow =>
                    FirstGiven(values, field.Children),
                Field.Kind.FlagBit => FirstGiven(values, [field.Inner!]),
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

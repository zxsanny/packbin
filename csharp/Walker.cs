namespace Packbin;

internal static partial class Walker
{
    public static bool IsPresent(IReadOnlyDictionary<string, object?> values, string name) =>
        values.TryGetValue(name, out var v) && v is not null;

    public static void PackField(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        switch (field.Type)
        {
            case Field.Kind.Flags:
                PackFlags(field, values, buffer, seen);
                break;
            case Field.Kind.FlagByte:
                PackFlagByte(field, values, buffer, seen);
                break;
            case Field.Kind.FlagBit:
                PackFlagBit(field, values, buffer, seen);
                break;
            case Field.Kind.When:
                PackWhen(field, values, buffer, seen);
                break;
            case Field.Kind.Repeat:
                PackRepeat(field, values, buffer, seen);
                break;
            case Field.Kind.Bytes:
                PackBytes(field, values, buffer, seen);
                break;
            case Field.Kind.Group:
                PackGroup(field, values, buffer, seen);
                break;
            case Field.Kind.Sized:
                PackSized(field, values, buffer, seen);
                break;
            case Field.Kind.U2:
                PackU2(field, values, buffer, seen);
                break;
            case Field.Kind.Bits:
                PackBits(field, values, buffer, seen);
                break;
            case Field.Kind.Packed:
                PackPacked(field, values, buffer, seen);
                break;
            case Field.Kind.Times:
                PackTimes(field, values, buffer, seen);
                break;
            case Field.Kind.Utf8:
                PackUtf8(field, values, buffer, seen);
                break;
            case Field.Kind.List:
                PackList(field, values, buffer, seen);
                break;
            case Field.Kind.Dict:
                PackDict(field, values, buffer, seen);
                break;
            case Field.Kind.Bool:
                PackBool(field, seen);
                break;
            default:
                PackScalar(field, values, buffer, seen);
                break;
        }
    }

    public static object? UnpackField(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values,
        bool repeatLists)
    {
        return field.Type switch
        {
            Field.Kind.Flags => UnpackFlags(field, bytes, ref offset, values),
            Field.Kind.FlagByte => UnpackFlagByte(field, bytes, ref offset, values),
            Field.Kind.FlagBit => UnpackFlagBit(field, values.FlagByte(field.FlagOwner!), bytes, ref offset, values),
            Field.Kind.When => UnpackWhen(field, bytes, ref offset, values),
            Field.Kind.Repeat => UnpackRepeat(field, bytes, ref offset, values),
            Field.Kind.Bytes => UnpackBytes(field, bytes, ref offset, values, repeatLists),
            Field.Kind.Group => UnpackGroup(field, bytes, ref offset, values),
            Field.Kind.Sized => UnpackSized(field, bytes, ref offset, values, repeatLists),
            Field.Kind.U2 => UnpackU2(field, bytes, ref offset, values, repeatLists),
            Field.Kind.Bits => UnpackBits(field, bytes, ref offset, values, repeatLists),
            Field.Kind.Packed => UnpackPacked(field, bytes, ref offset, values, repeatLists),
            Field.Kind.Times => UnpackTimes(field, bytes, ref offset, values),
            Field.Kind.Utf8 => UnpackUtf8(field, bytes, ref offset, values, repeatLists),
            Field.Kind.List => UnpackList(field, bytes, ref offset, values, repeatLists),
            Field.Kind.Dict => UnpackDict(field, bytes, ref offset, values, repeatLists),
            Field.Kind.Bool => UnpackBool(field, bytes, ref offset, values, repeatLists),
            _ => UnpackScalar(field, bytes, ref offset, values, repeatLists),
        };
    }

    // A bool is a flag bit with no payload; only a set bit reaches here.
    private static void PackBool(Field field, Scope seen) => seen[field.Name] = true;

    private static object? UnpackBool(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values,
        bool repeatLists)
    {
        _ = bytes;
        _ = offset;
        Store(values, field.Name, true, repeatLists);
        return null;
    }

    // Decided on the fields written so far in this scope, as unpack decides it on the fields read.
    private static void PackWhen(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        if (!ConditionHolds(field.Pred!, seen))
            return;
        foreach (var child in field.Children)
            PackField(child, values, buffer, seen);
    }

    private static void PackBytes(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        var raw = RequireBytes(field, values);
        if (raw.Length != field.ByteCount)
            throw new ArgumentException($"Field '{field.Name}' needs {field.ByteCount} bytes.");
        buffer.Reserve(raw.Length, field.Name);
        buffer.AddRange(raw);
        seen[field.Name] = raw;
    }

    // A typed row's nested row packs from its own values and its own `seen`, as unpack reads it into a scope of its own.
    private static void PackGroup(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        if (!(field.NestedRow && values is RowValues))
        {
            foreach (var child in field.Children)
                PackField(child, values, buffer, seen);
            return;
        }
        var nested = (RowValues)RequireValue(field, values);
        var inner = seen.Fresh();
        foreach (var child in field.Children)
            PackField(child, nested, buffer, inner);
    }

    private static void PackScalar(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        var value = RequireValue(field, values);
        Span<byte> tmp = stackalloc byte[8];
        var width = field.ByteCount;
        WriteScalar(field, value, tmp.Slice(0, width));
        buffer.Reserve(width, field.Name);
        for (var i = 0; i < width; i++)
            buffer.Add(tmp[i]);
        seen[field.Name] = value;
    }

    private static object? UnpackGroup(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values)
    {
        if (field.Children.Length == 0)
            values[field.Name] = true;
        var scope = field.NestedRow && values.Scoped ? values.Fresh() : values;
        foreach (var child in field.Children)
        {
            var err = UnpackField(child, bytes, ref offset, scope, repeatLists: false);
            if (err is not null)
                return err;
        }
        if (!ReferenceEquals(scope, values))
            values[field.Name] = scope;
        return null;
    }

    private static object? UnpackWhen(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values)
    {
        if (!ConditionHolds(field.Pred!, values))
            return null;
        foreach (var child in field.Children)
        {
            var err = UnpackField(child, bytes, ref offset, values, repeatLists: false);
            if (err is not null)
                return err;
        }
        return null;
    }

    private static object? UnpackRepeat(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values)
    {
        var names = RoundNames(field, packing: false);
        var slots = SlotsPerRound(names);
        var rounds = 0;
        while (offset < bytes.Length)
        {
            if (!values.Budget.TryStartRound(rounds++, slots))
                return InterimBadValue(field.Name, bytes.Length - offset);
            var roundStart = offset;
            var group = values.Fresh();
            foreach (var child in field.Children)
            {
                var err = UnpackField(child, bytes, ref offset, group, repeatLists: false);
                if (err is not null)
                    return err;
            }
            // A round that reads nothing can never reach the end of the buffer.
            if (offset == roundStart)
                return new TrailingBytes(bytes.Length - offset);
            AppendRound(values, group, names);
        }
        return null;
    }

    private static void Append(Dictionary<string, object?> values, string key, object? value)
    {
        if (!values.TryGetValue(key, out var existing) || existing is null)
        {
            values[key] = new List<object?> { value };
            return;
        }
        if (existing is List<object?> list)
        {
            list.Add(value);
            return;
        }
        values[key] = new List<object?> { existing, value };
    }

    private static object? UnpackBytes(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values,
        bool repeatLists)
    {
        var left = bytes.Length - offset;
        if (left < field.ByteCount)
            return new ShortPacket(field.Name, field.ByteCount, left);
        var slice = bytes.Slice(offset, field.ByteCount).ToArray();
        offset += field.ByteCount;
        Store(values, field.Name, slice, repeatLists);
        return null;
    }

    private static object? UnpackScalar(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values,
        bool repeatLists)
    {
        var left = bytes.Length - offset;
        if (left < field.ByteCount)
            return new ShortPacket(field.Name, field.ByteCount, left);
        var value = ReadScalar(field, bytes.Slice(offset, field.ByteCount));
        offset += field.ByteCount;
        Store(values, field.Name, value, repeatLists);
        return null;
    }

    private static void Store(
        Dictionary<string, object?> values,
        string name,
        object? value,
        bool repeatLists)
    {
        if (repeatLists)
            Append(values, name, value);
        else
            values[name] = value;
    }
}

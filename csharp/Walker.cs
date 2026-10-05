using System.Collections;
using System.Globalization;

namespace Packbin;

internal static partial class Walker
{
    public static bool IsPresent(IReadOnlyDictionary<string, object?> values, string name) =>
        values.TryGetValue(name, out var v) && v is not null;

    public static void PackField(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        switch (field.Type)
        {
            case Field.Kind.Flags:
                PackFlags(field, values, buffer);
                break;
            case Field.Kind.FlagByte:
                PackFlagByte(field, values, buffer);
                break;
            case Field.Kind.FlagBit:
                PackFlagBit(field, values, buffer);
                break;
            case Field.Kind.When:
                PackWhen(field, values, buffer);
                break;
            case Field.Kind.Repeat:
                PackRepeat(field, values, buffer);
                break;
            case Field.Kind.Bytes:
                PackBytes(field, values, buffer);
                break;
            case Field.Kind.Group:
                PackGroup(field, values, buffer);
                break;
            case Field.Kind.Sized:
                PackSized(field, values, buffer);
                break;
            case Field.Kind.U2:
                PackU2(field, values, buffer);
                break;
            case Field.Kind.Bits:
                PackBits(field, values, buffer);
                break;
            case Field.Kind.Packed:
                PackPacked(field, values, buffer);
                break;
            case Field.Kind.Times:
                PackTimes(field, values, buffer);
                break;
            case Field.Kind.Utf8:
                PackUtf8(field, values, buffer);
                break;
            case Field.Kind.List:
                PackList(field, values, buffer);
                break;
            case Field.Kind.Dict:
                PackDict(field, values, buffer);
                break;
            case Field.Kind.Bool:
                PackBool(field, values, buffer);
                break;
            default:
                PackScalar(field, values, buffer);
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

    private static void PackBool(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        _ = field;
        _ = values;
        _ = buffer;
    }

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

    private static void PackFlags(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        var flags = field.FlagOwner!.Compute(values);
        buffer.Add(flags);
        for (var i = 0; i < field.Children.Length; i++)
        {
            if ((flags & (1 << i)) == 0)
                continue;
            PackBitField(field.Children[i].Inner!, values, buffer);
        }
    }

    private static void PackFlagByte(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        buffer.Add(field.FlagOwner!.Compute(values));
    }

    private static void PackFlagBit(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        if (!BitOn(values, field.Inner!))
            return;
        PackBitField(field.Inner!, values, buffer);
    }

    private static void PackWhen(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        if (!ConditionHolds(field.Pred!, values))
            return;
        foreach (var child in field.Children)
            PackField(child, values, buffer);
    }

    private static void PackRepeat(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        var count = RepeatCount(field, values);
        for (var i = 0; i < count; i++)
        {
            var slice = SliceValues(field, values, i);
            foreach (var child in field.Children)
                PackField(child, slice, buffer);
        }
    }

    private static int RepeatCount(Field field, IReadOnlyDictionary<string, object?> values)
    {
        var count = 0;
        foreach (var child in field.Children)
        {
            if (!values.TryGetValue(child.Name, out var v) || v is null)
                continue;
            if (v is IList list)
                count = Math.Max(count, list.Count);
            else
                count = Math.Max(count, 1);
        }
        return count;
    }

    private static Dictionary<string, object?> SliceValues(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        int index)
    {
        var slice = new Dictionary<string, object?>();
        foreach (var child in field.Children)
        {
            if (!values.TryGetValue(child.Name, out var v) || v is null)
                continue;
            if (v is IList list)
            {
                if (index < list.Count)
                    slice[child.Name] = list[index];
            }
            else if (index == 0)
            {
                slice[child.Name] = v;
            }
        }
        return slice;
    }

    private static void PackBytes(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        if (!IsPresent(values, field.Name))
            return;
        var raw = (byte[])values[field.Name]!;
        if (raw.Length != field.ByteCount)
            throw new ArgumentException($"Field '{field.Name}' needs {field.ByteCount} bytes.");
        buffer.AddRange(raw);
    }

    private static void PackGroup(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        foreach (var child in field.Children)
            PackField(child, values, buffer);
    }

    private static void PackScalar(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        if (!IsPresent(values, field.Name))
            return;
        var value = values[field.Name]!;
        Span<byte> tmp = stackalloc byte[8];
        var width = field.ByteCount;
        WriteScalar(field, value, tmp[..width]);
        for (var i = 0; i < width; i++)
            buffer.Add(tmp[i]);
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

    private static object? UnpackGroup(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values)
    {
        if (field.Children.Length == 0)
            values[field.Name] = true;
        foreach (var child in field.Children)
        {
            var err = UnpackField(child, bytes, ref offset, values, repeatLists: false);
            if (err is not null)
                return err;
        }
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
        while (offset < bytes.Length)
        {
            var roundStart = offset;
            var group = new Scope();
            foreach (var child in field.Children)
            {
                var err = UnpackField(child, bytes, ref offset, group, repeatLists: false);
                if (err is not null)
                    return err;
            }
            // A round that reads nothing can never reach the end of the buffer.
            if (offset == roundStart)
                return new TrailingBytes(bytes.Length - offset);
            foreach (var (key, value) in group)
                Append(values, key, value);
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

    private static bool ConditionHolds(Condition condition, IReadOnlyDictionary<string, object?> values)
    {
        if (!values.TryGetValue(condition.FieldName, out var actual) || actual is null)
            return false;
        return ValuesEqual(actual, condition.Value);
    }

    private static bool ValuesEqual(object a, object b)
    {
        if (a is byte[] aa && b is byte[] bb)
            return aa.AsSpan().SequenceEqual(bb);
        if (a is float or double && !IsDecimalRange(a))
            return false;
        if (IsNumber(a) && IsNumber(b))
            return Convert.ToDecimal(a, CultureInfo.InvariantCulture)
                == Convert.ToDecimal(b, CultureInfo.InvariantCulture);
        return Equals(a, b);
    }

    // NaN, infinity and huge floats read from a packet have no decimal form; they equal nothing.
    private static bool IsDecimalRange(object value)
    {
        var d = Convert.ToDouble(value, CultureInfo.InvariantCulture);
        return double.IsFinite(d) && Math.Abs(d) < 7.9e28;
    }

    private static bool IsNumber(object value) =>
        value is byte or sbyte or ushort or short or uint or int or ulong or long or float or double or decimal;
}

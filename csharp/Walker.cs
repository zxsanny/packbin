using System.Buffers.Binary;
using System.Collections;
using System.Globalization;

namespace Packbin;

internal sealed class FlagGroup
{
    public string Name { get; }
    public List<Field> BitInners { get; } = [];
    public byte Unpacked { get; set; }

    public FlagGroup(string name) => Name = name;

    public Field AddBit(Field inner)
    {
        var index = BitInners.Count;
        BitInners.Add(inner);
        return Field.CreateFlagBit(this, index, inner);
    }

    public byte Compute(IReadOnlyDictionary<string, object?> values)
    {
        byte flags = 0;
        for (var i = 0; i < BitInners.Count; i++)
        {
            if (Walker.IsPresent(values, BitInners[i].Name))
                flags |= (byte)(1 << i);
        }
        return flags;
    }
}

internal static class Walker
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
            default:
                PackScalar(field, values, buffer);
                break;
        }
    }

    public static object? UnpackField(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values,
        bool repeatLists)
    {
        return field.Type switch
        {
            Field.Kind.Flags => UnpackFlags(field, bytes, ref offset, values),
            Field.Kind.FlagByte => UnpackFlagByte(field, bytes, ref offset, values),
            Field.Kind.FlagBit => UnpackFlagBit(field, bytes, ref offset, values),
            Field.Kind.When => UnpackWhen(field, bytes, ref offset, values),
            Field.Kind.Repeat => UnpackRepeat(field, bytes, ref offset, values),
            Field.Kind.Bytes => UnpackBytes(field, bytes, ref offset, values, repeatLists),
            _ => UnpackScalar(field, bytes, ref offset, values, repeatLists),
        };
    }

    private static void PackFlags(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        var flags = field.Group!.Compute(values);
        buffer.Add(flags);
        foreach (var bit in field.Children)
            PackFlagBit(bit, values, buffer);
    }

    private static void PackFlagByte(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        buffer.Add(field.Group!.Compute(values));
    }

    private static void PackFlagBit(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        if (!IsPresent(values, field.Name))
            return;
        PackField(field.Inner!, values, buffer);
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
        Dictionary<string, object?> values)
    {
        if (bytes.Length - offset < 1)
            return new ShortPacket(field.Name, 1, bytes.Length - offset);
        var flags = bytes[offset++];
        values[field.Name] = flags;
        field.Group!.Unpacked = flags;
        foreach (var bit in field.Children)
        {
            var err = UnpackFlagBit(bit, bytes, ref offset, values);
            if (err is not null)
                return err;
        }
        return null;
    }

    private static object? UnpackFlagByte(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values)
    {
        if (bytes.Length - offset < 1)
            return new ShortPacket(field.Name, 1, bytes.Length - offset);
        var flags = bytes[offset++];
        values[field.Name] = flags;
        field.Group!.Unpacked = flags;
        return null;
    }

    private static object? UnpackFlagBit(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values)
    {
        var bit = 1 << field.BitIndex;
        if ((field.Group!.Unpacked & bit) == 0)
            return null;
        return UnpackField(field.Inner!, bytes, ref offset, values, repeatLists: false);
    }

    private static object? UnpackWhen(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values)
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
        Dictionary<string, object?> values)
    {
        while (offset < bytes.Length)
        {
            var group = new Dictionary<string, object?>();
            foreach (var child in field.Children)
            {
                var err = UnpackField(child, bytes, ref offset, group, repeatLists: false);
                if (err is not null)
                    return err;
            }
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
        Dictionary<string, object?> values,
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
        Dictionary<string, object?> values,
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
        if (!values.TryGetValue(condition.Field, out var actual) || actual is null)
            return false;
        return ValuesEqual(actual, condition.Value);
    }

    private static bool ValuesEqual(object a, object b)
    {
        if (a is byte[] aa && b is byte[] bb)
            return aa.AsSpan().SequenceEqual(bb);
        if (IsNumber(a) && IsNumber(b))
            return Convert.ToDecimal(a, CultureInfo.InvariantCulture)
                == Convert.ToDecimal(b, CultureInfo.InvariantCulture);
        return Equals(a, b);
    }

    private static bool IsNumber(object value) =>
        value is byte or sbyte or ushort or short or uint or int or ulong or long or float or double or decimal;

    private static void WriteScalar(Field field, object value, Span<byte> dest)
    {
        switch (field.Type)
        {
            case Field.Kind.U8:
                dest[0] = Convert.ToByte(value, CultureInfo.InvariantCulture);
                break;
            case Field.Kind.I8:
                dest[0] = (byte)Convert.ToSByte(value, CultureInfo.InvariantCulture);
                break;
            case Field.Kind.U16:
            {
                var n = Convert.ToUInt16(value, CultureInfo.InvariantCulture);
                if (field.BigEndian) BinaryPrimitives.WriteUInt16BigEndian(dest, n);
                else BinaryPrimitives.WriteUInt16LittleEndian(dest, n);
                break;
            }
            case Field.Kind.I16:
            {
                var n = Convert.ToInt16(value, CultureInfo.InvariantCulture);
                if (field.BigEndian) BinaryPrimitives.WriteInt16BigEndian(dest, n);
                else BinaryPrimitives.WriteInt16LittleEndian(dest, n);
                break;
            }
            case Field.Kind.U32:
            {
                var n = Convert.ToUInt32(value, CultureInfo.InvariantCulture);
                if (field.BigEndian) BinaryPrimitives.WriteUInt32BigEndian(dest, n);
                else BinaryPrimitives.WriteUInt32LittleEndian(dest, n);
                break;
            }
            case Field.Kind.I32:
            {
                var n = Convert.ToInt32(value, CultureInfo.InvariantCulture);
                if (field.BigEndian) BinaryPrimitives.WriteInt32BigEndian(dest, n);
                else BinaryPrimitives.WriteInt32LittleEndian(dest, n);
                break;
            }
            case Field.Kind.U64:
            {
                var n = Convert.ToUInt64(value, CultureInfo.InvariantCulture);
                if (field.BigEndian) BinaryPrimitives.WriteUInt64BigEndian(dest, n);
                else BinaryPrimitives.WriteUInt64LittleEndian(dest, n);
                break;
            }
            case Field.Kind.I64:
            {
                var n = Convert.ToInt64(value, CultureInfo.InvariantCulture);
                if (field.BigEndian) BinaryPrimitives.WriteInt64BigEndian(dest, n);
                else BinaryPrimitives.WriteInt64LittleEndian(dest, n);
                break;
            }
            case Field.Kind.F32:
            {
                var n = Convert.ToSingle(value, CultureInfo.InvariantCulture);
                if (field.BigEndian) BinaryPrimitives.WriteSingleBigEndian(dest, n);
                else BinaryPrimitives.WriteSingleLittleEndian(dest, n);
                break;
            }
            case Field.Kind.F64:
            {
                var n = Convert.ToDouble(value, CultureInfo.InvariantCulture);
                if (field.BigEndian) BinaryPrimitives.WriteDoubleBigEndian(dest, n);
                else BinaryPrimitives.WriteDoubleLittleEndian(dest, n);
                break;
            }
            default:
                throw new InvalidOperationException($"Cannot write {field.Type}.");
        }
    }

    private static object ReadScalar(Field field, ReadOnlySpan<byte> src) =>
        field.Type switch
        {
            Field.Kind.U8 => src[0],
            Field.Kind.I8 => (sbyte)src[0],
            Field.Kind.U16 => field.BigEndian
                ? BinaryPrimitives.ReadUInt16BigEndian(src)
                : BinaryPrimitives.ReadUInt16LittleEndian(src),
            Field.Kind.I16 => field.BigEndian
                ? BinaryPrimitives.ReadInt16BigEndian(src)
                : BinaryPrimitives.ReadInt16LittleEndian(src),
            Field.Kind.U32 => field.BigEndian
                ? BinaryPrimitives.ReadUInt32BigEndian(src)
                : BinaryPrimitives.ReadUInt32LittleEndian(src),
            Field.Kind.I32 => field.BigEndian
                ? BinaryPrimitives.ReadInt32BigEndian(src)
                : BinaryPrimitives.ReadInt32LittleEndian(src),
            Field.Kind.U64 => field.BigEndian
                ? BinaryPrimitives.ReadUInt64BigEndian(src)
                : BinaryPrimitives.ReadUInt64LittleEndian(src),
            Field.Kind.I64 => field.BigEndian
                ? BinaryPrimitives.ReadInt64BigEndian(src)
                : BinaryPrimitives.ReadInt64LittleEndian(src),
            Field.Kind.F32 => field.BigEndian
                ? BinaryPrimitives.ReadSingleBigEndian(src)
                : BinaryPrimitives.ReadSingleLittleEndian(src),
            Field.Kind.F64 => field.BigEndian
                ? BinaryPrimitives.ReadDoubleBigEndian(src)
                : BinaryPrimitives.ReadDoubleLittleEndian(src),
            _ => throw new InvalidOperationException($"Cannot read {field.Type}."),
        };
}

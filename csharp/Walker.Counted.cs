using System.Collections;
using System.Globalization;

namespace Packbin;

internal static partial class Walker
{
    private static void PackSized(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        var count = RequireCount(values, field.CountName, field.Name);
        var raw = (byte[])values[field.Name]!;
        if (raw.Length != count)
            throw new ArgumentException($"{field.Name}: expected {count} bytes, got {raw.Length}");
        buffer.AddRange(raw);
    }

    private static void PackU2(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        var names = field.Names;
        var nbytes = (names.Length + 3) / 4;
        var raw = new byte[nbytes];
        for (var i = 0; i < names.Length; i++)
        {
            if (!values.TryGetValue(names[i], out var value) || value is null || value is bool)
                throw new ArgumentException($"{names[i]}: expected 2-bit int");
            var n = Convert.ToInt32(value, CultureInfo.InvariantCulture);
            if (n is < 0 or > 3)
                throw new ArgumentException($"{names[i]}: expected 2-bit int");
            raw[i / 4] |= (byte)(n << ((i % 4) * 2));
        }
        buffer.AddRange(raw);
    }

    private static void PackBits(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        var count = RequireCount(values, field.CountName, field.Name);
        if (values[field.Name] is not IList raw || raw.Count != count)
            throw new ArgumentException($"{field.Name}: expected {count} bits");
        var nbytes = (count + 7) / 8;
        var packed = new byte[nbytes];
        for (var i = 0; i < count; i++)
        {
            var bit = Convert.ToInt32(raw[i], CultureInfo.InvariantCulture);
            if (bit is not (0 or 1))
                throw new ArgumentException($"{field.Name}: expected 0 or 1");
            packed[i / 8] |= (byte)(bit << (i % 8));
        }
        buffer.AddRange(packed);
    }

    private static int RequireCount(
        IReadOnlyDictionary<string, object?> values,
        string countName,
        string fieldName)
    {
        if (!values.TryGetValue(countName, out var v) || v is null)
            throw new InvalidOperationException($"{fieldName}: count '{countName}' is missing");
        return Convert.ToInt32(v, CultureInfo.InvariantCulture);
    }

    private static object? UnpackSized(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values,
        bool repeatLists)
    {
        if (!values.TryGetValue(field.CountName, out var countObj) || countObj is null || countObj is bool)
            throw new InvalidOperationException($"{field.Name}: count '{field.CountName}' is missing");
        var count = Convert.ToInt32(countObj, CultureInfo.InvariantCulture);
        var left = bytes.Length - offset;
        if (left < count)
            return new ShortPacket(field.Name, count, left);
        var slice = bytes.Slice(offset, count).ToArray();
        offset += count;
        Store(values, field.Name, slice, repeatLists);
        return null;
    }

    private static object? UnpackU2(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values,
        bool repeatLists)
    {
        var names = field.Names;
        var nbytes = (names.Length + 3) / 4;
        var left = bytes.Length - offset;
        if (left < nbytes)
            return new ShortPacket(names[0], nbytes, left);
        for (var i = 0; i < names.Length; i++)
        {
            var value = (bytes[offset + i / 4] >> ((i % 4) * 2)) & 3;
            Store(values, names[i], value, repeatLists);
        }
        offset += nbytes;
        return null;
    }

    private static object? UnpackBits(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values,
        bool repeatLists)
    {
        if (!values.TryGetValue(field.CountName, out var countObj) || countObj is null || countObj is bool)
            throw new InvalidOperationException($"{field.Name}: count '{field.CountName}' is missing");
        var count = Convert.ToInt32(countObj, CultureInfo.InvariantCulture);
        var nbytes = (count + 7) / 8;
        var left = bytes.Length - offset;
        if (left < nbytes)
            return new ShortPacket(field.Name, nbytes, left);
        var bits = new List<int>(count);
        for (var i = 0; i < count; i++)
            bits.Add((bytes[offset + i / 8] >> (i % 8)) & 1);
        offset += nbytes;
        Store(values, field.Name, bits, repeatLists);
        return null;
    }
}

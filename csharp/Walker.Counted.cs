using System.Collections;
using System.Globalization;
using System.Text;

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

    private static int BorrowedCount(Field field, IReadOnlyDictionary<string, object?> values)
    {
        var count = RequireCount(values, field.CountName, field.Name) + field.Bias;
        if (count < 0)
            throw new ArgumentException($"{field.Name}: item count {count}");
        return count;
    }

    private static int PackedBytes(int width, int count) =>
        width == 2 ? (count + 3) / 4 : (count + 7) / 8;

    private static void PackPacked(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        var count = BorrowedCount(field, values);
        if (values[field.Name] is not IList raw || raw.Count != count)
            throw new ArgumentException($"{field.Name}: expected {count} items");
        var width = field.ByteCount;
        var max = width == 2 ? 3 : 1;
        var shift = width == 2 ? 2 : 1;
        var per = width == 2 ? 4 : 8;
        var packed = new byte[PackedBytes(width, count)];
        for (var i = 0; i < count; i++)
        {
            var n = Convert.ToInt32(raw[i], CultureInfo.InvariantCulture);
            if (n < 0 || n > max)
                throw new ArgumentException($"{field.Name}: expected 0..{max}");
            packed[i / per] |= (byte)(n << ((i % per) * shift));
        }
        buffer.AddRange(packed);
    }

    private static object? UnpackPacked(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values,
        bool repeatLists)
    {
        var count = BorrowedCount(field, values);
        var nbytes = PackedBytes(field.ByteCount, count);
        var left = bytes.Length - offset;
        if (left < nbytes)
            return new ShortPacket(field.Name, nbytes, left);
        var width = field.ByteCount;
        var mask = width == 2 ? 3 : 1;
        var shift = width == 2 ? 2 : 1;
        var per = width == 2 ? 4 : 8;
        var items = new List<int>(count);
        for (var i = 0; i < count; i++)
            items.Add((bytes[offset + i / per] >> ((i % per) * shift)) & mask);
        offset += nbytes;
        Store(values, field.Name, items, repeatLists);
        return null;
    }

    private static void PackTimes(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        var count = BorrowedCount(field, values);
        for (var i = 0; i < count; i++)
        {
            var slice = SliceValues(field, values, i);
            foreach (var child in field.Children)
                PackField(child, slice, buffer);
        }
    }

    private static object? UnpackTimes(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values)
    {
        var count = BorrowedCount(field, values);
        var built = new Dictionary<string, List<object?>>();
        for (var i = 0; i < count; i++)
        {
            var group = new Dictionary<string, object?>();
            foreach (var child in field.Children)
            {
                var err = UnpackField(child, bytes, ref offset, group, repeatLists: false);
                if (err is not null)
                    return err;
            }
            foreach (var (key, value) in group)
            {
                if (!built.TryGetValue(key, out var list))
                {
                    list = [];
                    built[key] = list;
                }
                list.Add(value);
            }
        }
        foreach (var (key, list) in built)
            values[key] = list;
        return null;
    }

    private static void PackUtf8(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        if (!values.TryGetValue(field.Name, out var value) || value is not string text)
            throw new ArgumentException($"{field.Name}: expected string");
        var raw = Encoding.UTF8.GetBytes(text);
        if (raw.Length > 65535)
            throw new ArgumentException($"{field.Name}: utf-8 length {raw.Length}");
        buffer.Add((byte)raw.Length);
        buffer.Add((byte)(raw.Length >> 8));
        buffer.AddRange(raw);
    }

    private static object? UnpackUtf8(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values,
        bool repeatLists)
    {
        var left = bytes.Length - offset;
        if (left < 2)
            return new ShortPacket(field.Name, 2, left);
        var count = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;
        left = bytes.Length - offset;
        if (left < count)
            return new ShortPacket(field.Name, count, left);
        var text = Encoding.UTF8.GetString(bytes.Slice(offset, count));
        offset += count;
        Store(values, field.Name, text, repeatLists);
        return null;
    }

    private static void PackList(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        if (values[field.Name] is not IList items)
            throw new ArgumentException($"{field.Name}: expected list");
        if (items.Count > 65535)
            throw new ArgumentException($"{field.Name}: length {items.Count}");
        buffer.Add((byte)items.Count);
        buffer.Add((byte)(items.Count >> 8));
        var child = field.Children[0];
        foreach (var item in items)
        {
            var slice = new Dictionary<string, object?>(values) { [child.Name] = item };
            PackField(child, slice, buffer);
        }
    }

    private static object? UnpackList(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values,
        bool repeatLists)
    {
        var left = bytes.Length - offset;
        if (left < 2)
            return new ShortPacket(field.Name, 2, left);
        var count = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;
        var child = field.Children[0];
        var items = new List<object?>(count);
        for (var i = 0; i < count; i++)
        {
            var one = new Dictionary<string, object?>();
            var err = UnpackField(child, bytes, ref offset, one, false);
            if (err is not null)
                return err;
            items.Add(one[child.Name]);
        }
        Store(values, field.Name, items, repeatLists);
        return null;
    }

    private static void PackDict(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        if (values[field.Name] is not IDictionary map)
            throw new ArgumentException($"{field.Name}: expected dictionary");
        if (map.Count > 65535)
            throw new ArgumentException($"{field.Name}: length {map.Count}");
        var entries = new List<(byte[] KeyBytes, object? Value)>(map.Count);
        foreach (DictionaryEntry entry in map)
        {
            if (entry.Key is not string key)
                throw new ArgumentException($"{field.Name}: expected string keys");
            var keyBytes = Encoding.UTF8.GetBytes(key);
            if (keyBytes.Length > 65535)
                throw new ArgumentException($"{field.Name}: utf-8 length {keyBytes.Length}");
            entries.Add((keyBytes, entry.Value));
        }
        entries.Sort(static (a, b) => CompareUtf8Bytes(a.KeyBytes, b.KeyBytes));
        buffer.Add((byte)entries.Count);
        buffer.Add((byte)(entries.Count >> 8));
        var child = field.Children[0];
        foreach (var (keyBytes, value) in entries)
        {
            buffer.Add((byte)keyBytes.Length);
            buffer.Add((byte)(keyBytes.Length >> 8));
            buffer.AddRange(keyBytes);
            var slice = new Dictionary<string, object?>(values) { [child.Name] = value };
            PackField(child, slice, buffer);
        }
    }

    private static object? UnpackDict(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Dictionary<string, object?> values,
        bool repeatLists)
    {
        var left = bytes.Length - offset;
        if (left < 2)
            return new ShortPacket(field.Name, 2, left);
        var count = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;
        var child = field.Children[0];
        var items = new Dictionary<string, object?>(count);
        for (var i = 0; i < count; i++)
        {
            left = bytes.Length - offset;
            if (left < 2)
                return new ShortPacket(field.Name, 2, left);
            var keyLen = bytes[offset] | (bytes[offset + 1] << 8);
            offset += 2;
            left = bytes.Length - offset;
            if (left < keyLen)
                return new ShortPacket(field.Name, keyLen, left);
            var key = Encoding.UTF8.GetString(bytes.Slice(offset, keyLen));
            offset += keyLen;
            var one = new Dictionary<string, object?>();
            var err = UnpackField(child, bytes, ref offset, one, false);
            if (err is not null)
                return err;
            if (items.ContainsKey(key))
                return new ShortPacket(field.Name, 0, 0);
            items[key] = one[child.Name];
        }
        Store(values, field.Name, items, repeatLists);
        return null;
    }

    private static int CompareUtf8Bytes(byte[] a, byte[] b)
    {
        var n = Math.Min(a.Length, b.Length);
        for (var i = 0; i < n; i++)
        {
            var c = a[i].CompareTo(b[i]);
            if (c != 0)
                return c;
        }
        return a.Length.CompareTo(b.Length);
    }
}

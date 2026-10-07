using System.Collections;
using System.Globalization;
using System.Text;

namespace Packbin;

internal static partial class Walker
{
    // utf8 length, list count and dictionary count are written as u16.
    private const int MaxLength = ushort.MaxValue;

    private static void PackSized(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer,
        Scope seen)
    {
        var count = RequireCount(seen, field.CountName, field.Name);
        var raw = (byte[])RequireValue(field, values);
        if (raw.Length != count)
            throw new ArgumentException($"{field.Name}: expected {count} bytes, got {raw.Length}");
        buffer.AddRange(raw);
        seen[field.Name] = raw;
    }

    private static void PackU2(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer,
        Scope seen)
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
            seen[names[i]] = value;
        }
        buffer.AddRange(raw);
    }

    private static void PackBits(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer,
        Scope seen)
    {
        var count = RequireCount(seen, field.CountName, field.Name);
        if (RequireValue(field, values) is not IList raw || raw.Count != count)
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
        seen[field.Name] = raw;
    }

    // The count is read from what pack wrote in this scope, as unpack reads it from what it read: a count field that a
    // `when` or a clear flag bit skipped is missing.
    private static int RequireCount(Scope seen, string countName, string fieldName)
    {
        if (!seen.TryGetValue(countName, out var v) || v is null)
            throw new ArgumentException($"{fieldName}: count '{countName}' is missing");
        return Convert.ToInt32(v, CultureInfo.InvariantCulture);
    }

    // No bad-value error type until C15: the same stand-in the duplicate dictionary key already uses.
    // Every bad-value return goes through here, so C15 changes this one method.
    private static ShortPacket InterimBadValue(string field, int left) => new(field, 0, left);

    private static int ClampToInt(long value) => value > int.MaxValue ? int.MaxValue : (int)value;

    private static long CeilDiv(long count, int per) => count / per + (count % per == 0 ? 0 : 1);

    // Item count and byte length of a bit/packed run. False when the run does not fit in the bytes left, or when its
    // item count does not fit an int (possible once a buffer holds more than 2^28 bytes).
    internal static bool FitsItems(long wanted, int per, int left, out int count, out int needed)
    {
        var bytesNeeded = CeilDiv(wanted, per);
        needed = ClampToInt(bytesNeeded);
        count = 0;
        if (bytesNeeded > left || wanted > int.MaxValue)
            return false;
        count = (int)wanted;
        return true;
    }

    // False when the count field has no value (behind a clear flag bit), is not a number, or is negative.
    private static bool TryUnpackCount(Field field, IReadOnlyDictionary<string, object?> values, out long count)
    {
        count = 0;
        if (!values.TryGetValue(field.CountName, out var value))
            return false;
        switch (value)
        {
            case byte or sbyte or ushort or short or uint or int or long:
                count = Convert.ToInt64(value, CultureInfo.InvariantCulture);
                break;
            case ulong big:
                count = big > long.MaxValue ? long.MaxValue : (long)big;
                break;
            case double narrow:
                // u8 ... u32 arrive here as a double (ReadScalar's switch has natural type double), always a whole number
                // in range; u64 and i64 are boxed as ulong and long and handled by the typed cases above.
                count = (long)narrow;
                break;
            default:
                return false;
        }
        if (count < 0)
            return false;
        count += field.Bias;
        return count >= 0;
    }

    private static object? UnpackSized(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values,
        bool repeatLists)
    {
        var left = bytes.Length - offset;
        if (!TryUnpackCount(field, values, out var count))
            return InterimBadValue(field.Name, left);
        if (left < count)
            return new ShortPacket(field.Name, ClampToInt(count), left);
        var slice = bytes.Slice(offset, (int)count).ToArray();
        offset += (int)count;
        Store(values, field.Name, slice, repeatLists);
        return null;
    }

    private static object? UnpackU2(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values,
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
        Scope values,
        bool repeatLists)
    {
        var left = bytes.Length - offset;
        if (!TryUnpackCount(field, values, out var wanted))
            return InterimBadValue(field.Name, left);
        if (!FitsItems(wanted, 8, left, out var count, out var needed))
            return new ShortPacket(field.Name, needed, left);
        var bits = new List<int>(count);
        for (var i = 0; i < count; i++)
            bits.Add((bytes[offset + i / 8] >> (i % 8)) & 1);
        offset += needed;
        Store(values, field.Name, bits, repeatLists);
        return null;
    }

    private static int BorrowedCount(Field field, Scope seen)
    {
        var count = RequireCount(seen, field.CountName, field.Name) + field.Bias;
        if (count < 0)
            throw new ArgumentException($"{field.Name}: item count {count}");
        return count;
    }

    private static int PackedBytes(int width, int count) =>
        width == 2 ? (count + 3) / 4 : (count + 7) / 8;

    private static void PackPacked(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer,
        Scope seen)
    {
        var count = BorrowedCount(field, seen);
        if (RequireValue(field, values) is not IList raw || raw.Count != count)
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
        seen[field.Name] = raw;
    }

    private static object? UnpackPacked(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values,
        bool repeatLists)
    {
        var left = bytes.Length - offset;
        if (!TryUnpackCount(field, values, out var wanted))
            return InterimBadValue(field.Name, left);
        var width = field.ByteCount;
        var mask = width == 2 ? 3 : 1;
        var shift = width == 2 ? 2 : 1;
        var per = width == 2 ? 4 : 8;
        if (!FitsItems(wanted, per, left, out var count, out var needed))
            return new ShortPacket(field.Name, needed, left);
        var items = new List<int>(count);
        for (var i = 0; i < count; i++)
            items.Add((bytes[offset + i / per] >> ((i % per) * shift)) & mask);
        offset += needed;
        Store(values, field.Name, items, repeatLists);
        return null;
    }

    private static object? UnpackTimes(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values)
    {
        if (!TryUnpackCount(field, values, out var count))
            return InterimBadValue(field.Name, bytes.Length - offset);
        var names = RoundNames(field, packing: false);
        var slots = SlotsPerRound(names);
        var built = new Dictionary<string, object?>();
        for (long i = 0; i < count; i++)
        {
            if (!values.Budget.TryStartRound(i, slots))
                return InterimBadValue(field.Name, bytes.Length - offset);
            var roundStart = offset;
            var group = values.Fresh();
            foreach (var child in field.Children)
            {
                var err = UnpackField(child, bytes, ref offset, group, repeatLists: false);
                if (err is not null)
                    return err;
            }
            // A round that reads nothing would only burn through a huge count.
            if (offset == roundStart)
                return InterimBadValue(field.Name, bytes.Length - roundStart);
            AppendRound(built, group, names);
        }
        foreach (var pair in built)
            values[pair.Key] = pair.Value;
        return null;
    }

    private static void PackUtf8(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer,
        Scope seen)
    {
        if (!values.TryGetValue(field.Name, out var value) || value is not string text)
            throw new ArgumentException($"{field.Name}: expected string");
        var raw = Encoding.UTF8.GetBytes(text);
        if (raw.Length > MaxLength)
            throw new ArgumentException($"{field.Name}: utf-8 length {raw.Length}");
        buffer.Add((byte)raw.Length);
        buffer.Add((byte)(raw.Length >> 8));
        buffer.AddRange(raw);
        seen[field.Name] = text;
    }

    private static object? UnpackUtf8(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values,
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
        if (!Compat.TryUtf8(bytes.Slice(offset, count), out var text))
            return InterimBadValue(field.Name, left);
        offset += count;
        Store(values, field.Name, text, repeatLists);
        return null;
    }

    private static void PackList(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        if (RequireValue(field, values) is not IList items)
            throw new ArgumentException($"{field.Name}: expected list");
        if (items.Count > MaxLength)
            throw new ArgumentException($"{field.Name}: length {items.Count}");
        buffer.Add((byte)items.Count);
        buffer.Add((byte)(items.Count >> 8));
        var child = field.Children[0];
        foreach (var item in items)
        {
            PackField(child, ElementValues(values, child, item), buffer, new Scope());
        }
    }

    // A typed row's element has values of its own. A dictionary row's element sees the row's values with its own added.
    private static IReadOnlyDictionary<string, object?> ElementValues(
        IReadOnlyDictionary<string, object?> values,
        Field element,
        object? item)
    {
        if (values is RowValues)
            return RowBinding.Element(element, item);
        var slice = values.ToDictionary(p => p.Key, p => p.Value);
        slice[element.Name] = item;
        return slice;
    }

    private static object? UnpackList(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values,
        bool repeatLists)
    {
        var left = bytes.Length - offset;
        if (left < 2)
            return new ShortPacket(field.Name, 2, left);
        var count = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;
        var child = field.Children[0];
        // Each element reads at least one byte, so the bytes left bound the count a packet can really hold.
        var items = new List<object?>(Math.Min(count, bytes.Length - offset));
        for (var i = 0; i < count; i++)
        {
            var one = values.Fresh();
            var elementStart = offset;
            var err = UnpackField(child, bytes, ref offset, one, false);
            if (err is not null)
                return err;
            // An element that reads nothing would let a few bytes ask for millions of empty items.
            if (offset == elementStart)
                return InterimBadValue(field.Name, bytes.Length - elementStart);
            items.Add(ElementValue(child, one));
        }
        Store(values, field.Name, items, repeatLists);
        return null;
    }

    private static void PackDict(Field field, IReadOnlyDictionary<string, object?> values, List<byte> buffer)
    {
        if (RequireValue(field, values) is not IDictionary map)
            throw new ArgumentException($"{field.Name}: expected dictionary");
        if (map.Count > MaxLength)
            throw new ArgumentException($"{field.Name}: length {map.Count}");
        var entries = new List<(byte[] KeyBytes, object? Value)>(map.Count);
        foreach (DictionaryEntry entry in map)
        {
            if (entry.Key is not string key)
                throw new ArgumentException($"{field.Name}: expected string keys");
            var keyBytes = Encoding.UTF8.GetBytes(key);
            if (keyBytes.Length > MaxLength)
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
            PackField(child, ElementValues(values, child, value), buffer, new Scope());
        }
    }

    private static object? UnpackDict(
        Field field,
        ReadOnlySpan<byte> bytes,
        ref int offset,
        Scope values,
        bool repeatLists)
    {
        var left = bytes.Length - offset;
        if (left < 2)
            return new ShortPacket(field.Name, 2, left);
        var count = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;
        var child = field.Children[0];
        var items = new Dictionary<string, object?>(Math.Min(count, bytes.Length - offset));
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
            if (!Compat.TryUtf8(bytes.Slice(offset, keyLen), out var key))
                return InterimBadValue(field.Name, left);
            offset += keyLen;
            var one = values.Fresh();
            var valueStart = offset;
            var err = UnpackField(child, bytes, ref offset, one, false);
            if (err is not null)
                return err;
            // A zero-width value would let a few bytes ask for 65 535 empty entries.
            if (offset == valueStart)
                return InterimBadValue(field.Name, bytes.Length - valueStart);
            if (items.ContainsKey(key))
                return new ShortPacket(field.Name, 0, 0);
            items[key] = ElementValue(child, one);
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

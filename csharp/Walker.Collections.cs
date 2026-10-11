using System.Collections;
using System.Text;

namespace Packbin;

internal static partial class Walker
{
    private static void PackList(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
    {
        if (RequireValue(field, values) is not IList items)
            throw new ArgumentException($"{field.Name}: expected list");
        if (items.Count > MaxLength)
            throw new ArgumentException($"{field.Name}: length {items.Count}");
        buffer.Reserve(2, field.Name);
        buffer.AddU16(items.Count);
        var child = field.Children[0];
        foreach (var item in items)
        {
            PackField(child, ElementValues(values, child, item), buffer, seen.Fresh());
        }
    }

    // An element has values of its own, typed row or dictionary row: a group's element is the row of its members that
    // unpack returns, any other element is its one value. A name the row around it also holds is never lent to it, so a
    // missing member is reported by name (and a flags element cannot set a bit the element leaves clear). A flags
    // element that is a row of its members by name (what unpack returns) is that row even in a typed row; only an
    // instance of the row type goes through its accessors.
    private static IReadOnlyDictionary<string, object?> ElementValues(
        IReadOnlyDictionary<string, object?> values,
        Field element,
        object? item)
    {
        if (element.Type == Field.Kind.Flags && !(values is RowValues && RowBinding.IsRow(element, item)))
            return item switch
            {
                null => new Dictionary<string, object?>(),
                IReadOnlyDictionary<string, object?> row => row,
                _ => throw new ArgumentException($"a flags element is a row of its members by name, got {item.GetType().Name}"),
            };
        if (values is RowValues)
            return RowBinding.Element(element, item);
        if (element is { Type: Field.Kind.Group, Children.Length: > 0 } && item is IReadOnlyDictionary<string, object?> members)
            return members.ToDictionary(p => p.Key, p => p.Value);
        return new Dictionary<string, object?> { [element.Name] = item };
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

    private static void PackDict(
        Field field,
        IReadOnlyDictionary<string, object?> values,
        PackOut buffer,
        Scope seen)
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
        buffer.Reserve(2, field.Name);
        buffer.AddU16(entries.Count);
        var child = field.Children[0];
        foreach (var (keyBytes, value) in entries)
        {
            buffer.Reserve(2 + keyBytes.Length, field.Name);
            buffer.AddU16(keyBytes.Length);
            buffer.AddRange(keyBytes);
            PackField(child, ElementValues(values, child, value), buffer, seen.Fresh());
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

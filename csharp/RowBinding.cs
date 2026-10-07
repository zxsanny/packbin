using System.Collections;
using System.Globalization;

namespace Packbin;

// The values of one typed row, by member name. A nested row's values sit under its member's name as a RowValues of
// their own, so a row never sees the members of the rows around it. Walker tells these apart from the flat
// dictionaries of the dictionary overloads, where a nested row's members share the row's names.
internal sealed class RowValues : Dictionary<string, object?>
{
    public RowValues(int capacity)
        : base(capacity)
    {
    }
}

// Reads and writes the members of a typed row through the accessor each field was declared with.
internal static class RowBinding
{
    public static RowValues Read(IReadOnlyList<Field> fields, object? row)
    {
        var values = new RowValues(fields.Count);
        if (row is not null)
        {
            for (var i = 0; i < fields.Count; i++)
                ReadField(fields[i], row, values);
        }
        return values;
    }

    // The values behind one element of a list or dict. An item of the element field's row type is read through that
    // field's accessor; any other item is the element's value itself.
    public static RowValues Element(Field element, object? item)
    {
        if (item is not null && element.RowType is { } rowType && rowType.IsInstanceOfType(item))
            return Read([element], item);
        var values = new RowValues(1);
        if (item is not null)
            values[element.Name] = item;
        return values;
    }

    private static void ReadField(Field field, object row, RowValues into)
    {
        switch (field.Type)
        {
            case Field.Kind.FlagByte:
                break;
            case Field.Kind.FlagBit:
                ReadField(field.Inner!, row, into);
                break;
            case Field.Kind.When:
            case Field.Kind.Flags:
            case Field.Kind.Repeat:
            case Field.Kind.Times:
                foreach (var child in field.Children)
                    ReadField(child, row, into);
                break;
            case Field.Kind.U2:
                for (var i = 0; i < field.Names.Length; i++)
                    Put(into, field.Names[i], field.Binding!.Slots[i].Get(row));
                break;
            case Field.Kind.Group when field.NestedRow:
                if (field.Binding!.Member.Get(row) is { } nested)
                    into[field.Name] = Read(field.Children, nested);
                break;
            case Field.Kind.Group:
                Put(into, field.Name, field.Binding!.Member.Get(row));
                foreach (var child in field.Children)
                    ReadField(child, row, into);
                break;
            default:
                Put(into, field.Name, field.Binding!.Member.Get(row));
                break;
        }
    }

    private static void Put(RowValues into, string name, object? value)
    {
        if (value is not null)
            into[name] = value;
    }

    public static T To<T>(IReadOnlyList<Field> fields, IReadOnlyDictionary<string, object?> values) where T : new()
    {
        var row = new T();
        Apply(fields, values, row);
        return row;
    }

    private static void Apply(IReadOnlyList<Field> fields, IReadOnlyDictionary<string, object?> values, object row)
    {
        for (var i = 0; i < fields.Count; i++)
            ApplyField(fields[i], values, row);
    }

    private static void ApplyField(Field field, IReadOnlyDictionary<string, object?> values, object row)
    {
        switch (field.Type)
        {
            case Field.Kind.FlagByte:
                break;
            case Field.Kind.FlagBit:
                ApplyField(field.Inner!, values, row);
                break;
            case Field.Kind.When:
            case Field.Kind.Flags:
            case Field.Kind.Repeat:
            case Field.Kind.Times:
                Apply(field.Children, values, row);
                break;
            case Field.Kind.U2:
                for (var i = 0; i < field.Names.Length; i++)
                {
                    if (values.TryGetValue(field.Names[i], out var slot) && slot is not null)
                        field.Binding!.Slots[i].Set(row, slot);
                }
                break;
            case Field.Kind.Group when !field.NestedRow:
                SetIfRead(field, values, row);
                Apply(field.Children, values, row);
                break;
            default:
                SetIfRead(field, values, row);
                break;
        }
    }

    private static void SetIfRead(Field field, IReadOnlyDictionary<string, object?> values, object row)
    {
        if (values.TryGetValue(field.Name, out var raw) && raw is not null)
            SetValue(field, row, raw);
    }

    // `raw` is what unpack read for the field: a value, a list or dictionary of them, or (typed rows) the Scope of a
    // nested row.
    private static void SetValue(Field field, object row, object raw)
    {
        var binding = field.Binding!;
        switch (field.Type)
        {
            case Field.Kind.Group when field.NestedRow:
                var nested = binding.CreateNested!();
                Apply(field.Children, (IReadOnlyDictionary<string, object?>)raw, nested);
                binding.Member.Set(row, nested);
                break;
            case Field.Kind.List:
                binding.Member.Set(row, ListOf(field, binding.Shape!, (IList)raw));
                break;
            case Field.Kind.Dict:
                binding.Member.Set(row, DictOf(field, binding.Shape!, (IDictionary)raw));
                break;
            default:
                binding.Member.Set(row, raw);
                break;
        }
    }

    // A list the member can hold: the one unpack read when its elements already fit, else a new one with each element
    // turned into the member's element type (a row, or a converted number).
    private static object ListOf(Field field, CollectionShape shape, IList read)
    {
        if (Fits(field, shape, read))
            return read;
        if (shape.IsArray)
        {
            var array = Array.CreateInstance(shape.ElementType, read.Count);
            for (var i = 0; i < read.Count; i++)
                array.SetValue(Element(field, shape, read[i]), i);
            return array;
        }
        var list = (IList)Created(field, shape);
        foreach (var item in read)
            list.Add(Element(field, shape, item));
        return list;
    }

    private static object DictOf(Field field, CollectionShape shape, IDictionary read)
    {
        if (Fits(field, shape, read))
            return read;
        var map = (IDictionary)Created(field, shape);
        foreach (DictionaryEntry entry in read)
            map.Add(entry.Key, Element(field, shape, entry.Value));
        return map;
    }

    private static bool Fits(Field field, CollectionShape shape, object read) =>
        !shape.RowElements && shape.ElementType == typeof(object) && field.Binding!.Member.Type.IsInstanceOfType(read);

    private static object Created(Field field, CollectionShape shape) =>
        shape.Create?.Invoke()
            ?? throw new InvalidCastException(
                $"Cannot build a {field.Binding!.Member.Type.Name} for '{field.Name}'.");

    private static object? Element(Field field, CollectionShape shape, object? item)
    {
        if (item is null)
            return null;
        if (shape.RowElements)
        {
            var element = shape.CreateElement!();
            var inner = field.Children[0];
            // An anchored group's fields belong to the element row itself, so its item holds them by name.
            if (inner is { Type: Field.Kind.Group, NestedRow: false, Children.Length: > 0 })
                ApplyField(inner, (IReadOnlyDictionary<string, object?>)item, element);
            else
                SetValue(inner, element, item);
            return element;
        }
        var type = Nullable.GetUnderlyingType(shape.ElementType) ?? shape.ElementType;
        return type.IsInstanceOfType(item) ? item : Convert.ChangeType(item, type, CultureInfo.InvariantCulture);
    }
}

namespace Packbin;

// When a flag bit is on, and what the field behind a set bit must hold.
internal static partial class Walker
{
    // A bool or an empty group is only a presence bit: on for true, off for false or no value. A group with children is
    // on when its own member or any value-bearing child (or a nested group's, a nested flags' or a flag bit's) has a
    // value. A `u2` is on when any of its slots has a value. A `when`, `repeat` or `times` inside a group gives it no
    // presence.
    public static bool BitOn(IReadOnlyDictionary<string, object?> values, Field inner) =>
        inner.Type switch
        {
            Field.Kind.Bool => IsTrue(values, inner.Name),
            Field.Kind.Group when inner.Children.Length == 0 => IsTrue(values, inner.Name),
            Field.Kind.Group => GroupOn(values, inner),
            Field.Kind.U2 => AnyPresent(values, inner.Names),
            _ => IsPresent(values, inner.Name),
        };

    private static bool AnyPresent(IReadOnlyDictionary<string, object?> values, string[] names)
    {
        for (var i = 0; i < names.Length; i++)
        {
            if (IsPresent(values, names[i]))
                return true;
        }
        return false;
    }

    private static bool IsTrue(IReadOnlyDictionary<string, object?> values, string name) =>
        values.TryGetValue(name, out var v) && v is true;

    // The values a group's fields read: a typed row's nested row has its own (null when the member is null), anything
    // else shares the row around it. A nested row counts for what is inside it, not for the member being non-null.
    private static IReadOnlyDictionary<string, object?>? ScopeOf(Field group, IReadOnlyDictionary<string, object?> values) =>
        group.NestedRow && values is RowValues
            ? values.TryGetValue(group.Name, out var nested) ? nested as RowValues : null
            : values;

    private static bool GroupOn(IReadOnlyDictionary<string, object?> values, Field group)
    {
        var scope = ScopeOf(group, values);
        if (scope is null)
            return false;
        if (ReferenceEquals(scope, values) && IsPresent(values, group.Name))
            return true;
        foreach (var child in group.Children)
        {
            if (ChildPresent(scope, child))
                return true;
        }
        return false;
    }

    private static bool ChildPresent(IReadOnlyDictionary<string, object?> values, Field child) =>
        child.Type switch
        {
            Field.Kind.Group => GroupOn(values, child),
            Field.Kind.U2 => AnyPresent(values, child.Names),
            Field.Kind.Flags => child.Children.Any(bit => ChildPresent(values, bit)),
            Field.Kind.FlagBit => BitOn(values, child.Inner!),
            _ => IsGroupValue(child) && IsPresent(values, child.Name),
        };

    private static bool IsGroupValue(Field child) =>
        Field.IsValueBearing(child) || child.Type is Field.Kind.List or Field.Kind.Dict;

    // The value of a field the pack walks. Only a flag bit may be left clear; a missing value anywhere else would give a
    // shorter packet that the peer reads wrongly, so it is an error that names the field.
    private static object RequireValue(Field field, IReadOnlyDictionary<string, object?> values)
    {
        if (values.TryGetValue(field.Name, out var value) && value is not null)
            return value;
        var id = field.Id >= 0 ? $" (field id {field.Id})" : "";
        throw new ArgumentException($"'{field.Name}'{id} has no value; a field that may be absent belongs in Flags");
    }

    // The field behind a set flag bit. A group there has no presence per value, so it is written in full: every value
    // in it, and in the groups nested in it, must be there. A missing one would give a packet its own unpack rejects.
    private static void PackBitField(
        Field inner,
        IReadOnlyDictionary<string, object?> values,
        List<byte> buffer,
        Scope seen)
    {
        if (inner.Type == Field.Kind.Group)
            RequireGroupValues(inner, inner, values);
        PackField(inner, values, buffer, seen);
    }

    private static void RequireGroupValues(Field flagged, Field group, IReadOnlyDictionary<string, object?> values)
    {
        var scope = ScopeOf(group, values)
            ?? throw new ArgumentException($"'{group.Name}': flag group '{flagged.Name}' is set, so it needs a value");
        foreach (var child in group.Children)
        {
            if (child.Type == Field.Kind.Group)
            {
                RequireGroupValues(flagged, child, scope);
                continue;
            }
            string[] names = child.Type == Field.Kind.U2 ? child.Names : IsGroupValue(child) ? [child.Name] : [];
            foreach (var name in names)
            {
                if (!IsPresent(scope, name))
                    throw new ArgumentException($"'{name}': flag group '{flagged.Name}' is set, so it needs a value");
            }
        }
    }
}

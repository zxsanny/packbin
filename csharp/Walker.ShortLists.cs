using System.Collections;

namespace Packbin;

// AZ-2383: a repeat takes its rounds from the longest list, and a member a flag bit can leave absent reads its list at the
// round's index. A list shorter than the rounds would silently leave the bit clear in the later rounds, which hides a
// row that dropped its data; it is refused before any round, and an entry per round (null where the member is absent)
// says what was meant. `times` keeps its rule: a list under `flags` there reads as absent for the rounds it does not reach.
internal static partial class Walker
{
    private static void RequireNoShortOptionalLists(Field repeat, IReadOnlyDictionary<string, object?> values)
    {
        var rounds = RoundCount(RoundNames(repeat, packing: true), values);
        var optional = new List<string>();
        foreach (var child in repeat.Children)
            AddOptionalNames(child, inFlags: false, optional);
        foreach (var name in optional)
        {
            if (values.TryGetValue(name, out var v) && v is IList { Count: > 0 } list && list.Count < rounds)
                throw new ArgumentException(
                    $"'{name}': {list.Count} items, repeat count {rounds}; give one entry per round, null where the member is absent");
        }
    }

    // The names of the members a flag bit can leave absent, in the order the round holds them: reached through `flags` or a
    // flag bit, also under a `when` or a group below them. A member under a `when` alone is required, as it is written
    // whenever its condition holds. An empty group has only its own name; a nested row's members are its own.
    private static void AddOptionalNames(Field field, bool inFlags, List<string> names)
    {
        switch (field.Type)
        {
            case Field.Kind.FlagByte:
                break;
            case Field.Kind.Flags:
                foreach (var bit in field.Children)
                    AddOptionalNames(bit.Inner!, inFlags: true, names);
                break;
            case Field.Kind.FlagBit:
                AddOptionalNames(field.Inner!, inFlags: true, names);
                break;
            case Field.Kind.When:
                foreach (var child in field.Children)
                    AddOptionalNames(child, inFlags, names);
                break;
            case Field.Kind.Group when field.NestedRow:
                if (inFlags)
                    names.Add(field.Name);
                break;
            case Field.Kind.Group:
                if (inFlags && field.Children.Length == 0)
                    names.Add(field.Name);
                foreach (var child in field.Children)
                    AddOptionalNames(child, inFlags, names);
                break;
            case Field.Kind.U2:
                if (inFlags)
                    names.AddRange(field.Names);
                break;
            default:
                if (inFlags)
                    names.Add(field.Name);
                break;
        }
    }
}

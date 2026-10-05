namespace Packbin;

// A split flag bit reads the byte its FlagByte() read earlier in the same container: the top level, a repeat or
// times round, or a list or dictionary element. A byte inside a when may be skipped, so it does not count outside it.
internal static class FlagScopes
{
    public static void Validate(IReadOnlyList<Field> fields) => Check(fields, []);

    private static void Check(IEnumerable<Field> fields, HashSet<FlagGroup> read)
    {
        foreach (var field in fields)
        {
            switch (field.Type)
            {
                case Field.Kind.FlagByte:
                    read.Add(field.FlagOwner!);
                    break;
                case Field.Kind.FlagBit:
                    if (!read.Contains(field.FlagOwner!))
                        throw new ArgumentException($"flag bit '{field.Name}' has no flag byte read before it in its scope");
                    Check([field.Inner!], [.. read]);
                    break;
                case Field.Kind.Flags:
                    foreach (var bit in field.Children)
                        Check([bit.Inner!], [.. read]);
                    break;
                case Field.Kind.When:
                    Check(field.Children, [.. read]);
                    break;
                case Field.Kind.Group:
                    Check(field.Children, read);
                    break;
                case Field.Kind.Repeat:
                case Field.Kind.Times:
                case Field.Kind.List:
                case Field.Kind.Dict:
                    Check(field.Children, []);
                    break;
            }
        }
    }
}

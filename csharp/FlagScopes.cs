namespace Packbin;

// Binds each split flag bit to the byte its FlagByte() read earlier in the same container: the top level, a repeat or
// times round, a list or dictionary element, or a nested row. A byte inside a when, a flags member or a flag bit's field
// is visible only there. A nested row has values of its own, so it starts with no byte visible and its bytes stay
// inside it; an anchored group shares the bytes around it.
//
// A bit is numbered by its place among the bits that follow one read of its byte, so the FlagByte() handle holds no bit
// and any number of schemes can share it. The returned fields are the scheme's own copies: every read of every handle
// gets a FlagGroup of its own, with the bits placed after it. One read holds at most eight bits.
internal static class FlagScopes
{
    public static Field[] Bind(IReadOnlyList<Field> fields) => BindAll(fields, []);

    // `visible` maps a flag byte handle to the latest read of it that this point can see.
    private static Field[] BindAll(IReadOnlyList<Field> fields, Dictionary<FlagGroup, FlagGroup> visible)
    {
        var bound = new Field[fields.Count];
        for (var i = 0; i < bound.Length; i++)
            bound[i] = BindOne(fields[i], visible);
        return bound;
    }

    private static Field BindOne(Field field, Dictionary<FlagGroup, FlagGroup> visible)
    {
        switch (field.Type)
        {
            case Field.Kind.FlagByte:
                var read = new FlagGroup(field.FlagOwner!.Name);
                visible[field.FlagOwner] = read;
                return field.With(flagOwner: read);
            case Field.Kind.FlagBit:
                if (!visible.TryGetValue(field.FlagOwner!, out var owner))
                    throw new ArgumentException($"flag bit '{field.Name}' has no flag byte read before it in its scope");
                var index = owner.Reserve(field.Inner!);
                var inner = BindOne(field.Inner!, new(visible));
                owner.Place(index, inner);
                return Field.CreateFlagBit(owner, index, inner);
            case Field.Kind.Flags:
                // Combined form: its members are numbered by position already; each is bound on its own.
                var bits = new Field[field.Children.Length];
                for (var i = 0; i < bits.Length; i++)
                    bits[i] = field.Children[i].With(inner: BindOne(field.Children[i].Inner!, new(visible)));
                return field.With(children: bits);
            case Field.Kind.When:
                return field.With(children: BindAll(field.Children, new(visible)));
            case Field.Kind.Group:
                return field.With(children: BindAll(field.Children, field.NestedRow ? [] : visible));
            case Field.Kind.Repeat:
            case Field.Kind.Times:
            case Field.Kind.List:
            case Field.Kind.Dict:
                return field.With(children: BindAll(field.Children, []));
            default:
                return field;
        }
    }
}

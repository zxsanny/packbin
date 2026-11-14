using Taken = System.Collections.Generic.Dictionary<int, (string Name, Packbin.Field.Kind Kind)>;

namespace Packbin;

internal static class SchemeOrder
{
    // The scheme's own copy of its fields, with each count and `when` bound to the member its field id names. The
    // caller's Field and Condition objects are never changed, so one can be reused in many schemes.
    public static Field[] Resolve(Type row, IReadOnlyList<Field> fields)
    {
        RequireDepth(fields);
        var scope = new Taken();
        var next = 0;
        var resolved = new Field[fields.Count];
        for (var i = 0; i < resolved.Length; i++)
            resolved[i] = Walk(fields[i], row, scope, ref next, where: TopLevel);
        resolved = FlagScopes.Bind(resolved);
        RoundScopes.Validate(resolved);
        return resolved;
    }

    internal const int MaxDepth = 256;

    // scheme-depth contract: the most containers on one path (when, flags, group or nested row, repeat, times, and a list
    // or dict with its element row) is MaxDepth. Measured first and without recursion, so no walk below sees a deeper scheme.
    // A flag bit adds no level of its own; the element row of a list or dict is one level together with its list or dict.
    // A Field object may stand in several places: one is measured again only when reached deeper than before, so a scheme
    // that uses the same field twice on every level costs its number of distinct fields, not two to the power of its depth.
    private static void RequireDepth(IReadOnlyList<Field> fields)
    {
        var pending = new Stack<(Field Field, int Depth)>();
        var deepest = new Dictionary<Field, int>();
        for (var i = fields.Count - 1; i >= 0; i--)
            pending.Push((fields[i], 0));
        while (pending.Count > 0)
        {
            var (field, above) = pending.Pop();
            if (deepest.TryGetValue(field, out var seen) && seen >= above)
                continue;
            deepest[field] = above;
            var depth = above + LevelsOf(field);
            if (depth > MaxDepth)
                throw new ArgumentException($"scheme nested too deep: more than {MaxDepth} levels; the limit is {MaxDepth}");
            if (field.Inner is { } inner)
                pending.Push((inner, depth));
            for (var i = field.Children.Length - 1; i >= 0; i--)
                pending.Push((field.Children[i], depth));
        }
    }

    private static int LevelsOf(Field field) =>
        field.Type switch
        {
            Field.Kind.When or Field.Kind.Flags or Field.Kind.Repeat or Field.Kind.Times
                or Field.Kind.List or Field.Kind.Dict => 1,
            Field.Kind.Group => field.Binding?.Member.IsElementRow == true ? 0 : 1,
            _ => 0,
        };

    // Ids number straight through repeat and times bodies, but a reference finds only the fields `scope` already holds:
    // the earlier ones of its own top level, repeat or times body, list or dict element, or nested row.
    // `row`: the row type every field here must be declared for, or a base type of it; null in a list or dict element
    // that is a single field, whose field may be declared for the value rather than a row (`U16<El>` for `ushort[]`).
    // `where`: how a refusal names that row (the scheme's, a nested row's, or the elements of a list or dict).
    // `flagBit`: the field is a direct child of Flags or the field of a FlagByte bit, the only place a bool or an empty
    // group has a bit to live in.
    private static Field Walk(
        Field field, Type? row, Taken scope, ref int next, string where, bool flagBit = false, bool inRound = false)
    {
        RequireFlagBit(field, flagBit);
        RequireRow(field, row, where);
        switch (field.Type)
        {
            case Field.Kind.When:
                RequireAnchor(field.Id, next);
                var pred = field.Pred!.Resolved(WhenSource(scope, field));
                return field.With(children: WalkChildren(field, row, scope, ref next, where, inRound), pred: pred);
            case Field.Kind.Group when field.Binding?.Member.IsElementRow == true:
                // The element row of a list or dict: its members are declared for the element row type.
                RequireAnchor(field.Id, next);
                return field.With(children: WalkChildren(field, field.RowType, scope, ref next, where, inRound));
            case Field.Kind.Flags:
            case Field.Kind.Group when !field.NestedRow:
                RequireAnchor(field.Id, next);
                return field.With(children: WalkChildren(field, row, scope, ref next, where, inRound));
            case Field.Kind.Repeat:
                RequireAnchor(field.Id, next);
                return field.With(children: WalkRound(field, row, ref next, where));
            case Field.Kind.Times:
                RequireAnchor(field.Id, next);
                var count = Count(scope, field.CountId, $"count of times {field.Id}", $"times {field.Id}");
                return field.With(children: WalkRound(field, row, ref next, where), countName: count);
            case Field.Kind.FlagBit:
                return field.With(inner: Walk(field.Inner!, row, scope, ref next, where, flagBit: true, inRound: inRound));
            case Field.Kind.Group:
            case Field.Kind.List:
            case Field.Kind.Dict:
                RequireCreatable(field, inRound);
                return field.With(children: WalkFromZero(field, inRound && field.Type == Field.Kind.Group));
            case Field.Kind.U2:
                for (var i = 0; i < field.SlotIds.Length; i++)
                    Take(field.SlotIds[i], field.Names[i], field.Type, scope, ref next);
                return field;
            case Field.Kind.Sized:
            case Field.Kind.Bits:
            case Field.Kind.Packed:
                var counted = field.With(countName: Count(
                    scope, field.CountId, $"count of field id {field.Id}", $"'{field.Name}' (field id {field.Id})"));
                Take(field.Id, field.Name, field.Type, scope, ref next);
                return counted;
            default:
                if (Field.IsValueBearing(field))
                    Take(field.Id, field.Name, field.Type, scope, ref next);
                return field;
        }
    }

    private static Field[] WalkChildren(Field field, Type? row, Taken scope, ref int next, string where, bool inRound = false)
    {
        var children = new Field[field.Children.Length];
        for (var i = 0; i < children.Length; i++)
            children[i] = Walk(field.Children[i], row, scope, ref next, where, inRound: inRound);
        return children;
    }

    // The fields of a round bound to a collection are declared for its row type E (RoundRow), named as the scheme's row.
    private static Field[] WalkRound(Field round, Type? row, ref int next, string where)
    {
        var roundRow = RoundRow(round, row);
        return WalkChildren(round, roundRow, [], ref next, roundRow == row ? where : TopLevel, inRound: true);
    }

    // A nested row, list element or dict element numbers its own fields from 0. A nested row's fields are declared for
    // its row type; a list or dict element is checked by its element row, if it is one (Walk).
    private static Field[] WalkFromZero(Field field, bool inRound)
    {
        var next = 0;
        return field.Type == Field.Kind.Group
            ? WalkChildren(field, field.Binding?.NestedType, [], ref next, $"the nested row '{field.Name}' is", inRound)
            : WalkChildren(field, null, [], ref next, $"the elements of '{field.Name}' are", inRound);
    }

    private const string TopLevel = "this scheme is for";

    // The row type the fields of a round are declared for: the enclosing row's, or for a round bound to a collection the
    // collection's row type E. The member must be one typed Unpack can fill (RowRounds.Binds), or the scheme is refused.
    private static Type? RoundRow(Field round, Type? row)
    {
        if (round.Binding?.Round is not { } rounds)
            return row;
        var member = round.Binding.Member.Type;
        if (!rounds.IsCollection)
            throw new ArgumentException(
                $"'{round.Name}': {TypeName(member)} is not a collection of rows a {round.Type.ToString().ToLowerInvariant()} can bind; "
                + "use E[], List<E> or IList<E> for a row class E");
        if (!rounds.Binds)
            throw NoConstructor(round, rounds.ElementType!);
        return rounds.ElementType;
    }

    // A value is found by member name, so a field declared for another row type would be silently left out.
    // A field declared for a base type of the row is the row's own member.
    private static void RequireRow(Field field, Type? row, string where)
    {
        if (row is not null && field.RowType is { } declared && !declared.IsAssignableFrom(row))
            throw new ArgumentException(
                $"'{field.Name}' is declared for row type {TypeName(declared)}, but {where} {TypeName(row)}");
    }

    // `List<Int32>` rather than the reflection name `List`1`, so two closed generic rows read apart.
    private static string TypeName(Type type) =>
        type.IsGenericType
            ? $"{type.Name.Substring(0, type.Name.IndexOf('`'))}<{string.Join(", ", type.GetGenericArguments().Select(TypeName))}>"
            : type.Name;

    // Unpack creates a nested row and the rows of a list or dict, so their types need a public parameterless constructor.
    private static void RequireCreatable(Field field, bool inRound)
    {
        var binding = field.Binding!;
        if (field.Type == Field.Kind.Group && binding.CreateNested is null)
            throw NoConstructor(field, binding.NestedType!);
        if (binding.Shape is { RowElements: true, CreateElement: null } shape)
            throw NoConstructor(field, shape.ElementType);
        if (binding.Shape is { } collection)
            RequireCollection(field, collection, inRound);
    }

    // In a repeat or times round a list or dict member holds one value per round: a list per round for a list field, a
    // dictionary per round for a dict field. The member must be one typed unpack can bind that to, which is the question
    // CollectionShape.HoldsRounds answers for the binding too, so the scheme builds if and only if typed Unpack binds it:
    // `List<List<object?>>`, `IList`, `IList<object?>`, `List<object?>`, `object[]`, `object` for a list; for a dict also
    // `List<Dictionary<string, object?>>`. `List<int>` could never take the rounds of a list, nor `Dictionary<string, E>`
    // the rounds of a dict.
    private static void RequireCollection(Field field, CollectionShape shape, bool inRound)
    {
        var member = field.Binding!.Member.Type;
        var kind = shape.Dictionary ? "dictionary" : "list";
        if (inRound)
        {
            if (!shape.HoldsRounds)
                throw new ArgumentException(
                    $"'{field.Name}': {TypeName(member)} cannot hold the list a repeat or times round reads for its field "
                    + $"(one {kind} per round); use "
                    + (shape.Dictionary ? "List<Dictionary<string, object?>>" : "List<List<object?>>")
                    + ", IList, IList<object?>, List<object?>, object[] or object");
            return;
        }
        if (!CollectionShape.IsSupported(member, shape.Dictionary))
            throw new ArgumentException(
                $"'{field.Name}': {TypeName(member)} is not a collection Packbin can fill; use an array, "
                + (shape.Dictionary ? "Dictionary<string, E>" : "List<E>") + $" for a {kind} field");
        var element = field.Children[0];
        if (shape.Holds(element))
            return;
        if (CollectionShape.IsReal(shape.ElementType) && element.Type is (>= Field.Kind.U8 and <= Field.Kind.I64) or Field.Kind.U2)
            throw new ArgumentException(
                $"'{field.Name}': {TypeName(member)} holds {TypeName(shape.ElementType)} elements, which pack refuses for the "
                + $"{Walker.KindName(element)} elements of its field; use an integer element type "
                + "(a float, double or decimal is for f32 and f64)");
        throw new ArgumentException(
            $"'{field.Name}': {TypeName(member)} cannot hold the {Walker.KindName(element)} "
            + $"elements of its field; element type {TypeName(shape.ElementType)} is too narrow or of another kind");
    }

    private static ArgumentException NoConstructor(Field field, Type type) =>
        new($"'{field.Name}': row type {TypeName(type)} needs a public parameterless constructor to be unpacked");

    private static void RequireFlagBit(Field field, bool flagBit)
    {
        if (!flagBit && IsPresenceOnly(field))
            throw new ArgumentException(
                $"'{field.Name}': a bool or an empty group is a flag bit with no payload; put it directly in Flags or a FlagByte bit");
    }

    private static bool IsPresenceOnly(Field field) =>
        field.Type == Field.Kind.Bool || (field.Type == Field.Kind.Group && field.Children.Length == 0);

    private static void RequireAnchor(int anchor, int next)
    {
        if (anchor != next)
            throw new ArgumentException($"anchor {anchor} must be {next}");
    }

    private static void Take(int id, string name, Field.Kind kind, Taken scope, ref int next)
    {
        if (id != next)
            throw new ArgumentException($"field id {id} must be {next}");
        if (!scope.TryAdd(id, (name, kind)))
            throw new ArgumentException($"duplicate field id {id}");
        next++;
    }

    private static (string Name, Field.Kind Kind) Earlier(Taken scope, int id, string by)
    {
        if (scope.TryGetValue(id, out var taken))
            return taken;
        throw new ArgumentException(
            $"{by} names field id {id}, which is not an earlier field in the same scope "
            + "(the top level, a repeat or times body, a list or dict element and a nested row are separate scopes)");
    }

    // A `when` reads an integer or a bool. A bool is true or a clear bit that is absent on the wire, so only `true` can
    // ever match it; a float, string or byte run would not compare the same in every package.
    private static string WhenSource(Taken scope, Field when)
    {
        var id = when.Pred!.FieldId;
        var (name, kind) = Earlier(scope, id, $"when {when.Id}");
        var value = when.Pred.Value;
        if (kind == Field.Kind.Bool)
        {
            if (value is not true)
                throw new ArgumentException(
                    $"when {when.Id} tests bool field {id} ('{name}') against {Describe(value)}; a bool is compared only with true");
            return name;
        }
        if (IsInteger(kind))
        {
            RequireIntegerValue(when, name, kind);
            return name;
        }
        throw new ArgumentException(
            $"when {when.Id} tests '{name}' (field id {id}), a {kind.ToString().ToLowerInvariant()} field; "
            + "a when names an integer or a bool field");
    }

    // An integer source holds one of its own range, so any other value could never match: a string, a bool, NaN, a
    // fraction or a number the field cannot hold fails when the scheme is built, not as a `when` that is never true.
    private static void RequireIntegerValue(Field when, string name, Field.Kind kind)
    {
        var (low, high) = IntegerRange(kind);
        var value = when.Pred!.Value;
        if (IsWholeNumberWithin(value, low, high))
        {
            // An integer source is compared with an integer, as Java, Python and Rust do; `5.0` is not the integer 5.
            if (value is float or double or decimal)
                throw new ArgumentException(
                    $"when {when.Id} tests {kind.ToString().ToLowerInvariant()} field {when.Pred.FieldId} ('{name}') against "
                    + $"{Describe(value)} ({value!.GetType().Name}); an integer field is compared with an integer type, not a float, double or decimal");
            return;
        }
        throw new ArgumentException(
            $"when {when.Id} tests {kind.ToString().ToLowerInvariant()} field {when.Pred.FieldId} ('{name}') against {Describe(value)}; "
            + $"the value must be a whole number from {low} to {high}");
    }

    private static bool IsWholeNumberWithin(object? value, decimal low, decimal high)
    {
        switch (value)
        {
            case byte or sbyte or short or ushort or int or uint or long or ulong:
                var whole = Convert.ToDecimal(value, System.Globalization.CultureInfo.InvariantCulture);
                return whole >= low && whole <= high;
            case decimal number:
                return number == decimal.Truncate(number) && number >= low && number <= high;
            case float or double:
                // Tested on the double itself: (decimal)real rounds to 15 digits, so 255.00000000000003 would pass as 255.
                // NaN and infinity are not numbers a field holds. A whole double converts to BigInteger exactly.
                var real = Convert.ToDouble(value, System.Globalization.CultureInfo.InvariantCulture);
                if (double.IsNaN(real) || double.IsInfinity(real) || real != Math.Floor(real))
                    return false;
                var exact = new System.Numerics.BigInteger(real);
                return exact >= new System.Numerics.BigInteger(low) && exact <= new System.Numerics.BigInteger(high);
            default:
                return false;
        }
    }

    private static (decimal Low, decimal High) IntegerRange(Field.Kind kind) =>
        kind switch
        {
            Field.Kind.U8 => (byte.MinValue, byte.MaxValue),
            Field.Kind.U16 => (ushort.MinValue, ushort.MaxValue),
            Field.Kind.U32 => (uint.MinValue, uint.MaxValue),
            Field.Kind.U64 => (ulong.MinValue, ulong.MaxValue),
            Field.Kind.I8 => (sbyte.MinValue, sbyte.MaxValue),
            Field.Kind.I16 => (short.MinValue, short.MaxValue),
            Field.Kind.I32 => (int.MinValue, int.MaxValue),
            Field.Kind.I64 => (long.MinValue, long.MaxValue),
            _ => (0, 3),
        };

    private static string Describe(object? value) =>
        value switch
        {
            null => "null",
            bool b => b ? "true" : "false",
            _ => Convert.ToString(value, System.Globalization.CultureInfo.InvariantCulture) ?? value.GetType().Name,
        };

    private static bool IsInteger(Field.Kind kind) => kind is (>= Field.Kind.U8 and <= Field.Kind.I64) or Field.Kind.U2;

    // A count is an integer: a u2 slot or an 8 to 64-bit integer field. A float, bool, string or byte run is read back
    // differently (or not at all) by the packages, so the same scheme would not mean the same bytes everywhere.
    private static string Count(Taken scope, int id, string by, string counted)
    {
        var (name, kind) = Earlier(scope, id, by);
        if (IsInteger(kind))
            return name;
        throw new ArgumentException(
            $"{counted}: its count names '{name}' (field id {id}), a {kind.ToString().ToLowerInvariant()} field; "
            + "a count must name an integer field");
    }
}

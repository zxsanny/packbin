using Taken = System.Collections.Generic.Dictionary<int, (string Name, Packbin.Field.Kind Kind)>;

namespace Packbin;

public sealed class Scheme<T> where T : class, new()
{
    public int TypeNumber { get; }
    public IReadOnlyList<Field> Fields { get; }
    public int MaxRounds { get; } = BinaryPacker.DefaultMaxRounds;
    public long MaxSlots { get; } = BinaryPacker.DefaultMaxSlots;

    public Scheme(int typeNumber, params Field[] fields)
    {
        if (typeNumber is < 0 or > 255)
            throw new ArgumentOutOfRangeException(nameof(typeNumber), typeNumber, "type number must be 0..255");
        TypeNumber = typeNumber;
        Fields = Array.AsReadOnly(SchemeOrder.Resolve(typeof(T), fields));
    }

    public Scheme(int typeNumber, Func<Fields<T>, Field[]> define)
        : this(typeNumber, define(new Fields<T>()))
    {
    }

    private Scheme(Scheme<T> source, int maxRounds, long maxSlots)
    {
        if (maxRounds < 1)
            throw new ArgumentOutOfRangeException(nameof(maxRounds), maxRounds, "must be at least 1");
        if (maxSlots < 1)
            throw new ArgumentOutOfRangeException(nameof(maxSlots), maxSlots, "must be at least 1");
        TypeNumber = source.TypeNumber;
        Fields = source.Fields;
        MaxRounds = maxRounds;
        MaxSlots = maxSlots;
    }

    // The same scheme with other limits: an omitted limit is the default, not this scheme's current value.
    public Scheme<T> WithLimits(
        int maxRounds = BinaryPacker.DefaultMaxRounds,
        long maxSlots = BinaryPacker.DefaultMaxSlots) =>
        new(this, maxRounds, maxSlots);

    public SchemeHandler On(Action<T> handler) => new SchemeHandler<T>(this, handler);
}

public abstract class SchemeHandler
{
    internal abstract int TypeNumber { get; }
    internal abstract object? Dispatch(ReadOnlySpan<byte> fieldBytes);
}

internal sealed class SchemeHandler<T> : SchemeHandler where T : class, new()
{
    private readonly Scheme<T> _scheme;
    private readonly Action<T> _action;

    internal SchemeHandler(Scheme<T> scheme, Action<T> action)
    {
        _scheme = scheme;
        _action = action;
    }

    internal override int TypeNumber => _scheme.TypeNumber;

    internal override object? Dispatch(ReadOnlySpan<byte> fieldBytes)
    {
        var raw = BinaryPacker.ReadFields(_scheme, fieldBytes, scoped: true);
        if (raw.Error is not null)
            return raw.Error;
        _action(RowBinding.To<T>(_scheme.Fields, raw.Values));
        return null;
    }
}

public sealed class Condition
{
    public int FieldId { get; }
    public object Value { get; }
    internal string FieldName { get; }

    private Condition(int fieldId, object value, string fieldName)
    {
        FieldId = fieldId;
        Value = value;
        FieldName = fieldName;
    }

    public static Condition Eq(int fieldId, object value) => new(fieldId, value, "");

    // The scheme's own copy, bound to the member its field id names there. A Condition is never changed.
    internal Condition Resolved(string fieldName) => new(FieldId, Value, fieldName);
}

public sealed class ShortPacket
{
    public string Field { get; }
    public int Needed { get; }
    public int Left { get; }

    public ShortPacket(string field, int needed, int left)
    {
        Field = field;
        Needed = needed;
        Left = left;
    }
}

public sealed class TrailingBytes
{
    public int Left { get; }

    public TrailingBytes(int left) => Left = left;
}

public sealed class TypeMismatch
{
    public int Expected { get; }
    public int Actual { get; }

    public TypeMismatch(int expected, int actual)
    {
        Expected = expected;
        Actual = actual;
    }
}

public sealed class UnpackResult
{
    public Dictionary<string, object?> Values { get; }
    public object? Error { get; }

    public UnpackResult(Dictionary<string, object?> values, object? error)
    {
        Values = values;
        Error = error;
    }
}

public static class BinaryPacker
{
    public const int DefaultMaxRounds = 65_535;
    public const long DefaultMaxSlots = 4_194_304;

    public static byte[] Pack<T>(Scheme<T> scheme, IReadOnlyDictionary<string, object?> values) where T : class, new()
    {
        var buffer = new List<byte>(32);
        buffer.Add((byte)scheme.TypeNumber);
        var seen = new Scope();
        foreach (var field in scheme.Fields)
            Walker.PackField(field, values, buffer, seen);
        return buffer.ToArray();
    }

    public static byte[] Pack<T>(Scheme<T> scheme, T? values) where T : class, new()
    {
        if (values is IReadOnlyDictionary<string, object?> map)
            return Pack(scheme, map);
        return Pack(scheme, RowBinding.Read(scheme.Fields, values));
    }

    public static object? Unpack(ReadOnlySpan<byte> bytes, params SchemeHandler[] handlers)
    {
        for (var i = 0; i < handlers.Length; i++)
        {
            for (var j = 0; j < i; j++)
            {
                if (handlers[j].TypeNumber == handlers[i].TypeNumber)
                    throw new ArgumentException("duplicate type number");
            }
        }

        if (bytes.Length < 1)
            return new ShortPacket("", 1, 0);

        var actual = bytes[0];
        foreach (var handler in handlers)
        {
            if (handler.TypeNumber != actual)
                continue;
            return handler.Dispatch(bytes.Slice(1));
        }

        return new TypeMismatch(0, actual);
    }

    internal static UnpackResult Read<T>(Scheme<T> scheme, ReadOnlySpan<byte> bytes) where T : class, new()
    {
        if (bytes.Length < 1)
            return new UnpackResult([], new ShortPacket("", 1, 0));
        var actual = bytes[0];
        if (actual != scheme.TypeNumber)
            return new UnpackResult([], new TypeMismatch(scheme.TypeNumber, actual));
        return ReadFields(scheme, bytes.Slice(1));
    }

    // `scoped`: read into a typed row, whose nested rows have scopes of their own; the dictionary result keeps one flat scope.
    internal static UnpackResult ReadFields<T>(Scheme<T> scheme, ReadOnlySpan<byte> bytes, bool scoped = false)
        where T : class, new()
    {
        var values = new Scope(new RoundBudget(scheme.MaxRounds, scheme.MaxSlots), scoped);
        var offset = 0;
        foreach (var field in scheme.Fields)
        {
            var err = Walker.UnpackField(field, bytes, ref offset, values, repeatLists: false);
            if (err is not null)
                return new UnpackResult([], err);
        }
        if (offset < bytes.Length)
            return new UnpackResult([], new TrailingBytes(bytes.Length - offset));
        return new UnpackResult(values, null);
    }
}

internal static class SchemeOrder
{
    // The scheme's own copy of its fields, with each count and `when` bound to the member its field id names. The
    // caller's Field and Condition objects are never changed, so one can be reused in many schemes.
    public static Field[] Resolve(Type row, IReadOnlyList<Field> fields)
    {
        var scope = new Taken();
        var next = 0;
        var resolved = new Field[fields.Count];
        for (var i = 0; i < resolved.Length; i++)
            resolved[i] = Walk(fields[i], row, scope, ref next);
        resolved = FlagScopes.Bind(resolved);
        RoundScopes.Validate(resolved);
        return resolved;
    }

    // Ids number straight through repeat and times bodies, but a reference finds only the fields `scope` already holds:
    // the earlier ones of its own top level, repeat or times body, list or dict element, or nested row.
    // `row`: the row type every field here must be declared for; null in a list or dict element and a nested row, which
    // bind their own row types.
    // `flagBit`: the field is a direct child of Flags or the field of a FlagByte bit, the only place a bool or an empty
    // group has a bit to live in.
    private static Field Walk(Field field, Type? row, Taken scope, ref int next, bool flagBit = false)
    {
        RequireFlagBit(field, flagBit);
        RequireRow(field, row);
        switch (field.Type)
        {
            case Field.Kind.When:
                RequireAnchor(field.Id, next);
                var pred = field.Pred!.Resolved(Earlier(scope, field.Pred.FieldId, $"when {field.Id}").Name);
                return field.With(children: WalkChildren(field, row, scope, ref next), pred: pred);
            case Field.Kind.Flags:
            case Field.Kind.Group when !field.NestedRow:
                RequireAnchor(field.Id, next);
                return field.With(children: WalkChildren(field, row, scope, ref next));
            case Field.Kind.Repeat:
                RequireAnchor(field.Id, next);
                return field.With(children: WalkChildren(field, row, [], ref next));
            case Field.Kind.Times:
                RequireAnchor(field.Id, next);
                var count = Count(scope, field.CountId, $"count of times {field.Id}", $"times {field.Id}");
                return field.With(children: WalkChildren(field, row, [], ref next), countName: count);
            case Field.Kind.FlagBit:
                return field.With(inner: Walk(field.Inner!, row, scope, ref next, flagBit: true));
            case Field.Kind.Group:
            case Field.Kind.List:
            case Field.Kind.Dict:
                RequireCreatable(field);
                return field.With(children: WalkFromZero(field));
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

    private static Field[] WalkChildren(Field field, Type? row, Taken scope, ref int next)
    {
        var children = new Field[field.Children.Length];
        for (var i = 0; i < children.Length; i++)
            children[i] = Walk(field.Children[i], row, scope, ref next);
        return children;
    }

    // A nested row, list element or dict element numbers its own fields from 0.
    private static Field[] WalkFromZero(Field field)
    {
        var next = 0;
        return WalkChildren(field, null, [], ref next);
    }

    // A value is found by member name, so a field declared for another row type would be silently left out.
    // A field declared for a base type of the row is the row's own member.
    private static void RequireRow(Field field, Type? row)
    {
        if (row is not null && field.RowType is { } declared && !declared.IsAssignableFrom(row))
            throw new ArgumentException(
                $"'{field.Name}' is declared for row type {TypeName(declared)}, but this scheme is for {TypeName(row)}");
    }

    // `List<Int32>` rather than the reflection name `List`1`, so two closed generic rows read apart.
    private static string TypeName(Type type) =>
        type.IsGenericType
            ? $"{type.Name.Substring(0, type.Name.IndexOf('`'))}<{string.Join(", ", type.GetGenericArguments().Select(TypeName))}>"
            : type.Name;

    // Unpack creates a nested row and the rows of a list or dict, so their types need a public parameterless constructor.
    private static void RequireCreatable(Field field)
    {
        var binding = field.Binding!;
        if (field.Type == Field.Kind.Group && binding.CreateNested is null)
            throw NoConstructor(field, binding.NestedType!);
        if (binding.Shape is { RowElements: true, CreateElement: null } shape)
            throw NoConstructor(field, shape.ElementType);
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

    // A count is an integer: a u2 slot or an 8 to 64-bit integer field. A float, bool, string or byte run is read back
    // differently (or not at all) by the packages, so the same scheme would not mean the same bytes everywhere.
    private static string Count(Taken scope, int id, string by, string counted)
    {
        var (name, kind) = Earlier(scope, id, by);
        if (kind is (>= Field.Kind.U8 and <= Field.Kind.I64) or Field.Kind.U2)
            return name;
        throw new ArgumentException(
            $"{counted}: its count names '{name}' (field id {id}), a {kind.ToString().ToLowerInvariant()} field; "
            + "a count must name an integer field");
    }
}

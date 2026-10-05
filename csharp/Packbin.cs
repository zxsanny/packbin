namespace Packbin;

public sealed class Scheme<T> where T : class, new()
{
    public int TypeNumber { get; }
    public IReadOnlyList<Field> Fields { get; }

    public Scheme(int typeNumber, params Field[] fields)
    {
        if (typeNumber is < 0 or > 255)
            throw new ArgumentOutOfRangeException(nameof(typeNumber), typeNumber, "type number must be 0..255");
        SchemeOrder.Validate(fields);
        TypeNumber = typeNumber;
        Fields = fields;
    }

    public Scheme(int typeNumber, Func<Fields<T>, Field[]> define)
        : this(typeNumber, define(new Fields<T>()))
    {
    }

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
        var raw = BinaryPacker.ReadFields(_scheme.Fields, fieldBytes);
        if (raw.Error is not null)
            return raw.Error;
        _action(ObjectValues.To<T>(raw.Values));
        return null;
    }
}

public sealed class Condition
{
    public int FieldId { get; }
    public object Value { get; }
    internal string FieldName { get; private set; } = "";

    private Condition(int fieldId, object value)
    {
        FieldId = fieldId;
        Value = value;
    }

    public static Condition Eq(int fieldId, object value) => new(fieldId, value);

    internal void Resolve(string fieldName) => FieldName = fieldName;
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
    public static byte[] Pack<T>(Scheme<T> scheme, IReadOnlyDictionary<string, object?> values) where T : class, new()
    {
        var buffer = new List<byte>(32);
        buffer.Add((byte)scheme.TypeNumber);
        foreach (var field in scheme.Fields)
            Walker.PackField(field, values, buffer);
        return buffer.ToArray();
    }

    public static byte[] Pack<T>(Scheme<T> scheme, T? values) where T : class, new()
    {
        if (values is IReadOnlyDictionary<string, object?> map)
            return Pack(scheme, map);
        return Pack(scheme, ObjectValues.From(values));
    }

    public static object? Unpack(ReadOnlySpan<byte> bytes, params SchemeHandler[] handlers)
    {
        var seen = new HashSet<int>();
        foreach (var handler in handlers)
        {
            if (!seen.Add(handler.TypeNumber))
                throw new ArgumentException("duplicate type number");
        }

        if (bytes.Length < 1)
            return new ShortPacket("", 1, 0);

        var actual = bytes[0];
        foreach (var handler in handlers)
        {
            if (handler.TypeNumber != actual)
                continue;
            return handler.Dispatch(bytes[1..]);
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
        return ReadFields(scheme.Fields, bytes[1..]);
    }

    internal static UnpackResult ReadFields(IReadOnlyList<Field> fields, ReadOnlySpan<byte> bytes)
    {
        var values = new Scope();
        var offset = 0;
        foreach (var field in fields)
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
    public static void Validate(IReadOnlyList<Field> fields)
    {
        var scope = new Dictionary<int, string>();
        var next = 0;
        foreach (var field in fields)
            Walk(field, scope, ref next);
        FlagScopes.Validate(fields);
    }

    // Ids number straight through repeat and times bodies, but a reference finds only the fields `scope` already holds:
    // the earlier ones of its own top level, repeat or times body, list or dict element, or nested row.
    // `flagBit`: the field is a direct child of Flags or the field of a FlagByte bit, the only place a bool or an empty
    // group has a bit to live in.
    private static void Walk(Field field, Dictionary<int, string> scope, ref int next, bool flagBit = false)
    {
        RequireFlagBit(field, flagBit);
        switch (field.Type)
        {
            case Field.Kind.When:
                RequireAnchor(field.Id, next);
                field.Pred!.Resolve(Earlier(scope, field.Pred.FieldId, $"when {field.Id}"));
                WalkChildren(field, scope, ref next);
                break;
            case Field.Kind.Flags:
            case Field.Kind.Group when !field.NestedRow:
                RequireAnchor(field.Id, next);
                WalkChildren(field, scope, ref next);
                break;
            case Field.Kind.Repeat:
                RequireAnchor(field.Id, next);
                WalkChildren(field, [], ref next);
                break;
            case Field.Kind.Times:
                RequireAnchor(field.Id, next);
                field.SetCountName(Earlier(scope, field.CountId, $"count of times {field.Id}"));
                WalkChildren(field, [], ref next);
                break;
            case Field.Kind.FlagBit:
                Walk(field.Inner!, scope, ref next, flagBit: true);
                break;
            case Field.Kind.Group:
            case Field.Kind.List:
            case Field.Kind.Dict:
                WalkFromZero(field);
                break;
            case Field.Kind.U2:
                for (var i = 0; i < field.SlotIds.Length; i++)
                    Take(field.SlotIds[i], field.Names[i], scope, ref next);
                break;
            case Field.Kind.Sized:
            case Field.Kind.Bits:
            case Field.Kind.Packed:
                field.SetCountName(Earlier(scope, field.CountId, $"count of field id {field.Id}"));
                Take(field.Id, field.Name, scope, ref next);
                break;
            default:
                if (Field.IsValueBearing(field))
                    Take(field.Id, field.Name, scope, ref next);
                break;
        }
    }

    private static void WalkChildren(Field field, Dictionary<int, string> scope, ref int next)
    {
        foreach (var child in field.Children)
            Walk(child, scope, ref next);
    }

    // A nested row, list element or dict element numbers its own fields from 0.
    private static void WalkFromZero(Field field)
    {
        var next = 0;
        WalkChildren(field, [], ref next);
    }

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

    private static void Take(int id, string name, Dictionary<int, string> scope, ref int next)
    {
        if (id != next)
            throw new ArgumentException($"field id {id} must be {next}");
        if (!scope.TryAdd(id, name))
            throw new ArgumentException($"duplicate field id {id}");
        next++;
    }

    private static string Earlier(Dictionary<int, string> scope, int id, string by)
    {
        if (scope.TryGetValue(id, out var name))
            return name;
        throw new ArgumentException(
            $"{by} names field id {id}, which is not an earlier field in the same scope "
            + "(the top level, a repeat or times body, a list or dict element and a nested row are separate scopes)");
    }
}

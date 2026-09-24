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

    public static Bound<T> Unpack<T>(Scheme<T> scheme, ReadOnlySpan<byte> bytes) where T : class, new()
    {
        var raw = Read(scheme, bytes);
        if (raw.Error is not null)
            return new Bound<T>(null, raw.Error);
        return new Bound<T>(ObjectValues.To<T>(raw.Values), null);
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
        var values = new Dictionary<string, object?>();
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
        Resolve(fields, scope);
    }

    private static void Walk(Field field, Dictionary<int, string> scope, ref int next)
    {
        switch (field.Type)
        {
            case Field.Kind.When:
            case Field.Kind.Repeat:
            case Field.Kind.Flags:
                foreach (var child in field.Children)
                    Walk(child, scope, ref next);
                break;
            case Field.Kind.FlagBit:
                Walk(field.Inner!, scope, ref next);
                break;
            case Field.Kind.FlagByte:
                break;
            case Field.Kind.Group:
                if (field.NestedRow)
                {
                    var nested = new Dictionary<int, string>();
                    var nestedNext = 0;
                    foreach (var child in field.Children)
                        Walk(child, nested, ref nestedNext);
                    Resolve(field.Children, nested);
                }
                else
                {
                    foreach (var child in field.Children)
                        Walk(child, scope, ref next);
                }
                break;
            case Field.Kind.List:
            case Field.Kind.Dict:
            {
                var nested = new Dictionary<int, string>();
                var nestedNext = 0;
                Walk(field.Children[0], nested, ref nestedNext);
                Resolve(field.Children, nested);
                break;
            }
            case Field.Kind.U2:
                for (var i = 0; i < field.SlotIds.Length; i++)
                    Take(field.SlotIds[i], field.Names[i], scope, ref next);
                break;
            default:
                if (Field.IsValueBearing(field))
                    Take(field.Id, field.Name, scope, ref next);
                break;
        }
    }

    private static void Take(int id, string name, Dictionary<int, string> scope, ref int next)
    {
        if (id != next)
            throw new ArgumentException($"field id {id} must be {next}");
        if (!scope.TryAdd(id, name))
            throw new ArgumentException($"duplicate field id {id}");
        next++;
    }

    private static void Resolve(IReadOnlyList<Field> fields, Dictionary<int, string> scope)
    {
        foreach (var field in fields)
            ResolveField(field, scope);
    }

    private static void ResolveField(Field field, Dictionary<int, string> scope)
    {
        switch (field.Type)
        {
            case Field.Kind.When:
                if (!scope.TryGetValue(field.Pred!.FieldId, out var condName))
                    throw new ArgumentException($"condition field id {field.Pred.FieldId} is unknown");
                field.Pred.Resolve(condName);
                foreach (var child in field.Children)
                    ResolveField(child, scope);
                break;
            case Field.Kind.Sized:
            case Field.Kind.Bits:
                if (!scope.TryGetValue(field.CountId, out var countName))
                    throw new ArgumentException($"count field id {field.CountId} is unknown");
                field.SetCountName(countName);
                break;
            case Field.Kind.Flags:
            case Field.Kind.Repeat:
                foreach (var child in field.Children)
                    ResolveField(child, scope);
                break;
            case Field.Kind.FlagBit:
                ResolveField(field.Inner!, scope);
                break;
            case Field.Kind.Group:
                if (!field.NestedRow)
                {
                    foreach (var child in field.Children)
                        ResolveField(child, scope);
                }
                break;
        }
    }
}

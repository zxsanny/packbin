namespace Packbin;

public sealed class Scheme<T> where T : class, new()
{
    public int TypeNumber { get; }
    public IReadOnlyList<Field> Fields { get; }

    public Scheme(int typeNumber, params Field[] fields)
    {
        if (typeNumber is < 0 or > 255)
            throw new ArgumentOutOfRangeException(nameof(typeNumber), typeNumber, "type number must be 0..255");
        TypeNumber = typeNumber;
        Fields = fields;
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
        var raw = Unpack.ReadFields(_scheme.Fields, fieldBytes);
        if (raw.Error is not null)
            return raw.Error;
        _action(ObjectValues.To<T>(raw.Values));
        return null;
    }
}

public sealed class Condition
{
    public string Field { get; }
    public object Value { get; }

    private Condition(string field, object value)
    {
        Field = field;
        Value = value;
    }

    public static Condition Eq(string field, object value) => new(field, value);
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

public sealed class Field
{
    internal enum Kind : byte
    {
        U8, U16, U32, U64,
        I8, I16, I32, I64,
        F32, F64,
        Bytes,
        Flags,
        FlagByte,
        FlagBit,
        When,
        Repeat,
        Group,
        Sized,
        U2,
        Bits,
        Utf8,
        List,
        Dict,
    }

    internal Kind Type { get; }
    internal string Name { get; }
    internal bool BigEndian { get; }
    internal int ByteCount { get; }
    internal Field[] Children { get; }
    internal Condition? Pred { get; }
    internal FlagGroup? FlagOwner { get; }
    internal int BitIndex { get; }
    internal Field? Inner { get; }
    internal string CountName { get; }
    internal string[] Names { get; }

    private Field(
        Kind type,
        string name,
        bool bigEndian = false,
        int byteCount = 0,
        Field[]? children = null,
        Condition? pred = null,
        FlagGroup? flagOwner = null,
        int bitIndex = 0,
        Field? inner = null,
        string countName = "",
        string[]? names = null)
    {
        Type = type;
        Name = name;
        BigEndian = bigEndian;
        ByteCount = byteCount;
        Children = children ?? [];
        Pred = pred;
        FlagOwner = flagOwner;
        BitIndex = bitIndex;
        Inner = inner;
        CountName = countName;
        Names = names ?? [];
    }

    public Field Be() =>
        new(Type, Name, true, ByteCount, Children, Pred, FlagOwner, BitIndex, Inner, CountName, Names);

    public Field Bit(Field field)
    {
        if (Type != Kind.FlagByte || FlagOwner is null)
            throw new InvalidOperationException("Bit requires FlagByte.");
        return FlagOwner.AddBit(field);
    }

    public static Field U8(string name) => new(Kind.U8, name, byteCount: 1);
    public static Field U16(string name) => new(Kind.U16, name, byteCount: 2);
    public static Field U32(string name) => new(Kind.U32, name, byteCount: 4);
    public static Field U64(string name) => new(Kind.U64, name, byteCount: 8);
    public static Field I8(string name) => new(Kind.I8, name, byteCount: 1);
    public static Field I16(string name) => new(Kind.I16, name, byteCount: 2);
    public static Field I32(string name) => new(Kind.I32, name, byteCount: 4);
    public static Field I64(string name) => new(Kind.I64, name, byteCount: 8);
    public static Field F32(string name) => new(Kind.F32, name, byteCount: 4);
    public static Field F64(string name) => new(Kind.F64, name, byteCount: 8);
    public static Field Bytes(string name, int n) => new(Kind.Bytes, name, byteCount: n);

    public static Field FlagByte(string name)
    {
        var group = new FlagGroup(name);
        return new Field(Kind.FlagByte, name, flagOwner: group);
    }

    public static Field Flags(string name, params Field[] fields)
    {
        var group = new FlagGroup(name);
        var bits = new Field[fields.Length];
        for (var i = 0; i < fields.Length; i++)
            bits[i] = group.AddBit(fields[i]);
        return new Field(Kind.Flags, name, children: bits, flagOwner: group);
    }

    public static Field When(Condition condition, params Field[] fields) =>
        new(Kind.When, condition.Field, children: fields, pred: condition);

    public static Field Repeat(params Field[] fields) =>
        new(Kind.Repeat, "", children: fields);

    public static Field Group(string name, params Field[] fields) =>
        new(Kind.Group, name, children: fields);

    public static Field Sized(string name, string countField) =>
        new(Kind.Sized, name, countName: countField);

    public static Field U2(params string[] names)
    {
        if (names.Length == 0)
            throw new ArgumentException("u2 needs at least one name");
        return new Field(Kind.U2, names[0], names: names);
    }

    public static Field Bits(string name, string countField) =>
        new(Kind.Bits, name, countName: countField);

    public static Field Utf8(string name) => new(Kind.Utf8, name);

    public static Field List(string name, Field element)
    {
        if (element.Type == Kind.Repeat)
            throw new ArgumentException("repeat is not a list element");
        return new(Kind.List, name, children: [element]);
    }

    public static Field Dict(string name, Field element)
    {
        if (element.Type == Kind.Repeat)
            throw new ArgumentException("repeat is not a dictionary element");
        return new(Kind.Dict, name, children: [element]);
    }

    internal static Field CreateFlagBit(FlagGroup group, int bitIndex, Field inner) =>
        new(Kind.FlagBit, inner.Name, flagOwner: group, bitIndex: bitIndex, inner: inner);
}


public static class Pack
{
    public static byte[] Run<T>(Scheme<T> scheme, IReadOnlyDictionary<string, object?> values) where T : class, new()
    {
        var buffer = new List<byte>(32);
        buffer.Add((byte)scheme.TypeNumber);
        foreach (var field in scheme.Fields)
            Walker.PackField(field, values, buffer);
        return buffer.ToArray();
    }

    public static byte[] Run<T>(Scheme<T> scheme, T? values) where T : class, new()
    {
        if (values is IReadOnlyDictionary<string, object?> map)
            return Run(scheme, map);
        return Run(scheme, ObjectValues.From(values));
    }
}

public static class Unpack
{
    public static Bound<T> Run<T>(Scheme<T> scheme, ReadOnlySpan<byte> bytes) where T : class, new()
    {
        var raw = Read(scheme, bytes);
        if (raw.Error is not null)
            return new Bound<T>(null, raw.Error);
        return new Bound<T>(ObjectValues.To<T>(raw.Values), null);
    }

    public static object? Run(ReadOnlySpan<byte> bytes, params SchemeHandler[] handlers)
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

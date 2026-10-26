namespace Packbin;

public sealed class Scheme<T> where T : class, new()
{
    public int TypeNumber { get; }
    public IReadOnlyList<Field> Fields { get; }
    public int MaxRounds { get; } = BinaryPacker.DefaultMaxRounds;
    public long MaxSlots { get; } = BinaryPacker.DefaultMaxSlots;
    public long MaxBytes { get; } = BinaryPacker.DefaultMaxBytes;

    // Parity bytes appended to every packed message (0 to 32); 0 is the unprotected format of every earlier release.
    public int Parity { get; }

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

    private Scheme(Scheme<T> source, int maxRounds, long maxSlots, long maxBytes, int parity)
    {
        if (maxRounds < 1)
            throw new ArgumentOutOfRangeException(nameof(maxRounds), maxRounds, "must be at least 1");
        if (maxSlots < 1)
            throw new ArgumentOutOfRangeException(nameof(maxSlots), maxSlots, "must be at least 1");
        if (maxBytes < 1)
            throw new ArgumentOutOfRangeException(nameof(maxBytes), maxBytes, "must be at least 1");
        TypeNumber = source.TypeNumber;
        Fields = source.Fields;
        MaxRounds = maxRounds;
        MaxSlots = maxSlots;
        MaxBytes = maxBytes;
        Ecc.RequireParity(parity);
        Parity = parity;
    }

    // The loop 19 signature, kept so code compiled against it still binds. It sets the round and slot limits and leaves the
    // output budget at its default, as the three-limit overload does for an omitted limit.
    public Scheme<T> WithLimits(int maxRounds, long maxSlots) =>
        WithLimits(maxRounds, maxSlots, BinaryPacker.DefaultMaxBytes);

    // The same scheme with other limits: an omitted limit is the default, not this scheme's current value.
    public Scheme<T> WithLimits(
        int maxRounds = BinaryPacker.DefaultMaxRounds,
        long maxSlots = BinaryPacker.DefaultMaxSlots,
        long maxBytes = BinaryPacker.DefaultMaxBytes) =>
        new(this, maxRounds, maxSlots, maxBytes, Parity);

    // The same scheme with `parity` bytes of error correction (message-ecc contract). Limits are kept.
    public Scheme<T> WithParity(int parity) => new(this, MaxRounds, MaxSlots, MaxBytes, parity);

    public SchemeHandler On(Action<T> handler) => new SchemeHandler<T>(this, handler);
}

public abstract class SchemeHandler
{
    internal abstract int TypeNumber { get; }
    internal abstract int Parity { get; }
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

    internal override int Parity => _scheme.Parity;

    internal override object? Dispatch(ReadOnlySpan<byte> fieldBytes)
    {
        var raw = BinaryPacker.ReadFields(_scheme, fieldBytes, scoped: true);
        if (raw.Error is not null)
            return raw.Error;
        var row = RowBinding.To<T>(_scheme.Fields, raw.Values, out var unfit);
        if (unfit is not null)
            return Walker.InterimBadValue(unfit, 0);
        _action(row);
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
    public const long DefaultMaxSlots = 1_048_576;

    // The longest packet one pack call writes, the type byte included.
    public const long DefaultMaxBytes = 16_777_216;

    public static byte[] Pack<T>(Scheme<T> scheme, IReadOnlyDictionary<string, object?> values) where T : class, new() =>
        Ecc.Protect(PackClear(scheme, values), scheme.Parity);

    public static byte[] Pack<T>(Scheme<T> scheme, T? values) where T : class, new() =>
        Ecc.Protect(PackClear(scheme, values), scheme.Parity);

    // The packed fields without parity: what an unprotected scheme writes.
    internal static byte[] PackClear<T>(Scheme<T> scheme, IReadOnlyDictionary<string, object?> values) where T : class, new()
    {
        var buffer = new PackOut(scheme.MaxBytes);
        buffer.Add((byte)scheme.TypeNumber);
        var seen = new Scope(new RoundBudget(scheme.MaxRounds, scheme.MaxSlots));
        foreach (var field in scheme.Fields)
            Walker.PackField(field, values, buffer, seen);
        return buffer.ToArray();
    }

    internal static byte[] PackClear<T>(Scheme<T> scheme, T? values) where T : class, new()
    {
        if (values is IReadOnlyDictionary<string, object?> map)
            return PackClear(scheme, map);
        return PackClear(scheme, RowBinding.Read(scheme.Fields, values));
    }

    public static object? Unpack(ReadOnlySpan<byte> bytes, params SchemeHandler[] handlers) =>
        Unpack(bytes, 0, out _, handlers);

    // Handlers that declare parity bytes share one count. The message is repaired (up to `limit` wrong bytes, 0 to
    // parity / 2) before the type byte picks the handler; `repaired` is the number of bytes changed.
    public static object? Unpack(ReadOnlySpan<byte> bytes, int limit, out int repaired, params SchemeHandler[] handlers)
    {
        repaired = 0;
        RequireHandlers(handlers);
        var parity = Ecc.SharedParity(handlers, limit);
        if (parity == 0)
            return Dispatch(bytes, handlers);
        var error = Ecc.Repair(bytes, parity, limit, out var word, out repaired);
        if (error is not null)
            return error;
        return Dispatch(word.AsSpan(0, word.Length - parity), handlers);
    }

    // An empty list or a duplicate type number is refused before any byte is read.
    internal static void RequireHandlers(SchemeHandler[] handlers)
    {
        if (handlers.Length == 0)
            throw new ArgumentException("unpack needs at least one handler");
        for (var i = 0; i < handlers.Length; i++)
        {
            for (var j = 0; j < i; j++)
            {
                if (handlers[j].TypeNumber == handlers[i].TypeNumber)
                    throw new ArgumentException("duplicate type number");
            }
        }
    }

    // The unprotected walk: the type byte picks the handler.
    internal static object? Dispatch(ReadOnlySpan<byte> bytes, SchemeHandler[] handlers)
    {
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

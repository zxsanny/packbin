using System.Collections;
using System.Linq.Expressions;

namespace Packbin;

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
        Packed,
        Times,
        Utf8,
        List,
        Dict,
        Bool,
    }

    internal Kind Type { get; }
    internal int Id { get; }
    internal string Name { get; }
    internal bool BigEndian { get; }
    internal int ByteCount { get; }
    internal Field[] Children { get; }
    internal Condition? Pred { get; }
    internal FlagGroup? FlagOwner { get; }
    internal int BitIndex { get; }
    internal Field? Inner { get; }
    internal int CountId { get; }
    internal string CountName { get; private set; }
    internal string[] Names { get; }
    internal int[] SlotIds { get; }
    internal bool NestedRow { get; }
    internal int Bias { get; }

    private Field(
        Kind type,
        int id,
        string name,
        bool bigEndian = false,
        int byteCount = 0,
        Field[]? children = null,
        Condition? pred = null,
        FlagGroup? flagOwner = null,
        int bitIndex = 0,
        Field? inner = null,
        int countId = -1,
        string countName = "",
        string[]? names = null,
        int[]? slotIds = null,
        bool nestedRow = false,
        int bias = 0)
    {
        Type = type;
        Id = id;
        Name = name;
        BigEndian = bigEndian;
        ByteCount = byteCount;
        Children = children ?? [];
        Pred = pred;
        FlagOwner = flagOwner;
        BitIndex = bitIndex;
        Inner = inner;
        CountId = countId;
        CountName = countName;
        Names = names ?? [];
        SlotIds = slotIds ?? [];
        NestedRow = nestedRow;
        Bias = bias;
    }

    internal void SetCountName(string name) => CountName = name;

    public Field Be() =>
        new(Type, Id, Name, true, ByteCount, Children, Pred, FlagOwner, BitIndex, Inner, CountId, CountName, Names, SlotIds, NestedRow, Bias);

    public Field Bit(Field field)
    {
        if (Type != Kind.FlagByte || FlagOwner is null)
            throw new InvalidOperationException("Bit requires FlagByte.");
        return FlagOwner.AddBit(field);
    }

    public static Field U8<T>(int id, Expression<Func<T, byte>> accessor) => Scalar(Kind.U8, id, accessor, 1);
    public static Field U8<T>(int id, Expression<Func<T, byte?>> accessor) => Scalar(Kind.U8, id, accessor, 1);
    public static Field U16<T>(int id, Expression<Func<T, ushort>> accessor) => Scalar(Kind.U16, id, accessor, 2);
    public static Field U16<T>(int id, Expression<Func<T, ushort?>> accessor) => Scalar(Kind.U16, id, accessor, 2);
    public static Field U32<T>(int id, Expression<Func<T, uint>> accessor) => Scalar(Kind.U32, id, accessor, 4);
    public static Field U32<T>(int id, Expression<Func<T, uint?>> accessor) => Scalar(Kind.U32, id, accessor, 4);
    public static Field U64<T>(int id, Expression<Func<T, ulong>> accessor) => Scalar(Kind.U64, id, accessor, 8);
    public static Field U64<T>(int id, Expression<Func<T, ulong?>> accessor) => Scalar(Kind.U64, id, accessor, 8);
    public static Field I8<T>(int id, Expression<Func<T, sbyte>> accessor) => Scalar(Kind.I8, id, accessor, 1);
    public static Field I8<T>(int id, Expression<Func<T, sbyte?>> accessor) => Scalar(Kind.I8, id, accessor, 1);
    public static Field I16<T>(int id, Expression<Func<T, short>> accessor) => Scalar(Kind.I16, id, accessor, 2);
    public static Field I16<T>(int id, Expression<Func<T, short?>> accessor) => Scalar(Kind.I16, id, accessor, 2);
    public static Field I32<T>(int id, Expression<Func<T, int>> accessor) => Scalar(Kind.I32, id, accessor, 4);
    public static Field I32<T>(int id, Expression<Func<T, int?>> accessor) => Scalar(Kind.I32, id, accessor, 4);
    public static Field I64<T>(int id, Expression<Func<T, long>> accessor) => Scalar(Kind.I64, id, accessor, 8);
    public static Field I64<T>(int id, Expression<Func<T, long?>> accessor) => Scalar(Kind.I64, id, accessor, 8);
    public static Field F32<T>(int id, Expression<Func<T, float>> accessor) => Scalar(Kind.F32, id, accessor, 4);
    public static Field F32<T>(int id, Expression<Func<T, float?>> accessor) => Scalar(Kind.F32, id, accessor, 4);
    public static Field F64<T>(int id, Expression<Func<T, double>> accessor) => Scalar(Kind.F64, id, accessor, 8);
    public static Field F64<T>(int id, Expression<Func<T, double?>> accessor) => Scalar(Kind.F64, id, accessor, 8);

    public static Field Bytes<T>(int id, Expression<Func<T, byte[]>> accessor, int n) =>
        Scalar(Kind.Bytes, id, accessor, n);

    public static Field Bool<T>(int id, Expression<Func<T, bool>> accessor) =>
        new(Kind.Bool, id, MemberAccess.From(accessor).Name);

    public static Field Bool<T>(int id, Expression<Func<T, bool?>> accessor) =>
        new(Kind.Bool, id, MemberAccess.From(accessor).Name);

    public static Field Utf8<T>(int id, Expression<Func<T, string>> accessor) =>
        new(Kind.Utf8, id, MemberAccess.From(accessor).Name);

    public static Field Sized<T>(int id, Expression<Func<T, byte[]>> accessor, int countId) =>
        new(Kind.Sized, id, MemberAccess.From(accessor).Name, countId: countId);

    public static Field Bits<T>(int id, Expression<Func<T, List<int>?>> accessor, int countId) =>
        new(Kind.Bits, id, MemberAccess.From(accessor).Name, countId: countId);

    public static Field Bits<T>(int id, Expression<Func<T, IList>> accessor, int countId) =>
        new(Kind.Bits, id, MemberAccess.From(accessor).Name, countId: countId);

    public static Field Packed<T>(int width, int id, Expression<Func<T, List<int>?>> accessor, int countId, int bias = 0)
    {
        if (width is not (1 or 2))
            throw new ArgumentException("packed width must be 1 or 2");
        if (bias is not (0 or -1))
            throw new ArgumentException("packed bias must be 0 or -1");
        return new Field(Kind.Packed, id, MemberAccess.From(accessor).Name, byteCount: width, countId: countId, bias: bias);
    }

    public static Field Times(int countId, params Field[] fields) =>
        new(Kind.Times, -1, "times", children: fields, countId: countId);

    public static Field U2<T>(params (int Id, Expression<Func<T, int>> Accessor)[] slots)
    {
        if (slots.Length == 0)
            throw new ArgumentException("u2 needs at least one slot");
        var names = new string[slots.Length];
        var ids = new int[slots.Length];
        for (var i = 0; i < slots.Length; i++)
        {
            ids[i] = slots[i].Id;
            names[i] = MemberAccess.From(slots[i].Accessor).Name;
        }
        return new Field(Kind.U2, ids[0], names[0], names: names, slotIds: ids);
    }

    public static Field FlagByte()
    {
        var group = new FlagGroup("");
        return new Field(Kind.FlagByte, -1, "", flagOwner: group);
    }

    public static Field Flags(params Field[] fields)
    {
        var group = new FlagGroup("");
        var bits = new Field[fields.Length];
        for (var i = 0; i < fields.Length; i++)
            bits[i] = group.AddBit(fields[i]);
        return new Field(Kind.Flags, -1, "", children: bits, flagOwner: group);
    }

    public static Field When(Condition condition, params Field[] fields) =>
        new(Kind.When, -1, "", children: fields, pred: condition);

    public static Field Repeat(params Field[] fields) =>
        new(Kind.Repeat, -1, "", children: fields);

    public static Field Group<T, TChild>(Expression<Func<T, TChild>> accessor, params Field[] fields)
    {
        var access = MemberAccess.From(accessor);
        var childType = Nullable.GetUnderlyingType(typeof(TChild)) ?? typeof(TChild);
        var nested = childType.IsClass
            && childType != typeof(string)
            && childType != typeof(byte[])
            && childType != typeof(bool);
        return new Field(Kind.Group, -1, access.Name, children: fields, nestedRow: nested);
    }

    public static Field List<T, TProp>(Expression<Func<T, TProp>> accessor, Field element)
    {
        if (element.Type == Kind.Repeat)
            throw new ArgumentException("repeat is not a list element");
        return new Field(Kind.List, -1, MemberAccess.From(accessor).Name, children: [element]);
    }

    public static Field Dict<T, TProp>(Expression<Func<T, TProp>> accessor, Field element)
    {
        if (element.Type == Kind.Repeat)
            throw new ArgumentException("repeat is not a dictionary element");
        return new Field(Kind.Dict, -1, MemberAccess.From(accessor).Name, children: [element]);
    }

    internal static Field CreateFlagBit(FlagGroup group, int bitIndex, Field inner) =>
        new(Kind.FlagBit, inner.Id, inner.Name, flagOwner: group, bitIndex: bitIndex, inner: inner);

    private static Field Scalar<T, TProp>(Kind kind, int id, Expression<Func<T, TProp>> accessor, int byteCount) =>
        new(kind, id, MemberAccess.From(accessor).Name, byteCount: byteCount);

    internal static bool IsValueBearing(Field field) =>
        field.Type is (>= Kind.U8 and <= Kind.F64)
            or Kind.Bytes or Kind.Sized or Kind.Bits or Kind.Packed or Kind.Utf8 or Kind.Bool
            or Kind.U2;
}

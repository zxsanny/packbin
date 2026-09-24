using System.Collections;
using System.Linq.Expressions;

namespace Packbin;

public sealed class Fields<T>
{
    public Field U8(int id, Expression<Func<T, byte>> accessor) => Field.U8(id, accessor);
    public Field U8(int id, Expression<Func<T, byte?>> accessor) => Field.U8(id, accessor);
    public Field U16(int id, Expression<Func<T, ushort>> accessor) => Field.U16(id, accessor);
    public Field U16(int id, Expression<Func<T, ushort?>> accessor) => Field.U16(id, accessor);
    public Field U32(int id, Expression<Func<T, uint>> accessor) => Field.U32(id, accessor);
    public Field U32(int id, Expression<Func<T, uint?>> accessor) => Field.U32(id, accessor);
    public Field U64(int id, Expression<Func<T, ulong>> accessor) => Field.U64(id, accessor);
    public Field U64(int id, Expression<Func<T, ulong?>> accessor) => Field.U64(id, accessor);
    public Field I8(int id, Expression<Func<T, sbyte>> accessor) => Field.I8(id, accessor);
    public Field I8(int id, Expression<Func<T, sbyte?>> accessor) => Field.I8(id, accessor);
    public Field I16(int id, Expression<Func<T, short>> accessor) => Field.I16(id, accessor);
    public Field I16(int id, Expression<Func<T, short?>> accessor) => Field.I16(id, accessor);
    public Field I32(int id, Expression<Func<T, int>> accessor) => Field.I32(id, accessor);
    public Field I32(int id, Expression<Func<T, int?>> accessor) => Field.I32(id, accessor);
    public Field I64(int id, Expression<Func<T, long>> accessor) => Field.I64(id, accessor);
    public Field I64(int id, Expression<Func<T, long?>> accessor) => Field.I64(id, accessor);
    public Field F32(int id, Expression<Func<T, float>> accessor) => Field.F32(id, accessor);
    public Field F32(int id, Expression<Func<T, float?>> accessor) => Field.F32(id, accessor);
    public Field F64(int id, Expression<Func<T, double>> accessor) => Field.F64(id, accessor);
    public Field F64(int id, Expression<Func<T, double?>> accessor) => Field.F64(id, accessor);
    public Field Bytes(int id, Expression<Func<T, byte[]>> accessor, int n) => Field.Bytes(id, accessor, n);
    public Field Bool(int id, Expression<Func<T, bool>> accessor) => Field.Bool(id, accessor);
    public Field Bool(int id, Expression<Func<T, bool?>> accessor) => Field.Bool(id, accessor);
    public Field Utf8(int id, Expression<Func<T, string>> accessor) => Field.Utf8(id, accessor);
    public Field Sized(int id, Expression<Func<T, byte[]>> accessor, int countId) => Field.Sized(id, accessor, countId);
    public Field Bits(int id, Expression<Func<T, List<int>?>> accessor, int countId) => Field.Bits(id, accessor, countId);
    public Field Bits(int id, Expression<Func<T, IList>> accessor, int countId) => Field.Bits(id, accessor, countId);
    public Field U2(params (int Id, Expression<Func<T, int>> Accessor)[] slots) => Field.U2(slots);

    public Field Flags(params Field[] fields) => Field.Flags(fields);
    public Field When(Condition condition, params Field[] fields) => Field.When(condition, fields);
    public Field Repeat(params Field[] fields) => Field.Repeat(fields);

    public Field Group<TChild>(Expression<Func<T, TChild>> accessor, Func<Fields<TChild>, Field[]> children) =>
        Field.Group(accessor, children(new Fields<TChild>()));

    public Field List<TProp>(Expression<Func<T, TProp>> accessor, Field element) =>
        Field.List(accessor, element);

    public Field List<TChild>(Expression<Func<T, List<TChild>>> accessor, Func<Fields<TChild>, Field> element) =>
        Field.List(accessor, element(new Fields<TChild>()));

    public Field Dict<TProp>(Expression<Func<T, TProp>> accessor, Field element) =>
        Field.Dict(accessor, element);

    public Field Dict<TChild>(Expression<Func<T, Dictionary<string, TChild>>> accessor, Func<Fields<TChild>, Field> element) =>
        Field.Dict(accessor, element(new Fields<TChild>()));
}

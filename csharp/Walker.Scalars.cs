using System.Buffers.Binary;
using System.Globalization;

namespace Packbin;

internal static partial class Walker
{
    private static void WriteScalar(Field field, object value, Span<byte> dest)
    {
        switch (field.Type)
        {
            case Field.Kind.U8:
                dest[0] = Convert.ToByte(value, CultureInfo.InvariantCulture);
                break;
            case Field.Kind.I8:
                dest[0] = (byte)Convert.ToSByte(value, CultureInfo.InvariantCulture);
                break;
            case Field.Kind.U16:
                {
                    var n = Convert.ToUInt16(value, CultureInfo.InvariantCulture);
                    if (field.BigEndian) BinaryPrimitives.WriteUInt16BigEndian(dest, n);
                    else BinaryPrimitives.WriteUInt16LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.I16:
                {
                    var n = Convert.ToInt16(value, CultureInfo.InvariantCulture);
                    if (field.BigEndian) BinaryPrimitives.WriteInt16BigEndian(dest, n);
                    else BinaryPrimitives.WriteInt16LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.U32:
                {
                    var n = Convert.ToUInt32(value, CultureInfo.InvariantCulture);
                    if (field.BigEndian) BinaryPrimitives.WriteUInt32BigEndian(dest, n);
                    else BinaryPrimitives.WriteUInt32LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.I32:
                {
                    var n = Convert.ToInt32(value, CultureInfo.InvariantCulture);
                    if (field.BigEndian) BinaryPrimitives.WriteInt32BigEndian(dest, n);
                    else BinaryPrimitives.WriteInt32LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.U64:
                {
                    var n = Convert.ToUInt64(value, CultureInfo.InvariantCulture);
                    if (field.BigEndian) BinaryPrimitives.WriteUInt64BigEndian(dest, n);
                    else BinaryPrimitives.WriteUInt64LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.I64:
                {
                    var n = Convert.ToInt64(value, CultureInfo.InvariantCulture);
                    if (field.BigEndian) BinaryPrimitives.WriteInt64BigEndian(dest, n);
                    else BinaryPrimitives.WriteInt64LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.F32:
                {
                    var n = Convert.ToSingle(value, CultureInfo.InvariantCulture);
                    var bits = Compat.SingleToInt32Bits(n);
                    if (field.BigEndian) BinaryPrimitives.WriteInt32BigEndian(dest, bits);
                    else BinaryPrimitives.WriteInt32LittleEndian(dest, bits);
                    break;
                }
            case Field.Kind.F64:
                {
                    var n = Convert.ToDouble(value, CultureInfo.InvariantCulture);
                    var bits = BitConverter.DoubleToInt64Bits(n);
                    if (field.BigEndian) BinaryPrimitives.WriteInt64BigEndian(dest, bits);
                    else BinaryPrimitives.WriteInt64LittleEndian(dest, bits);
                    break;
                }
            default:
                throw new InvalidOperationException($"Cannot write {field.Type}.");
        }
    }

    // The switch below has natural type double, so the narrower scalars box as double (exact types: AZ-2116).
    // 64-bit integers are read separately so the top of their range does not round and overflow on conversion.
    private static object ReadScalar(Field field, ReadOnlySpan<byte> src)
    {
        switch (field.Type)
        {
            case Field.Kind.U64:
                return field.BigEndian
                    ? BinaryPrimitives.ReadUInt64BigEndian(src)
                    : BinaryPrimitives.ReadUInt64LittleEndian(src);
            case Field.Kind.I64:
                return field.BigEndian
                    ? BinaryPrimitives.ReadInt64BigEndian(src)
                    : BinaryPrimitives.ReadInt64LittleEndian(src);
            default:
                return ReadNarrowScalar(field, src);
        }
    }

    private static object ReadNarrowScalar(Field field, ReadOnlySpan<byte> src) =>
        field.Type switch
        {
            Field.Kind.U8 => src[0],
            Field.Kind.I8 => (sbyte)src[0],
            Field.Kind.U16 => field.BigEndian
                ? BinaryPrimitives.ReadUInt16BigEndian(src)
                : BinaryPrimitives.ReadUInt16LittleEndian(src),
            Field.Kind.I16 => field.BigEndian
                ? BinaryPrimitives.ReadInt16BigEndian(src)
                : BinaryPrimitives.ReadInt16LittleEndian(src),
            Field.Kind.U32 => field.BigEndian
                ? BinaryPrimitives.ReadUInt32BigEndian(src)
                : BinaryPrimitives.ReadUInt32LittleEndian(src),
            Field.Kind.I32 => field.BigEndian
                ? BinaryPrimitives.ReadInt32BigEndian(src)
                : BinaryPrimitives.ReadInt32LittleEndian(src),
            Field.Kind.F32 => Compat.Int32BitsToSingle(field.BigEndian
                ? BinaryPrimitives.ReadInt32BigEndian(src)
                : BinaryPrimitives.ReadInt32LittleEndian(src)),
            Field.Kind.F64 => BitConverter.Int64BitsToDouble(field.BigEndian
                ? BinaryPrimitives.ReadInt64BigEndian(src)
                : BinaryPrimitives.ReadInt64LittleEndian(src)),
            _ => throw new InvalidOperationException($"Cannot read {field.Type}."),
        };
}

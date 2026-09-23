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
                if (field.BigEndian) BinaryPrimitives.WriteSingleBigEndian(dest, n);
                else BinaryPrimitives.WriteSingleLittleEndian(dest, n);
                break;
            }
            case Field.Kind.F64:
            {
                var n = Convert.ToDouble(value, CultureInfo.InvariantCulture);
                if (field.BigEndian) BinaryPrimitives.WriteDoubleBigEndian(dest, n);
                else BinaryPrimitives.WriteDoubleLittleEndian(dest, n);
                break;
            }
            default:
                throw new InvalidOperationException($"Cannot write {field.Type}.");
        }
    }

    private static object ReadScalar(Field field, ReadOnlySpan<byte> src) =>
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
            Field.Kind.U64 => field.BigEndian
                ? BinaryPrimitives.ReadUInt64BigEndian(src)
                : BinaryPrimitives.ReadUInt64LittleEndian(src),
            Field.Kind.I64 => field.BigEndian
                ? BinaryPrimitives.ReadInt64BigEndian(src)
                : BinaryPrimitives.ReadInt64LittleEndian(src),
            Field.Kind.F32 => field.BigEndian
                ? BinaryPrimitives.ReadSingleBigEndian(src)
                : BinaryPrimitives.ReadSingleLittleEndian(src),
            Field.Kind.F64 => field.BigEndian
                ? BinaryPrimitives.ReadDoubleBigEndian(src)
                : BinaryPrimitives.ReadDoubleLittleEndian(src),
            _ => throw new InvalidOperationException($"Cannot read {field.Type}."),
        };
}

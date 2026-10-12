using System.Buffers.Binary;

namespace Packbin;

internal static partial class Walker
{
    private static void WriteScalar(Field field, object value, Span<byte> dest)
    {
        switch (field.Type)
        {
            case Field.Kind.U8:
                dest[0] = (byte)WholeNumber(field, value);
                break;
            case Field.Kind.I8:
                dest[0] = (byte)(sbyte)WholeNumber(field, value);
                break;
            case Field.Kind.U16:
                {
                    var n = (ushort)WholeNumber(field, value);
                    if (field.BigEndian) BinaryPrimitives.WriteUInt16BigEndian(dest, n);
                    else BinaryPrimitives.WriteUInt16LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.I16:
                {
                    var n = (short)WholeNumber(field, value);
                    if (field.BigEndian) BinaryPrimitives.WriteInt16BigEndian(dest, n);
                    else BinaryPrimitives.WriteInt16LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.U32:
                {
                    var n = (uint)WholeNumber(field, value);
                    if (field.BigEndian) BinaryPrimitives.WriteUInt32BigEndian(dest, n);
                    else BinaryPrimitives.WriteUInt32LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.I32:
                {
                    var n = (int)WholeNumber(field, value);
                    if (field.BigEndian) BinaryPrimitives.WriteInt32BigEndian(dest, n);
                    else BinaryPrimitives.WriteInt32LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.U64:
                {
                    var n = (ulong)WholeNumber(field, value);
                    if (field.BigEndian) BinaryPrimitives.WriteUInt64BigEndian(dest, n);
                    else BinaryPrimitives.WriteUInt64LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.I64:
                {
                    var n = (long)WholeNumber(field, value);
                    if (field.BigEndian) BinaryPrimitives.WriteInt64BigEndian(dest, n);
                    else BinaryPrimitives.WriteInt64LittleEndian(dest, n);
                    break;
                }
            case Field.Kind.F32:
                {
                    var n = SingleNumber(field, value);
                    var bits = Compat.SingleToInt32Bits(n);
                    if (field.BigEndian) BinaryPrimitives.WriteInt32BigEndian(dest, bits);
                    else BinaryPrimitives.WriteInt32LittleEndian(dest, bits);
                    break;
                }
            case Field.Kind.F64:
                {
                    var n = RealNumber(field, value);
                    var bits = BitConverter.DoubleToInt64Bits(n);
                    if (field.BigEndian) BinaryPrimitives.WriteInt64BigEndian(dest, bits);
                    else BinaryPrimitives.WriteInt64LittleEndian(dest, bits);
                    break;
                }
            default:
                throw new InvalidOperationException($"Cannot write {field.Type}.");
        }
    }

    // The first arm is cast to object so the switch is typed object; left bare, the arms would convert to their natural type
    // double and box every narrow integer as one.
    // Unpack returns each integer field as its exact type (byte, sbyte, ushort, short, uint, int, ulong, long); an f32 is
    // returned as a double, which holds every float exactly.
    private static object ReadScalar(Field field, ReadOnlySpan<byte> src) =>
        field.Type switch
        {
            Field.Kind.U8 => (object)src[0],
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
            Field.Kind.F32 => (double)Compat.Int32BitsToSingle(field.BigEndian
                ? BinaryPrimitives.ReadInt32BigEndian(src)
                : BinaryPrimitives.ReadInt32LittleEndian(src)),
            Field.Kind.F64 => BitConverter.Int64BitsToDouble(field.BigEndian
                ? BinaryPrimitives.ReadInt64BigEndian(src)
                : BinaryPrimitives.ReadInt64LittleEndian(src)),
            _ => throw new InvalidOperationException($"Cannot read {field.Type}."),
        };
}

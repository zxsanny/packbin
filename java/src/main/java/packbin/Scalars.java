package packbin;

import java.nio.ByteBuffer;

final class Scalars {
    private Scalars() {}

    static void writeScalar(Field field, Object value, ByteBuffer buf) {
        switch (field.kind) {
            case U8 -> buf.put(toUnsignedByte(field.label(), value, 0xFFL));
            case I8 -> buf.put((byte) requireLong(field.label(), value, -0x80L, 0x7FL));
            case U16 -> buf.putShort(toUnsignedShort(field.label(), value, 0xFFFFL));
            case I16 -> buf.putShort((short) requireLong(field.label(), value, -0x8000L, 0x7FFFL));
            case U32 -> buf.putInt((int) requireLong(field.label(), value, 0L, 0xFFFFFFFFL));
            case I32 -> buf.putInt((int) requireLong(field.label(), value, -0x80000000L, 0x7FFFFFFFL));
            case U64 -> buf.putLong(requireU64(field.label(), value));
            case I64 -> buf.putLong(requireLong(field.label(), value, Long.MIN_VALUE, Long.MAX_VALUE));
            case F32 -> buf.putFloat(((Number) value).floatValue());
            case F64 -> buf.putDouble(((Number) value).doubleValue());
            default -> throw new IllegalStateException("Cannot write " + field.kind);
        }
    }

    static Object readScalar(Field field, ByteBuffer buf) {
        return switch (field.kind) {
            case U8 -> buf.get() & 0xFF;
            case I8 -> (int) buf.get();
            case U16 -> buf.getShort() & 0xFFFF;
            case I16 -> (int) buf.getShort();
            case U32 -> buf.getInt() & 0xFFFFFFFFL;
            case I32 -> buf.getInt();
            case U64 -> buf.getLong();
            case I64 -> buf.getLong();
            case F32 -> buf.getFloat();
            case F64 -> buf.getDouble();
            default -> throw new IllegalStateException("Cannot read " + field.kind);
        };
    }

    private static byte toUnsignedByte(String name, Object value, long max) {
        return (byte) requireLong(name, value, 0L, max);
    }

    private static short toUnsignedShort(String name, Object value, long max) {
        return (short) requireLong(name, value, 0L, max);
    }

    private static long requireLong(String name, Object value, long min, long max) {
        if (!(value instanceof Number) || value instanceof Float || value instanceof Double) {
            throw new IllegalArgumentException(name + ": expected int, got " + typeName(value));
        }
        long n = ((Number) value).longValue();
        if (n < min || n > max) {
            throw new ArithmeticException(name + ": " + n + " does not fit");
        }
        return n;
    }

    private static long requireU64(String name, Object value) {
        if (value instanceof Long l) {
            return l;
        }
        if (value instanceof Integer || value instanceof Short || value instanceof Byte) {
            long n = ((Number) value).longValue();
            if (n < 0) {
                throw new ArithmeticException(name + ": " + n + " does not fit");
            }
            return n;
        }
        throw new IllegalArgumentException(name + ": expected int, got " + typeName(value));
    }

    private static String typeName(Object value) {
        return value == null ? "null" : value.getClass().getSimpleName();
    }
}

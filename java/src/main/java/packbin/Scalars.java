package packbin;

import java.math.BigDecimal;
import java.math.BigInteger;
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
            case F32 -> buf.putFloat(requireF32(field.label(), value));
            case F64 -> buf.putDouble(requireF64(field.label(), value));
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

    /**
     * The value as a long, only when it is a whole number: a Byte, Short, Integer, Long or BigInteger, or any other
     * Number but a Float or Double whose decimal text has no fraction (BigDecimal, the atomics). A fraction, a
     * Float or Double, a string, a boolean and a number past 64 bits are refused instead of being narrowed.
     */
    private static long exactLong(String name, Object value) {
        if (value instanceof Long || value instanceof Integer || value instanceof Short || value instanceof Byte) {
            return ((Number) value).longValue();
        }
        if (value instanceof BigInteger big) {
            if (big.bitLength() > 63) {
                throw new IllegalArgumentException(name + ": " + big + " does not fit");
            }
            return big.longValue();
        }
        if (value instanceof Number number && !(value instanceof Float || value instanceof Double)) {
            BigDecimal whole = decimal(name, number).stripTrailingZeros();
            if (whole.scale() <= 0) {
                // 19 digits hold every long; a 1E+999999999 is refused before it is expanded.
                if (whole.precision() - whole.scale() > 19 || whole.toBigInteger().bitLength() > 63) {
                    throw new IllegalArgumentException(name + ": " + number + " does not fit");
                }
                return whole.longValueExact();
            }
        }
        throw new IllegalArgumentException(name + ": expected int, got " + typeName(value));
    }

    private static BigDecimal decimal(String name, Number number) {
        if (number instanceof BigDecimal decimal) {
            return decimal;
        }
        String text = number.toString();
        if (text == null) {
            throw new IllegalArgumentException(name + ": expected int, got " + typeName(number));
        }
        try {
            return new BigDecimal(text);
        } catch (NumberFormatException ex) {
            throw new IllegalArgumentException(name + ": expected int, got " + typeName(number), ex);
        }
    }

    private static long requireLong(String name, Object value, long min, long max) {
        long n = exactLong(name, value);
        if (n < min || n > max) {
            throw new IllegalArgumentException(name + ": " + n + " does not fit");
        }
        return n;
    }

    /** A Long is the unsigned bit pattern, so a u64 read from the wire above 2^63 (a negative Long) packs back. */
    private static long requireU64(String name, Object value) {
        if (value instanceof Long l) {
            return l;
        }
        if (value instanceof Integer || value instanceof Short || value instanceof Byte) {
            long n = ((Number) value).longValue();
            if (n < 0) {
                throw new IllegalArgumentException(name + ": " + n + " does not fit");
            }
            return n;
        }
        throw new IllegalArgumentException(name + ": expected int, got " + typeName(value));
    }

    private static Number requireNumber(String name, Object value) {
        if (!(value instanceof Number number)) {
            throw new IllegalArgumentException(name + ": expected number, got " + typeName(value));
        }
        return number;
    }

    private static float requireF32(String name, Object value) {
        Number number = requireNumber(name, value);
        float narrowed = number.floatValue();
        refuseFiniteOverflow(name, number, Float.isInfinite(narrowed), "f32");
        return narrowed;
    }

    private static double requireF64(String name, Object value) {
        Number number = requireNumber(name, value);
        double narrowed = number.doubleValue();
        refuseFiniteOverflow(name, number, Double.isInfinite(narrowed), "f64");
        return narrowed;
    }

    /**
     * A value that would become infinity is refused unless it is a Float or Double that is infinity itself: an
     * explicit infinity is written, a BigInteger, BigDecimal or finite Double past the width is not one.
     */
    private static void refuseFiniteOverflow(String name, Number number, boolean becameInfinite, String kind) {
        boolean explicit = (number instanceof Float || number instanceof Double) && Double.isInfinite(number.doubleValue());
        if (becameInfinite && !explicit) {
            String shown = number instanceof Float || number instanceof Double ? number.toString() : typeName(number);
            throw new IllegalArgumentException(name + ": " + shown + " does not fit in " + kind);
        }
    }

    private static String typeName(Object value) {
        return value == null ? "null" : value.getClass().getSimpleName();
    }
}

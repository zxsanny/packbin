package packbin;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class Walker {
    private Walker() {}

    static boolean isPresent(Map<String, Object> values, String name) {
        return values.containsKey(name) && values.get(name) != null;
    }

    static boolean groupOn(Map<String, Object> values, Field group) {
        if (isPresent(values, group.name)) {
            return true;
        }
        for (Field child : group.children) {
            if ((isScalar(child.kind) || child.kind == Field.Kind.BYTES)
                    && isPresent(values, child.name)) {
                return true;
            }
        }
        return false;
    }

    private static boolean isScalar(Field.Kind kind) {
        return switch (kind) {
            case U8, U16, U32, U64, I8, I16, I32, I64, F32, F64 -> true;
            default -> false;
        };
    }

    static void packField(Field field, Map<String, Object> values, ByteSink sink) {
        switch (field.kind) {
            case FLAGS -> packFlags(field, values, sink);
            case FLAG_BYTE -> packFlagByte(field, values, sink);
            case FLAG_BIT -> packFlagBit(field, values, sink);
            case WHEN -> packWhen(field, values, sink);
            case REPEAT -> packRepeat(field, values, sink);
            case BYTES -> packBytes(field, values, sink);
            case GROUP -> packGroup(field, values, sink);
            case SIZED -> VarFields.packSized(field, values, sink);
            case U2 -> VarFields.packU2(field, values, sink);
            case BITS -> VarFields.packBits(field, values, sink);
            case UTF8 -> VarFields.packUtf8(field, values, sink);
            case LIST -> VarFields.packList(field, values, sink);
            case DICT -> VarFields.packDict(field, values, sink);
            default -> packScalar(field, values, sink);
        }
    }

    static Object unpackField(
            Field field,
            byte[] data,
            int[] offset,
            Map<String, Object> values,
            boolean asList) {
        return switch (field.kind) {
            case FLAGS -> unpackFlags(field, data, offset, values);
            case FLAG_BYTE -> unpackFlagByte(field, data, offset, values);
            case FLAG_BIT -> unpackFlagBit(field, data, offset, values);
            case WHEN -> unpackWhen(field, data, offset, values);
            case REPEAT -> unpackRepeat(field, data, offset, values);
            case BYTES -> unpackBytes(field, data, offset, values, asList);
            case GROUP -> unpackGroup(field, data, offset, values);
            case SIZED -> VarFields.unpackSized(field, data, offset, values, asList);
            case U2 -> VarFields.unpackU2(field, data, offset, values, asList);
            case BITS -> VarFields.unpackBits(field, data, offset, values, asList);
            case UTF8 -> VarFields.unpackUtf8(field, data, offset, values, asList);
            case LIST -> VarFields.unpackList(field, data, offset, values, asList);
            case DICT -> VarFields.unpackDict(field, data, offset, values, asList);
            default -> unpackScalar(field, data, offset, values, asList);
        };
    }

    private static void packFlags(Field field, Map<String, Object> values, ByteSink sink) {
        int flags = field.group.compute(values);
        sink.write((byte) flags);
        for (Field bit : field.children) {
            packFlagBit(bit, values, sink);
        }
    }

    private static void packFlagByte(Field field, Map<String, Object> values, ByteSink sink) {
        sink.write((byte) field.group.compute(values));
    }

    private static void packFlagBit(Field field, Map<String, Object> values, ByteSink sink) {
        Field inner = field.inner;
        if (inner.kind == Field.Kind.GROUP) {
            if (!groupOn(values, inner)) {
                return;
            }
            packGroup(inner, values, sink);
            return;
        }
        if (!isPresent(values, field.name)) {
            return;
        }
        packField(inner, values, sink);
    }

    private static void packGroup(Field field, Map<String, Object> values, ByteSink sink) {
        for (Field child : field.children) {
            packField(child, values, sink);
        }
    }

    private static void packWhen(Field field, Map<String, Object> values, ByteSink sink) {
        if (!conditionHolds(field.condition, values)) {
            return;
        }
        for (Field child : field.children) {
            packField(child, values, sink);
        }
    }

    private static void packRepeat(Field field, Map<String, Object> values, ByteSink sink) {
        int count = repeatCount(field, values);
        for (int i = 0; i < count; i++) {
            Map<String, Object> slice = sliceValues(field, values, i);
            for (Field child : field.children) {
                packField(child, slice, sink);
            }
        }
    }

    private static int repeatCount(Field field, Map<String, Object> values) {
        int count = 0;
        for (Field child : field.children) {
            Object v = values.get(child.fieldName());
            if (v == null) {
                continue;
            }
            if (v instanceof List<?> list) {
                count = Math.max(count, list.size());
            } else {
                count = Math.max(count, 1);
            }
        }
        return count;
    }

    private static Map<String, Object> sliceValues(Field field, Map<String, Object> values, int index) {
        Map<String, Object> slice = new HashMap<>();
        for (Field child : field.children) {
            String name = child.fieldName();
            Object v = values.get(name);
            if (v == null) {
                continue;
            }
            if (v instanceof List<?> list) {
                if (index < list.size()) {
                    slice.put(name, list.get(index));
                }
            } else if (index == 0) {
                slice.put(name, v);
            }
        }
        return slice;
    }

    private static void packBytes(Field field, Map<String, Object> values, ByteSink sink) {
        if (!isPresent(values, field.name)) {
            throw new IllegalArgumentException("missing field '" + field.name + "'");
        }
        Object raw = values.get(field.name);
        if (!(raw instanceof byte[] bytes)) {
            throw new IllegalArgumentException(field.name + ": expected bytes");
        }
        if (bytes.length != field.size) {
            throw new IllegalArgumentException(
                    field.name + ": expected " + field.size + " bytes, got " + bytes.length);
        }
        sink.write(bytes);
    }

    private static void packScalar(Field field, Map<String, Object> values, ByteSink sink) {
        if (!isPresent(values, field.name)) {
            throw new IllegalArgumentException("missing field '" + field.name + "'");
        }
        ByteBuffer buf = ByteBuffer.allocate(field.size);
        buf.order(field.bigEndian ? ByteOrder.BIG_ENDIAN : ByteOrder.LITTLE_ENDIAN);
        writeScalar(field, values.get(field.name), buf);
        buf.flip();
        sink.write(buf);
    }

    private static Object unpackFlags(
            Field field, byte[] data, int[] offset, Map<String, Object> values) {
        int left = data.length - offset[0];
        if (left < 1) {
            return new Packbin.ShortPacket(field.name, 1, left);
        }
        int flags = data[offset[0]++] & 0xFF;
        values.put(field.name, flags);
        field.group.unpacked = flags;
        for (Field bit : field.children) {
            Object err = unpackFlagBit(bit, data, offset, values);
            if (err != null) {
                return err;
            }
        }
        return null;
    }

    private static Object unpackFlagByte(
            Field field, byte[] data, int[] offset, Map<String, Object> values) {
        int left = data.length - offset[0];
        if (left < 1) {
            return new Packbin.ShortPacket(field.name, 1, left);
        }
        int flags = data[offset[0]++] & 0xFF;
        values.put(field.name, flags);
        field.group.unpacked = flags;
        return null;
    }

    private static Object unpackFlagBit(
            Field field, byte[] data, int[] offset, Map<String, Object> values) {
        if ((field.group.unpacked & (1 << field.bitIndex)) == 0) {
            return null;
        }
        return unpackField(field.inner, data, offset, values, false);
    }

    private static Object unpackGroup(
            Field field, byte[] data, int[] offset, Map<String, Object> values) {
        if (field.children.isEmpty()) {
            values.put(field.name, true);
            return null;
        }
        for (Field child : field.children) {
            Object err = unpackField(child, data, offset, values, false);
            if (err != null) {
                return err;
            }
        }
        return null;
    }

    private static Object unpackWhen(
            Field field, byte[] data, int[] offset, Map<String, Object> values) {
        if (!conditionHolds(field.condition, values)) {
            return null;
        }
        for (Field child : field.children) {
            Object err = unpackField(child, data, offset, values, false);
            if (err != null) {
                return err;
            }
        }
        return null;
    }

    private static Object unpackRepeat(
            Field field, byte[] data, int[] offset, Map<String, Object> values) {
        while (offset[0] < data.length) {
            Object err = unpackFieldGroup(field, data, offset, values);
            if (err != null) {
                return err;
            }
        }
        return null;
    }

    private static Object unpackFieldGroup(
            Field field, byte[] data, int[] offset, Map<String, Object> values) {
        for (Field child : field.children) {
            Object err = unpackField(child, data, offset, values, true);
            if (err != null) {
                return err;
            }
        }
        return null;
    }

    private static Object unpackBytes(
            Field field,
            byte[] data,
            int[] offset,
            Map<String, Object> values,
            boolean asList) {
        int left = data.length - offset[0];
        if (left < field.size) {
            return new Packbin.ShortPacket(field.name, field.size, left);
        }
        byte[] raw = new byte[field.size];
        System.arraycopy(data, offset[0], raw, 0, field.size);
        offset[0] += field.size;
        store(values, field.name, raw, asList);
        return null;
    }

    private static Object unpackScalar(
            Field field,
            byte[] data,
            int[] offset,
            Map<String, Object> values,
            boolean asList) {
        int left = data.length - offset[0];
        if (left < field.size) {
            return new Packbin.ShortPacket(field.name, field.size, left);
        }
        ByteBuffer buf = ByteBuffer.wrap(data, offset[0], field.size);
        buf.order(field.bigEndian ? ByteOrder.BIG_ENDIAN : ByteOrder.LITTLE_ENDIAN);
        Object value = readScalar(field, buf);
        offset[0] += field.size;
        store(values, field.name, value, asList);
        return null;
    }

    @SuppressWarnings("unchecked")
    static void store(Map<String, Object> values, String name, Object value, boolean asList) {
        if (!asList) {
            values.put(name, value);
            return;
        }
        Object existing = values.get(name);
        if (existing instanceof List<?> list) {
            ((List<Object>) list).add(value);
        } else if (existing == null) {
            List<Object> list = new ArrayList<>();
            list.add(value);
            values.put(name, list);
        } else {
            List<Object> list = new ArrayList<>();
            list.add(existing);
            list.add(value);
            values.put(name, list);
        }
    }

    private static boolean conditionHolds(Packbin.Eq condition, Map<String, Object> values) {
        Object actual = values.get(condition.field);
        if (actual == null) {
            return false;
        }
        return valuesEqual(actual, condition.value);
    }

    private static boolean valuesEqual(Object a, Object b) {
        if (a instanceof byte[] aa && b instanceof byte[] bb) {
            return java.util.Arrays.equals(aa, bb);
        }
        if (a instanceof Number na && b instanceof Number nb) {
            if (a instanceof Double || a instanceof Float || b instanceof Double || b instanceof Float) {
                return Double.compare(na.doubleValue(), nb.doubleValue()) == 0;
            }
            return na.longValue() == nb.longValue();
        }
        return a.equals(b);
    }

    private static void writeScalar(Field field, Object value, ByteBuffer buf) {
        switch (field.kind) {
            case U8 -> buf.put(toUnsignedByte(field.name, value, 0xFFL));
            case I8 -> buf.put((byte) requireLong(field.name, value, -0x80L, 0x7FL));
            case U16 -> buf.putShort(toUnsignedShort(field.name, value, 0xFFFFL));
            case I16 -> buf.putShort((short) requireLong(field.name, value, -0x8000L, 0x7FFFL));
            case U32 -> buf.putInt((int) requireLong(field.name, value, 0L, 0xFFFFFFFFL));
            case I32 -> buf.putInt((int) requireLong(field.name, value, -0x80000000L, 0x7FFFFFFFL));
            case U64 -> buf.putLong(requireU64(field.name, value));
            case I64 -> buf.putLong(requireLong(field.name, value, Long.MIN_VALUE, Long.MAX_VALUE));
            case F32 -> buf.putFloat(((Number) value).floatValue());
            case F64 -> buf.putDouble(((Number) value).doubleValue());
            default -> throw new IllegalStateException("Cannot write " + field.kind);
        }
    }

    private static Object readScalar(Field field, ByteBuffer buf) {
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

    private static int requireCount(String name, Object value) {
        if (!(value instanceof Number) || value instanceof Float || value instanceof Double) {
            throw new IllegalStateException(name + ": count is missing");
        }
        return ((Number) value).intValue();
    }

    private static int requireU2(String name, Object value) {
        if (value instanceof Boolean
                || !(value instanceof Number)
                || value instanceof Float
                || value instanceof Double) {
            throw new IllegalArgumentException(name + ": expected 2-bit int");
        }
        int n = ((Number) value).intValue();
        if (n < 0 || n > 3) {
            throw new IllegalArgumentException(name + ": expected 2-bit int");
        }
        return n;
    }

    private static int requireBit(String name, Object value) {
        if (!(value instanceof Number) || value instanceof Float || value instanceof Double) {
            throw new IllegalArgumentException(name + ": expected 0 or 1");
        }
        int n = ((Number) value).intValue();
        if (n != 0 && n != 1) {
            throw new IllegalArgumentException(name + ": expected 0 or 1");
        }
        return n;
    }

    private static byte toUnsignedByte(String name, Object value, long max) {
        long n = requireLong(name, value, 0L, max);
        return (byte) n;
    }

    private static short toUnsignedShort(String name, Object value, long max) {
        long n = requireLong(name, value, 0L, max);
        return (short) n;
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

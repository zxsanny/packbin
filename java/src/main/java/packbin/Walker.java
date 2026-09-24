package packbin;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class Walker {
    private Walker() {}

    @FunctionalInterface
    interface Take {
        Object apply(Field field);
    }

    static boolean isPresent(Object value) {
        return value != null;
    }

    static boolean boolOn(Object value) {
        return Boolean.TRUE.equals(value);
    }

    static boolean childOn(Object row, Field child) {
        return switch (child.kind) {
            case GROUP -> groupOn(row, child);
            case BOOL -> boolOn(child.get.get(row));
            case FLAG_BIT -> childOn(row, child.inner);
            case U8, U16, U32, U64, I8, I16, I32, I64, F32, F64, BYTES, UTF8, SIZED, BITS, LIST, DICT ->
                    isPresent(child.get.get(row));
            default -> false;
        };
    }

    static boolean groupOn(Object row, Field group) {
        if (group.get != null && isPresent(group.get.get(row))) {
            return true;
        }
        for (Field child : group.children) {
            if (childOn(row, child)) {
                return true;
            }
        }
        return false;
    }

    static void packFields(
            List<Field> fields,
            Object row,
            ByteSink sink,
            Map<Integer, Object> seen,
            Take take) {
        for (Field field : fields) {
            packField(field, row, sink, seen, take);
        }
    }

    static void packField(Field field, Object row, ByteSink sink, Map<Integer, Object> seen, Take take) {
        switch (field.kind) {
            case FLAGS -> packFlags(field, row, sink, seen, take);
            case FLAG_BYTE -> sink.write((byte) field.group.compute(row));
            case FLAG_BIT -> {
                if (childOn(row, field.inner)) {
                    packField(field.inner, row, sink, seen, take);
                }
            }
            case WHEN -> {
                if (conditionHolds(field.condition, seen)) {
                    packFields(field.children, row, sink, seen, take);
                }
            }
            case REPEAT -> packRepeat(field, row, sink, seen);
            case BYTES -> packBytes(field, row, sink, seen, take);
            case GROUP -> packGroup(field, row, sink, seen, take);
            case SIZED -> VarFields.packSized(field, row, sink, seen, take);
            case U2 -> VarFields.packU2(field, row, sink, seen);
            case BITS -> VarFields.packBits(field, row, sink, seen, take);
            case UTF8 -> VarFields.packUtf8(field, row, sink, seen, take);
            case LIST -> VarFields.packList(field, takeValue(field, row, take), sink);
            case DICT -> VarFields.packDict(field, takeValue(field, row, take), sink);
            case BOOL -> seen.put(field.id, takeValue(field, row, take));
            default -> packScalar(field, row, sink, seen, take);
        }
    }

    static Object unpackFields(
            List<Field> fields,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        for (Field field : fields) {
            Object err = unpackField(field, data, offset, row, seen, asList);
            if (err != null) {
                return err;
            }
        }
        return null;
    }

    static Object unpackField(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        return switch (field.kind) {
            case FLAGS -> unpackFlags(field, data, offset, row, seen, asList);
            case FLAG_BYTE -> unpackFlagByte(field, data, offset);
            case FLAG_BIT -> unpackFlagBit(field, data, offset, row, seen, asList);
            case WHEN -> unpackWhen(field, data, offset, row, seen, asList);
            case REPEAT -> unpackRepeat(field, data, offset, row, seen);
            case BYTES -> unpackBytes(field, data, offset, row, seen, asList);
            case GROUP -> unpackGroup(field, data, offset, row, seen, asList);
            case SIZED -> VarFields.unpackSized(field, data, offset, row, seen, asList);
            case U2 -> VarFields.unpackU2(field, data, offset, row, seen, asList);
            case BITS -> VarFields.unpackBits(field, data, offset, row, seen, asList);
            case UTF8 -> VarFields.unpackUtf8(field, data, offset, row, seen, asList);
            case LIST -> VarFields.unpackList(field, data, offset, row, asList);
            case DICT -> VarFields.unpackDict(field, data, offset, row, asList);
            case BOOL -> null;
            default -> unpackScalar(field, data, offset, row, seen, asList);
        };
    }

    private static Object takeValue(Field field, Object row, Take take) {
        if (take != null) {
            return take.apply(field);
        }
        return field.get.get(row);
    }

    private static void packFlags(
            Field field, Object row, ByteSink sink, Map<Integer, Object> seen, Take take) {
        int flags = field.group.compute(row);
        sink.write((byte) flags);
        for (int i = 0; i < field.children.size(); i++) {
            if ((flags & (1 << i)) == 0) {
                continue;
            }
            Field bit = field.children.get(i);
            Field inner = bit.inner;
            if (inner.kind == Field.Kind.BOOL) {
                seen.put(inner.id, inner.get.get(row));
            } else if (inner.kind == Field.Kind.GROUP) {
                packGroup(inner, row, sink, seen, take);
            } else {
                packField(inner, row, sink, seen, take);
            }
        }
    }

    private static void packGroup(
            Field field, Object row, ByteSink sink, Map<Integer, Object> seen, Take take) {
        Object target = row;
        if (field.nestedRow) {
            target = field.get.get(row);
            if (target == null) {
                return;
            }
        }
        packFields(field.children, target, sink, seen, take);
    }

    private static void packRepeat(Field field, Object row, ByteSink sink, Map<Integer, Object> seen) {
        int count = 0;
        for (Field child : field.children) {
            Object v = child.get.get(row);
            if (v == null) {
                continue;
            }
            if (v instanceof List<?> list) {
                count = Math.max(count, list.size());
            } else {
                count = Math.max(count, 1);
            }
        }
        for (int i = 0; i < count; i++) {
            int index = i;
            Take at = child -> {
                Object v = child.get.get(row);
                if (v instanceof List<?> list) {
                    return index < list.size() ? list.get(index) : null;
                }
                return v;
            };
            packFields(field.children, row, sink, seen, at);
        }
    }

    private static void packBytes(
            Field field, Object row, ByteSink sink, Map<Integer, Object> seen, Take take) {
        Object raw = takeValue(field, row, take);
        if (!isPresent(raw) && take == null) {
            throw new IllegalArgumentException("missing field " + field.id);
        }
        seen.put(field.id, raw);
        if (!(raw instanceof byte[] bytes)) {
            throw new IllegalArgumentException(field.id + ": expected bytes");
        }
        if (bytes.length != field.size) {
            throw new IllegalArgumentException(
                    field.id + ": expected " + field.size + " bytes, got " + bytes.length);
        }
        sink.write(bytes);
    }

    private static void packScalar(
            Field field, Object row, ByteSink sink, Map<Integer, Object> seen, Take take) {
        Object value = takeValue(field, row, take);
        if (!isPresent(value) && take == null) {
            throw new IllegalArgumentException("missing field " + field.id);
        }
        seen.put(field.id, value);
        ByteBuffer buf = ByteBuffer.allocate(field.size);
        buf.order(field.bigEndian ? ByteOrder.BIG_ENDIAN : ByteOrder.LITTLE_ENDIAN);
        writeScalar(field, value, buf);
        buf.flip();
        sink.write(buf);
    }

    private static Object unpackFlags(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        int left = data.length - offset[0];
        if (left < 1) {
            return new Packbin.ShortPacket("", 1, left);
        }
        int flags = data[offset[0]++] & 0xFF;
        field.group.unpacked = flags;
        for (int i = 0; i < field.children.size(); i++) {
            if ((flags & (1 << i)) == 0) {
                continue;
            }
            Field bit = field.children.get(i);
            Field inner = bit.inner;
            if (inner.kind == Field.Kind.BOOL) {
                seen.put(inner.id, true);
                store(row, inner, true, asList);
            } else {
                Object err = unpackField(inner, data, offset, row, seen, asList);
                if (err != null) {
                    return err;
                }
            }
        }
        return null;
    }

    private static Object unpackFlagByte(Field field, byte[] data, int[] offset) {
        int left = data.length - offset[0];
        if (left < 1) {
            return new Packbin.ShortPacket("", 1, left);
        }
        field.group.unpacked = data[offset[0]++] & 0xFF;
        return null;
    }

    private static Object unpackFlagBit(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        if ((field.group.unpacked & (1 << field.bitIndex)) == 0) {
            return null;
        }
        return unpackField(field.inner, data, offset, row, seen, asList);
    }

    private static Object unpackGroup(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        if (field.nestedRow) {
            Object child = newChild(field, row);
            Object err = unpackFields(field.children, data, offset, child, seen, asList);
            if (err != null) {
                return err;
            }
            store(row, field, child, asList);
            return null;
        }
        if (field.children.isEmpty()) {
            if (field.set != null) {
                store(row, field, true, asList);
            }
            return null;
        }
        return unpackFields(field.children, data, offset, row, seen, asList);
    }

    private static Object newChild(Field field, Object parent) {
        Object existing = field.get.get(parent);
        if (existing != null) {
            return existing;
        }
        return new HashMap<String, Object>();
    }

    private static Object unpackWhen(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        if (!conditionHolds(field.condition, seen)) {
            return null;
        }
        return unpackFields(field.children, data, offset, row, seen, asList);
    }

    private static Object unpackRepeat(
            Field field, byte[] data, int[] offset, Object row, Map<Integer, Object> seen) {
        while (offset[0] < data.length) {
            Object err = unpackFields(field.children, data, offset, row, seen, true);
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
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        int left = data.length - offset[0];
        if (left < field.size) {
            return new Packbin.ShortPacket(field.label(), field.size, left);
        }
        byte[] raw = new byte[field.size];
        System.arraycopy(data, offset[0], raw, 0, field.size);
        offset[0] += field.size;
        seen.put(field.id, raw);
        store(row, field, raw, asList);
        return null;
    }

    private static Object unpackScalar(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        int left = data.length - offset[0];
        if (left < field.size) {
            return new Packbin.ShortPacket(field.label(), field.size, left);
        }
        ByteBuffer buf = ByteBuffer.wrap(data, offset[0], field.size);
        buf.order(field.bigEndian ? ByteOrder.BIG_ENDIAN : ByteOrder.LITTLE_ENDIAN);
        Object value = readScalar(field, buf);
        offset[0] += field.size;
        seen.put(field.id, value);
        store(row, field, value, asList);
        return null;
    }

    @SuppressWarnings("unchecked")
    static void store(Object row, Field field, Object value, boolean asList) {
        if (row == null || field.set == null) {
            return;
        }
        if (!asList) {
            field.set.set(row, value);
            return;
        }
        Object existing = field.get.get(row);
        if (existing instanceof List<?> list) {
            ((List<Object>) list).add(value);
        } else if (existing == null) {
            List<Object> list = new ArrayList<>();
            list.add(value);
            field.set.set(row, list);
        } else {
            List<Object> list = new ArrayList<>();
            list.add(existing);
            list.add(value);
            field.set.set(row, list);
        }
    }

    private static boolean conditionHolds(Packbin.Eq condition, Map<Integer, Object> seen) {
        Object actual = seen.get(condition.fieldId);
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

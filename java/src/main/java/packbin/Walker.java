package packbin;

import java.nio.Buffer;
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

    /** Whether a flag bit is set. {@code take} is the repeat or times round's item lookup, null outside rounds. */
    static boolean childOn(Object row, Field child, Take take) {
        return switch (child.kind) {
            case GROUP -> groupOn(row, child, take);
            case BOOL -> boolOn(takeValue(child, row, take));
            case FLAG_BIT -> childOn(row, child.inner, take);
            case U8, U16, U32, U64, I8, I16, I32, I64, F32, F64, BYTES, UTF8, SIZED, BITS, PACKED, LIST, DICT ->
                    isPresent(takeValue(child, row, take));
            default -> false;
        };
    }

    private static boolean groupOn(Object row, Field group, Take take) {
        if (group.get != null && isPresent(takeValue(group, row, take))) {
            return true;
        }
        for (Field child : group.children) {
            if (childOn(row, child, take)) {
                return true;
            }
        }
        return false;
    }

    static void packFields(
            List<Field> fields,
            Object row,
            ByteSink sink,
            Map<Object, Object> seen,
            Take take) {
        for (Field field : fields) {
            packField(field, row, sink, seen, take);
        }
    }

    static void packField(Field field, Object row, ByteSink sink, Map<Object, Object> seen, Take take) {
        switch (field.kind) {
            case FLAGS -> packFlags(field, row, sink, seen, take);
            case FLAG_BYTE -> sink.write((byte) field.group.compute(row, take));
            case FLAG_BIT -> {
                if (childOn(row, field.inner, take)) {
                    packField(field.inner, row, sink, seen, take);
                }
            }
            case WHEN -> {
                if (conditionHolds(field.condition, seen)) {
                    packFields(field.children, row, sink, seen, take);
                }
            }
            case REPEAT -> Rounds.packRepeat(field, row, sink, seen);
            case TIMES -> VarFields.packTimes(field, row, sink, seen);
            case BYTES -> packBytes(field, row, sink, seen, take);
            case GROUP -> packGroup(field, row, sink, seen, take);
            case SIZED -> VarFields.packSized(field, row, sink, seen, take);
            case U2 -> VarFields.packU2(field, row, sink, seen);
            case BITS -> VarFields.packBits(field, row, sink, seen, take);
            case PACKED -> VarFields.packPacked(field, row, sink, seen, take);
            case UTF8 -> VarFields.packUtf8(field, row, sink, seen, take);
            case LIST -> Containers.packList(field, takeValue(field, row, take), sink);
            case DICT -> Containers.packDict(field, takeValue(field, row, take), sink);
            case BOOL -> seen.put(field.id, takeValue(field, row, take));
            default -> packScalar(field, row, sink, seen, take);
        }
    }

    static Object unpackFields(
            List<Field> fields,
            byte[] data,
            int[] offset,
            Object row,
            Map<Object, Object> seen,
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
            Map<Object, Object> seen,
            boolean asList) {
        return switch (field.kind) {
            case FLAGS -> unpackFlags(field, data, offset, row, seen, asList);
            case FLAG_BYTE -> unpackFlagByte(field, data, offset, seen);
            case FLAG_BIT -> unpackFlagBit(field, data, offset, row, seen, asList);
            case WHEN -> unpackWhen(field, data, offset, row, seen, asList);
            case REPEAT -> Rounds.unpackRepeat(field, data, offset, row, seen);
            case TIMES -> VarFields.unpackTimes(field, data, offset, row, seen);
            case BYTES -> unpackBytes(field, data, offset, row, seen, asList);
            case GROUP -> unpackGroup(field, data, offset, row, seen, asList);
            case SIZED -> VarFields.unpackSized(field, data, offset, row, seen, asList);
            case U2 -> VarFields.unpackU2(field, data, offset, row, seen, asList);
            case BITS -> VarFields.unpackBits(field, data, offset, row, seen, asList);
            case PACKED -> VarFields.unpackPacked(field, data, offset, row, seen, asList);
            case UTF8 -> VarFields.unpackUtf8(field, data, offset, row, seen, asList);
            case LIST -> Containers.unpackList(field, data, offset, row, asList);
            case DICT -> Containers.unpackDict(field, data, offset, row, asList);
            case BOOL -> unpackSetBool(field, row, seen, asList);
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
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Take take) {
        int flags = field.group.compute(row, take);
        sink.write((byte) flags);
        for (int i = 0; i < field.children.size(); i++) {
            if ((flags & (1 << i)) != 0) {
                packField(field.children.get(i).inner, row, sink, seen, take);
            }
        }
    }

    private static void packGroup(
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Take take) {
        Object target = row;
        if (field.nestedRow) {
            target = field.get.get(row);
            if (target == null) {
                return;
            }
        }
        packFields(field.children, target, sink, seen, take);
    }

    private static void packBytes(
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Take take) {
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
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Take take) {
        Object value = takeValue(field, row, take);
        if (!isPresent(value) && take == null) {
            throw new IllegalArgumentException("missing field " + field.id);
        }
        seen.put(field.id, value);
        ByteBuffer buf = ByteBuffer.allocate(field.size);
        buf.order(field.bigEndian ? ByteOrder.BIG_ENDIAN : ByteOrder.LITTLE_ENDIAN);
        Scalars.writeScalar(field, value, buf);
        ((Buffer) buf).flip();
        sink.write(buf);
    }

    private static Object unpackFlags(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Object, Object> seen,
            boolean asList) {
        int left = data.length - offset[0];
        if (left < 1) {
            return new Packbin.ShortPacket("", 1, left);
        }
        int flags = data[offset[0]++] & 0xFF;
        for (int i = 0; i < field.children.size(); i++) {
            if ((flags & (1 << i)) == 0) {
                continue;
            }
            Object err = unpackField(field.children.get(i).inner, data, offset, row, seen, asList);
            if (err != null) {
                return err;
            }
        }
        return null;
    }

    /** A bool is only ever a flag bit's payload (SchemeOrder), read here because its bit is set: TRUE, no bytes. */
    private static Object unpackSetBool(Field field, Object row, Map<Object, Object> seen, boolean asList) {
        seen.put(field.id, Boolean.TRUE);
        store(row, field, Boolean.TRUE, asList);
        return null;
    }

    private static Object unpackFlagByte(Field field, byte[] data, int[] offset, Map<Object, Object> seen) {
        int left = data.length - offset[0];
        if (left < 1) {
            return new Packbin.ShortPacket("", 1, left);
        }
        seen.put(field.group, data[offset[0]++] & 0xFF);
        return null;
    }

    private static Object unpackFlagBit(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Object, Object> seen,
            boolean asList) {
        // The byte lives in this call's map under its group. Validated schemes always read it first; 0 is a safety net.
        int flags = seen.get(field.group) instanceof Integer read ? read : 0;
        if ((flags & (1 << field.bitIndex)) == 0) {
            return null;
        }
        return unpackField(field.inner, data, offset, row, seen, asList);
    }

    private static Object unpackGroup(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Object, Object> seen,
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
            Map<Object, Object> seen,
            boolean asList) {
        if (!conditionHolds(field.condition, seen)) {
            return null;
        }
        return unpackFields(field.children, data, offset, row, seen, asList);
    }

    private static Object unpackBytes(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Object, Object> seen,
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
            Map<Object, Object> seen,
            boolean asList) {
        int left = data.length - offset[0];
        if (left < field.size) {
            return new Packbin.ShortPacket(field.label(), field.size, left);
        }
        ByteBuffer buf = ByteBuffer.wrap(data, offset[0], field.size);
        buf.order(field.bigEndian ? ByteOrder.BIG_ENDIAN : ByteOrder.LITTLE_ENDIAN);
        Object value = Scalars.readScalar(field, buf);
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

    private static boolean conditionHolds(Packbin.Eq condition, Map<Object, Object> seen) {
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
}

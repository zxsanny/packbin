package packbin;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

final class VarFields {
    private VarFields() {}

    static void packSized(
            Field field, Object row, ByteSink sink, Map<Integer, Object> seen, Walker.Take take) {
        Object countRaw = seen.get(field.countId);
        if (!(countRaw instanceof Number) || countRaw instanceof Float || countRaw instanceof Double) {
            throw new IllegalStateException(field.id + ": count " + field.countId + " is missing");
        }
        int count = ((Number) countRaw).intValue();
        Object raw = take != null ? take.apply(field) : field.get.get(row);
        seen.put(field.id, raw);
        if (!(raw instanceof byte[] bytes)) {
            throw new IllegalArgumentException(field.id + ": expected bytes");
        }
        if (bytes.length != count) {
            throw new IllegalArgumentException(
                    field.id + ": expected " + count + " bytes, got " + bytes.length);
        }
        sink.write(bytes);
    }

    static Object unpackSized(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        Object countRaw = seen.get(field.countId);
        if (!(countRaw instanceof Number) || countRaw instanceof Float || countRaw instanceof Double) {
            throw new IllegalStateException(field.id + ": count " + field.countId + " is missing");
        }
        int count = ((Number) countRaw).intValue();
        int left = data.length - offset[0];
        if (left < count) {
            return new Packbin.ShortPacket(field.label(), count, left);
        }
        byte[] raw = new byte[count];
        System.arraycopy(data, offset[0], raw, 0, count);
        offset[0] += count;
        seen.put(field.id, raw);
        Walker.store(row, field, raw, asList);
        return null;
    }

    static void packU2(Field field, Object row, ByteSink sink, Map<Integer, Object> seen) {
        List<Field> slots = field.children;
        int nbytes = (slots.size() + 3) / 4;
        byte[] raw = new byte[nbytes];
        for (int i = 0; i < slots.size(); i++) {
            Field slot = slots.get(i);
            Object value = slot.get.get(row);
            seen.put(slot.id, value);
            int n = requireU2(slot.label(), value);
            raw[i / 4] |= (byte) (n << ((i % 4) * 2));
        }
        sink.write(raw);
    }

    static Object unpackU2(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        List<Field> slots = field.children;
        int nbytes = (slots.size() + 3) / 4;
        int left = data.length - offset[0];
        if (left < nbytes) {
            return new Packbin.ShortPacket(slots.get(0).label(), nbytes, left);
        }
        for (int i = 0; i < slots.size(); i++) {
            int value = (data[offset[0] + i / 4] >> ((i % 4) * 2)) & 3;
            Field slot = slots.get(i);
            seen.put(slot.id, value);
            Walker.store(row, slot, value, asList);
        }
        offset[0] += nbytes;
        return null;
    }

    static void packBits(
            Field field, Object row, ByteSink sink, Map<Integer, Object> seen, Walker.Take take) {
        Object countRaw = seen.get(field.countId);
        if (!(countRaw instanceof Number) || countRaw instanceof Float || countRaw instanceof Double) {
            throw new IllegalStateException(field.id + ": count " + field.countId + " is missing");
        }
        int count = ((Number) countRaw).intValue();
        Object raw = take != null ? take.apply(field) : field.get.get(row);
        seen.put(field.id, raw);
        if (!(raw instanceof List<?> bits) || bits.size() != count) {
            throw new IllegalArgumentException(field.id + ": expected " + count + " bits");
        }
        int nbytes = (count + 7) / 8;
        byte[] packed = new byte[nbytes];
        for (int i = 0; i < count; i++) {
            int bit = requireBit(field.label(), bits.get(i));
            packed[i / 8] |= (byte) (bit << (i % 8));
        }
        sink.write(packed);
    }

    static Object unpackBits(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        Object countRaw = seen.get(field.countId);
        if (!(countRaw instanceof Number) || countRaw instanceof Float || countRaw instanceof Double) {
            throw new IllegalStateException(field.id + ": count " + field.countId + " is missing");
        }
        int count = ((Number) countRaw).intValue();
        int nbytes = (count + 7) / 8;
        int left = data.length - offset[0];
        if (left < nbytes) {
            return new Packbin.ShortPacket(field.label(), nbytes, left);
        }
        List<Integer> out = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            out.add((data[offset[0] + i / 8] >> (i % 8)) & 1);
        }
        offset[0] += nbytes;
        seen.put(field.id, out);
        Walker.store(row, field, out, asList);
        return null;
    }

    static int borrowedCount(Field field, Map<Integer, Object> seen) {
        Object countRaw = seen.get(field.countId);
        if (!(countRaw instanceof Number) || countRaw instanceof Float || countRaw instanceof Double) {
            throw new IllegalStateException(field.label() + ": count " + field.countId + " is missing");
        }
        int count = ((Number) countRaw).intValue() + field.bias;
        if (count < 0) {
            throw new IllegalArgumentException(field.label() + ": item count " + count);
        }
        return count;
    }

    static int packedBytes(int width, int count) {
        return (count * width + 7) / 8;
    }

    static void packPacked(
            Field field, Object row, ByteSink sink, Map<Integer, Object> seen, Walker.Take take) {
        int count = borrowedCount(field, seen);
        Object raw = take != null ? take.apply(field) : field.get.get(row);
        seen.put(field.id, raw);
        if (!(raw instanceof List<?> items) || items.size() != count) {
            throw new IllegalArgumentException(field.id + ": expected " + count + " items");
        }
        int width = field.size;
        int max = width == 2 ? 3 : 1;
        int shift = width == 2 ? 2 : 1;
        int per = width == 2 ? 4 : 8;
        byte[] packed = new byte[packedBytes(width, count)];
        for (int i = 0; i < count; i++) {
            int n = requirePacked(field.label(), items.get(i), max);
            packed[i / per] |= (byte) (n << ((i % per) * shift));
        }
        sink.write(packed);
    }

    static Object unpackPacked(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        int count = borrowedCount(field, seen);
        int width = field.size;
        int nbytes = packedBytes(width, count);
        int left = data.length - offset[0];
        if (left < nbytes) {
            return new Packbin.ShortPacket(field.label(), nbytes, left);
        }
        int mask = width == 2 ? 3 : 1;
        int shift = width == 2 ? 2 : 1;
        int per = width == 2 ? 4 : 8;
        List<Integer> out = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            out.add((data[offset[0] + i / per] >> ((i % per) * shift)) & mask);
        }
        offset[0] += nbytes;
        seen.put(field.id, out);
        Walker.store(row, field, out, asList);
        return null;
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

    private static int requirePacked(String name, Object value, int max) {
        if (value instanceof Boolean
                || !(value instanceof Number)
                || value instanceof Float
                || value instanceof Double) {
            throw new IllegalArgumentException(name + ": expected 0.." + max);
        }
        int n = ((Number) value).intValue();
        if (n < 0 || n > max) {
            throw new IllegalArgumentException(name + ": expected 0.." + max);
        }
        return n;
    }

    static void packUtf8(
            Field field, Object row, ByteSink sink, Map<Integer, Object> seen, Walker.Take take) {
        Object value = take != null ? take.apply(field) : field.get.get(row);
        seen.put(field.id, value);
        if (!(value instanceof String text)) {
            throw new IllegalArgumentException(field.id + ": expected string");
        }
        byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
        if (bytes.length > 65535) {
            throw new IllegalArgumentException(field.id + ": utf-8 length " + bytes.length);
        }
        sink.write((byte) bytes.length);
        sink.write((byte) (bytes.length >> 8));
        sink.write(bytes);
    }

    static Object unpackUtf8(
            Field field,
            byte[] data,
            int[] offset,
            Object row,
            Map<Integer, Object> seen,
            boolean asList) {
        int left = data.length - offset[0];
        if (left < 2) {
            return new Packbin.ShortPacket(field.label(), 2, left);
        }
        int count = (data[offset[0]] & 0xff) | ((data[offset[0] + 1] & 0xff) << 8);
        offset[0] += 2;
        left = data.length - offset[0];
        if (left < count) {
            return new Packbin.ShortPacket(field.label(), count, left);
        }
        String text = new String(data, offset[0], count, StandardCharsets.UTF_8);
        offset[0] += count;
        seen.put(field.id, text);
        Walker.store(row, field, text, asList);
        return null;
    }

    static void packList(Field field, Object itemsRaw, ByteSink sink) {
        if (!(itemsRaw instanceof List<?> items)) {
            throw new IllegalArgumentException("list: expected list");
        }
        if (items.size() > 65535) {
            throw new IllegalArgumentException("list: length " + items.size());
        }
        sink.write((byte) items.size());
        sink.write((byte) (items.size() >> 8));
        Field child = field.children.get(0);
        for (Object item : items) {
            packElement(child, item, sink);
        }
    }

    static Object unpackList(Field field, byte[] data, int[] offset, Object row, boolean asList) {
        Object[] got = unpackListItems(field.children.get(0), data, offset);
        if (got[1] != null) {
            return got[1];
        }
        Walker.store(row, field, got[0], asList);
        return null;
    }

    private static Object[] unpackListItems(Field element, byte[] data, int[] offset) {
        int left = data.length - offset[0];
        if (left < 2) {
            return new Object[] {List.of(), new Packbin.ShortPacket("", 2, left)};
        }
        int count = (data[offset[0]] & 0xff) | ((data[offset[0] + 1] & 0xff) << 8);
        offset[0] += 2;
        List<Object> items = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            Object[] got = unpackElement(element, data, offset);
            if (got[1] != null) {
                return new Object[] {items, got[1]};
            }
            items.add(got[0]);
        }
        return new Object[] {items, null};
    }

    static void packDict(Field field, Object mappingRaw, ByteSink sink) {
        if (!(mappingRaw instanceof Map<?, ?> items)) {
            throw new IllegalArgumentException("dict: expected dictionary");
        }
        if (items.size() > 65535) {
            throw new IllegalArgumentException("dict: length " + items.size());
        }
        List<String> keys = new ArrayList<>(items.size());
        for (Object key : items.keySet()) {
            if (!(key instanceof String text)) {
                throw new IllegalArgumentException("dict: expected string key");
            }
            keys.add(text);
        }
        keys.sort((a, b) -> Arrays.compareUnsigned(
                a.getBytes(StandardCharsets.UTF_8), b.getBytes(StandardCharsets.UTF_8)));
        sink.write((byte) keys.size());
        sink.write((byte) (keys.size() >> 8));
        Field child = field.children.get(0);
        for (String key : keys) {
            byte[] rawKey = key.getBytes(StandardCharsets.UTF_8);
            if (rawKey.length > 65535) {
                throw new IllegalArgumentException("dict: key length " + rawKey.length);
            }
            sink.write((byte) rawKey.length);
            sink.write((byte) (rawKey.length >> 8));
            sink.write(rawKey);
            packElement(child, items.get(key), sink);
        }
    }

    static Object unpackDict(Field field, byte[] data, int[] offset, Object row, boolean asList) {
        Object[] got = unpackDictItems(field.children.get(0), data, offset);
        if (got[1] != null) {
            return got[1];
        }
        Walker.store(row, field, got[0], asList);
        return null;
    }

    private static Object[] unpackDictItems(Field element, byte[] data, int[] offset) {
        int left = data.length - offset[0];
        if (left < 2) {
            return new Object[] {Map.of(), new Packbin.ShortPacket("", 2, left)};
        }
        int count = (data[offset[0]] & 0xff) | ((data[offset[0] + 1] & 0xff) << 8);
        offset[0] += 2;
        Map<String, Object> items = new LinkedHashMap<>();
        Set<String> seenKeys = new HashSet<>();
        for (int i = 0; i < count; i++) {
            left = data.length - offset[0];
            if (left < 2) {
                return new Object[] {items, new Packbin.ShortPacket("", 2, left)};
            }
            int keyLen = (data[offset[0]] & 0xff) | ((data[offset[0] + 1] & 0xff) << 8);
            offset[0] += 2;
            left = data.length - offset[0];
            if (left < keyLen) {
                return new Object[] {items, new Packbin.ShortPacket("", keyLen, left)};
            }
            String key = new String(data, offset[0], keyLen, StandardCharsets.UTF_8);
            offset[0] += keyLen;
            if (!seenKeys.add(key)) {
                return new Object[] {items, new Packbin.ShortPacket("", 0, 0)};
            }
            Object[] got = unpackElement(element, data, offset);
            if (got[1] != null) {
                return new Object[] {items, got[1]};
            }
            items.put(key, got[0]);
        }
        return new Object[] {items, null};
    }

    static void packTimes(Field field, Object row, ByteSink sink, Map<Integer, Object> seen) {
        int count = borrowedCount(field, seen);
        for (int i = 0; i < count; i++) {
            Walker.packIndexed(field, row, sink, seen, i);
        }
    }

    static Object unpackTimes(
            Field field, byte[] data, int[] offset, Object row, Map<Integer, Object> seen) {
        int count = borrowedCount(field, seen);
        for (int i = 0; i < count; i++) {
            Object err = Walker.unpackFields(field.children, data, offset, row, seen, true);
            if (err != null) {
                return err;
            }
        }
        return null;
    }

    private static boolean isLeaf(Field field) {
        return switch (field.kind) {
            case U8, U16, U32, U64, I8, I16, I32, I64, F32, F64, BYTES, UTF8, BOOL, SIZED, BITS, PACKED -> true;
            default -> false;
        };
    }

    private static void packElement(Field element, Object item, ByteSink sink) {
        if (element.kind == Field.Kind.LIST) {
            packList(element, item, sink);
        } else if (element.kind == Field.Kind.DICT) {
            packDict(element, item, sink);
        } else if (isLeaf(element)) {
            Walker.packFields(List.of(element), item, sink, new HashMap<>(), field -> item);
        } else {
            Walker.packFields(List.of(element), item, sink, new HashMap<>(), null);
        }
    }

    private static Object[] unpackElement(Field element, byte[] data, int[] offset) {
        if (element.kind == Field.Kind.LIST) {
            return unpackListItems(element.children.get(0), data, offset);
        }
        if (element.kind == Field.Kind.DICT) {
            return unpackDictItems(element.children.get(0), data, offset);
        }
        if (isLeaf(element)) {
            Map<Integer, Object> seen = new HashMap<>();
            Object err = Walker.unpackField(element, data, offset, null, seen, false);
            if (err != null) {
                return new Object[] {null, err};
            }
            if (element.kind == Field.Kind.BOOL) {
                return new Object[] {true, null};
            }
            return new Object[] {seen.get(element.id), null};
        }
        Map<String, Object> child = new HashMap<>();
        Object err = Walker.unpackFields(List.of(element), data, offset, child, new HashMap<>(), false);
        return new Object[] {child, err};
    }
}

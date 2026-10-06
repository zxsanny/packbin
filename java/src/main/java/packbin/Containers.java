package packbin;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

final class Containers {
    private Containers() {}

    static void packList(Field field, Object itemsRaw, ByteSink sink) {
        if (!(itemsRaw instanceof List<?> items)) {
            throw new IllegalArgumentException("list: expected list");
        }
        if (items.size() > VarFields.MAX_U16) {
            throw new IllegalArgumentException("list: length " + items.size());
        }
        sink.write((byte) items.size());
        sink.write((byte) (items.size() >> 8));
        Field child = field.children.get(0);
        for (Object item : items) {
            packElement(child, item, sink);
        }
    }

    static Object unpackList(Field field, byte[] data, Cursor cur, Object row, boolean asList) {
        Object[] got = unpackListItems(field.children.get(0), data, cur);
        if (got[1] != null) {
            return got[1];
        }
        Walker.store(row, field, got[0], asList);
        return null;
    }

    private static Object[] unpackListItems(Field element, byte[] data, Cursor cur) {
        int left = data.length - cur.pos;
        if (left < 2) {
            return new Object[] {Collections.emptyList(), new Packbin.ShortPacket("", 2, left)};
        }
        int count = (data[cur.pos] & 0xff) | ((data[cur.pos + 1] & 0xff) << 8);
        cur.pos += 2;
        List<Object> items = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            Object[] got = unpackElement(element, data, cur);
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
        if (items.size() > VarFields.MAX_U16) {
            throw new IllegalArgumentException("dict: length " + items.size());
        }
        List<String> keys = new ArrayList<>(items.size());
        for (Object key : items.keySet()) {
            if (!(key instanceof String text)) {
                throw new IllegalArgumentException("dict: expected string key");
            }
            keys.add(text);
        }
        keys.sort((a, b) -> compareUnsigned(
                a.getBytes(StandardCharsets.UTF_8), b.getBytes(StandardCharsets.UTF_8)));
        sink.write((byte) keys.size());
        sink.write((byte) (keys.size() >> 8));
        Field child = field.children.get(0);
        for (String key : keys) {
            byte[] rawKey = key.getBytes(StandardCharsets.UTF_8);
            if (rawKey.length > VarFields.MAX_U16) {
                throw new IllegalArgumentException("dict: key length " + rawKey.length);
            }
            sink.write((byte) rawKey.length);
            sink.write((byte) (rawKey.length >> 8));
            sink.write(rawKey);
            packElement(child, items.get(key), sink);
        }
    }

    /** Unsigned byte order, then length; Arrays.compareUnsigned needs Android API 33. */
    private static int compareUnsigned(byte[] a, byte[] b) {
        int common = Math.min(a.length, b.length);
        for (int i = 0; i < common; i++) {
            int diff = (a[i] & 0xff) - (b[i] & 0xff);
            if (diff != 0) {
                return diff;
            }
        }
        return a.length - b.length;
    }

    static Object unpackDict(Field field, byte[] data, Cursor cur, Object row, boolean asList) {
        Object[] got = unpackDictItems(field.children.get(0), data, cur);
        if (got[1] != null) {
            return got[1];
        }
        Walker.store(row, field, got[0], asList);
        return null;
    }

    private static Object[] unpackDictItems(Field element, byte[] data, Cursor cur) {
        int left = data.length - cur.pos;
        if (left < 2) {
            return new Object[] {Collections.emptyMap(), new Packbin.ShortPacket("", 2, left)};
        }
        int count = (data[cur.pos] & 0xff) | ((data[cur.pos + 1] & 0xff) << 8);
        cur.pos += 2;
        Map<String, Object> items = new LinkedHashMap<>();
        Set<String> seenKeys = new HashSet<>();
        for (int i = 0; i < count; i++) {
            left = data.length - cur.pos;
            if (left < 2) {
                return new Object[] {items, new Packbin.ShortPacket("", 2, left)};
            }
            int keyLen = (data[cur.pos] & 0xff) | ((data[cur.pos + 1] & 0xff) << 8);
            cur.pos += 2;
            left = data.length - cur.pos;
            if (left < keyLen) {
                return new Object[] {items, new Packbin.ShortPacket("", keyLen, left)};
            }
            String key = VarFields.decodeUtf8(data, cur.pos, keyLen);
            if (key == null) {
                return new Object[] {items, new Packbin.ShortPacket("", keyLen, 0)};
            }
            cur.pos += keyLen;
            if (!seenKeys.add(key)) {
                return new Object[] {items, new Packbin.ShortPacket("", 0, 0)};
            }
            Object[] got = unpackElement(element, data, cur);
            if (got[1] != null) {
                return new Object[] {items, got[1]};
            }
            items.put(key, got[0]);
        }
        return new Object[] {items, null};
    }

    private static boolean isLeaf(Field field) {
        return switch (field.kind) {
            case U8, U16, U32, U64, I8, I16, I32, I64, F32, F64, BYTES, UTF8, SIZED, BITS, PACKED -> true;
            default -> false;
        };
    }

    private static void packElement(Field element, Object item, ByteSink sink) {
        if (element.kind == Field.Kind.LIST) {
            packList(element, item, sink);
        } else if (element.kind == Field.Kind.DICT) {
            packDict(element, item, sink);
        } else if (isLeaf(element)) {
            Walker.packFields(Collections.singletonList(element), item, sink, new HashMap<>(), field -> item);
        } else {
            Walker.packFields(Collections.singletonList(element), item, sink, new HashMap<>(), null);
        }
    }

    /** An element that reads 0 bytes would repeat for a count the packet controls; it is an error. */
    private static Object[] unpackElement(Field element, byte[] data, Cursor cur) {
        int before = cur.pos;
        Object[] got = readElement(element, data, cur);
        if (got[1] == null && cur.pos == before) {
            return new Object[] {null, new Packbin.ShortPacket("", 0, data.length - before)};
        }
        return got;
    }

    private static Object[] readElement(Field element, byte[] data, Cursor cur) {
        if (element.kind == Field.Kind.LIST) {
            return unpackListItems(element.children.get(0), data, cur);
        }
        if (element.kind == Field.Kind.DICT) {
            return unpackDictItems(element.children.get(0), data, cur);
        }
        if (isLeaf(element)) {
            Map<Object, Object> seen = new HashMap<>();
            Object err = Walker.unpackField(element, data, cur, null, seen, false);
            if (err != null) {
                return new Object[] {null, err};
            }
            return new Object[] {seen.get(element.id), null};
        }
        Map<String, Object> child = new HashMap<>();
        Object err = Walker.unpackFields(Collections.singletonList(element), data, cur, child, new HashMap<>(), false);
        return new Object[] {child, err};
    }
}

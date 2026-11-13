package packbin;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class Containers {
    private Containers() {}

    static void packList(Field field, Object itemsRaw, ByteSink sink) {
        if (!(itemsRaw instanceof List<?> items)) {
            throw new IllegalArgumentException("list: expected list");
        }
        if (items.size() > VarFields.MAX_U16) {
            throw new IllegalArgumentException("list: length " + items.size());
        }
        sink.writeCount(field, items.size());
        Field child = field.children.get(0);
        int index = 0;
        for (Object item : items) {
            if (item == null && isNestedRow(child)) {
                throw new IllegalArgumentException("missing list element " + index);
            }
            packElement(child, item, sink);
            index++;
        }
    }

    static Object unpackList(Field field, byte[] data, Cursor cur, Object row, boolean asList) {
        Object[] got = unpackListItems(field.children.get(0), data, cur);
        if (got[1] != null) {
            return got[1];
        }
        Walker.storeContainer(row, field, got[0], asList);
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
        List<EncodedKey> keys = new ArrayList<>(items.size());
        for (Object key : items.keySet()) {
            if (!(key instanceof String text)) {
                throw new IllegalArgumentException("dict: expected string key");
            }
            keys.add(new EncodedKey(text, VarFields.utf8Bytes(text)));
        }
        keys.sort((a, b) -> compareUnsigned(a.bytes, b.bytes));
        // An unpaired surrogate is written as U+FFFD, so two keys that differ only in such halves are one key on the
        // wire, and unpack refuses a repeated key: refuse them here, so the packet is never one the reader cannot read.
        for (int i = 1; i < keys.size(); i++) {
            if (compareUnsigned(keys.get(i - 1).bytes, keys.get(i).bytes) == 0) {
                throw new IllegalArgumentException(
                        "dict: two keys are the same once an unpaired surrogate is written as U+FFFD");
            }
        }
        sink.writeCount(field, keys.size());
        Field child = field.children.get(0);
        for (EncodedKey encoded : keys) {
            String key = encoded.text;
            byte[] rawKey = encoded.bytes;
            if (rawKey.length > VarFields.MAX_U16) {
                throw new IllegalArgumentException("dict: key length " + rawKey.length);
            }
            sink.writeText(field, rawKey);
            Object value = items.get(key);
            if (value == null && isNestedRow(child)) {
                throw new IllegalArgumentException("missing dict element \"" + key + "\"");
            }
            packElement(child, value, sink);
        }
    }

    /** A dictionary key and the UTF-8 bytes written for it, encoded once for the sort and the write. */
    private static final class EncodedKey {
        final String text;
        final byte[] bytes;

        EncodedKey(String text, byte[] bytes) {
            this.text = text;
            this.bytes = bytes;
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

    /** Code point order of two valid strings equals their UTF-8 byte order; String.compareTo (UTF-16 units) does not. */
    private static int compareUtf8Order(String a, String b) {
        int i = 0;
        int j = 0;
        while (i < a.length() && j < b.length()) {
            int x = a.codePointAt(i);
            int y = b.codePointAt(j);
            if (x != y) {
                return x < y ? -1 : 1;
            }
            i += Character.charCount(x);
            j += Character.charCount(y);
        }
        return (a.length() - i) - (b.length() - j);
    }

    static Object unpackDict(Field field, byte[] data, Cursor cur, Object row, boolean asList) {
        Object[] got = unpackDictItems(field.children.get(0), data, cur);
        if (got[1] != null) {
            return got[1];
        }
        Walker.storeContainer(row, field, got[0], asList);
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
        String previous = null;
        for (int i = 0; i < count; i++) {
            Object read = TextDecoder.read("", data, cur);
            if (!(read instanceof String key)) {
                return new Object[] {items, read};
            }
            // Keys must ascend strictly by UTF-8 bytes: one compare with the previous key finds a repeat too.
            if (previous != null && compareUtf8Order(previous, key) >= 0) {
                return new Object[] {items, new Packbin.ShortPacket("", 0, 0)};
            }
            previous = key;
            Object[] got = unpackElement(element, data, cur);
            if (got[1] != null) {
                return new Object[] {items, got[1]};
            }
            items.put(key, got[0]);
        }
        return new Object[] {items, null};
    }

    private static boolean isNestedRow(Field element) {
        return element.kind == Field.Kind.GROUP && element.nestedRow;
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
        Object child = Walker.newRow(element);
        Object err = Walker.unpackFields(Collections.singletonList(element), data, cur, child, new HashMap<>(), false);
        return new Object[] {child, err};
    }
}

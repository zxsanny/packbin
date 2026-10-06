package packbin;

import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

final class VarFields {
    static final int MAX_U16 = 65535;

    private VarFields() {}

    /**
     * The count a field borrows from an earlier field, or -1 when the packet gave none (clear flag bit)
     * or a negative one. A u64 above Long.MAX_VALUE reads negative and lands here too. The value stays a
     * long until it has been compared with the bytes left.
     */
    private static long unpackCount(Field field, Map<Object, Object> seen) {
        Object raw = seen.get(field.countId);
        if (!(raw instanceof Number) || raw instanceof Float || raw instanceof Double) {
            return -1;
        }
        long count = ((Number) raw).longValue();
        if (count < 0) {
            return -1;
        }
        return count + field.bias < 0 ? -1 : count + field.bias;
    }

    /** ShortPacket for a count the packet cannot satisfy; {@code needed} is clamped because the field is an int. */
    private static Packbin.ShortPacket shortCount(Field field, long needed, int left) {
        long reported = needed < 0 ? Integer.MAX_VALUE : Math.min(needed, Integer.MAX_VALUE);
        return new Packbin.ShortPacket(field.label(), (int) reported, left);
    }

    private static long bytesFor(long count, int perByte) {
        return count / perByte + (count % perByte == 0 ? 0 : 1);
    }

    static void packSized(
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Walker.Take take) {
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
            Cursor cur,
            Object row,
            Map<Object, Object> seen,
            boolean asList) {
        long count = unpackCount(field, seen);
        int left = data.length - cur.pos;
        if (count < 0 || count > left) {
            return shortCount(field, count, left);
        }
        byte[] raw = new byte[(int) count];
        System.arraycopy(data, cur.pos, raw, 0, raw.length);
        cur.pos += raw.length;
        seen.put(field.id, raw);
        Walker.store(row, field, raw, asList);
        return null;
    }

    static void packU2(
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Walker.Take take) {
        List<Field> slots = field.children;
        int nbytes = (slots.size() + 3) / 4;
        byte[] raw = new byte[nbytes];
        for (int i = 0; i < slots.size(); i++) {
            Field slot = slots.get(i);
            Object value = take != null ? take.apply(slot) : slot.get.get(row);
            seen.put(slot.id, value);
            int n = requireU2(slot.label(), value);
            raw[i / 4] |= (byte) (n << ((i % 4) * 2));
        }
        sink.write(raw);
    }

    static Object unpackU2(
            Field field,
            byte[] data,
            Cursor cur,
            Object row,
            Map<Object, Object> seen,
            boolean asList) {
        List<Field> slots = field.children;
        int nbytes = (slots.size() + 3) / 4;
        int left = data.length - cur.pos;
        if (left < nbytes) {
            return new Packbin.ShortPacket(slots.get(0).label(), nbytes, left);
        }
        for (int i = 0; i < slots.size(); i++) {
            int value = (data[cur.pos + i / 4] >> ((i % 4) * 2)) & 3;
            Field slot = slots.get(i);
            seen.put(slot.id, value);
            Walker.store(row, slot, value, asList);
        }
        cur.pos += nbytes;
        return null;
    }

    static void packBits(
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Walker.Take take) {
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
            Cursor cur,
            Object row,
            Map<Object, Object> seen,
            boolean asList) {
        long wanted = unpackCount(field, seen);
        long nbytes = bytesFor(wanted, 8);
        int left = data.length - cur.pos;
        if (wanted < 0 || wanted > Integer.MAX_VALUE || nbytes > left) {
            return shortCount(field, wanted < 0 || wanted > Integer.MAX_VALUE ? wanted : nbytes, left);
        }
        int count = (int) wanted;
        List<Integer> out = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            out.add((data[cur.pos + i / 8] >> (i % 8)) & 1);
        }
        cur.pos += (int) nbytes;
        seen.put(field.id, out);
        Walker.store(row, field, out, asList);
        return null;
    }

    static int borrowedCount(Field field, Map<Object, Object> seen) {
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
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Walker.Take take) {
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
            Cursor cur,
            Object row,
            Map<Object, Object> seen,
            boolean asList) {
        long wanted = unpackCount(field, seen);
        int width = field.size;
        int per = width == 2 ? 4 : 8;
        long nbytes = bytesFor(wanted, per);
        int left = data.length - cur.pos;
        if (wanted < 0 || wanted > Integer.MAX_VALUE || nbytes > left) {
            return shortCount(field, wanted < 0 || wanted > Integer.MAX_VALUE ? wanted : nbytes, left);
        }
        int count = (int) wanted;
        int mask = width == 2 ? 3 : 1;
        int shift = width == 2 ? 2 : 1;
        List<Integer> out = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            out.add((data[cur.pos + i / per] >> ((i % per) * shift)) & mask);
        }
        cur.pos += (int) nbytes;
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
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Walker.Take take) {
        Object value = take != null ? take.apply(field) : field.get.get(row);
        seen.put(field.id, value);
        if (!(value instanceof String text)) {
            throw new IllegalArgumentException(field.id + ": expected string");
        }
        byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
        if (bytes.length > MAX_U16) {
            throw new IllegalArgumentException(field.id + ": utf-8 length " + bytes.length);
        }
        sink.write((byte) bytes.length);
        sink.write((byte) (bytes.length >> 8));
        sink.write(bytes);
    }

    static Object unpackUtf8(
            Field field,
            byte[] data,
            Cursor cur,
            Object row,
            Map<Object, Object> seen,
            boolean asList) {
        int left = data.length - cur.pos;
        if (left < 2) {
            return new Packbin.ShortPacket(field.label(), 2, left);
        }
        int count = (data[cur.pos] & 0xff) | ((data[cur.pos + 1] & 0xff) << 8);
        cur.pos += 2;
        left = data.length - cur.pos;
        if (left < count) {
            return new Packbin.ShortPacket(field.label(), count, left);
        }
        String text = decodeUtf8(data, cur.pos, count);
        if (text == null) {
            return new Packbin.ShortPacket(field.label(), count, 0);
        }
        cur.pos += count;
        seen.put(field.id, text);
        Walker.store(row, field, text, asList);
        return null;
    }

    /** Strict decode: malformed input yields null instead of U+FFFD replacements. */
    static String decodeUtf8(byte[] data, int from, int length) {
        try {
            return StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(data, from, length))
                    .toString();
        } catch (CharacterCodingException ex) {
            return null;
        }
    }

    static void packTimes(
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Walker.Take take) {
        Rounds.packTimes(field, row, sink, seen, borrowedCount(field, seen), take);
    }

    static Object unpackTimes(
            Field field, byte[] data, Cursor cur, Object row, Map<Object, Object> seen, boolean nested) {
        long count = unpackCount(field, seen);
        if (count < 0) {
            return shortCount(field, count, data.length - cur.pos);
        }
        return Rounds.unpackTimes(field, count, data, cur, row, seen, nested);
    }
}

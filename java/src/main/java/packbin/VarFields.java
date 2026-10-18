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
        int count = borrowedCount(field, seen, Integer.MAX_VALUE);
        Object raw = take != null ? take.apply(field) : field.get.get(row);
        seen.put(field.id, raw);
        if (!(raw instanceof byte[] bytes)) {
            throw new IllegalArgumentException(field.id + ": expected bytes");
        }
        if (bytes.length != count) {
            throw new IllegalArgumentException(
                    field.id + ": expected " + count + " bytes, got " + bytes.length);
        }
        sink.write(field, bytes);
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
        sink.write(field, raw);
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
        int count = borrowedCount(field, seen, Integer.MAX_VALUE);
        Object raw = take != null ? take.apply(field) : field.get.get(row);
        seen.put(field.id, raw);
        if (!(raw instanceof List<?> bits) || bits.size() != count) {
            throw new IllegalArgumentException(field.id + ": expected " + count + " bits");
        }
        byte[] packed = new byte[(int) bytesFor(count, 8)];
        for (int i = 0; i < count; i++) {
            int bit = requireBit(field.label(), bits.get(i));
            packed[i / 8] |= (byte) (bit << (i % 8));
        }
        sink.write(field, packed);
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

    /** The count a field borrows plus its bias, as a long so a u32 or u64 count is never cut to an int. */
    static long borrowedLong(Field field, Map<Object, Object> seen) {
        Object countRaw = seen.get(field.countId);
        if (!(countRaw instanceof Number) || countRaw instanceof Float || countRaw instanceof Double) {
            throw new IllegalStateException(field.label() + ": count " + field.countId + " is missing");
        }
        long raw = ((Number) countRaw).longValue();
        long count = field.bias > 0 && raw > Long.MAX_VALUE - field.bias ? Long.MAX_VALUE : raw + field.bias;
        if (count < 0) {
            throw new IllegalArgumentException(field.label() + ": item count " + count);
        }
        return count;
    }

    /** The borrowed count as an int, refused above {@code limit} before any cast. */
    static int borrowedCount(Field field, Map<Object, Object> seen, long limit) {
        long count = borrowedLong(field, seen);
        if (count > limit) {
            throw new IllegalArgumentException(
                    field.label() + ": count " + count + " is above the limit of " + limit + " items");
        }
        return (int) count;
    }

    static int packedBytes(int width, int count) {
        return (int) (((long) count * width + 7) / 8);
    }

    static void packPacked(
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Walker.Take take) {
        int count = borrowedCount(field, seen, Integer.MAX_VALUE);
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
        sink.write(field, packed);
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
        return wholeInt(name, value, 3, "expected 2-bit int");
    }

    private static int requireBit(String name, Object value) {
        return wholeInt(name, value, 1, "expected 0 or 1");
    }

    private static int requirePacked(String name, Object value, int max) {
        return wholeInt(name, value, max, "expected 0.." + max);
    }

    /**
     * A whole number from 0 to {@code max}, as written; a fraction, a number that does not fit a long (it would
     * be cut to an int), a Boolean, a Float or Double and anything but a number are refused with {@code expected}.
     */
    private static int wholeInt(String name, Object value, int max, String expected) {
        long n;
        try {
            n = Scalars.exactLong(name, value);
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException(name + ": " + expected, ex);
        }
        if (n < 0 || n > max) {
            throw new IllegalArgumentException(name + ": " + expected);
        }
        return (int) n;
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
        sink.writeText(field, bytes);
    }

    static Object unpackUtf8(
            Field field,
            byte[] data,
            Cursor cur,
            Object row,
            Map<Object, Object> seen,
            boolean asList) {
        Object text = TextDecoder.read(field.label(), data, cur);
        if (!(text instanceof String)) {
            return text;
        }
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

    /**
     * Whether a times that is a flags member writes: its count is above 0. A count the row skipped is no round (unpack
     * would not read the field either). A count of 0 refuses the entries the row holds, as a times outside flags does.
     */
    static boolean timesOn(Field field, Object row, Walker.Take take, Map<Object, Object> seen) {
        Object countRaw = seen.get(field.countId);
        if (!(countRaw instanceof Number) || countRaw instanceof Float || countRaw instanceof Double) {
            return false;
        }
        long count = borrowedLong(field, seen);
        if (count == 0) {
            Rounds.requireEntriesFit(field, row, 0, take);
            Rounds.requireNoLone(field, row, take);
        }
        return count > 0;
    }

    static void packTimes(
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Walker.Take take) {
        Rounds.packTimes(field, row, sink, seen, borrowedLong(field, seen), take);
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

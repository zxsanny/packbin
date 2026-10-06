package packbin;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * Repeat and times rounds, as C++ per-round items ({@code unpack_items}). A round packs item {@code i} of every
 * body field's list and sees no value of an earlier round ({@code clear_scope}). Unpack keeps one list entry per
 * round for every value field of the body, null where the round skipped it, so packing by round index gives the
 * same bytes back.
 */
final class Rounds {
    private Rounds() {}

    static void packRepeat(Field field, Object row, ByteSink sink, Map<Object, Object> seen) {
        List<Field> values = values(field.children);
        int count = 0;
        for (Field value : values) {
            count = Math.max(count, entries(value.get.get(row)));
        }
        pack(field, values, row, sink, seen, count);
    }

    static void packTimes(Field field, Object row, ByteSink sink, Map<Object, Object> seen, int count) {
        pack(field, values(field.children), row, sink, seen, count);
    }

    private static void pack(
            Field field, List<Field> values, Object row, ByteSink sink, Map<Object, Object> seen, int count) {
        for (int i = 0; i < count; i++) {
            clear(values, seen);
            int index = i;
            Walker.Take at = child -> {
                Object v = child.get.get(row);
                if (v instanceof List<?> list) {
                    return index < list.size() ? list.get(index) : null;
                }
                return v;
            };
            Walker.packFields(field.children, row, sink, seen, at);
        }
    }

    static Object unpackRepeat(Field field, byte[] data, Cursor cur, Object row, Map<Object, Object> seen) {
        List<Field> values = values(field.children);
        long started = 0;
        while (cur.pos < data.length) {
            if (!cur.startRound(started++, values.size())) {
                return refused(field, data, cur);
            }
            int before = cur.pos;
            Object err = unpackRound(field, values, data, cur, row, seen);
            if (err != null) {
                return err;
            }
            if (cur.pos == before) {
                // A round that reads nothing would read nothing forever; the bytes left are not part of the packet.
                return new Packbin.TrailingBytes(data.length - cur.pos);
            }
        }
        return null;
    }

    static Object unpackTimes(
            Field field, long count, byte[] data, Cursor cur, Object row, Map<Object, Object> seen) {
        List<Field> values = values(field.children);
        for (long i = 0; i < count; i++) {
            if (!cur.startRound(i, values.size())) {
                return refused(field, data, cur);
            }
            int before = cur.pos;
            Object err = unpackRound(field, values, data, cur, row, seen);
            if (err != null) {
                return err;
            }
            if (cur.pos == before) {
                // An empty round repeats the same nothing for the rest of a count the packet controls.
                return new Packbin.ShortPacket(field.label(), 0, data.length - before);
            }
        }
        return null;
    }

    /** A round past the limits of the scheme; the interim error, like the empty `times` round. */
    private static Object refused(Field field, byte[] data, Cursor cur) {
        return new Packbin.ShortPacket(field.label(), 0, data.length - cur.pos);
    }

    /**
     * Reads one round, then adds one null entry to every value field the round skipped. It compares each field's
     * entries before and after the round, so a setter that keeps nothing costs one store per round, not one per
     * earlier round.
     */
    private static Object unpackRound(
            Field field, List<Field> values, byte[] data, Cursor cur, Object row, Map<Object, Object> seen) {
        clear(values, seen);
        int[] before = new int[values.size()];
        for (int i = 0; i < before.length; i++) {
            before[i] = entries(values.get(i).get.get(row));
        }
        Object err = Walker.unpackFields(field.children, data, cur, row, seen, true);
        if (err != null) {
            return err;
        }
        for (int i = 0; i < before.length; i++) {
            Field value = values.get(i);
            if (entries(value.get.get(row)) == before[i]) {
                Walker.store(row, value, null, true);
            }
        }
        return null;
    }

    private static void clear(List<Field> values, Map<Object, Object> seen) {
        for (Field value : values) {
            seen.remove(value.id);
        }
    }

    private static int entries(Object value) {
        if (value == null) {
            return 0;
        }
        return value instanceof List<?> list ? list.size() : 1;
    }

    /**
     * The fields a round reads into its own entries: value fields, lists, dicts and nested rows, looking through
     * flags, flag bits, when and anchored groups. SchemeOrder refuses a repeat or times inside a round.
     */
    private static List<Field> values(List<Field> body) {
        List<Field> out = new ArrayList<>();
        collect(body, out);
        return out;
    }

    private static void collect(List<Field> body, List<Field> out) {
        for (Field field : body) {
            switch (field.kind) {
                case FLAGS, WHEN, U2 -> collect(field.children, out);
                case FLAG_BIT -> collect(Collections.singletonList(field.inner), out);
                case GROUP -> {
                    if (field.nestedRow) {
                        out.add(field);
                    } else {
                        collect(field.children, out);
                    }
                }
                case FLAG_BYTE, REPEAT, TIMES -> {}
                default -> out.add(field);
            }
        }
    }
}

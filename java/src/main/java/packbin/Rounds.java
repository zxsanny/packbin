package packbin;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Repeat and times rounds, as C++ per-round items ({@code unpack_items}). A round packs item {@code i} of every
 * body field's list and sees no value of an earlier round ({@code clear_scope}). Unpack keeps one list entry per
 * round for every value field of the body, null where the round skipped it, so packing by round index gives the
 * same bytes back. A repeat or times inside a round is a group of its own: its value fields hold one list per
 * outer round ({@code v: [[5], [7]]}, null where the outer round skipped the group), each list holding that
 * round's inner entries, as C++ keeps one inner array per outer item.
 */
final class Rounds {
    private Rounds() {}

    /**
     * {@code outer} is the enclosing round's item lookup, null at the top level. A repeat reads to the end of the
     * packet, so one that a second round of an enclosing round would write is refused: a reader would take that
     * round's bytes as more rounds of the first. {@code seen} keeps the repeats this pack call has written, by
     * field, as it keeps flag bytes by group.
     */
    static void packRepeat(
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, Walker.Take outer) {
        if (seen.put(field, Boolean.TRUE) != null) {
            throw new IllegalArgumentException(
                    field.label() + ": a repeat has no end marker, so it can be written in one round only");
        }
        List<Field> values = values(field.children);
        int count = 0;
        for (Field value : values) {
            count = Math.max(count, entries(read(value, row, outer)));
        }
        pack(field, values, row, sink, seen, count, outer);
    }

    static void packTimes(
            Field field, Object row, ByteSink sink, Map<Object, Object> seen, int count, Walker.Take outer) {
        List<Field> values = values(field.children);
        for (Field value : values) {
            Object list = read(value, row, outer);
            if (list instanceof List<?> items && items.size() > count) {
                throw new IllegalArgumentException(
                        member(value) + ": list has " + items.size() + " entries for a count of " + count);
            }
        }
        pack(field, values, row, sink, seen, count, outer);
    }

    private static void pack(
            Field field,
            List<Field> values,
            Object row,
            ByteSink sink,
            Map<Object, Object> seen,
            int count,
            Walker.Take outer) {
        for (int i = 0; i < count; i++) {
            clear(values, seen);
            int index = i;
            Walker.Take at = child -> item(read(child, row, outer), index);
            Walker.packFields(field.children, row, sink, seen, at);
        }
    }

    /** Fields carry no names: a member with a field id is named by it, a nested row, list or dict by its kind. */
    private static String member(Field value) {
        return value.id >= 0 ? value.label() : value.kind.name().toLowerCase(Locale.ROOT);
    }

    private static Object read(Field value, Object row, Walker.Take outer) {
        return outer != null ? outer.apply(value) : value.get.get(row);
    }

    /** Entry {@code index} of a list, null past its end; a lone value is the item of every round. */
    private static Object item(Object value, int index) {
        if (value instanceof List<?> list) {
            return index < list.size() ? list.get(index) : null;
        }
        return value;
    }

    /** {@code nested} is true inside another round: the entries of every round fold into one entry per outer round. */
    static Object unpackRepeat(
            Field field, byte[] data, Cursor cur, Object row, Map<Object, Object> seen, boolean nested) {
        List<Field> values = values(field.children);
        int[] before = nested ? entryCounts(values, row) : null;
        long started = 0;
        while (cur.pos < data.length) {
            if (!cur.startRound(started++, values.size())) {
                return refused(field, data, cur);
            }
            int round = cur.pos;
            Object err = unpackRound(field, values, data, cur, row, seen);
            if (err != null) {
                return err;
            }
            if (cur.pos == round) {
                // A round that reads nothing would read nothing forever; the bytes left are not part of the packet.
                return new Packbin.TrailingBytes(data.length - cur.pos);
            }
        }
        foldIntoOuterRound(values, before, row);
        return null;
    }

    static Object unpackTimes(
            Field field, long count, byte[] data, Cursor cur, Object row, Map<Object, Object> seen, boolean nested) {
        List<Field> values = values(field.children);
        int[] before = nested ? entryCounts(values, row) : null;
        for (long i = 0; i < count; i++) {
            if (!cur.startRound(i, values.size())) {
                return refused(field, data, cur);
            }
            int round = cur.pos;
            Object err = unpackRound(field, values, data, cur, row, seen);
            if (err != null) {
                return err;
            }
            if (cur.pos == round) {
                // An empty round repeats the same nothing for the rest of a count the packet controls.
                return new Packbin.ShortPacket(field.label(), 0, data.length - round);
            }
        }
        foldIntoOuterRound(values, before, row);
        return null;
    }

    private static int[] entryCounts(List<Field> values, Object row) {
        int[] counts = new int[values.size()];
        for (int i = 0; i < counts.length; i++) {
            counts[i] = entries(values.get(i).get.get(row));
        }
        return counts;
    }

    /**
     * The inner rounds just read added their entries to the lists of the outer rounds. Moves the entries after
     * {@code before} out of each list into one list that becomes the single entry of the outer round that holds
     * the group (empty when the group read no round). A null {@code before} is the top level: nothing to fold.
     */
    private static void foldIntoOuterRound(List<Field> values, int[] before, Object row) {
        if (before == null) {
            return;
        }
        for (int i = 0; i < before.length; i++) {
            Field value = values.get(i);
            List<Object> inner = new ArrayList<>();
            if (value.get.get(row) instanceof List<?> list) {
                List<?> added = list.subList(before[i], list.size());
                inner.addAll(added);
                added.clear();
            }
            Walker.store(row, value, inner, true);
        }
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
        int[] before = entryCounts(values, row);
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
     * flags, flag bits, when, anchored groups and an inner repeat or times (whose fields hold one list per round).
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
                case REPEAT, TIMES -> collect(field.children, out);
                case FLAG_BYTE -> {}
                default -> out.add(field);
            }
        }
    }
}

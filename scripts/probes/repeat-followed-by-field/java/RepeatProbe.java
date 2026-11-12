// Probe of AZ-4206: a repeat that is not the last thing a packet reads. It builds each shape of
// ../README.md, packs the values given there and unpacks its own bytes. One line per shape:
// package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
//
// This file is in the default package on purpose, so it reaches only the public API of packbin.
//
// Java writes a scheme two ways and both can express every shape:
//   - a Map row (Scheme<Map>, Access.get("x") / Access.set("x")): the lines on stdout. It is the
//     row TypeScript uses, so the names and values are the ones of the README.
//   - a typed row (a class, Access.get(fn) / Access.set(fn), group(get, set, Child::new, ...)): the same
//     shapes with the suffix "-typed", on stderr.
// A third spelling of shapes b and c, an anchored group as the element (group(0, ...)) instead of a nested
// row (group(identity(), ignore(), ...)), is on stderr too with the suffix "-anchored".
// In every form the rounds of a repeat are one list per name (v = [5, 6]), never rows.
import java.io.PrintStream;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.function.Supplier;
import packbin.Access;
import packbin.BinaryPacker;
import packbin.Field;
import packbin.Getter;
import packbin.Packbin;
import packbin.Scheme;
import packbin.Setter;

@SuppressWarnings({"unchecked", "rawtypes"})
public final class RepeatProbe {
    private RepeatProbe() {}

    public static final class Item {
        public Integer mode;
        public List<Object> v;
    }

    public static final class Nested {
        public List<Object> v;
    }

    /** The typed row of every shape; a member a shape does not use stays null and is not shown. */
    public static final class Top {
        public Integer x;
        public Integer k;
        public List<Object> v;
        public List<Object> w;
        public List<Item> items;
        public Map<String, Item> d;
        public Nested m;
    }

    private static String oneLine(String text) {
        return text.replaceAll("\\s+", " ").trim();
    }

    private static String named(Throwable e) {
        return oneLine(e.getClass().getSimpleName() + ": " + e.getMessage());
    }

    private static String hex(byte[] bytes) {
        StringBuilder out = new StringBuilder();
        for (byte b : bytes) {
            out.append(String.format("%02x", b & 0xff));
        }
        return out.toString();
    }

    private static String quoted(String text) {
        return "\"" + text.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }

    private static Object member(java.lang.reflect.Field field, Object of) {
        try {
            return field.get(of);
        } catch (IllegalAccessException e) {
            throw new IllegalStateException("cannot read " + field, e);
        }
    }

    /** The members of a typed row by name; a null member is one the row does not have. */
    private static Map<String, Object> members(Object row) {
        Map<String, Object> out = new TreeMap<>();
        for (java.lang.reflect.Field field : row.getClass().getFields()) {
            if (!Modifier.isStatic(field.getModifiers()) && member(field, row) != null) {
                out.put(field.getName(), member(field, row));
            }
        }
        return out;
    }

    /** The names that hold the rounds of a repeat, in every shape of this probe. */
    private static final Set<String> ROUNDS = Set.of("v", "w");

    /** The values as they are printed: keys in sorted order, so two rows that hold the same values print the same text. */
    private static String shown(Object value) {
        return shown(value, false);
    }

    /**
     * The text two rows are compared by. A repeat that reads no round gives its names no key in a Map row and leaves
     * the member null in a typed row, where the values given hold an empty list. So for the rounds of a repeat an
     * absent key, null and an empty list are one value here; without this a correct read of zero rounds would never
     * print "same". The values after "differs:" are printed as they came back.
     */
    private static String compared(Object value) {
        return shown(value, true);
    }

    private static boolean noRounds(Object key, Object value) {
        return ROUNDS.contains(String.valueOf(key)) && (value == null || value instanceof List<?> list && list.isEmpty());
    }

    private static String shown(Object value, boolean noRoundsIsAbsent) {
        if (value == null) {
            return "null";
        }
        if (value instanceof Number || value instanceof Boolean) {
            return value.toString();
        }
        if (value instanceof String text) {
            return quoted(text);
        }
        if (value instanceof List<?> list) {
            List<String> items = new ArrayList<>();
            for (Object item : list) {
                items.add(shown(item, noRoundsIsAbsent));
            }
            return "[" + String.join(",", items) + "]";
        }
        Map<?, ?> map = value instanceof Map<?, ?> given ? new TreeMap<>(given) : members(value);
        List<String> entries = new ArrayList<>();
        for (Map.Entry<?, ?> entry : map.entrySet()) {
            if (!noRoundsIsAbsent || !noRounds(entry.getKey(), entry.getValue())) {
                entries.add(quoted(String.valueOf(entry.getKey())) + ":" + shown(entry.getValue(), noRoundsIsAbsent));
            }
        }
        return "{" + String.join(",", entries) + "}";
    }

    /** An error value has public fields and no toString: its class and its fields, as the JVM lists them (HotSpot: as declared). */
    private static String error(Object value) {
        if (value == null) {
            return "null";
        }
        List<String> fields = new ArrayList<>();
        for (java.lang.reflect.Field field : value.getClass().getFields()) {
            if (!Modifier.isStatic(field.getModifiers())) {
                Object held = member(field, value);
                fields.add(field.getName() + "=" + (held instanceof String text ? quoted(text) : String.valueOf(held)));
            }
        }
        return value.getClass().getSimpleName() + "(" + String.join(", ", fields) + ")";
    }

    private static <T> void probe(PrintStream out, String shape, Supplier<Scheme<T>> build, T values) {
        String start = "java\t" + shape + "\t";
        Scheme<T> scheme;
        try {
            scheme = build.get();
        } catch (Throwable e) {
            out.println(start + "refused: " + named(e) + "\t-\t-");
            return;
        }
        byte[] packed;
        try {
            packed = BinaryPacker.pack(scheme, values);
        } catch (Throwable e) {
            out.println(start + "built\trefused: " + named(e) + "\t-");
            return;
        }
        start += "built\t" + hex(packed) + "\t";
        Object[] got = new Object[1];
        Object result;
        try {
            result = BinaryPacker.unpack(packed, scheme.on(row -> got[0] = row));
        } catch (Throwable e) {
            out.println(start + "threw: " + named(e));
            return;
        }
        out.println(start + unpacked(result, got[0], values));
    }

    /**
     * The unpack column once unpack returned. The probe's own rendering runs inside the try: a failure of it is
     * printed, and the shapes after this one still run.
     */
    private static String unpacked(Object result, Object got, Object given) {
        try {
            if (result != null || got == null) {
                return "refused: " + oneLine(error(result));
            }
            return compared(got).equals(compared(given)) ? "same" : "differs: " + oneLine(shown(got));
        } catch (Throwable e) {
            return "threw: probe: " + named(e);
        }
    }

    private static Map<String, Object> map(Object... pairs) {
        Map<String, Object> out = new HashMap<>();
        for (int i = 0; i < pairs.length; i += 2) {
            out.put((String) pairs[i], pairs[i + 1]);
        }
        return out;
    }

    // Map rows.

    private static Scheme<Map> scheme(Field... fields) {
        return new Scheme<>(1, (Class) Map.class, fields);
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    /** The row (u8 mode, repeat(u8 v)) of shapes b and c as a nested row: each element is a Map of its own. */
    private static Field elementRow() {
        return Packbin.group(Access.identity(), Access.ignore(), u8(0, "mode"), Packbin.repeat(1, u8(1, "v")));
    }

    /** The same row as an anchored group: the members are read from the element itself, also a Map. */
    private static Field anchoredElement() {
        return Packbin.group(0, u8(0, "mode"), Packbin.repeat(1, u8(1, "v")));
    }

    private static List<Object> twoItems() {
        return List.of(map("mode", 1, "v", List.of(5)), map("mode", 2, "v", List.of()));
    }

    private static Map<String, Object> twoEntries() {
        return map("a", map("mode", 1, "v", List.of(5)), "b", map("mode", 2, "v", List.of()));
    }

    private static void mapRows(PrintStream out) {
        // control: the repeat is the last thing read.
        probe(out, "control", () -> scheme(u8(0, "x"), Packbin.repeat(1, u8(1, "v"))), map("x", 9, "v", List.of(5, 6)));

        // a: a field after a repeat, top level.
        probe(out, "a", () -> scheme(Packbin.repeat(0, u8(0, "v")), u8(1, "x")), map("v", List.of(5, 6), "x", 9));

        // b: a repeat inside a list element row, two items.
        probe(out, "b", () -> scheme(Packbin.list(Access.get("items"), Access.set("items"), elementRow())),
                map("items", twoItems()));

        // c: a repeat inside a dict element row, two entries.
        probe(out, "c", () -> scheme(Packbin.dict(Access.get("d"), Access.set("d"), elementRow())),
                map("d", twoEntries()));

        // d: a repeat inside a nested row, then a field. The nested row is a Map under "m" and numbers its fields
        // from 0 itself, so x is field 0 of the top level.
        probe(out, "d", () -> scheme(
                        Packbin.group(Access.get("m"), Access.set("m"), Packbin.repeat(0, u8(0, "v"))), u8(0, "x")),
                map("m", map("v", List.of(5, 6)), "x", 9));

        // e-when: a repeat under a when that is taken, then a field.
        probe(out, "e-when", () -> scheme(
                        u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), Packbin.repeat(1, u8(1, "v"))), u8(2, "x")),
                map("k", 1, "v", List.of(5, 6), "x", 9));

        // e-flags: a repeat under flags, then a field.
        probe(out, "e-flags", () -> scheme(Packbin.flags(0, Packbin.repeat(0, u8(0, "v"))), u8(1, "x")),
                map("v", List.of(5, 6), "x", 9));

        // f: a repeat after a repeat, one round each.
        probe(out, "f", () -> scheme(Packbin.repeat(0, u8(0, "v")), Packbin.repeat(1, u8(1, "w"))),
                map("v", List.of(5), "w", List.of(6)));
    }

    private static void anchoredElements(PrintStream out) {
        probe(out, "b-anchored", () -> scheme(Packbin.list(Access.get("items"), Access.set("items"), anchoredElement())),
                map("items", twoItems()));
        probe(out, "c-anchored", () -> scheme(Packbin.dict(Access.get("d"), Access.set("d"), anchoredElement())),
                map("d", twoEntries()));
    }

    // Typed rows.

    private static Scheme<Top> typed(Field... fields) {
        return new Scheme<>(1, Top.class, fields);
    }

    private static int number(Object value) {
        return ((Number) value).intValue();
    }

    private static Field x(int id) {
        return Packbin.u8(id, Access.get((Top r) -> r.x), Access.set((Top r, Object v) -> r.x = number(v)));
    }

    private static Field k(int id) {
        return Packbin.u8(id, Access.get((Top r) -> r.k), Access.set((Top r, Object v) -> r.k = number(v)));
    }

    /** In a round the member holds the list of what the rounds read. */
    private static Field v(int id) {
        return Packbin.u8(id, Access.get((Top r) -> r.v), Access.set((Top r, Object v) -> r.v = (List<Object>) v));
    }

    private static Field typedElementRow() {
        Field mode = Packbin.u8(0, Access.get((Item i) -> i.mode), Access.set((Item i, Object v) -> i.mode = number(v)));
        Field rounds = Packbin.u8(1, Access.get((Item i) -> i.v), Access.set((Item i, Object v) -> i.v = (List<Object>) v));
        return Packbin.group(Access.identity(), Access.ignore(), Item::new, mode, Packbin.repeat(1, rounds));
    }

    private static Item item(int mode, List<Object> v) {
        Item item = new Item();
        item.mode = mode;
        item.v = v;
        return item;
    }

    private static Top top(Integer x, List<Object> v) {
        Top row = new Top();
        row.x = x;
        row.v = v;
        return row;
    }

    private static void typedRows(PrintStream out) {
        probe(out, "control-typed", () -> typed(x(0), Packbin.repeat(1, v(1))), top(9, List.of(5, 6)));

        probe(out, "a-typed", () -> typed(Packbin.repeat(0, v(0)), x(1)), top(9, List.of(5, 6)));

        Getter items = Access.get((Top r) -> r.items);
        Setter setItems = Access.set((Top r, Object v) -> r.items = (List<Item>) v);
        Top listed = new Top();
        listed.items = List.of(item(1, List.of(5)), item(2, List.of()));
        probe(out, "b-typed", () -> typed(Packbin.list(items, setItems, typedElementRow())), listed);

        Getter entries = Access.get((Top r) -> r.d);
        Setter setEntries = Access.set((Top r, Object v) -> r.d = (Map<String, Item>) v);
        Top mapped = new Top();
        mapped.d = Map.of("a", item(1, List.of(5)), "b", item(2, List.of()));
        probe(out, "c-typed", () -> typed(Packbin.dict(entries, setEntries, typedElementRow())), mapped);

        Field nestedRounds = Packbin.u8(0, Access.get((Nested n) -> n.v), Access.set((Nested n, Object v) -> n.v = (List<Object>) v));
        Top outer = top(9, null);
        outer.m = new Nested();
        outer.m.v = List.of(5, 6);
        probe(out, "d-typed", () -> typed(
                Packbin.group(Access.get((Top r) -> r.m), Access.set((Top r, Object v) -> r.m = (Nested) v), Nested::new,
                        Packbin.repeat(0, nestedRounds)),
                x(0)), outer);

        Top keyed = top(9, List.of(5, 6));
        keyed.k = 1;
        probe(out, "e-when-typed", () -> typed(k(0), Packbin.when(1, Packbin.eq(0, 1), Packbin.repeat(1, v(1))), x(2)), keyed);

        probe(out, "e-flags-typed", () -> typed(Packbin.flags(0, Packbin.repeat(0, v(0))), x(1)), top(9, List.of(5, 6)));

        Field w = Packbin.u8(1, Access.get((Top r) -> r.w), Access.set((Top r, Object v) -> r.w = (List<Object>) v));
        Top twice = top(null, List.of(5));
        twice.w = List.of(6);
        probe(out, "f-typed", () -> typed(Packbin.repeat(0, v(0)), Packbin.repeat(1, w)), twice);
    }

    public static void main(String[] args) {
        mapRows(System.out);
        anchoredElements(System.err);
        typedRows(System.err);
    }
}

// Probe of AZ-4242: a list or dict whose element is a row of required members (no flag byte per element). It
// builds each shape of ../README.md, packs the values given there and unpacks its own bytes. One line per shape:
// package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
//
// This file is in the default package on purpose, so it reaches only the public API of packbin.
//
// Java writes a scheme two ways:
//   - a typed row (a class, Access.get(fn) / Access.set(fn), the element row a nested row with a child factory:
//     group(identity(), ignore(), Comment::new, ...)): the plain shape names. Only typed rows declare a member
//     for a row class, so other-row and nested-other-row are real shapes here.
//   - a Map row (Scheme<Map>, Access.get("x") / Access.set("x"), the element row group(identity(), ignore(), ...),
//     one HashMap per element): the suffix "-map", printed for the shapes whose path differs (the element row is
//     built without a factory, an absent member is a missing key): list-3, dict-2, when, times, null-member, null-item.
// The coll-<type> lines declare the list or dict member of the typed row with another collection type. A setter
// casts what unpack hands it to the member's declared type, as a scheme author writes it.
//
// "refused" is an IllegalArgumentException or IllegalStateException thrown by a packbin class (the package's own
// error), or an error value returned by unpack. "threw" is any other exception (ClassCastException,
// NullPointerException, ...); where it was thrown goes to stderr.
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.function.Supplier;
import packbin.Access;
import packbin.BinaryPacker;
import packbin.Field;
import packbin.Packbin;
import packbin.Scheme;

@SuppressWarnings({"unchecked", "rawtypes"})
public final class ElementRowProbe {
    private ElementRowProbe() {}

    /** The element row of AZ-4199. */
    public static final class Comment {
        public String id;
        public String text;
        public Long authorId;
        public String author;
    }

    /** Another row class with the same members: other-row declares the element's members for it. */
    public static final class Other {
        public String id;
        public String text;
        public Long authorId;
        public String author;
    }

    public static final class Mode {
        public Integer mode;
        public Integer speed;
    }

    public static final class Count {
        public Integer c;
        public List<Object> v;
    }

    /** The typed row of every shape; a member a shape does not use stays null and is not shown. */
    public static final class Top {
        public List<Comment> items;
        public Map<String, Comment> map;
        public ArrayList<Comment> arrayList;
        public LinkedList<Comment> linkedList;
        public Comment[] array;
        public Set<Comment> set;
        public HashMap<String, Comment> hashMap;
        public TreeMap<String, Comment> treeMap;
        public List<Mode> modes;
        public List<Count> counts;
        public Comment nested;
    }

    // Printing and comparing.

    private static String oneLine(String text) {
        return text.replaceAll("\\s+", " ").trim();
    }

    private static String named(Throwable e) {
        return oneLine(e.getClass().getSimpleName() + ": " + e.getMessage());
    }

    /** The package's own error: an IllegalArgumentException or IllegalStateException thrown by a packbin class. */
    private static boolean ownError(Throwable e) {
        StackTraceElement[] trace = e.getStackTrace();
        return (e instanceof IllegalArgumentException || e instanceof IllegalStateException)
                && trace.length > 0
                && trace[0].getClassName().startsWith("packbin.");
    }

    private static String failure(String shape, Throwable e) {
        if (ownError(e)) {
            return "refused: " + named(e);
        }
        StackTraceElement[] trace = e.getStackTrace();
        StringBuilder where = new StringBuilder();
        for (int i = 0; i < Math.min(trace.length, 4); i++) {
            where.append(i == 0 ? "" : " < ").append(trace[i]);
        }
        System.err.println("java " + shape + ": " + named(e) + " at " + where);
        return "threw: " + named(e);
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

    /**
     * Keys in sorted order, so two rows that hold the same values print the same text. With {@code forCompare} the
     * rounds of a times ("v") that are null or an empty list are left out: zero rounds may come back as either, or
     * as no key. Numbers print by value (an Integer 7 and a Long 7 are one value).
     */
    private static String shown(Object value, boolean forCompare) {
        if (value == null) {
            return "null";
        }
        if (value instanceof Number || value instanceof Boolean) {
            return value.toString();
        }
        if (value instanceof String text) {
            return quoted(text);
        }
        if (value instanceof Object[] array) {
            return shown(Arrays.asList(array), forCompare);
        }
        if (value instanceof Collection<?> items) {
            List<String> out = new ArrayList<>();
            for (Object item : items) {
                out.add(shown(item, forCompare));
            }
            return "[" + String.join(",", out) + "]";
        }
        Map<?, ?> map = value instanceof Map<?, ?> given ? new TreeMap<>(given) : members(value);
        List<String> entries = new ArrayList<>();
        for (Map.Entry<?, ?> entry : map.entrySet()) {
            boolean noRounds = "v".equals(String.valueOf(entry.getKey()))
                    && (entry.getValue() == null || entry.getValue() instanceof List<?> l && l.isEmpty());
            if (!(forCompare && noRounds)) {
                entries.add(quoted(String.valueOf(entry.getKey())) + ":" + shown(entry.getValue(), forCompare));
            }
        }
        return "{" + String.join(",", entries) + "}";
    }

    /** An error value has public fields and no toString: its class and its fields. */
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

    private static <T> void probe(String shape, Supplier<Scheme<T>> build, T values) {
        String start = "java\t" + shape + "\t";
        Scheme<T> scheme;
        try {
            scheme = build.get();
        } catch (Throwable e) {
            System.out.println(start + failure(shape, e) + "\t-\t-");
            return;
        }
        byte[] packed;
        try {
            packed = BinaryPacker.pack(scheme, values);
        } catch (Throwable e) {
            System.out.println(start + "built\t" + failure(shape, e) + "\t-");
            return;
        }
        start += "built\t" + hex(packed) + "\t";
        Object[] got = new Object[1];
        Object result;
        try {
            result = BinaryPacker.unpack(packed, scheme.on(row -> got[0] = row));
        } catch (Throwable e) {
            System.out.println(start + failure(shape, e));
            return;
        }
        System.out.println(start + unpacked(result, got[0], values));
    }

    /** The unpack column once unpack returned; a failure of the probe's own rendering is printed, not thrown. */
    private static String unpacked(Object result, Object got, Object given) {
        try {
            if (result != null || got == null) {
                return "refused: " + oneLine(error(result));
            }
            return shown(got, true).equals(shown(given, true)) ? "same" : "differs: " + oneLine(shown(got, false));
        } catch (Throwable e) {
            return "threw: probe: " + named(e);
        }
    }

    private static void na(String shape, String why) {
        System.out.println("java\t" + shape + "\tn/a: " + why + "\t-\t-");
    }

    // Typed rows.

    private static Comment comment(String id, String text, long authorId, String author) {
        Comment c = new Comment();
        c.id = id;
        c.text = text;
        c.authorId = authorId;
        c.author = author;
        return c;
    }

    private static Comment c1() {
        return comment("c1", "hi", 7, "ann");
    }

    private static Comment c2() {
        return comment("c2", "ok", 258, "bo");
    }

    private static Comment c3() {
        return comment("c3", "yes", 1, "cy");
    }

    private static Field[] commentMembers() {
        return new Field[] {
            Packbin.utf8(0, Access.get((Comment c) -> c.id), Access.set((Comment c, Object v) -> c.id = (String) v)),
            Packbin.utf8(1, Access.get((Comment c) -> c.text), Access.set((Comment c, Object v) -> c.text = (String) v)),
            Packbin.u32(2, Access.get((Comment c) -> c.authorId),
                    Access.set((Comment c, Object v) -> c.authorId = (Long) v)),
            Packbin.utf8(3, Access.get((Comment c) -> c.author),
                    Access.set((Comment c, Object v) -> c.author = (String) v)),
        };
    }

    /** The members of Comment declared for the row class Other. */
    private static Field[] otherMembers() {
        return new Field[] {
            Packbin.utf8(0, Access.get((Other o) -> o.id), Access.set((Other o, Object v) -> o.id = (String) v)),
            Packbin.utf8(1, Access.get((Other o) -> o.text), Access.set((Other o, Object v) -> o.text = (String) v)),
            Packbin.u32(2, Access.get((Other o) -> o.authorId), Access.set((Other o, Object v) -> o.authorId = (Long) v)),
            Packbin.utf8(3, Access.get((Other o) -> o.author), Access.set((Other o, Object v) -> o.author = (String) v)),
        };
    }

    /** The element row: a nested row onto the element itself, with a factory for unpack. */
    private static Field commentRow(Field... members) {
        return Packbin.group(Access.identity(), Access.ignore(), Comment::new, members);
    }

    private static Scheme<Top> typed(Field... fields) {
        return new Scheme<>(1, Top.class, fields);
    }

    private static Scheme<Top> listed() {
        return typed(Packbin.list(Access.get((Top t) -> t.items), Access.set((Top t, Object v) -> t.items = (List<Comment>) v),
                commentRow(commentMembers())));
    }

    private static Scheme<Top> keyed() {
        return typed(Packbin.dict(Access.get((Top t) -> t.map),
                Access.set((Top t, Object v) -> t.map = (Map<String, Comment>) v), commentRow(commentMembers())));
    }

    private static Top items(Comment... comments) {
        Top top = new Top();
        top.items = Arrays.asList(comments);
        return top;
    }

    private static <M extends Map<String, Comment>> M twoEntries(M map) {
        map.put("b", c2());
        map.put("a", c1());
        return map;
    }

    private static void typedRows() {
        probe("list-0", ElementRowProbe::listed, items());
        probe("list-1", ElementRowProbe::listed, items(c1()));
        probe("list-3", ElementRowProbe::listed, items(c1(), c2(), c3()));
        Top dict = new Top();
        dict.map = twoEntries(new LinkedHashMap<>());
        probe("dict-2", ElementRowProbe::keyed, dict);

        // A list field packs any java.util.List and a dict field any java.util.Map (Containers.packList/packDict);
        // unpack hands the setter an ArrayList and a LinkedHashMap.
        Top arrayList = new Top();
        arrayList.arrayList = new ArrayList<>(List.of(c1(), c2(), c3()));
        probe("coll-arraylist", () -> typed(Packbin.list(Access.get((Top t) -> t.arrayList),
                Access.set((Top t, Object v) -> t.arrayList = (ArrayList<Comment>) v), commentRow(commentMembers()))),
                arrayList);
        Top linkedList = new Top();
        linkedList.linkedList = new LinkedList<>(List.of(c1(), c2(), c3()));
        probe("coll-linkedlist", () -> typed(Packbin.list(Access.get((Top t) -> t.linkedList),
                Access.set((Top t, Object v) -> t.linkedList = (LinkedList<Comment>) v), commentRow(commentMembers()))),
                linkedList);
        Top array = new Top();
        array.array = new Comment[] {c1(), c2(), c3()};
        probe("coll-array", () -> typed(Packbin.list(Access.get((Top t) -> t.array),
                Access.set((Top t, Object v) -> t.array = (Comment[]) v), commentRow(commentMembers()))), array);
        Top set = new Top();
        set.set = new LinkedHashSet<>(List.of(c1(), c2(), c3()));
        probe("coll-set", () -> typed(Packbin.list(Access.get((Top t) -> t.set),
                Access.set((Top t, Object v) -> t.set = (Set<Comment>) v), commentRow(commentMembers()))), set);
        Top hashMap = new Top();
        hashMap.hashMap = twoEntries(new HashMap<>());
        probe("coll-hashmap", () -> typed(Packbin.dict(Access.get((Top t) -> t.hashMap),
                Access.set((Top t, Object v) -> t.hashMap = (HashMap<String, Comment>) v), commentRow(commentMembers()))),
                hashMap);
        Top treeMap = new Top();
        treeMap.treeMap = twoEntries(new TreeMap<>());
        probe("coll-treemap", () -> typed(Packbin.dict(Access.get((Top t) -> t.treeMap),
                Access.set((Top t, Object v) -> t.treeMap = (TreeMap<String, Comment>) v), commentRow(commentMembers()))),
                treeMap);

        // when inside an element row: speed is written only for mode 1.
        Mode fast = new Mode();
        fast.mode = 1;
        fast.speed = 7;
        Mode still = new Mode();
        still.mode = 0;
        Top modes = new Top();
        modes.modes = List.of(fast, still);
        probe("when", () -> typed(Packbin.list(Access.get((Top t) -> t.modes),
                Access.set((Top t, Object v) -> t.modes = (List<Mode>) v),
                Packbin.group(Access.identity(), Access.ignore(), Mode::new,
                        Packbin.u8(0, Access.get((Mode m) -> m.mode),
                                Access.set((Mode m, Object v) -> m.mode = ((Number) v).intValue())),
                        Packbin.when(1, Packbin.eq(0, 1), Packbin.u8(1, Access.get((Mode m) -> m.speed),
                                Access.set((Mode m, Object v) -> m.speed = ((Number) v).intValue())))))),
                modes);

        // times inside an element row: c rounds of v; the rounds of v are one list.
        Count two = new Count();
        two.c = 2;
        two.v = List.of(5, 6);
        Count none = new Count();
        none.c = 0;
        none.v = List.of();
        Top counts = new Top();
        counts.counts = List.of(two, none);
        probe("times", () -> typed(Packbin.list(Access.get((Top t) -> t.counts),
                Access.set((Top t, Object v) -> t.counts = (List<Count>) v),
                Packbin.group(Access.identity(), Access.ignore(), Count::new,
                        Packbin.u8(0, Access.get((Count k) -> k.c),
                                Access.set((Count k, Object v) -> k.c = ((Number) v).intValue())),
                        Packbin.times(1, 0, Packbin.u8(1, Access.get((Count k) -> k.v),
                                Access.set((Count k, Object v) -> k.v = (List<Object>) v)))))),
                counts);

        // other-row: the element row of List<Comment> with its members declared for Other.
        probe("other-row", () -> typed(Packbin.list(Access.get((Top t) -> t.items),
                Access.set((Top t, Object v) -> t.items = (List<Comment>) v), commentRow(otherMembers()))), items(c1()));

        // nested-other-row: a nested row (no anchor) for the member Comment nested, its members declared for Other.
        Top nested = new Top();
        nested.nested = c1();
        probe("nested-other-row", () -> typed(Packbin.group(Access.get((Top t) -> t.nested),
                Access.set((Top t, Object v) -> t.nested = (Comment) v), Comment::new, otherMembers())), nested);

        // A required member left null in an element.
        probe("null-member", ElementRowProbe::listed, items(comment("c1", null, 7, "ann")));

        // A list that holds a null element.
        probe("null-item", ElementRowProbe::listed, items(c1(), null));
    }

    // Map rows.

    private static Map<String, Object> map(Object... pairs) {
        Map<String, Object> out = new HashMap<>();
        for (int i = 0; i < pairs.length; i += 2) {
            out.put((String) pairs[i], pairs[i + 1]);
        }
        return out;
    }

    private static Scheme<Map> scheme(Field... fields) {
        return new Scheme<>(1, (Class) Map.class, fields);
    }

    private static Field utf8(int id, String name) {
        return Packbin.utf8(id, Access.get(name), Access.set(name));
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static Field mapCommentRow() {
        return Packbin.group(Access.identity(), Access.ignore(),
                utf8(0, "id"), utf8(1, "text"), Packbin.u32(2, Access.get("authorId"), Access.set("authorId")),
                utf8(3, "author"));
    }

    private static Scheme<Map> mapListed() {
        return scheme(Packbin.list(Access.get("items"), Access.set("items"), mapCommentRow()));
    }

    private static Map<String, Object> m1() {
        return map("id", "c1", "text", "hi", "authorId", 7L, "author", "ann");
    }

    private static Map<String, Object> m2() {
        return map("id", "c2", "text", "ok", "authorId", 258L, "author", "bo");
    }

    private static Map<String, Object> m3() {
        return map("id", "c3", "text", "yes", "authorId", 1L, "author", "cy");
    }

    private static void mapRows() {
        probe("list-3-map", ElementRowProbe::mapListed, map("items", List.of(m1(), m2(), m3())));
        Map<String, Object> entries = new LinkedHashMap<>();
        entries.put("b", m2());
        entries.put("a", m1());
        probe("dict-2-map", () -> scheme(Packbin.dict(Access.get("map"), Access.set("map"), mapCommentRow())),
                map("map", entries));
        probe("when-map", () -> scheme(Packbin.list(Access.get("items"), Access.set("items"),
                        Packbin.group(Access.identity(), Access.ignore(), u8(0, "mode"),
                                Packbin.when(1, Packbin.eq(0, 1), u8(1, "speed"))))),
                map("items", List.of(map("mode", 1, "speed", 7), map("mode", 0))));
        probe("times-map", () -> scheme(Packbin.list(Access.get("items"), Access.set("items"),
                        Packbin.group(Access.identity(), Access.ignore(), u8(0, "c"),
                                Packbin.times(1, 0, u8(1, "v"))))),
                map("items", List.of(map("c", 2, "v", List.of(5, 6)), map("c", 0, "v", List.of()))));
        probe("null-member-map", ElementRowProbe::mapListed,
                map("items", List.of(map("id", "c1", "authorId", 7L, "author", "ann"))));
        probe("null-item-map", ElementRowProbe::mapListed, map("items", Arrays.asList(m1(), null)));
    }

    public static void main(String[] args) {
        typedRows();
        mapRows();
    }
}

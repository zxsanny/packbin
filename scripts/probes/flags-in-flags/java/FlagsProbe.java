// Probe of AZ-4251: a `flags` that is a direct member of a `flags`. It builds scheme S of ../README.md,
// packs each shape's values and unpacks its own bytes. One line per shape: package, shape, build, pack,
// unpack (tab separated). It asserts nothing: it prints what happens.
//
// This file is in the default package on purpose, so it reaches only the public API of packbin.
//
// Java writes a scheme two ways:
//   - a Map row (Scheme<Map>, Access.get("x") / Access.set("x")): the lines on stdout. A shape leaves a value out
//     by leaving its key out.
//   - a typed row (a class with Integer x and Boolean b, Access.get(fn) / Access.set(fn)): the same shapes with
//     the suffix "-typed", on stdout when its build, pack or unpack cell differs from the Map line of the shape,
//     else on stderr.
// Ids: both flags and x are 0, b is 1.
import java.io.PrintStream;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.function.Supplier;
import packbin.Access;
import packbin.BinaryPacker;
import packbin.Field;
import packbin.Packbin;
import packbin.Scheme;

@SuppressWarnings({"unchecked", "rawtypes"})
public final class FlagsProbe {
    private FlagsProbe() {}

    /** The typed row; a member with no value is null. */
    public static final class Row {
        public Integer x;
        public Boolean b;
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

    private static Object member(java.lang.reflect.Field field, Object of) {
        try {
            return field.get(of);
        } catch (IllegalAccessException e) {
            throw new IllegalStateException("cannot read " + field, e);
        }
    }

    /** The members of a row by name, a Map row's keys or a typed row's public fields. */
    private static Map<String, Object> members(Object row) {
        if (row instanceof Map<?, ?> given) {
            Map<String, Object> out = new TreeMap<>();
            given.forEach((k, v) -> out.put(String.valueOf(k), v));
            return out;
        }
        Map<String, Object> out = new TreeMap<>();
        for (java.lang.reflect.Field field : row.getClass().getFields()) {
            if (!Modifier.isStatic(field.getModifiers())) {
                out.put(field.getName(), member(field, row));
            }
        }
        return out;
    }

    /** A row as text: keys in sorted order, so two rows that hold the same values print the same text. */
    private static String shown(Object row) {
        List<String> entries = new ArrayList<>();
        members(row).forEach((k, v) -> entries.add("\"" + k + "\":" + v));
        return "{" + String.join(",", entries) + "}";
    }

    /**
     * The values two rows are compared by: a member with no value (null) is absent, and so is b = false, which
     * leaves the bit clear as an absent b does (README §Bool). Numbers compare by value whatever their class.
     */
    private static String present(Object row) {
        List<String> entries = new ArrayList<>();
        members(row).forEach((k, v) -> {
            if (v != null && !("b".equals(k) && Boolean.FALSE.equals(v))) {
                entries.add(k + "=" + (v instanceof Number n ? Long.toString(n.longValue()) : v.toString()));
            }
        });
        return String.join(",", entries);
    }

    /** An error value has public fields and no toString: its class and its fields, as the JVM lists them. */
    private static String error(Object value) {
        if (value == null) {
            return "null";
        }
        List<String> fields = new ArrayList<>();
        for (java.lang.reflect.Field field : value.getClass().getFields()) {
            if (!Modifier.isStatic(field.getModifiers())) {
                fields.add(field.getName() + "=" + member(field, value));
            }
        }
        return value.getClass().getSimpleName() + "(" + String.join(", ", fields) + ")";
    }

    /** The build, pack and unpack cells of one shape. */
    private static <T> String[] probe(Supplier<Scheme<T>> build, T values) {
        Scheme<T> scheme;
        try {
            scheme = build.get();
        } catch (Throwable e) {
            return new String[] {"refused: " + named(e), "-", "-"};
        }
        byte[] packed;
        try {
            packed = BinaryPacker.pack(scheme, values);
        } catch (Throwable e) {
            return new String[] {"built", "refused: " + named(e), "-"};
        }
        Object[] got = new Object[1];
        Object result;
        try {
            result = BinaryPacker.unpack(packed, scheme.on(row -> got[0] = row));
        } catch (Throwable e) {
            return new String[] {"built", hex(packed), "threw: " + named(e)};
        }
        return new String[] {"built", hex(packed), unpacked(result, got[0], values)};
    }

    /** The unpack column once unpack returned; a failure of the probe's own rendering is printed. */
    private static String unpacked(Object result, Object got, Object given) {
        try {
            if (result != null || got == null) {
                return "refused: " + oneLine(error(result));
            }
            return present(got).equals(present(given)) ? "same" : "differs: " + oneLine(shown(got));
        } catch (Throwable e) {
            return "threw: probe: " + named(e);
        }
    }

    private static void print(PrintStream out, String shape, String[] cells) {
        out.println("java\t" + shape + "\t" + String.join("\t", cells));
    }

    private static Scheme<Map> mapScheme() {
        Field x = Packbin.u8(0, Access.get("x"), Access.set("x"));
        Field b = Packbin.boolField(1, Access.get("b"), Access.set("b"));
        return new Scheme<>(1, (Class) Map.class, Packbin.flags(0, Packbin.flags(0, x), b));
    }

    private static Scheme<Row> typedScheme() {
        Field x = Packbin.u8(0, Access.get((Row r) -> r.x),
                Access.set((Row r, Object v) -> r.x = v == null ? null : ((Number) v).intValue()));
        Field b = Packbin.boolField(1, Access.get((Row r) -> r.b), Access.set((Row r, Object v) -> r.b = (Boolean) v));
        return new Scheme<>(1, Row.class, Packbin.flags(0, Packbin.flags(0, x), b));
    }

    public static void main(String[] args) {
        String[] shapes = {"both", "x-only", "b-only", "none"};
        Integer[] xs = {9, 9, null, null};
        Boolean[] bs = {true, null, true, null};
        List<String[]> mapCells = new ArrayList<>();
        for (int i = 0; i < shapes.length; i++) {
            Map<String, Object> values = new HashMap<>();
            if (xs[i] != null) {
                values.put("x", xs[i]);
            }
            if (bs[i] != null) {
                values.put("b", bs[i]);
            }
            String[] cells = probe(FlagsProbe::mapScheme, (Map) values);
            print(System.out, shapes[i], cells);
            mapCells.add(cells);
        }
        for (int i = 0; i < shapes.length; i++) {
            Row row = new Row();
            row.x = xs[i];
            row.b = bs[i];
            String[] cells = probe(FlagsProbe::typedScheme, row);
            boolean same = java.util.Arrays.equals(cells, mapCells.get(i));
            print(same ? System.err : System.out, shapes[i] + "-typed", cells);
        }
    }
}

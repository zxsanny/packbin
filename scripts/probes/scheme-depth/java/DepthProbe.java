// Probe of AZ-4291: how deep may a scheme be nested. Usage: DepthProbe <when|group> <depth>.
// Prints one tab-separated line: package, shape-with-depth, build, pack, unpack. It asserts nothing.
//
// Form used for the group shape: the Map row with a nested-row group (Packbin.group(Access.get("m"),
// Access.set("m"), ...), a group without an anchor whose member is a Map under "m"). A typed row would need
// a class per level, which is impractical at depth 50,000. The scheme and the values are built in loops,
// innermost first, so the probe itself never recurses and its own comparison of the result walks in a loop.
//
// The default package and the default thread stack are on purpose: the default behaviour is the finding.
// A package error (IllegalArgumentException, IllegalStateException, or an error value returned by unpack)
// is "refused"; a StackOverflowError or any other exception is "threw".
import java.util.HashMap;
import java.util.Map;
import packbin.Access;
import packbin.BinaryPacker;
import packbin.Field;
import packbin.Packbin;
import packbin.Scheme;

@SuppressWarnings({"unchecked", "rawtypes"})
public final class DepthProbe {
    private DepthProbe() {}

    private static String oneLine(String text) {
        return text.replaceAll("\\s+", " ").trim();
    }

    private static String cut(String text) {
        return text.length() > 120 ? text.substring(0, 120) : text;
    }

    private static boolean own(Throwable e) {
        return e instanceof IllegalArgumentException || e instanceof IllegalStateException;
    }

    private static String failure(Throwable e) {
        if (own(e)) {
            return "refused: " + cut(oneLine(e.getClass().getSimpleName() + ": " + e.getMessage()));
        }
        return "threw: " + e.getClass().getSimpleName();
    }

    private static String hex(byte[] bytes) {
        StringBuilder out = new StringBuilder();
        for (byte b : bytes) {
            out.append(String.format("%02x", b & 0xff));
        }
        String all = out.toString();
        return all.length() > 80 ? all.substring(0, 40) + "...(" + bytes.length + " bytes)" : all;
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static Field whenChain(int depth) {
        Field inner = u8(1, "b");
        for (int i = 0; i < depth; i++) {
            inner = Packbin.when(1, Packbin.eq(0, 1), inner);
        }
        return inner;
    }

    private static Field groupChain(int depth) {
        Field inner = u8(0, "b");
        for (int i = 0; i < depth; i++) {
            inner = Packbin.group(Access.get("m"), Access.set("m"), inner);
        }
        return inner;
    }

    private static Map<String, Object> groupValues(int depth) {
        Map<String, Object> inner = new HashMap<>();
        inner.put("b", 7);
        for (int i = 0; i < depth; i++) {
            Map<String, Object> outer = new HashMap<>();
            outer.put("m", inner);
            inner = outer;
        }
        return inner;
    }

    private static Map<String, Object> whenValues() {
        Map<String, Object> row = new HashMap<>();
        row.put("a", 1);
        row.put("b", 7);
        return row;
    }

    /** Compares the nested maps in a loop; returns null when equal, else what differs. */
    private static String compareGroups(Object got, Object given, int depth) {
        Object a = got;
        Object b = given;
        for (int i = 0; i < depth; i++) {
            if (!(a instanceof Map<?, ?> am) || !(b instanceof Map<?, ?> bm)) {
                return "level " + i + " is not a map";
            }
            if (am.size() != bm.size() || !am.containsKey("m")) {
                return "level " + i + " has keys " + am.keySet();
            }
            a = am.get("m");
            b = bm.get("m");
        }
        if (!(a instanceof Map<?, ?> am) || !(b instanceof Map<?, ?> bm) || am.size() != bm.size()
                || !(am.get("b") instanceof Number x) || !(bm.get("b") instanceof Number y)
                || x.longValue() != y.longValue()) {
            return "innermost is " + a;
        }
        return null;
    }

    private static String compareWhen(Object got, Object given) {
        Map<?, ?> g = (Map<?, ?>) got;
        Map<?, ?> w = (Map<?, ?>) given;
        if (g.size() != w.size()) {
            return String.valueOf(new java.util.TreeMap<>(g));
        }
        for (Map.Entry<?, ?> entry : w.entrySet()) {
            if (!(g.get(entry.getKey()) instanceof Number x) || x.longValue() != ((Number) entry.getValue()).longValue()) {
                return String.valueOf(new java.util.TreeMap<>(g));
            }
        }
        return null;
    }

    public static void main(String[] args) {
        String shape = args[0];
        int depth = Integer.parseInt(args[1]);
        String start = "java\t" + shape + "-" + depth + "\t";

        Scheme<Map> scheme;
        Map<String, Object> values;
        try {
            if (shape.equals("when")) {
                scheme = new Scheme<>(1, (Class) Map.class, u8(0, "a"), whenChain(depth));
                values = whenValues();
            } else {
                scheme = new Scheme<>(1, (Class) Map.class, groupChain(depth));
                values = groupValues(depth);
            }
        } catch (Throwable e) {
            System.out.println(start + failure(e) + "\t-\t-");
            return;
        }
        start += "built\t";

        byte[] packed;
        try {
            packed = BinaryPacker.pack(scheme, values);
        } catch (Throwable e) {
            System.out.println(start + failure(e) + "\t-");
            return;
        }
        start += hex(packed) + "\t";

        Object[] got = new Object[1];
        Object result;
        try {
            result = BinaryPacker.unpack(packed, scheme.on(row -> got[0] = row));
        } catch (Throwable e) {
            System.out.println(start + failure(e));
            return;
        }
        if (result != null || got[0] == null) {
            System.out.println(start + "refused: " + cut(oneLine(String.valueOf(result == null ? "no row" : result.getClass().getSimpleName()))));
            return;
        }
        String diff;
        try {
            diff = shape.equals("when") ? compareWhen(got[0], values) : compareGroups(got[0], values, depth);
        } catch (Throwable e) {
            System.out.println(start + "threw: probe " + e.getClass().getSimpleName());
            return;
        }
        System.out.println(start + (diff == null ? "same" : "differs: " + cut(oneLine(diff))));
    }
}

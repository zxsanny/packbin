package packbin;

import java.util.List;
import java.util.Map;
import java.util.function.IntFunction;

/**
 * Contract scheme-depth (AZ-4298): a scheme nested deeper than 256 levels is refused when it is built, with the
 * scheme error of the package and the contract's text, before any walk that recurses. A scheme of 256 levels builds,
 * packs and unpacks at the default stack of the JVM (no {@code -Xss}). Each chain is written by a loop, innermost
 * first, so the test itself never recurses. The chains here are also the ones HostileLoop126 replays.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class SchemeDepthTest {
    private SchemeDepthTest() {}

    static final String TOO_DEEP = "scheme nested too deep: more than 256 levels; the limit is 256";
    static final int LIMIT = 256;
    private static final long WITHIN_MS = 5_000;

    /** A typed row for the group chain: each level is a Node holding the next one in {@code m}. */
    public static final class Node {
        public Node m;
        public Integer b;
    }

    /**
     * One kind of container nested {@code depth} deep: the scheme, the row to pack, the bytes it packs to and the row
     * unpack gives back (the row itself, except for times: each nested round wraps its values in one more list).
     */
    private record Kind(String name, IntFunction<Scheme> scheme, IntFunction<Object> row, IntFunction<String> hex,
            IntFunction<Object> unpacked) {
        Kind(String name, IntFunction<Scheme> scheme, IntFunction<Object> row, IntFunction<String> hex) {
            this(name, scheme, row, hex, row);
        }
    }

    private static final List<Kind> KINDS = List.of(
            new Kind("when", SchemeDepthTest::whenScheme, d -> Maps.map("a", 1, "b", 7), d -> "010107"),
            new Kind("group (map rows)", SchemeDepthTest::groupScheme, SchemeDepthTest::groupRow, d -> "0107"),
            new Kind("group (typed rows)", SchemeDepthTest::typedGroupScheme, SchemeDepthTest::typedGroupRow,
                    d -> "0107"),
            new Kind("list element", SchemeDepthTest::listScheme, SchemeDepthTest::listRow,
                    d -> "01" + "0100".repeat(d) + "07"),
            new Kind("dict element", SchemeDepthTest::dictScheme, SchemeDepthTest::dictRow,
                    d -> "01" + "010002106b".repeat(d) + "07"),
            new Kind("flags", SchemeDepthTest::flagsScheme, d -> Maps.map("b", 7), d -> "01" + "01".repeat(d) + "07"),
            new Kind("times round", SchemeDepthTest::timesScheme, SchemeDepthTest::timesRow,
                    d -> "01" + "01".repeat(d + 1) + "07", SchemeDepthTest::timesUnpacked));

    static void run() {
        ac2TwoHundredFiftySixLevelsStillWork();
        ac1MoreThanTwoHundredFiftySixIsRefused();
        ac1TheLevelsAreCountedByTheContract();
        ac1ASharedFieldIsNotWalkedOnceForEachPathToIt();
    }

    // The chains. Innermost first, built in a loop.

    /** u8 a (id 0), then {@code depth} nested whens {@code eq(0, 1)}, the innermost holds u8 b (id 1). */
    static Scheme<Map> whenScheme(int depth) {
        Field inner = u8(1, "b");
        for (int i = 0; i < depth; i++) {
            inner = Packbin.when(1, Packbin.eq(0, 1), inner);
        }
        return Maps.scheme(1, u8(0, "a"), inner);
    }

    /** {@code depth} nested groups without an anchor (Map rows), the innermost holds u8 b. */
    static Scheme<Map> groupScheme(int depth) {
        Field inner = u8(0, "b");
        for (int i = 0; i < depth; i++) {
            inner = Packbin.group(Access.get("m"), Access.set("m"), inner);
        }
        return Maps.scheme(1, inner);
    }

    static Map<String, Object> groupRow(int depth) {
        Map<String, Object> row = Maps.map("b", 7);
        for (int i = 0; i < depth; i++) {
            row = Maps.map("m", row);
        }
        return row;
    }

    /** {@code depth} nested groups on a typed row: Node { Node m; Integer b }, a factory for each level. */
    static Scheme<Node> typedGroupScheme(int depth) {
        Field inner = Packbin.u8(0, Access.get((Node n) -> n.b),
                Access.set((Node n, Object v) -> n.b = ((Number) v).intValue()));
        for (int i = 0; i < depth; i++) {
            inner = Packbin.group(Access.get((Node n) -> n.m), Access.set((Node n, Object v) -> n.m = (Node) v),
                    Node::new, inner);
        }
        return new Scheme<>(1, Node.class, inner);
    }

    static Node typedGroupRow(int depth) {
        Node row = new Node();
        row.b = 7;
        for (int i = 0; i < depth; i++) {
            Node outer = new Node();
            outer.m = row;
            row = outer;
        }
        return row;
    }

    /** {@code depth} nested lists, the innermost element is u8; each list holds one element. */
    static Scheme<Map> listScheme(int depth) {
        Field inner = Packbin.u8(0, Access.identity(), Access.ignore());
        for (int i = 1; i < depth; i++) {
            inner = Packbin.list(Access.identity(), Access.ignore(), inner);
        }
        return Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"), inner));
    }

    static Map<String, Object> listRow(int depth) {
        Object row = 7;
        for (int i = 0; i < depth; i++) {
            row = List.of(row);
        }
        return Maps.map("xs", row);
    }

    /** {@code depth} nested dicts, the innermost value is u8; each dict holds the key "k". */
    static Scheme<Map> dictScheme(int depth) {
        Field inner = Packbin.u8(0, Access.identity(), Access.ignore());
        for (int i = 1; i < depth; i++) {
            inner = Packbin.dict(Access.identity(), Access.ignore(), inner);
        }
        return Maps.scheme(1, Packbin.dict(Access.get("m"), Access.set("m"), inner));
    }

    static Map<String, Object> dictRow(int depth) {
        Object row = 7;
        for (int i = 0; i < depth; i++) {
            row = Maps.map("k", row);
        }
        return Maps.map("m", row);
    }

    /** {@code depth} nested flags, the innermost holds u8 b; a flag bit adds no level. */
    static Scheme<Map> flagsScheme(int depth) {
        Field inner = u8(0, "b");
        for (int i = 0; i < depth; i++) {
            inner = Packbin.flags(0, inner);
        }
        return Maps.scheme(1, inner);
    }

    /** u8 c0, then {@code depth} nested times (each round: u8 c_i, the next times), the innermost holds u8 b. */
    static Scheme<Map> timesScheme(int depth) {
        Field inner = u8(depth + 1, "b");
        for (int i = depth; i >= 1; i--) {
            inner = Packbin.times(i, i - 1, u8(i, "c" + i), inner);
        }
        return Maps.scheme(1, u8(0, "c0"), inner);
    }

    static Map<String, Object> timesRow(int depth) {
        Map<String, Object> row = Maps.map("c0", 1, "b", List.of(7));
        for (int i = 1; i <= depth; i++) {
            row.put("c" + i, List.of(1));
        }
        return row;
    }

    /** What unpack gives for the times chain: a value of the round at level i is wrapped in i lists. */
    static Map<String, Object> timesUnpacked(int depth) {
        Map<String, Object> row = Maps.map("c0", 1, "b", wrapped(7, depth));
        for (int i = 1; i <= depth; i++) {
            row.put("c" + i, wrapped(1, i));
        }
        return row;
    }

    private static Object wrapped(Object value, int lists) {
        Object out = value;
        for (int i = 0; i < lists; i++) {
            out = List.of(out);
        }
        return out;
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    // AC-2: 256 levels build, pack the bytes they packed before and unpack to the same value, at the default stack.
    private static void ac2TwoHundredFiftySixLevelsStillWork() {
        for (Kind kind : KINDS) {
            String label = "AC-2 " + kind.name + " at " + LIMIT;
            // Arrange
            Scheme scheme = kind.scheme.apply(LIMIT);
            Object row = kind.row.apply(LIMIT);
            // Act
            byte[] bytes = BinaryPacker.pack(scheme, row);
            Object[] got = new Object[1];
            Object error = BinaryPacker.unpack(bytes, scheme.on(r -> got[0] = r));
            // Assert
            PackbinTest.expectEq(label + " bytes", kind.hex.apply(LIMIT), PackbinTest.toHex(bytes));
            PackbinTest.expectTrue(label + " unpacks (" + error + ")", error == null && got[0] != null);
            if (got[0] instanceof Node node) {
                PackbinTest.expectEq(label + " unpacked row", LIMIT, typedDepth(node));
            } else {
                PackbinTest.expectEq(label + " unpacked row", kind.unpacked.apply(LIMIT), got[0]);
            }
            PackbinTest.expectEq(label + " at 1", kind.hex.apply(1),
                    PackbinTest.toHex(BinaryPacker.pack(kind.scheme.apply(1), kind.row.apply(1))));
        }
    }

    /** Counts the nodes under {@code node} that hold a next node, and checks the innermost b; -1 when b is wrong. */
    private static int typedDepth(Node node) {
        int depth = 0;
        Node cursor = node;
        while (cursor.m != null) {
            cursor = cursor.m;
            depth++;
        }
        return cursor.b != null && cursor.b == 7 ? depth : -1;
    }

    // AC-1: 257, 1,000 and 50,000 levels are refused with the contract's text, quickly, with no stack error.
    private static void ac1MoreThanTwoHundredFiftySixIsRefused() {
        for (Kind kind : KINDS) {
            for (int depth : new int[] {LIMIT + 1, 1_000, 50_000}) {
                String label = "AC-1 " + kind.name + " at " + depth;
                // Arrange: the chain is made by the builders alone; nothing has checked it yet.
                long start = System.nanoTime();
                // Act and Assert
                PackbinTest.expectThrows(label, () -> kind.scheme.apply(depth), TOO_DEEP);
                long ms = (System.nanoTime() - start) / 1_000_000;
                PackbinTest.expectTrue(label + " is refused within " + WITHIN_MS + " ms (" + ms + " ms)", ms < WITHIN_MS);
            }
        }
    }

    // AC-1 (counting, contract 1.0.1): a list or dict counts one level plus its element's own kind; a flag bit none.
    private static void ac1TheLevelsAreCountedByTheContract() {
        // Arrange and Act: 128 times (list of group) is 256 levels; one level more is 257.
        PackbinTest.expectEq("AC-1 128 lists of groups build", 1, listsOfGroups(LIMIT / 2).fields.size());
        PackbinTest.expectThrows("AC-1 128 lists of groups and a list", () -> listsOfGroupsAndAList(LIMIT / 2), TOO_DEEP);
        // A repeat counts one level: 255 whens and a repeat are 256, 256 whens and a repeat are 257.
        PackbinTest.expectEq("AC-1 255 whens and a repeat pack", "01010506",
                PackbinTest.toHex(BinaryPacker.pack(whensOverARepeat(LIMIT - 1), Maps.map("a", 1, "v", List.of(5, 6)))));
        PackbinTest.expectThrows("AC-1 256 whens and a repeat", () -> whensOverARepeat(LIMIT), TOO_DEEP);
        // A flag bit adds none (256 flags in flags build, 257 are refused above), nor does a scalar: 1,000 flat
        // scalars build.
        Field[] flat = new Field[1_000];
        for (int i = 0; i < flat.length; i++) {
            flat[i] = u8(i, "f" + i);
        }
        PackbinTest.expectEq("AC-1 1,000 scalars build", 1_000, Maps.scheme(1, flat).fields.size());
    }

    private static Scheme<Map> listsOfGroups(int pairs) {
        return Maps.scheme(1, listOfGroupsChain(pairs, false));
    }

    private static Scheme<Map> listsOfGroupsAndAList(int pairs) {
        return Maps.scheme(1, listOfGroupsChain(pairs, true));
    }

    /** {@code pairs} times (list holding a group), innermost u8; one more list on top when {@code extra}. */
    private static Field listOfGroupsChain(int pairs, boolean extra) {
        Field inner = u8(0, "b");
        for (int i = 0; i < pairs; i++) {
            inner = Packbin.list(Access.get("xs"), Access.set("xs"),
                    Packbin.group(Access.identity(), Access.ignore(), inner));
        }
        return extra ? Packbin.list(Access.get("top"), Access.set("top"), inner) : inner;
    }

    private static Scheme<Map> whensOverARepeat(int whens) {
        Field inner = Packbin.repeat(1, u8(1, "v"));
        for (int i = 0; i < whens; i++) {
            inner = Packbin.when(1, Packbin.eq(0, 1), inner);
        }
        return Maps.scheme(1, u8(0, "a"), inner);
    }

    // AC-1 (cost): a field that stands under two parents is measured again only when it is reached deeper, so a
    // chain of whens that each hold the next one twice costs the size of the scheme, not 2 to the depth.
    private static void ac1ASharedFieldIsNotWalkedOnceForEachPathToIt() {
        // Arrange
        Field inner = u8(1, "b");
        for (int i = 0; i < 300; i++) {
            inner = Packbin.when(1, Packbin.eq(0, 1), inner, inner);
        }
        Field top = inner;
        // Act and Assert
        long start = System.nanoTime();
        PackbinTest.expectThrows("AC-1 shared fields at 300", () -> Maps.scheme(1, u8(0, "a"), top), TOO_DEEP);
        long ms = (System.nanoTime() - start) / 1_000_000;
        PackbinTest.expectTrue("AC-1 shared fields are refused within " + WITHIN_MS + " ms (" + ms + " ms)",
                ms < WITHIN_MS);
    }
}

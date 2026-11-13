package packbin;

import java.util.ArrayList;
import java.util.List;

/**
 * AZ-4253: a nested row with a child factory (a nested row, or the element row of a list or dict) refuses at
 * construction a member declared for another row class, naming the member and the row class (owner decisions D10
 * and D13). Before, it built and pack threw a raw ClassCastException.
 */
@SuppressWarnings("unchecked")
final class RowClassTest {
    private RowClassTest() {}

    static void run() {
        ac1ElementRowOfAListIsRefused();
        ac1ElementRowOfADictIsRefused();
        ac2NestedRowIsRefused();
        ac3MembersInsideContainersAreRefused();
        ac4BaseClassMembersBuildAndRoundTrip();
        ac5OtherAccessorFailuresStillBuild();
    }

    static class Base {
        public Integer a;
    }

    static final class Row extends Base {
        public Integer b;
        public Integer n;
        public List<Integer> v;
        public String s;
    }

    static final class Other {
        public Integer a;
        public Integer b;
    }

    static final class Top {
        public List<Row> items;
        public Row nested;
    }

    private static final String ROW_U8_0 = "u8 0: declared for another row class; this row is Row";

    private static Field otherB(int id) {
        return Packbin.u8(id, Access.get((Other o) -> o.b), Access.set((Other o, Object v) -> o.b = (Integer) v));
    }

    private static Field rowB(int id) {
        return Packbin.u8(id, Access.get((Row r) -> r.b), Access.set((Row r, Object v) -> r.b = (Integer) v));
    }

    private static Field element(Field... fields) {
        return Packbin.group(Access.identity(), Access.ignore(), Row::new, fields);
    }

    private static Field items(Field element) {
        return Packbin.list(Access.get((Top t) -> t.items),
                Access.set((Top t, Object v) -> t.items = (List<Row>) v), element);
    }

    private static Field nested(Field... fields) {
        return Packbin.group(Access.get((Top t) -> t.nested),
                Access.set((Top t, Object v) -> t.nested = (Row) v), Row::new, fields);
    }

    private static void ac1ElementRowOfAListIsRefused() {
        // Arrange, Act, Assert: the element row is refused where it is built, before the list or the scheme.
        PackbinTest.expectThrows("AZ-4253 AC-1 list element", () -> items(element(otherB(0))), ROW_U8_0);
    }

    private static void ac1ElementRowOfADictIsRefused() {
        PackbinTest.expectThrows("AZ-4253 AC-1 dict element",
                () -> Packbin.dict(Access.get((Top t) -> t.items), Access.ignore(), element(otherB(0))), ROW_U8_0);
    }

    private static void ac2NestedRowIsRefused() {
        PackbinTest.expectThrows("AZ-4253 AC-2 nested row",
                () -> new Scheme<>(1, Top.class, nested(rowB(0), otherB(1))),
                "u8 1: declared for another row class; this row is Row");
    }

    private static void ac3MembersInsideContainersAreRefused() {
        // Arrange: a member of Other under each container that shares the row.
        Field n = Packbin.u8(0, Access.get((Row r) -> r.n), Access.set((Row r, Object v) -> r.n = (Integer) v));
        Field m = Packbin.flagByte();

        // Act, Assert
        PackbinTest.expectThrows("AZ-4253 AC-3 flags", () -> element(Packbin.flags(0, otherB(1))),
                "u8 1: declared for another row class; this row is Row");
        PackbinTest.expectThrows("AZ-4253 AC-3 flag bit", () -> element(m, m.bit(otherB(0))), ROW_U8_0);
        PackbinTest.expectThrows("AZ-4253 AC-3 when",
                () -> element(n, Packbin.when(1, Packbin.eq(0, 1), otherB(2))),
                "u8 2: declared for another row class; this row is Row");
        PackbinTest.expectThrows("AZ-4253 AC-3 anchored group", () -> element(Packbin.group(0, otherB(1))),
                "u8 1: declared for another row class; this row is Row");
        PackbinTest.expectThrows("AZ-4253 AC-3 times", () -> element(n, Packbin.times(1, 0, otherB(2))),
                "u8 2: declared for another row class; this row is Row");
        PackbinTest.expectThrows("AZ-4253 AC-3 nested row member",
                () -> element(Packbin.group(Access.get((Other o) -> o.b), Access.ignore(), Row::new, rowB(0))),
                "group: declared for another row class; this row is Row");
    }

    private static void ac4BaseClassMembersBuildAndRoundTrip() {
        // Arrange: member a declared for Base, b for Row; the same scheme with a declared for Row.
        Field baseA = Packbin.u8(0, Access.get((Base r) -> r.a), Access.set((Base r, Object v) -> r.a = (Integer) v));
        Field rowA = Packbin.u8(0, Access.get((Row r) -> r.a), Access.set((Row r, Object v) -> r.a = (Integer) v));
        Scheme<Top> viaBase = new Scheme<>(1, Top.class, items(element(baseA, rowB(1))));
        Scheme<Top> viaRow = new Scheme<>(1, Top.class, items(element(rowA, rowB(1))));
        Top top = new Top();
        Row row = new Row();
        row.a = 7;
        row.b = 9;
        top.items = new ArrayList<>(List.of(row));

        // Act
        String packed = PackbinTest.toHex(BinaryPacker.pack(viaBase, top));
        Top[] got = new Top[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(packed), viaBase.on(t -> got[0] = t));

        // Assert
        PackbinTest.expectEq("AZ-4253 AC-4 bytes as the Row scheme", PackbinTest.toHex(BinaryPacker.pack(viaRow, top)),
                packed);
        PackbinTest.expectEq("AZ-4253 AC-4 unpack error", null, err);
        PackbinTest.expectEq("AZ-4253 AC-4 read back",
                "7,9", got[0].items.get(0).a + "," + got[0].items.get(0).b);
    }

    private static void ac5OtherAccessorFailuresStillBuild() {
        // Arrange: a getter that throws NullPointerException on a fresh child (s is null until set).
        Field length = Packbin.u8(0, Access.get((Row r) -> r.s.length()), Access.ignore());

        // Act, Assert
        try {
            element(length);
        } catch (RuntimeException ex) {
            PackbinTest.fail("AZ-4253 AC-5: a getter that fails on a fresh child must still build, threw " + ex);
        }
    }
}

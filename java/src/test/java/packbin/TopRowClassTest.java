package packbin;

import java.util.List;

/**
 * AZ-4257 (hygiene entry java-top-level-row-class, owner decision D14): a top-level {@code new Scheme<>(n, Row.class,
 * fields)} refuses at construction a member declared for another row class with the AZ-4253 text, as the nested row and
 * the element row do (RowClassTest). The accessors are called on one row made with the no-argument constructor that
 * unpack uses; where there is no such row the scheme builds as before.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class TopRowClassTest {
    private TopRowClassTest() {}

    static void run() {
        aMemberOfAnotherClassIsRefusedAtBuild();
        membersInsideContainersAreRefusedAtBuild();
        aNestedRowMemberOfAnotherClassIsRefused();
        aBaseClassMemberBuildsAndRoundTrips();
        aRowWithoutAUsableConstructorBuildsAsBefore();
        aPrivateConstructorMakesTheRow();
        theConstructorRunsOnceAtBuild();
        otherAccessorFailuresStillBuild();
    }

    static class Base {
        public Integer a;
    }

    static final class Row extends Base {
        public Integer b;
        public Integer n;
        public Row nested;
    }

    static final class Other {
        public Integer a;
        public Integer b;
        public Other nested;
    }

    static final class Counted {
        static int made;
        public Integer b;

        Counted() {
            made++;
        }
    }

    static final class NoDefault {
        public Integer b;

        NoDefault(int unused) {}
    }

    static final class Throws {
        public Integer b;

        Throws() {
            throw new IllegalStateException("no row");
        }
    }

    static final class Hidden {
        public Integer b;

        private Hidden() {}
    }

    static abstract class Abstract {
        public Integer b;
    }

    private static final String ROW_U8_0 = "u8 0: declared for another row class; this row is Row";
    private static final String ROW_U8_1 = "u8 1: declared for another row class; this row is Row";

    private static Field rowB(int id) {
        return Packbin.u8(id, Access.get((Row r) -> r.b), Access.set((Row r, Object v) -> r.b = (Integer) v));
    }

    private static Field otherB(int id) {
        return Packbin.u8(id, Access.get((Other o) -> o.b), Access.set((Other o, Object v) -> o.b = (Integer) v));
    }

    private static void aMemberOfAnotherClassIsRefusedAtBuild() {
        // Arrange, Act, Assert: member 1 is declared for Other in a scheme of Row.
        PackbinTest.expectThrows("AZ-4257 AC-3 top-level member", () -> new Scheme<>(1, Row.class, rowB(0), otherB(1)),
                ROW_U8_1);
    }

    private static void membersInsideContainersAreRefusedAtBuild() {
        // Arrange
        Field n = Packbin.u8(0, Access.get((Row r) -> r.n), Access.set((Row r, Object v) -> r.n = (Integer) v));
        Field flagByte = Packbin.flagByte();

        // Act, Assert
        PackbinTest.expectThrows("AZ-4257 AC-3 flags", () -> new Scheme<>(1, Row.class, Packbin.flags(0, otherB(0))),
                ROW_U8_0);
        PackbinTest.expectThrows("AZ-4257 AC-3 flag bit",
                () -> new Scheme<>(1, Row.class, flagByte, flagByte.bit(otherB(0))),
                ROW_U8_0);
        PackbinTest.expectThrows("AZ-4257 AC-3 when",
                () -> new Scheme<>(1, Row.class, n, Packbin.when(1, Packbin.eq(0, 1), otherB(1))),
                ROW_U8_1);
        PackbinTest.expectThrows("AZ-4257 AC-3 times",
                () -> new Scheme<>(1, Row.class, n, Packbin.times(1, 0, otherB(1))),
                ROW_U8_1);
        PackbinTest.expectThrows("AZ-4257 AC-3 anchored group",
                () -> new Scheme<>(1, Row.class, Packbin.group(0, otherB(0))),
                ROW_U8_0);
    }

    private static void aNestedRowMemberOfAnotherClassIsRefused() {
        // Arrange: the nested row member itself is declared for Other; its inside is checked by its own factory.
        Field nested = Packbin.group(Access.get((Other o) -> o.nested), Access.set((Other o, Object v) -> o.nested = (Other) v),
                Other::new, otherB(0));

        // Act, Assert
        PackbinTest.expectThrows("AZ-4257 AC-3 nested row member", () -> new Scheme<>(1, Row.class, nested),
                "group: declared for another row class; this row is Row");
    }

    private static void aBaseClassMemberBuildsAndRoundTrips() {
        // Arrange: member a declared for Base, b for Row.
        Field baseA = Packbin.u8(0, Access.get((Base r) -> r.a), Access.set((Base r, Object v) -> r.a = (Integer) v));
        Scheme<Row> scheme = new Scheme<>(1, Row.class, baseA, rowB(1));
        Row row = new Row();
        row.a = 7;
        row.b = 9;
        Row[] got = new Row[1];

        // Act
        byte[] packed = BinaryPacker.pack(scheme, row);
        Object err = BinaryPacker.unpack(packed, scheme.on(r -> got[0] = r));

        // Assert
        PackbinTest.expectEq("AZ-4257 AC-3 base class bytes", "010709", PackbinTest.toHex(packed));
        PackbinTest.expectEq("AZ-4257 AC-3 base class unpack error", null, err);
        PackbinTest.expectEq("AZ-4257 AC-3 base class read back", "7,9", got[0].a + "," + got[0].b);
    }

    /** D14: no row to call the accessors on, so nothing is checked; the member of Other is the same as in AC-3. */
    private static void aRowWithoutAUsableConstructorBuildsAsBefore() {
        // Arrange
        Field a = Packbin.u8(0, Access.get((Other o) -> o.b), Access.set((Other o, Object v) -> o.b = (Integer) v));

        // Act
        String mapRow = built(() -> Maps.scheme(1, a));
        String noDefault = built(() -> new Scheme<>(1, NoDefault.class, a));
        String throwing = built(() -> new Scheme<>(1, Throws.class, a));
        String abstractRow = built(() -> new Scheme<>(1, Abstract.class, a));
        String anInterface = built(() -> new Scheme<>(1, List.class, a));

        // Assert
        PackbinTest.expectEq("AZ-4257 AC-3 a Map row", "built", mapRow);
        PackbinTest.expectEq("AZ-4257 AC-3 a class without a no-argument constructor", "built", noDefault);
        PackbinTest.expectEq("AZ-4257 AC-3 a constructor that throws", "built", throwing);
        PackbinTest.expectEq("AZ-4257 AC-3 an abstract class", "built", abstractRow);
        PackbinTest.expectEq("AZ-4257 AC-3 an interface", "built", anInterface);
    }

    /** Unpack calls the private constructor too (BinaryPacker.newRow), so the check does. */
    private static void aPrivateConstructorMakesTheRow() {
        // Arrange
        Field otherOnHidden = Packbin.u8(0, Access.get((Other o) -> o.b), Access.set((Other o, Object v) -> o.b = (Integer) v));

        // Act, Assert
        PackbinTest.expectThrows("AZ-4257 AC-3 a private constructor", () -> new Scheme<>(1, Hidden.class, otherOnHidden),
                "u8 0: declared for another row class; this row is Hidden");
    }

    private static void theConstructorRunsOnceAtBuild() {
        // Arrange
        Counted.made = 0;
        Field b = Packbin.u8(0, Access.get((Counted c) -> c.b), Access.set((Counted c, Object v) -> c.b = (Integer) v));

        // Act
        Scheme<Counted> scheme = new Scheme<>(1, Counted.class, b);
        scheme.withLimits(4, 100);

        // Assert: one row for the check; the limit variants do not check again.
        PackbinTest.expectEq("AZ-4257 AC-3 constructor runs once at build", 1, Counted.made);
    }

    private static void otherAccessorFailuresStillBuild() {
        // Arrange: a getter that throws NullPointerException on a fresh row (nested is null until set).
        Field deep = Packbin.u8(0, Access.get((Row r) -> r.nested.b), Access.ignore());

        // Act, Assert
        PackbinTest.expectEq("AZ-4257 AC-3 a getter that fails on a fresh row still builds", "built",
                built(() -> new Scheme<>(1, Row.class, deep)));
    }

    private static String built(Runnable build) {
        try {
            build.run();
        } catch (IllegalArgumentException ex) {
            return ex.getMessage();
        }
        return "built";
    }
}

package packbin;

import java.util.Collections;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.IntFunction;
import java.util.function.Supplier;

/**
 * AZ-2246: a member name used twice in one scope is refused when the scheme is built. Only a setter made by
 * {@code Access.set(String)} carries a name; a typed accessor and a hand-written lambda do not, so a repeat there
 * builds as before. {@code u8(id, key)} below is {@code Packbin.u8(id, Access.get(key), Access.set(key))}.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class DuplicateNamesTest {
    private DuplicateNamesTest() {}

    public static final class Row {
        public Integer x;
    }

    static void run() {
        ac1SameKeyTwiceAtOneLevelIsRefused();
        ac2KeyOutsideAndInsideARoundIsRefused();
        ac3TwoTimesBodiesThatShareAKeyAreRefused();
        ac4EveryNamedKindAndSharedContainerIsChecked();
        ac4EveryScalarKindIsNamed();
        ac5ElementsAndNestedRowsAreScopesOfTheirOwn();
        ac5ElementUnderAWhenIsStillAScopeOfItsOwn();
        ac6AlternateWhenBranchesKeepSharingAKey();
        ac7HandleReadTwiceAndGetterOnlyEchoesStayLegal();
        ac8NestedRowKeysAndUnnamedAccessorsAreNotChecked();
        ac9ExistingRefusalsKeepTheirMessageAndWin();
        ac10AccessSetBehavesAsBefore();
    }

    private static Field u8(int id, String key) {
        return Packbin.u8(id, Access.get(key), Access.set(key));
    }

    private static Field u16(int id, String key) {
        return Packbin.u16(id, Access.get(key), Access.set(key));
    }

    private static Field bool(int id, String key) {
        return Packbin.boolField(id, Access.get(key), Access.set(key));
    }

    private static Field sized(int id, String key, int countId) {
        return Packbin.sized(id, Access.get(key), Access.set(key), countId);
    }

    private static Field slot(int id, String key) {
        return Packbin.u2Slot(id, Access.get(key), Access.set(key));
    }

    private static Field nestedRow(String key, Field... fields) {
        return Packbin.group(Access.get(key), Access.set(key), fields);
    }

    private static Field list(String key, Field element) {
        return Packbin.list(Access.get(key), Access.set(key), element);
    }

    private static Field dict(String key, Field element) {
        return Packbin.dict(Access.get(key), Access.set(key), element);
    }

    private static String twice(String key) {
        return "member " + key + ": declared twice in one scope; a row holds one value per name, so one would be lost";
    }

    private static void expectRefused(String label, Supplier<Scheme<Map>> build, String key) {
        PackbinTest.expectThrows(label, build::get, twice(key));
    }

    private static void expectBuilds(String label, Supplier<Scheme<Map>> build) {
        try {
            build.get();
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": expected the scheme to build, threw " + ex);
        }
    }

    private static void expectPacks(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        try {
            PackbinTest.expectEq(label + " bytes", hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": pack threw " + ex);
        }
    }

    private static Map unpackOk(String label, Scheme<Map> scheme, String hex) {
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(r -> got[0] = r));
        PackbinTest.expectTrue(label + " unpack ok (" + err + ")", err == null && got[0] != null);
        return got[0];
    }

    private static void expectUnpacks(String label, Scheme<Map> scheme, String hex, Map<String, Object> row) {
        PackbinTest.expectEq(label + " row", row, unpackOk(label, scheme, hex));
    }

    /** Pack {@code row}, unpack the bytes, expect {@code row} back. */
    private static void expectRoundTrip(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        expectPacks(label, scheme, row, hex);
        expectUnpacks(label, scheme, hex, row);
    }

    /** AC-1: today it builds, {@code 010505} unpacks {@code 010708} to {@code {x=8}} and repacks {@code 010808}. */
    private static void ac1SameKeyTwiceAtOneLevelIsRefused() {
        expectRefused("AC-1 u8 x, u8 x", () -> Maps.scheme(1, u8(0, "x"), u8(1, "x")), "x");
    }

    /** AC-2: a round stores its values in the row around it, so a name outside and inside a round clashes. */
    private static void ac2KeyOutsideAndInsideARoundIsRefused() {
        expectRefused("AC-2 key, then times", () -> Maps.scheme(1,
                u8(0, "x"), u8(1, "c"), Packbin.times(2, 1, u8(2, "x"))), "x");
        expectRefused("AC-2 times, then key", () -> Maps.scheme(1,
                u8(0, "c"), Packbin.times(1, 0, u8(1, "x")), u8(2, "x")), "x");
        expectRefused("AC-2 key, then repeat", () -> Maps.scheme(1,
                u8(0, "x"), Packbin.repeat(1, u8(1, "x"))), "x");
        expectRefused("AC-2 inner times inside repeat", () -> Maps.scheme(1,
                Packbin.repeat(0, u8(0, "n"), Packbin.times(1, 0, u8(1, "v")), u8(2, "v"))), "v");
    }

    private static void ac3TwoTimesBodiesThatShareAKeyAreRefused() {
        expectRefused("AC-3 two times bodies", () -> Maps.scheme(1,
                u8(0, "n"), Packbin.times(1, 0, u8(1, "v")), u8(2, "m"), Packbin.times(3, 2, u8(3, "v"))), "v");
    }

    private static void ac4EveryNamedKindAndSharedContainerIsChecked() {
        expectRefused("AC-4 u2 slot and u8", () -> Maps.scheme(1,
                Packbin.u2(slot(0, "a"), slot(1, "b")), u8(2, "a")), "a");
        expectRefused("AC-4 u2 slots", () -> Maps.scheme(1,
                Packbin.u2(slot(0, "b"), slot(1, "b"))), "b");
        expectRefused("AC-4 two sized", () -> Maps.scheme(1,
                u8(0, "n"), sized(1, "b", 0), sized(2, "b", 0)), "b");
        expectRefused("AC-4 inside flags", () -> Maps.scheme(1,
                Packbin.flags(0, u8(0, "a"), u8(1, "a"))), "a");
        expectRefused("AC-4 key, then flags", () -> Maps.scheme(1,
                u8(0, "a"), Packbin.flags(1, u8(1, "a"))), "a");
        expectRefused("AC-4 two bools in flags", () -> Maps.scheme(1,
                Packbin.flags(0, bool(0, "on"), bool(1, "on"))), "on");
        expectRefused("AC-4 key, then flag byte bit", () -> {
            Field handle = Packbin.flagByte();
            return Maps.scheme(1, u8(0, "a"), handle, handle.bit(u8(1, "a")));
        }, "a");
        expectRefused("AC-4 anchored group, then key", () -> Maps.scheme(1,
                Packbin.group(0, u8(0, "a")), u8(1, "a")), "a");
        expectRefused("AC-4 two lists", () -> Maps.scheme(1,
                list("xs", u8(0, "e")), list("xs", u8(0, "e"))), "xs");
        expectRefused("AC-4 list, then key", () -> Maps.scheme(1,
                list("xs", u8(0, "e")), u8(0, "xs")), "xs");
        expectRefused("AC-4 one setter object on two fields", () -> {
            Setter shared = Access.set("x");
            return Maps.scheme(1, Packbin.u8(0, Access.get("x"), shared), Packbin.u8(1, Access.get("x"), shared));
        }, "x");
        expectRefused("AC-4 list, then dict", () -> Maps.scheme(1,
                list("xs", u8(0, "e")), dict("xs", u8(0, "e"))), "xs");
    }

    /** Each scalar helper names its member through its setter; {@code kind.apply(0)} writes the member {@code x}. */
    private static void ac4EveryScalarKindIsNamed() {
        Getter get = Access.get("x");
        Setter set = Access.set("x");
        List<IntFunction<Field>> kinds = Arrays.asList(
                id -> Packbin.u16(id, get, set), id -> Packbin.u32(id, get, set), id -> Packbin.u64(id, get, set),
                id -> Packbin.i8(id, get, set), id -> Packbin.i16(id, get, set), id -> Packbin.i32(id, get, set),
                id -> Packbin.i64(id, get, set), id -> Packbin.f32(id, get, set), id -> Packbin.f64(id, get, set),
                id -> Packbin.utf8(id, get, set), id -> Packbin.bytes(id, get, set, 2),
                id -> Packbin.be(Packbin.u16(id, get, set)));
        for (int i = 0; i < kinds.size(); i++) {
            IntFunction<Field> kind = kinds.get(i);
            expectRefused("AC-4 scalar kind " + i, () -> Maps.scheme(1, kind.apply(0), u8(1, "x")), "x");
        }
        expectRefused("AC-4 bits", () -> Maps.scheme(1,
                u8(0, "n"), Packbin.bits(1, get, set, 0), u8(2, "x")), "x");
        expectRefused("AC-4 packed", () -> Maps.scheme(1,
                u8(0, "n"), Packbin.packed(1, 1, get, set, 0, 0), u8(2, "x")), "x");
    }

    private static void ac5ElementsAndNestedRowsAreScopesOfTheirOwn() {
        expectRefused("AC-5 list element", () -> Maps.scheme(1,
                list("xs", Packbin.group(0, u8(0, "a"), u8(1, "a")))), "a");
        expectRefused("AC-5 dict element", () -> Maps.scheme(1,
                dict("m", Packbin.group(0, u8(0, "a"), u8(1, "a")))), "a");
        expectRefused("AC-5 nested row", () -> Maps.scheme(1,
                nestedRow("g", u8(0, "a"), u8(1, "a"))), "a");
        expectRefused("AC-5 nested row inside flags", () -> Maps.scheme(1,
                Packbin.flags(0, nestedRow("g", u8(0, "a"), u8(1, "a")))), "a");
        expectRefused("AC-5 nested row as list element", () -> Maps.scheme(1,
                list("xs", nestedRow("p", u8(0, "a"), u8(1, "a")))), "a");

        Scheme<Map> element = Maps.scheme(1, u8(0, "a"), list("xs", Packbin.group(0, u8(0, "a"), u8(1, "b"))));
        expectRoundTrip("AC-5 a beside a list element that holds a", element,
                Maps.map("a", 7, "xs", Collections.singletonList(Maps.map("a", 1, "b", 2))), "010701000102");
        Scheme<Map> nested = Maps.scheme(1, u8(0, "a"), nestedRow("g", u8(0, "a")));
        expectRoundTrip("AC-5 a beside a nested row that holds a", nested,
                Maps.map("a", 7, "g", Maps.map("a", 9)), "010709");
    }

    /** A list or dict element starts a scope that is not under the `when` around the list: its repeats are refused. */
    private static void ac5ElementUnderAWhenIsStillAScopeOfItsOwn() {
        expectRefused("AC-5 list element under a when", () -> Maps.scheme(1,
                u8(0, "k"),
                Packbin.when(1, Packbin.eq(0, 0), list("xs", Packbin.group(0, u8(0, "a"), u8(1, "a"))))), "a");
        expectRefused("AC-5 dict element under a when", () -> Maps.scheme(1,
                u8(0, "k"),
                Packbin.when(1, Packbin.eq(0, 0), dict("m", Packbin.group(0, u8(0, "a"), u8(1, "a"))))), "a");
        expectBuilds("AC-5 list element under a when, distinct keys", () -> Maps.scheme(1,
                u8(0, "k"),
                Packbin.when(1, Packbin.eq(0, 0), list("xs", Packbin.group(0, u8(0, "a"), u8(1, "b"))))));
    }

    private static void ac6AlternateWhenBranchesKeepSharingAKey() {
        Scheme<Map> branches = Maps.scheme(1,
                u8(0, "k"), Packbin.when(1, Packbin.eq(0, 0), u8(1, "s")), Packbin.when(2, Packbin.eq(0, 1), u16(2, "s")));
        expectRoundTrip("AC-6 two when branches", branches, Maps.map("k", 1, "s", 300), "01012c01");

        Scheme<Map> outsideFirst = Maps.scheme(1,
                u8(0, "k"), u8(1, "s"), Packbin.when(2, Packbin.eq(0, 1), u16(2, "s")));
        expectUnpacks("AC-6 outside, then when", outsideFirst, "010107ff00", Maps.map("k", 1, "s", 255));

        Scheme<Map> sameWhen = Maps.scheme(1,
                u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "s"), u8(2, "s")));
        expectUnpacks("AC-6 one when body", sameWhen, "01010708", Maps.map("k", 1, "s", 8));

        expectBuilds("AC-6 times under two whens", () -> Maps.scheme(1,
                u8(0, "n"),
                Packbin.when(1, Packbin.eq(0, 1), Packbin.times(1, 0, u8(1, "v"))),
                Packbin.when(2, Packbin.eq(0, 2), Packbin.times(2, 0, u8(2, "v")))));
    }

    private static void ac7HandleReadTwiceAndGetterOnlyEchoesStayLegal() {
        Scheme<Map> twice = scheme(() -> {
            Field handle = Packbin.flagByte();
            return Maps.scheme(1, handle, handle.bit(u8(0, "a")), handle, handle.bit(u8(1, "b")));
        });
        expectRoundTrip("AC-7 flag byte handle read twice", twice, Maps.map("a", 5, "b", 9), "0101050109");

        Scheme<Map> ignored = Maps.scheme(1, u8(0, "a"), Packbin.u8(1, Access.get("a"), Access.ignore()));
        expectPacks("AC-7 getter-only echo, ignore", ignored, Maps.map("a", 5), "010505");
        expectUnpacks("AC-7 getter-only echo, ignore", ignored, "010507", Maps.map("a", 5));

        Scheme<Map> mirrored = Maps.scheme(1, u8(0, "a"), Packbin.u8(1, Access.get("a"), Access.set("b")));
        expectPacks("AC-7 getter-only echo, other key", mirrored, Maps.map("a", 5), "010505");
        expectUnpacks("AC-7 getter-only echo, other key", mirrored, "010507", Maps.map("a", 5, "b", 7));
    }

    private static Scheme<Map> scheme(Supplier<Scheme<Map>> build) {
        return build.get();
    }

    private static void ac8NestedRowKeysAndUnnamedAccessorsAreNotChecked() {
        Scheme<Map> rows = Maps.scheme(1, nestedRow("g", u8(0, "a")), nestedRow("g", u8(0, "b")));
        expectUnpacks("AC-8 one nested row key twice", rows, "010102", Maps.map("g", Maps.map("a", 1, "b", 2)));
        expectPacks("AC-8 one nested row key twice", rows, Maps.map("g", Maps.map("a", 1, "b", 2)), "010102");

        Scheme<Row> typed = new Scheme<>(1, Row.class, typedU8(0), typedU8(1));
        Row row = new Row();
        row.x = 5;
        PackbinTest.expectEq("AC-8 typed row bytes", "010505", PackbinTest.toHex(BinaryPacker.pack(typed, row)));
        Row[] got = new Row[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("010708"), typed.on(r -> got[0] = r));
        PackbinTest.expectTrue("AC-8 typed row unpack ok (" + err + ")", err == null && got[0] != null && got[0].x == 8);

        Scheme<Map> lambdas = Maps.scheme(1, mapLambdaU8(0), mapLambdaU8(1));
        expectPacks("AC-8 hand-written lambdas", lambdas, Maps.map("x", 5), "010505");
        expectUnpacks("AC-8 hand-written lambdas", lambdas, "010708", Maps.map("x", 8));

        Scheme<Map> mixed = Maps.scheme(1, u8(0, "x"), mapLambdaU8(1));
        expectUnpacks("AC-8 named and hand-written", mixed, "010708", Maps.map("x", 8));
    }

    private static Field typedU8(int id) {
        return Packbin.u8(id, Access.get((Row r) -> r.x), Access.set((Row r, Object v) -> r.x = ((Number) v).intValue()));
    }

    private static Field mapLambdaU8(int id) {
        return Packbin.u8(id, r -> ((Map) r).get("x"), (r, v) -> ((Map) r).put("x", v));
    }

    /** Every scheme here repeats {@code x} and is also wrong in another way; the existing message must win. */
    private static void ac9ExistingRefusalsKeepTheirMessageAndWin() {
        PackbinTest.expectThrows("AC-9 field id", () -> Maps.scheme(1, u8(0, "x"), u8(1, "x"), u8(5, "y")),
                "field id 5 must be 2");
        PackbinTest.expectThrows("AC-9 when names a later field", () -> Maps.scheme(1,
                u8(0, "x"), u8(1, "x"), Packbin.when(2, Packbin.eq(9, 1), u8(2, "y"))),
                "when 2 tests field 9, which is not an earlier integer or bool field in its scope");
        PackbinTest.expectThrows("AC-9 bit without a flag byte", () -> Maps.scheme(1,
                u8(0, "x"), u8(1, "x"), Packbin.flagByte().bit(u8(2, "b"))),
                "flag bit U8 2 has no flagByte before it in the same scope");
        PackbinTest.expectThrows("AC-9 bit in another scope", () -> {
            Field handle = Packbin.flagByte();
            Maps.scheme(1, handle, nestedRow("g", handle.bit(u8(0, "v"))), u8(0, "x"), u8(1, "x"));
        }, "flag bit U8 0 has no flagByte before it in the same scope");
        PackbinTest.expectThrows("AC-9 nine bits", () -> {
            Field handle = Packbin.flagByte();
            Field[] fields = new Field[12];
            fields[0] = u8(0, "x");
            fields[1] = u8(1, "x");
            fields[2] = handle;
            for (int i = 0; i < 9; i++) {
                fields[3 + i] = handle.bit(u8(2 + i, "b" + i));
            }
            Maps.scheme(1, fields);
        }, "flags already has 8 bits");
        PackbinTest.expectThrows("AC-9 empty group", () -> Maps.scheme(1, u8(0, "x"), u8(1, "x"), Packbin.group(2)),
                "empty group 2 has no fields and no accessor, so its bit can never be set");
        PackbinTest.expectThrows("AC-9 same id twice", () -> Maps.scheme(1, u8(0, "x"), u8(0, "x")),
                "field id 0 must be 1");
    }

    private static void ac10AccessSetBehavesAsBefore() {
        Setter set = Access.set("k");
        Map<Object, Object> map = new HashMap<>();

        set.set(map, 3);

        PackbinTest.expectEq("AC-10 put on a map", Maps.map("k", 3), map);
        PackbinTest.expectThrows("AC-10 not a map", () -> set.set("not a map", 3), "expected map");
        try {
            PackbinTest.expectEq("AC-10 return type", Setter.class, Access.class.getMethod("set", String.class).getReturnType());
        } catch (NoSuchMethodException ex) {
            PackbinTest.fail("AC-10 Access.set(String) is missing: " + ex);
        }
    }
}

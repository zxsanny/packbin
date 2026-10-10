package packbin;

import java.util.Map;
import java.util.function.Supplier;

/**
 * AZ-2126: a when names an integer or a bool, a bool only compared with true; a count names an integer only. The
 * float, utf8 and bytes refusals for a when are pinned by ReferenceScopeTest (AZ-2085 AC-5).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class EqBoolTrueOnlyTest {
    private EqBoolTrueOnlyTest() {}

    private static final String COUNT_INTEGER = ", which is not an earlier integer field in its scope";

    static void run() {
        eqBoolFalseIsRefused();
        eqBoolTrueRoundTrips();
        countNamesIntegerOnly();
    }

    private static Field bool(int id, String name) {
        return Packbin.boolField(id, Access.get(name), Access.set(name));
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static void expectRefused(String label, Supplier<Scheme<Map>> build, String message) {
        PackbinTest.expectThrows(label, build::get, message);
    }

    private static Scheme<Map> whenBool(Object value) {
        return Maps.scheme(1, Packbin.flags(0, bool(0, "on")), Packbin.when(1, Packbin.eq(0, value), u8(1, "v")));
    }

    private static void eqBoolFalseIsRefused() {
        expectRefused("AZ-2126 AC-1 eq(bool, false)", () -> whenBool(false),
                "when 1 tests bool field 0 against false; a bool is compared only with true");
        expectRefused("AZ-2126 AC-1 eq(bool, 1)", () -> whenBool(1),
                "when 1 tests bool field 0 against 1; a bool is compared only with true");
        expectRefused("AZ-2126 AC-1 eq(bool, text)", () -> whenBool("yes"),
                "when 1 tests bool field 0 against yes; a bool is compared only with true");
        expectRefused("AZ-2126 AC-1 eq(bool, null)", () -> whenBool(null),
                "when 1 tests bool field 0 against null; a bool is compared only with true");
        expectRefused("AZ-2126 AC-1 eq(flagByte bit, false)", () -> {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb, fb.bit(bool(0, "on")), Packbin.when(1, Packbin.eq(0, false), u8(1, "v")));
        }, "when 1 tests bool field 0 against false; a bool is compared only with true");
        expectRefused("AZ-2126 AC-1 eq(bool, false) inside a repeat round", () -> Maps.scheme(1,
                Packbin.repeat(0, Packbin.flags(0, bool(0, "on")), Packbin.when(1, Packbin.eq(0, false), u8(1, "v")))),
                "when 1 tests bool field 0 against false; a bool is compared only with true");
    }

    private static void eqBoolTrueRoundTrips() {
        Scheme<Map> scheme = whenBool(true);
        PackbinTest.expectEq("AZ-2126 AC-2 bytes", "010105",
                PackbinTest.toHex(BinaryPacker.pack(scheme, Maps.map("on", true, "v", 5))));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("010105"), scheme.on(row -> got[0] = row));
        PackbinTest.expectTrue("AZ-2126 AC-2 unpack ok (" + err + ")", err == null);
        PackbinTest.expectEq("AZ-2126 AC-2 row", Maps.map("on", true, "v", 5), got[0]);
        PackbinTest.expectEq("AZ-2126 AC-2 clear bit leaves the when out", "0100",
                PackbinTest.toHex(BinaryPacker.pack(scheme, Maps.map("on", false, "v", 5))));
    }

    private static void countNamesIntegerOnly() {
        String bool = ", which is a bool; a count names an integer field";
        Field flags = Packbin.flags(0, bool(0, "on"));
        expectRefused("AZ-2126 count names a bool (times)", () -> Maps.scheme(1,
                flags, Packbin.times(1, 0, u8(1, "x"))), "times 1 takes its count from field 0" + bool);
        expectRefused("AZ-2126 count names a bool (sized)", () -> Maps.scheme(1,
                flags, Packbin.sized(1, Access.get("p"), Access.set("p"), 0)), "sized 1 takes its count from field 0" + bool);
        expectRefused("AZ-2126 count names a bool (bits)", () -> Maps.scheme(1,
                flags, Packbin.bits(1, Access.get("p"), Access.set("p"), 0)), "bits 1 takes its count from field 0" + bool);
        expectRefused("AZ-2126 count names a bool (packed)", () -> Maps.scheme(1,
                flags, Packbin.packed(2, 1, Access.get("p"), Access.set("p"), 0, 0)),
                "packed 1 takes its count from field 0" + bool);
        expectRefused("AZ-2126 count names an f32", () -> Maps.scheme(1,
                Packbin.f32(0, Access.get("x"), Access.set("x")), Packbin.times(1, 0, u8(1, "v"))),
                "times 1 takes its count from field 0" + COUNT_INTEGER);
        expectRefused("AZ-2126 count names bytes", () -> Maps.scheme(1,
                Packbin.bytes(0, Access.get("z"), Access.set("z"), 1), Packbin.times(1, 0, u8(1, "v"))),
                "times 1 takes its count from field 0" + COUNT_INTEGER);

        Scheme<Map> ok = Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, u8(1, "x")));
        PackbinTest.expectEq("AZ-2126 integer count still packs", "01020708",
                PackbinTest.toHex(BinaryPacker.pack(ok, Maps.map("n", 2, "x", java.util.List.of(7, 8)))));
    }
}

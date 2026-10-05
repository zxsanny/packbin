package packbin;

import java.util.Map;
import java.util.function.Supplier;

/** AZ-2089: a bool or an empty group is only a flag bit; a set bool bit unpacks as TRUE in both flag forms. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class BoolPlacementTest {
    private BoolPlacementTest() {}

    private static final String ONLY_A_BIT = " is allowed only as a bit of flags or a flagByte";

    static void run() {
        boolOutsideFlagsIsRejected();
        boolAsFlagBitStillBuilds();
        emptyGroupOutsideFlagsIsRejected();
        emptyGroupAsFlagBitStillBuilds();
        splitFormBoolUnpacksTrue();
        combinedFormBitRuleUnchanged();
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static Field bool(int id, String name) {
        return Packbin.boolField(id, Access.get(name), Access.set(name));
    }

    private static void expectRefused(String label, Supplier<Scheme<Map>> build, String message) {
        PackbinTest.expectThrows(label, build::get, message);
    }

    private static void expectBuilds(String label, Supplier<Scheme<Map>> build) {
        try {
            build.get();
        } catch (IllegalArgumentException ex) {
            PackbinTest.fail(label + ": refused with \"" + ex.getMessage() + "\"");
        }
    }

    private static void boolOutsideFlagsIsRejected() {
        Scheme[] built = new Scheme[1];
        byte[][] wrote = {new byte[0]};
        PackbinTest.expectThrows("AC-5 bool at top level", () -> {
            built[0] = Maps.scheme(1, bool(0, "on"), u8(1, "n"));
            wrote[0] = BinaryPacker.pack(built[0], Maps.map("on", true, "n", 7));
        }, "bool 0" + ONLY_A_BIT);
        PackbinTest.expectTrue("AC-5 bool at top level: 0 schemes", built[0] == null);
        PackbinTest.expectEq("AC-5 bool at top level: 0 bytes", 0, wrote[0].length);

        expectRefused("AC-5 vector bool_outside_flags", () -> Maps.scheme(1, u8(0, "a"), bool(1, "on")),
                "bool 1" + ONLY_A_BIT);
        expectRefused("AC-5 bool in when", () -> Maps.scheme(1,
                u8(0, "m"), Packbin.when(1, Packbin.eq(0, 1), bool(1, "on"))),
                "bool 1" + ONLY_A_BIT);
        expectRefused("AC-5 bool in repeat", () -> Maps.scheme(1, Packbin.repeat(0, bool(0, "on"))),
                "bool 0" + ONLY_A_BIT);
        expectRefused("AC-5 bool in times", () -> Maps.scheme(1,
                u8(0, "n"), Packbin.times(1, 0, bool(1, "on"))),
                "bool 1" + ONLY_A_BIT);
        expectRefused("AC-5 bool as list element", () -> Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"),
                Packbin.boolField(0, Access.identity(), Access.ignore()))),
                "bool 0" + ONLY_A_BIT);
        expectRefused("AC-5 bool as dict element", () -> Maps.scheme(1, Packbin.dict(Access.get("m"), Access.set("m"),
                Packbin.boolField(0, Access.identity(), Access.ignore()))),
                "bool 0" + ONLY_A_BIT);
        expectRefused("AC-5 bool in a group", () -> Maps.scheme(1, Packbin.group(0, bool(0, "on"), u8(1, "x"))),
                "bool 0" + ONLY_A_BIT);
        expectRefused("AC-5 bool in a group under flags", () -> Maps.scheme(1,
                Packbin.flags(0, Packbin.group(0, bool(0, "on"), u8(1, "x")))),
                "bool 0" + ONLY_A_BIT);
        expectRefused("AC-5 bool in a group under a flag byte bit", () -> {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb, fb.bit(Packbin.group(0, bool(0, "on"), u8(1, "x"))));
        }, "bool 0" + ONLY_A_BIT);
        expectRefused("AC-5 bool in a nested row", () -> Maps.scheme(1,
                Packbin.group(Access.get("g"), Access.set("g"), bool(0, "on"))),
                "bool 0" + ONLY_A_BIT);
    }

    private static void boolAsFlagBitStillBuilds() {
        expectBuilds("AC-5 bool in flags", () -> Maps.scheme(1, Packbin.flags(0, bool(0, "on"))));
        expectBuilds("AC-5 bool as a flag byte bit", () -> {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb, fb.bit(bool(0, "on")));
        });
        expectBuilds("AC-5 bool as a flag byte bit inside a when", () -> {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, u8(0, "m"), fb, Packbin.when(1, Packbin.eq(0, 1), fb.bit(bool(1, "on"))));
        });
        expectBuilds("AC-5 bool in flags as a list element", () -> Maps.scheme(1, Packbin.list(
                Access.get("xs"), Access.set("xs"), Packbin.flags(0, bool(0, "on")))));
    }

    private static void emptyGroupOutsideFlagsIsRejected() {
        expectRefused("AC-6 empty group alone", () -> Maps.scheme(1, Packbin.group(0)),
                "empty group 0" + ONLY_A_BIT);
        expectRefused("AC-6 vector empty_group_outside_flags", () -> Maps.scheme(1, u8(0, "a"), Packbin.group(1)),
                "empty group 1" + ONLY_A_BIT);
        expectRefused("AC-6 empty group in a group", () -> Maps.scheme(1,
                Packbin.group(0, u8(0, "a"), Packbin.group(1))),
                "empty group 1" + ONLY_A_BIT);
        expectRefused("AC-6 empty group in when", () -> Maps.scheme(1,
                u8(0, "m"), Packbin.when(1, Packbin.eq(0, 1), Packbin.group(1))),
                "empty group 1" + ONLY_A_BIT);
        expectRefused("AC-6 empty group in repeat", () -> Maps.scheme(1,
                Packbin.repeat(0, u8(0, "k"), Packbin.group(1))),
                "empty group 1" + ONLY_A_BIT);
        expectRefused("AC-6 empty group as list element", () -> Maps.scheme(1, Packbin.list(
                Access.get("xs"), Access.set("xs"), Packbin.group(0))),
                "empty group 0" + ONLY_A_BIT);
        expectRefused("AC-6 empty nested row", () -> Maps.scheme(1, Packbin.group(Access.get("g"), Access.set("g"))),
                "empty group" + ONLY_A_BIT);
    }

    private static void emptyGroupAsFlagBitStillBuilds() {
        expectBuilds("AC-6 empty group in flags", () -> Maps.scheme(1, Packbin.flags(0, Packbin.group(0))));
        expectBuilds("AC-6 empty group as a flag byte bit", () -> {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb, fb.bit(Packbin.group(0)));
        });
    }

    private static Map unpackOk(String label, Scheme<Map> scheme, String hex) {
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(row -> got[0] = row));
        PackbinTest.expectTrue(label + " unpack ok (" + err + ")", err == null && got[0] != null);
        return got[0] == null ? Map.of() : got[0];
    }

    private static void splitFormBoolUnpacksTrue() {
        Field fb = Packbin.flagByte();
        Scheme<Map> split = Maps.scheme(1, fb, fb.bit(bool(0, "on")));
        PackbinTest.expectEq("AC-7 split {on: true} bytes", "0101",
                PackbinTest.toHex(BinaryPacker.pack(split, Maps.map("on", true))));
        PackbinTest.expectEq("AC-7 split 0101 on", Boolean.TRUE, unpackOk("AC-7 split 0101", split, "0101").get("on"));
        PackbinTest.expectEq("AC-7 split {on: false} bytes", "0100",
                PackbinTest.toHex(BinaryPacker.pack(split, Maps.map("on", false))));
        Map clear = unpackOk("AC-7 split 0100", split, "0100");
        PackbinTest.expectTrue("AC-7 split 0100 on stays null (" + clear + ")", !clear.containsKey("on"));

        Field motion = Packbin.flagByte();
        Scheme<Map> mixed = Maps.scheme(1, motion, motion.bit(bool(0, "on")), motion.bit(u8(1, "x")));
        PackbinTest.expectEq("AC-7 split bool and u8 bytes", "010307",
                PackbinTest.toHex(BinaryPacker.pack(mixed, Maps.map("on", true, "x", 7))));
        PackbinTest.expectEq("AC-7 split bool and u8 row", Maps.map("on", true, "x", 7),
                unpackOk("AC-7 split bool and u8", mixed, "010307"));

        Field inWhen = Packbin.flagByte();
        Scheme<Map> gated = Maps.scheme(1, u8(0, "m"), inWhen,
                Packbin.when(1, Packbin.eq(0, 1), inWhen.bit(bool(1, "on"))));
        PackbinTest.expectEq("AC-7 split bool bit inside a when", Maps.map("m", 1, "on", true),
                unpackOk("AC-7 split bool bit inside a when", gated, "010101"));

        FieldIdBindingTest.MarkerRow typed = new FieldIdBindingTest.MarkerRow();
        Field typedByte = Packbin.flagByte();
        Scheme<FieldIdBindingTest.MarkerRow> rows = new Scheme<>(1, FieldIdBindingTest.MarkerRow.class, typedByte,
                typedByte.bit(Packbin.boolField(0,
                        Access.get((FieldIdBindingTest.MarkerRow r) -> r.hidden),
                        Access.set((FieldIdBindingTest.MarkerRow r, Object v) -> r.hidden = (Boolean) v))));
        typed.hidden = true;
        FieldIdBindingTest.MarkerRow[] back = new FieldIdBindingTest.MarkerRow[1];
        Object err = BinaryPacker.unpack(BinaryPacker.pack(rows, typed), rows.on(row -> back[0] = row));
        PackbinTest.expectTrue("AC-7 split typed row ok", err == null && back[0] != null);
        if (back[0] != null) {
            PackbinTest.expectEq("AC-7 split typed row hidden", Boolean.TRUE, back[0].hidden);
        }
    }

    private static void combinedFormBitRuleUnchanged() {
        Scheme<Map> combined = Maps.scheme(1, Packbin.flags(0, bool(0, "b")));
        PackbinTest.expectEq("AC-8 {b: false}", "0100", PackbinTest.toHex(BinaryPacker.pack(combined, Maps.map("b", false))));
        PackbinTest.expectEq("AC-8 {}", "0100", PackbinTest.toHex(BinaryPacker.pack(combined, Maps.map())));
        PackbinTest.expectEq("AC-8 {b: true}", "0101", PackbinTest.toHex(BinaryPacker.pack(combined, Maps.map("b", true))));
        Map clear = unpackOk("AC-8 0100", combined, "0100");
        PackbinTest.expectTrue("AC-8 0100 b stays null (" + clear + ")", !clear.containsKey("b"));
        PackbinTest.expectEq("AC-8 0101 b", Boolean.TRUE, unpackOk("AC-8 0101", combined, "0101").get("b"));
    }
}

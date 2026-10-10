package packbin;

import static packbin.MemberCases.packs;
import static packbin.MemberCases.packsAs;
import static packbin.MemberCases.refused;
import static packbin.MemberCases.row;
import static packbin.MemberCases.u16;
import static packbin.MemberCases.u8;
import static packbin.MemberCases.unpacks;

import java.util.Map;

/**
 * AZ-2120 AC-3 and AC-5 (owner decision 2026-10-10): a {@code when} that is a member of a flags container, a split
 * flag bit or a group under one is written like any other value. Its bit is on exactly when its condition holds on
 * the values written so far and its body holds a value. A set member that cannot be written in full fails pack
 * naming the missing value. Every hex is the C# package's, pinned in the wave 3 reference table.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class FlagsWhenMemberTest {
    private FlagsWhenMemberTest() {}

    private static final Scheme<Map> WA = Maps.scheme(1, u8(0, "mode"),
            Packbin.flags(1, Packbin.when(1, Packbin.eq(0, 1), u8(1, "speed")), u16(2, "heading")));

    private static final Scheme<Map> WS = splitScheme();

    private static final Scheme<Map> WG = Maps.scheme(1, u8(0, "mode"),
            Packbin.flags(1, Packbin.group(1, Packbin.when(1, Packbin.eq(0, 1), u8(1, "speed"))), u16(2, "heading")));

    private static final Scheme<Map> W2 = Maps.scheme(1, u8(0, "mode"),
            Packbin.flags(1, Packbin.when(1, Packbin.eq(0, 1), u8(1, "speed"), u8(2, "extra")), u16(3, "heading")));

    private static final Scheme<Map> GS = Maps.scheme(1, u8(0, "mode"),
            Packbin.flags(1, Packbin.group(1, u8(1, "extra"), Packbin.when(2, Packbin.eq(0, 1), u8(2, "speed"))),
                    u16(3, "heading")));

    private static final Scheme<Map> WE = Maps.scheme(1,
            Packbin.flags(0, u8(0, "mode"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "speed"))));

    private static Scheme<Map> splitScheme() {
        Field byteField = Packbin.flagByte();
        return Maps.scheme(1, u8(0, "mode"), byteField,
                byteField.bit(Packbin.when(1, Packbin.eq(0, 1), u8(1, "speed"))), byteField.bit(u16(2, "heading")));
    }

    static void run() {
        ac3WhenUnderFlags();
        ac3OldAndNewPacketsUnpack();
        ac3SplitForm();
        ac3WhenInAGroup();
        ac3TwoValueBodyAndMissingValues();
        ac3GroupWithASibling();
        ac3WhenNamesAnEarlierMemberOfTheSameFlags();
        ac3TypedRowGivesTheSameBytes();
        ac3HostileValueFailsNamingTheField();
    }

    private static void ac3WhenUnderFlags() {
        packs("AC-3 W-true", WA, row("mode", 1, "speed", 7, "heading", 90), "010103075a00");
        packs("AC-3 W-false", WA, row("mode", 0, "heading", 90), "0100025a00");
        packs("AC-3 W-true-no-body", WA, row("mode", 1, "heading", 90), "0101025a00");
        packsAs("AC-3 W-false-body-given", WA, row("mode", 0, "speed", 7, "heading", 90), "0100025a00",
                row("mode", 0, "heading", 90));
        packs("AC-3 W-only-when", WA, row("mode", 1, "speed", 7), "01010107");
        packs("AC-3 W-only-mode", WA, row("mode", 0), "010000");
    }

    private static void ac3OldAndNewPacketsUnpack() {
        unpacks("AC-5 W-old-packet (bit clear)", WA, "0101025a00", row("mode", 1, "heading", 90));
        unpacks("AC-5 W-new-packet", WA, "010103075a00", row("mode", 1, "speed", 7, "heading", 90));
        unpacks("AC-5 W-group-old-packet", WG, "0101025a00", row("mode", 1, "heading", 90));
        unpacks("AC-5 W-split-old-packet", WS, "0101025a00", row("mode", 1, "heading", 90));
    }

    private static void ac3SplitForm() {
        packs("AC-3 W-split-true", WS, row("mode", 1, "speed", 7, "heading", 90), "010103075a00");
        packs("AC-3 W-split-false", WS, row("mode", 0, "heading", 90), "0100025a00");
        packs("AC-3 W-split-no-body", WS, row("mode", 1, "heading", 90), "0101025a00");
        packsAs("AC-3 W-split-false-body-given", WS, row("mode", 0, "speed", 7, "heading", 90), "0100025a00",
                row("mode", 0, "heading", 90));
    }

    private static void ac3WhenInAGroup() {
        packs("AC-3 W-group-true", WG, row("mode", 1, "speed", 7, "heading", 90), "010103075a00");
        packs("AC-3 W-group-false", WG, row("mode", 0, "heading", 90), "0100025a00");
        packs("AC-3 W-group-no-body", WG, row("mode", 1, "heading", 90), "0101025a00");
        packsAs("AC-3 W-group-false-body-given", WG, row("mode", 0, "speed", 7, "heading", 90), "0100025a00",
                row("mode", 0, "heading", 90));
        packs("AC-3 W-group-only-when", WG, row("mode", 1, "speed", 7), "01010107");
    }

    private static void ac3TwoValueBodyAndMissingValues() {
        refused("AC-3 W-missing-body-value", W2, row("mode", 1, "speed", 7, "heading", 90), "missing field 2");
        packs("AC-3 W-two-values", W2, row("mode", 1, "speed", 7, "extra", 8, "heading", 90), "01010307085a00");
    }

    private static void ac3GroupWithASibling() {
        packs("AC-3 W-group-sibling-true", GS, row("mode", 1, "extra", 4, "speed", 7, "heading", 90), "01010304075a00");
        packs("AC-3 W-group-sibling-false", GS, row("mode", 0, "extra", 4, "heading", 90), "010003045a00");
        refused("AC-3 W-group-sibling-missing-when-body", GS, row("mode", 1, "extra", 4, "heading", 90),
                "missing field 2");
        refused("AC-3 W-group-sibling-missing-sibling", GS, row("mode", 1, "speed", 7, "heading", 90),
                "missing field 1");
        packs("AC-3 W-group-nothing", GS, row("mode", 1, "heading", 90), "0101025a00");
    }

    private static void ac3WhenNamesAnEarlierMemberOfTheSameFlags() {
        packs("AC-3 W-same-flags-true", WE, row("mode", 1, "speed", 7), "01030107");
        packsAs("AC-3 W-same-flags-false", WE, row("mode", 0, "speed", 7), "010100", row("mode", 0));
        packs("AC-3 W-same-flags-no-body", WE, row("mode", 1), "010101");
        packsAs("AC-3 W-same-flags-no-mode", WE, row("speed", 7), "0100", row());
        unpacks("AC-5 W-same-flags-unpack", WE, "01030107", row("mode", 1, "speed", 7));
    }

    public static final class WhenRow {
        public Integer mode;
        public Integer speed;
        public Integer heading;
    }

    private static Field typed(int id, java.util.function.Function<WhenRow, Integer> get,
            java.util.function.BiConsumer<WhenRow, Integer> set) {
        return Packbin.u8(id, Access.get((WhenRow r) -> get.apply(r)),
                Access.set((WhenRow r, Object v) -> set.accept(r, v == null ? null : ((Number) v).intValue())));
    }

    private static void ac3TypedRowGivesTheSameBytes() {
        Scheme<WhenRow> scheme = new Scheme<>(1, WhenRow.class,
                typed(0, r -> r.mode, (r, v) -> r.mode = v),
                Packbin.flags(1,
                        Packbin.when(1, Packbin.eq(0, 1), typed(1, r -> r.speed, (r, v) -> r.speed = v)),
                        Packbin.u16(2, Access.get((WhenRow r) -> r.heading),
                                Access.set((WhenRow r, Object v) -> r.heading = ((Number) v).intValue()))));
        WhenRow row = new WhenRow();
        row.mode = 1;
        row.speed = 7;
        row.heading = 90;
        PackbinTest.expectEq("AC-3 typed row bytes", "010103075a00", PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        WhenRow[] got = new WhenRow[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("010103075a00"), scheme.on(r -> got[0] = r));
        PackbinTest.expectTrue("AC-3 typed row unpack ok (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq("AC-3 typed row speed", 7, got[0].speed);
        PackbinTest.expectEq("AC-3 typed row heading", 90, got[0].heading);
        row.mode = 0;
        PackbinTest.expectEq("AC-3 typed row mode 0 drops speed", "0100025a00",
                PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
    }

    /** A body value outside its field range fails pack naming the field and returns no bytes. */
    private static void ac3HostileValueFailsNamingTheField() {
        refused("AC-3 hostile speed=300", WA, row("mode", 1, "speed", 300, "heading", 90), "1: 300 does not fit");
        refused("AC-3 hostile split speed=300", WS, row("mode", 1, "speed", 300, "heading", 90), "1: 300 does not fit");
    }
}

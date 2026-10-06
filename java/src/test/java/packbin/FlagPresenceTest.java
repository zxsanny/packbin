package packbin;

import java.util.Map;

/**
 * AZ-2128: a flags bit is on when any value inside its member is present, at any depth: a u2, a flags nested in a
 * flags or in a group, a split bit in a group. A set bit that cannot be written in full fails pack naming the value.
 * AC-3 (golden and route fixtures unchanged) is the golden and route checks of the whole suite.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class FlagPresenceTest {
    private FlagPresenceTest() {}

    static void run() {
        ac1U2SetsTheBit();
        ac1NestedFlagsSetTheBit();
        ac1SplitBitInAGroupSetsTheBit();
        ac2MissingSiblingValueFailsPackNamingIt();
        absentMembersStillLeaveTheBitClear();
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static Field slot(int id, String name) {
        return Packbin.u2Slot(id, Access.get(name), Access.set(name));
    }

    private static void expectRoundTrip(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        PackbinTest.expectEq(label + " bytes", hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(r -> got[0] = r));
        PackbinTest.expectTrue(label + " unpack ok (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq(label + " row", row, got[0]);
    }

    private static void ac1U2SetsTheBit() {
        Scheme<Map> direct = Maps.scheme(1, Packbin.flags(0, Packbin.u2(slot(0, "a"), slot(1, "b"))));
        expectRoundTrip("AC-1 flags(u2) {a: 1, b: 2}", direct, Maps.map("a", 1, "b", 2), "01" + "01" + "09");
        PackbinTest.expectEq("AC-1 flags(u2) with no slot present leaves the bit clear", "0100",
                PackbinTest.toHex(BinaryPacker.pack(direct, Maps.map())));

        Scheme<Map> inGroup = Maps.scheme(1, Packbin.flags(0, Packbin.group(0, Packbin.u2(slot(0, "a"), slot(1, "b")))));
        expectRoundTrip("AC-1 flags(group(u2)) {a: 1, b: 2}", inGroup, Maps.map("a", 1, "b", 2), "01" + "01" + "09");

        Scheme<Map> second = Maps.scheme(1, Packbin.flags(0, u8(0, "x"), Packbin.u2(slot(1, "a"), slot(2, "b"))));
        expectRoundTrip("AC-1 flags(u8, u2) bit 1 only", second, Maps.map("a", 3, "b", 0), "01" + "02" + "03");
    }

    private static void ac1NestedFlagsSetTheBit() {
        Scheme<Map> direct = Maps.scheme(1, Packbin.flags(0, Packbin.flags(0, u8(0, "b"))));
        expectRoundTrip("AC-1 flags(flags(u8)) {b: 5}", direct, Maps.map("b", 5), "01" + "01" + "01" + "05");
        PackbinTest.expectEq("AC-1 flags(flags(u8)) absent", "0100", PackbinTest.toHex(BinaryPacker.pack(direct, Maps.map())));

        Scheme<Map> inGroup = Maps.scheme(1, Packbin.flags(0,
                Packbin.group(0, u8(0, "mark"), Packbin.flags(1, u8(1, "b")))));
        expectRoundTrip("AC-1 group(mark, flags(b)) {mark: 1, b: 5}", inGroup, Maps.map("mark", 1, "b", 5),
                "01" + "01" + "01" + "01" + "05");
        expectRoundTrip("AC-1 group(mark, flags(b)) {mark: 1}", inGroup, Maps.map("mark", 1), "01" + "01" + "01" + "00");
    }

    private static void ac1SplitBitInAGroupSetsTheBit() {
        Field fb = Packbin.flagByte();
        Scheme<Map> scheme = Maps.scheme(1, Packbin.flags(0, Packbin.group(0, fb, fb.bit(u8(0, "a")))));
        expectRoundTrip("AC-1 group(flagByte, bit(u8)) {a: 7}", scheme, Maps.map("a", 7), "01" + "01" + "01" + "07");
    }

    /** The group is set because its nested container holds a value, so its required sibling must be there too. */
    private static void ac2MissingSiblingValueFailsPackNamingIt() {
        Scheme<Map> nested = Maps.scheme(1, Packbin.flags(0,
                Packbin.group(0, u8(0, "mark"), Packbin.flags(1, u8(1, "b")))));
        PackbinTest.expectThrows("AC-2 b present, mark missing", () -> BinaryPacker.pack(nested, Maps.map("b", 5)),
                "missing field 0");

        Scheme<Map> deeper = Maps.scheme(1, Packbin.flags(0,
                Packbin.group(0, u8(0, "mark"), Packbin.group(1, Packbin.flags(1, u8(1, "b"))))));
        PackbinTest.expectThrows("AC-2 b two groups down, mark missing", () -> BinaryPacker.pack(deeper, Maps.map("b", 5)),
                "missing field 0");

        Scheme<Map> u2 = Maps.scheme(1, Packbin.flags(0, Packbin.u2(slot(0, "a"), slot(1, "b"))));
        PackbinTest.expectThrows("AC-2 u2 with one slot missing", () -> BinaryPacker.pack(u2, Maps.map("a", 1)),
                "1: expected 2-bit int");

        Scheme<Map> u2Sibling = Maps.scheme(1, Packbin.flags(0,
                Packbin.group(0, u8(0, "mark"), Packbin.u2(slot(1, "a"), slot(2, "b")))));
        PackbinTest.expectThrows("AC-2 u2 present, mark missing", () -> BinaryPacker.pack(u2Sibling, Maps.map("a", 1, "b", 2)),
                "missing field 0");
    }

    private static void absentMembersStillLeaveTheBitClear() {
        Scheme<Map> scheme = Maps.scheme(1,
                Packbin.flags(0, Packbin.group(0, u8(0, "mark"), Packbin.flags(1, u8(1, "b"))),
                        Packbin.u2(slot(2, "p"), slot(3, "q")), Packbin.flags(4, u8(4, "c"))));
        PackbinTest.expectEq("empty row", "0100", PackbinTest.toHex(BinaryPacker.pack(scheme, Maps.map())));
        expectRoundTrip("only the nested flags of the third member", scheme, Maps.map("c", 4), "01" + "04" + "01" + "04");
        PackbinTest.expectEq("flags byte follows each member", "01" + "07" + "01" + "01" + "01" + "09" + "01" + "04",
                PackbinTest.toHex(BinaryPacker.pack(scheme,
                        Maps.map("mark", 1, "b", 1, "p", 1, "q", 2, "c", 4))));
    }
}

package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

/** AZ-2187: a times member whose list holds more entries than the count is refused, not cut to the count. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class TimesLongerTest {
    private TimesLongerTest() {}

    static void run() {
        ac1LongerListIsRefused();
        ac2ExactListStillPacks();
        ac3MemberUnderFlagsIsCheckedToo();
        ac4ExtraEntriesAreRefusedWhateverTheyHold();
        ac5ShorterListsAndScalarsKeepTheirBehavior();
        ac6SessionPackRefusesToo();
        aMemberWithoutAFieldIdIsNamedByItsKind();
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static final Scheme<Map> PLAIN = Maps.scheme(1, u8(0, "a"), Packbin.times(1, 0, u8(1, "x")));

    private static final Scheme<Map> UNDER_FLAGS =
            Maps.scheme(1, u8(0, "a"), Packbin.times(1, 0, Packbin.flags(1, u8(1, "x"))));

    /** Packs {@code row} and expects an IllegalArgumentException that starts with the member's field id. */
    private static void expectRefused(String label, Scheme<Map> scheme, Map<String, Object> row, String message) {
        byte[][] wrote = {null};
        PackbinTest.expectThrows(label, () -> wrote[0] = BinaryPacker.pack(scheme, row), message);
        PackbinTest.expectTrue(label + ": no bytes returned", wrote[0] == null);
    }

    private static String pack(String label, Scheme<Map> scheme, Map<String, Object> row) {
        try {
            return PackbinTest.toHex(BinaryPacker.pack(scheme, row));
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": pack threw " + ex);
            return "";
        }
    }

    private static void ac1LongerListIsRefused() {
        expectRefused("AC-1 {a:2, x:[1,2,3]}", PLAIN, Maps.map("a", 2, "x", List.of(1, 2, 3)),
                "1: list has 3 entries for a count of 2");
    }

    private static void ac2ExactListStillPacks() {
        Map<String, Object> row = Maps.map("a", 2, "x", List.of(1, 2));
        PackbinTest.expectEq("AC-2 bytes", "01020102", pack("AC-2", PLAIN, row));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("01020102"), PLAIN.on(r -> got[0] = r));
        PackbinTest.expectTrue("AC-2 unpack ok (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq("AC-2 x", List.of(1, 2), got[0] == null ? null : got[0].get("x"));
    }

    private static void ac3MemberUnderFlagsIsCheckedToo() {
        expectRefused("AC-3 flags x:[1,2,3]", UNDER_FLAGS, Maps.map("a", 2, "x", List.of(1, 2, 3)),
                "1: list has 3 entries for a count of 2");
        PackbinTest.expectEq("AC-3 flags x:[1,null] bytes", "0102010100",
                pack("AC-3", UNDER_FLAGS, Maps.map("a", 2, "x", Arrays.asList(1, null))));

        Scheme<Map> underWhen = Maps.scheme(1, u8(0, "a"),
                Packbin.times(1, 0, u8(1, "k"), Packbin.when(2, Packbin.eq(1, 1), u8(2, "v"))));
        expectRefused("AC-3 when v:[1,2,3]", underWhen, Maps.map("a", 2, "k", List.of(1, 1), "v", List.of(1, 2, 3)),
                "2: list has 3 entries for a count of 2");
        Scheme<Map> underGroup = Maps.scheme(1, u8(0, "a"), Packbin.times(1, 0, Packbin.group(1, u8(1, "x"))));
        expectRefused("AC-3 anchored group x:[1,2,3]", underGroup, Maps.map("a", 2, "x", List.of(1, 2, 3)),
                "1: list has 3 entries for a count of 2");
    }

    private static void ac4ExtraEntriesAreRefusedWhateverTheyHold() {
        expectRefused("AC-4 x:[1,2,null]", PLAIN, Maps.map("a", 2, "x", Arrays.asList(1, 2, null)),
                "1: list has 3 entries for a count of 2");
        expectRefused("AC-4 count 0, x:[1]", Maps.scheme(1, u8(0, "a"), Packbin.times(1, 0, u8(1, "x"))),
                Maps.map("a", 0, "x", List.of(1)), "1: list has 1 entries for a count of 0");
    }

    private static void ac5ShorterListsAndScalarsKeepTheirBehavior() {
        PackbinTest.expectThrows("AC-5 x:[1] is short, as before", () ->
                BinaryPacker.pack(PLAIN, Maps.map("a", 2, "x", List.of(1))), "1: expected int, got null");
        PackbinTest.expectEq("AC-5 lone x=5 bytes", "01020505", pack("AC-5", PLAIN, Maps.map("a", 2, "x", 5)));
    }

    private static void ac6SessionPackRefusesToo() {
        byte[] seed = new byte[PackSession.SEED_SIZE];
        PackSession sender = PackSession.load(seed);
        PackSession reader = PackSession.load(seed);
        byte[] nonce = sender.start();
        PackbinTest.expectTrue("AC-6 session opens", nonce != null && reader.join(nonce));
        PackbinTest.expectThrows("AC-6 session pack of a 3-entry list",
                () -> sender.pack(PLAIN, Maps.map("a", 2, "x", List.of(1, 2, 3))),
                "1: list has 3 entries for a count of 2");

        Map[] got = new Map[1];
        byte[] sealed = sender.pack(PLAIN, Maps.map("a", 2, "x", List.of(1, 2)));
        Object err = reader.unpack(sealed, PLAIN.on(r -> got[0] = r));
        PackbinTest.expectTrue("AC-6 the next valid row is read by the peer (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq("AC-6 x", List.of(1, 2), got[0] == null ? null : got[0].get("x"));
    }

    /** A nested row, list or dict has no field id, so the message names its kind, never "-1". */
    private static void aMemberWithoutAFieldIdIsNamedByItsKind() {
        Scheme<Map> rows = Maps.scheme(1, u8(0, "a"),
                Packbin.times(1, 0, Packbin.group(Access.get("g"), Access.set("g"), u8(0, "v"))));
        Map<String, Object> three = Maps.map("a", 2,
                "g", List.of(Maps.map("v", 1), Maps.map("v", 2), Maps.map("v", 3)));
        expectRefused("F5 nested row g with 3 maps", rows, three, "group: list has 3 entries for a count of 2");

        Scheme<Map> lists = Maps.scheme(1, u8(0, "a"), Packbin.times(1, 0, Packbin.list(
                Access.get("xs"), Access.set("xs"), Packbin.u8(0, Access.identity(), Access.ignore()))));
        expectRefused("F5 list xs with 3 lists", lists,
                Maps.map("a", 2, "xs", List.of(List.of(1), List.of(2), List.of(3))),
                "list: list has 3 entries for a count of 2");
        PackbinTest.expectEq("F5 nested row with 2 maps packs", "01020102",
                pack("F5", rows, Maps.map("a", 2, "g", List.of(Maps.map("v", 1), Maps.map("v", 2)))));
    }
}

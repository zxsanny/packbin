package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/** AZ-2089: a when condition or a borrowed count names an earlier value field in its own scope; repeat rounds pack. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ReferenceScopeTest {
    private ReferenceScopeTest() {}

    private static final String NOT_EARLIER = ", which is not an earlier integer or bool field in its scope";

    static void run() {
        laterWhenReferenceIsRejected();
        laterCountReferenceIsRejected();
        outerReferenceInsideRepeatOrTimesIsRejected();
        referenceNamesIntegerOrBoolOnly();
        repeatSiblingReferenceRoundTrips();
        repeatRoundsCountNestedValueFields();
        sameScopeReferencesStillBuild();
    }

    private static void expectRefused(String label, Supplier<Scheme<Map>> build, String message) {
        PackbinTest.expectThrows(label, build::get, message);
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static void laterWhenReferenceIsRejected() {
        Scheme[] built = new Scheme[1];
        byte[][] wrote = {new byte[0]};
        PackbinTest.expectThrows("AC-1 when names a later field", () -> {
            built[0] = Maps.scheme(1, Packbin.when(0, Packbin.eq(1, 1), u8(0, "a")), u8(1, "b"));
            wrote[0] = BinaryPacker.pack(built[0], Maps.map("a", 5, "b", 1));
        }, "when 0 tests field 1" + NOT_EARLIER);
        PackbinTest.expectTrue("AC-1 later when: 0 schemes", built[0] == null);
        PackbinTest.expectEq("AC-1 later when: 0 bytes", 0, wrote[0].length);

        expectRefused("AC-1 vector when_names_later_field", () -> Maps.scheme(1,
                u8(0, "a"), Packbin.when(1, Packbin.eq(2, 1), u8(1, "b")), u8(2, "c")),
                "when 1 tests field 2" + NOT_EARLIER);
        expectRefused("AC-1 when names its own body", () -> Maps.scheme(1,
                Packbin.when(0, Packbin.eq(0, 1), u8(0, "a"))),
                "when 0 tests field 0" + NOT_EARLIER);
    }

    private static void laterCountReferenceIsRejected() {
        expectRefused("AC-2 sized count names a later field", () -> Maps.scheme(1,
                Packbin.sized(0, Access.get("p"), Access.set("p"), 1), u8(1, "n")),
                "sized 0 takes its count from field 1" + NOT_EARLIER);
        expectRefused("AC-2 bits count names a later field", () -> Maps.scheme(1,
                Packbin.bits(0, Access.get("p"), Access.set("p"), 1), u8(1, "n")),
                "bits 0 takes its count from field 1" + NOT_EARLIER);
        expectRefused("AC-2 packed count names a later field", () -> Maps.scheme(1,
                Packbin.packed(2, 0, Access.get("p"), Access.set("p"), 1, 0), u8(1, "n")),
                "packed 0 takes its count from field 1" + NOT_EARLIER);
        expectRefused("AC-2 times count names a later field", () -> Maps.scheme(1,
                Packbin.times(0, 1, u8(0, "x")), u8(1, "n")),
                "times 0 takes its count from field 1" + NOT_EARLIER);
        expectRefused("AC-2 vector count_names_later_field", () -> Maps.scheme(1,
                Packbin.sized(0, Access.get("payload"), Access.set("payload"), 1),
                Packbin.u16(1, Access.get("n"), Access.set("n"))),
                "sized 0 takes its count from field 1" + NOT_EARLIER);
        expectRefused("AC-2 sized count names itself", () -> Maps.scheme(1,
                Packbin.sized(0, Access.get("p"), Access.set("p"), 0)),
                "sized 0 takes its count from field 0" + NOT_EARLIER);
        expectRefused("AC-2 times count names its own body", () -> Maps.scheme(1,
                Packbin.times(0, 0, u8(0, "x"))),
                "times 0 takes its count from field 0" + NOT_EARLIER);
    }

    private static void outerReferenceInsideRepeatOrTimesIsRejected() {
        expectRefused("AC-3 when in repeat names an outer field", () -> Maps.scheme(1,
                u8(0, "p"),
                Packbin.repeat(1, u8(1, "x"), Packbin.when(2, Packbin.eq(0, 1), u8(2, "y")))),
                "when 2 tests field 0" + NOT_EARLIER);
        expectRefused("AC-3 when in times names an outer field", () -> Maps.scheme(1,
                u8(0, "p"),
                Packbin.times(1, 0, u8(1, "x"), Packbin.when(2, Packbin.eq(0, 1), u8(2, "y")))),
                "when 2 tests field 0" + NOT_EARLIER);
        expectRefused("AC-3 vector when_names_outer_field_in_repeat", () -> Maps.scheme(1,
                u8(0, "mode"),
                Packbin.repeat(1, Packbin.when(1, Packbin.eq(0, 1), u8(1, "v")))),
                "when 1 tests field 0" + NOT_EARLIER);
        expectRefused("AC-3 count in repeat names an outer field", () -> Maps.scheme(1,
                u8(0, "n"),
                Packbin.repeat(1, Packbin.sized(1, Access.get("p"), Access.set("p"), 0))),
                "sized 1 takes its count from field 0" + NOT_EARLIER);
        expectRefused("AC-3 count in times names an outer field", () -> Maps.scheme(1,
                u8(0, "n"),
                Packbin.times(1, 0, Packbin.sized(1, Access.get("p"), Access.set("p"), 0))),
                "sized 1 takes its count from field 0" + NOT_EARLIER);
        expectRefused("AC-3 field after a repeat names a field inside it", () -> Maps.scheme(1,
                Packbin.repeat(0, u8(0, "k")),
                Packbin.when(1, Packbin.eq(0, 1), u8(1, "v"))),
                "when 1 tests field 0" + NOT_EARLIER);
    }

    /** C++ is_count_source: a when or a count names an integer or a bool, never a float, bytes, text or a count field. */
    private static void referenceNamesIntegerOrBoolOnly() {
        expectRefused("F4 when names an f32", () -> Maps.scheme(1,
                Packbin.f32(0, Access.get("x"), Access.set("x")), Packbin.when(1, Packbin.eq(0, 1.5f), u8(1, "v"))),
                "when 1 tests field 0" + NOT_EARLIER);
        expectRefused("F4 when names an f64", () -> Maps.scheme(1,
                Packbin.f64(0, Access.get("x"), Access.set("x")), Packbin.when(1, Packbin.eq(0, 1.5), u8(1, "v"))),
                "when 1 tests field 0" + NOT_EARLIER);
        expectRefused("F4 when names bytes", () -> Maps.scheme(1,
                Packbin.bytes(0, Access.get("z"), Access.set("z"), 1),
                Packbin.when(1, Packbin.eq(0, new byte[] {1}), u8(1, "v"))),
                "when 1 tests field 0" + NOT_EARLIER);
        expectRefused("F4 when names utf8", () -> Maps.scheme(1,
                Packbin.utf8(0, Access.get("s"), Access.set("s")), Packbin.when(1, Packbin.eq(0, "a"), u8(1, "v"))),
                "when 1 tests field 0" + NOT_EARLIER);
        expectRefused("F4 count names utf8", () -> Maps.scheme(1,
                Packbin.utf8(0, Access.get("s"), Access.set("s")), Packbin.sized(1, Access.get("p"), Access.set("p"), 0)),
                "sized 1 takes its count from field 0" + NOT_EARLIER);
        expectRefused("F4 count names a sized field", () -> Maps.scheme(1,
                u8(0, "n"), Packbin.sized(1, Access.get("p"), Access.set("p"), 0),
                Packbin.times(2, 1, u8(2, "x"))),
                "times 2 takes its count from field 1" + NOT_EARLIER);

        Scheme<Map> slot = Maps.scheme(1,
                Packbin.u2(Packbin.u2Slot(0, Access.get("a"), Access.set("a")), Packbin.u2Slot(1, Access.get("b"), Access.set("b"))),
                Packbin.when(2, Packbin.eq(1, 3), u8(2, "v")));
        expectRoundTrip("F4 when names a u2 slot", slot, Maps.map("a", 0, "b", 3, "v", 9), "01" + "0c" + "09");
        Scheme<Map> signed = Maps.scheme(1,
                Packbin.i16(0, Access.get("n"), Access.set("n")),
                Packbin.when(1, Packbin.eq(0, -1), Packbin.u8(1, Access.get("v"), Access.set("v"))));
        expectRoundTrip("F4 when names an i16", signed, Maps.map("n", -1, "v", 4), "01" + "ffff" + "04");
    }

    /** Pack, or record the exception as a failure so the remaining tests still run. */
    private static String packHex(String label, Scheme<Map> scheme, Map<String, Object> row) {
        try {
            return PackbinTest.toHex(BinaryPacker.pack(scheme, row));
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": pack threw " + ex);
            return "";
        }
    }

    /** Pack, check the bytes, unpack, check the row, pack the row again and check the same bytes. */
    private static void expectRoundTrip(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        expectRoundTrip(label, scheme, row, hex, row);
    }

    private static void expectRoundTrip(
            String label, Scheme<Map> scheme, Map<String, Object> row, String hex, Map<String, Object> unpacked) {
        String packed = packHex(label, scheme, row);
        PackbinTest.expectEq(label + " bytes", hex, packed);
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(back -> got[0] = back));
        PackbinTest.expectTrue(label + " unpack ok (" + err + ")", err == null);
        if (got[0] != null) {
            PackbinTest.expectEq(label + " row", unpacked, got[0]);
            PackbinTest.expectEq(label + " repack", hex, packHex(label + " repack", scheme, got[0]));
        }
    }

    private static void repeatSiblingReferenceRoundTrips() {
        Scheme<Map> scheme = Maps.scheme(1, Packbin.repeat(0,
                u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "v"))));
        expectRoundTrip("AC-4 when names an earlier sibling of the same round", scheme,
                Maps.map("k", List.of(1, 2), "v", List.of(9)), "01" + "0109" + "02",
                Maps.map("k", List.of(1, 2), "v", Arrays.asList(9, null)));
    }

    private static void repeatRoundsCountNestedValueFields() {
        expectRoundTrip("AC-4 repeat of flags", Maps.scheme(1, Packbin.repeat(0,
                Packbin.flags(0, u8(0, "a")))),
                Maps.map("a", List.of(1, 2)), "01" + "0101" + "0102");
        expectRoundTrip("AC-4 repeat of a group", Maps.scheme(1, Packbin.repeat(0,
                Packbin.group(0, u8(0, "a"), u8(1, "b")))),
                Maps.map("a", List.of(1, 2), "b", List.of(3, 4)), "01" + "0103" + "0204");
        Field round = Packbin.flagByte();
        expectRoundTrip("AC-4 repeat of a split flag byte", Maps.scheme(1, Packbin.repeat(0,
                round, round.bit(u8(0, "a")))),
                Maps.map("a", List.of(7, 9)), "01" + "0107" + "0109");
        expectRoundTrip("AC-4 repeat with a when inside a group", Maps.scheme(1,
                Packbin.repeat(0, u8(0, "k"), Packbin.group(1,
                        Packbin.when(1, Packbin.eq(0, 1), u8(1, "v"))))),
                Maps.map("k", List.of(1, 1), "v", List.of(5, 6)), "01" + "0105" + "0106");
    }

    private static void sameScopeReferencesStillBuild() {
        Scheme<Map> times = Maps.scheme(1,
                u8(0, "n"),
                Packbin.times(1, 0, u8(1, "len"), Packbin.sized(2, Access.get("p"), Access.set("p"), 1)));
        Map<String, Object> row = Maps.map(
                "n", 2, "len", List.of(1, 2), "p", List.of(new byte[] {(byte) 0xaa}, new byte[] {(byte) 0xbb, (byte) 0xcc}));
        String hex = "01" + "02" + "01aa" + "02bbcc";
        PackbinTest.expectEq("AC-4 count names an earlier sibling of the same times round", hex,
                packHex("AC-4 times sibling count", times, row));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), times.on(back -> got[0] = back));
        PackbinTest.expectTrue("AC-4 times sibling count unpack ok", err == null);
        if (got[0] != null) {
            PackbinTest.expectEq("AC-4 times sibling count repack", hex, packHex("AC-4 times repack", times, got[0]));
        }

        Scheme<Map> element = Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"),
                Packbin.group(0, u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "v")))));
        expectRoundTrip("AC-4 when names an earlier field of the same list element", element,
                Maps.map("xs", List.of(Maps.map("k", 1, "v", 9), Maps.map("k", 2))), "01" + "0200" + "0109" + "02");

        Scheme<Map> flagged = Maps.scheme(1,
                Packbin.flags(0, u8(0, "n")),
                Packbin.when(1, Packbin.eq(0, 2), Packbin.sized(1, Access.get("p"), Access.set("p"), 0)));
        PackbinTest.expectEq("AC-4 references into an earlier flags of the same scope", "01" + "0102" + "abcd",
                packHex("AC-4 flags reference", flagged, Maps.map("n", 2, "p", new byte[] {(byte) 0xab, (byte) 0xcd})));
    }
}

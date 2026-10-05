package packbin;

import java.util.Map;
import java.util.function.Supplier;

/** AZ-2110: zero-width list/dict elements are errors, and a split flag bit needs its flag byte in scope. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ZeroWidthElementTest {
    private ZeroWidthElementTest() {}

    static void run() {
        zeroWidthListElementIsError();
        zeroWidthDictValueIsError();
        partlyZeroWidthElementIsError();
        emptyListOfZeroWidthStillUnpacks();
        orphanFlagBitIsConstructionError();
        sameScopeFlagBitStillBuilds();
    }

    private static Scheme<Map> listOfBytes0() {
        return Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"),
                Packbin.bytes(0, Access.identity(), Access.ignore(), 0)));
    }

    /** Interim ShortPacket: label "", needed 0, left = bytes left at the start of the element. */
    private static void expectEmptyElement(String label, Scheme<Map> scheme, String hex, int left) {
        expectEmptyElement(label, scheme, hex, left, HostileRun.LIMIT_MS);
    }

    private static void expectEmptyElement(String label, Scheme<Map> scheme, String hex, int left, long limitMs) {
        HostileRun run = HostileRun.of(scheme, PackbinTest.parseHex(hex), limitMs);
        PackbinTest.expectTrue(label + " finished", run.finished);
        PackbinTest.expectTrue(label + " -> " + run.kind() + " is ShortPacket", run.result instanceof Packbin.ShortPacket);
        PackbinTest.expectTrue(label + " handler not called", !run.handled);
        if (run.result instanceof Packbin.ShortPacket packet) {
            PackbinTest.expectEq(label + " field", "", packet.field);
            PackbinTest.expectEq(label + " needed", 0, packet.needed);
            PackbinTest.expectEq(label + " left", left, packet.left);
        }
    }

    /** Outer count 65535, then 65535 inner counts of ffff: about 131 KB asking for 4.3 billion empty items. */
    private static String amplifier() {
        StringBuilder hex = new StringBuilder("01ffff");
        for (int i = 0; i < 65535; i++) {
            hex.append("ffff");
        }
        return hex.toString();
    }

    private static void zeroWidthListElementIsError() {
        Scheme<Map> nested = Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"),
                Packbin.list(Access.identity(), Access.ignore(),
                        Packbin.bytes(0, Access.identity(), Access.ignore(), 0))));
        expectEmptyElement("AC-1 list of list of bytes(0), full counts", nested, "01ffffffff", 0);
        expectEmptyElement("AC-1 amplifier: 65535 inner counts of ffff", nested, amplifier(), 2 * (65535 - 1), 2000);
        expectEmptyElement("AC-1 two inner lists of 65535 empties", nested, "01" + "0200" + "ffff" + "ffff", 2);
        expectEmptyElement("AC-1 list of bytes(0), count 3", listOfBytes0(), "010300", 0);
    }

    private static void zeroWidthDictValueIsError() {
        Scheme<Map> dict = Maps.scheme(1, Packbin.dict(Access.get("m"), Access.set("m"),
                Packbin.bytes(0, Access.identity(), Access.ignore(), 0)));
        expectEmptyElement("AC-2 dict count ffff, one key", dict, "01ffff010061", 0);
        expectEmptyElement("AC-2 dict count 1, zero-width value", dict, "010100010061", 0);
    }

    /**
     * AZ-2089 F4: a when names only an integer or a bool, so the never-matching when on a bytes(0) field is refused
     * at construction. An element holding a repeat reads nothing only when no bytes are left, so it still reaches
     * the zero-width element guard for some packets and reads normally for others.
     */
    private static void partlyZeroWidthElementIsError() {
        PackbinTest.expectThrows("AC-3 when on a bytes(0) element field is refused", () -> Maps.scheme(1, Packbin.list(
                Access.get("xs"), Access.set("xs"),
                Packbin.group(0,
                        Packbin.bytes(0, Access.get("z"), Access.set("z"), 0),
                        Packbin.when(1, Packbin.eq(0, new byte[] {1}),
                                Packbin.u8(1, Access.get("v"), Access.set("v")))))),
                "when 1 tests field 0, which is not an earlier integer or bool field in its scope");
        Scheme<Map> list = Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"),
                Packbin.group(0, Packbin.repeat(0, Packbin.u8(0, Access.get("v"), Access.set("v"))))));
        expectEmptyElement("AC-3 element repeat with no bytes left, count 3", list, "010300", 0);
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("0101000506"), list.on(row -> got[0] = row));
        PackbinTest.expectTrue("AC-3 element repeat with bytes, count 1 ok", err == null);
        PackbinTest.expectEq("AC-3 element repeat with bytes, count 1 row",
                Maps.map("xs", java.util.List.of(Maps.map("v", java.util.List.of(5, 6)))), got[0]);
    }

    private static void emptyListOfZeroWidthStillUnpacks() {
        Scheme<Map> list = listOfBytes0();
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("010000"), list.on(row -> got[0] = row));
        PackbinTest.expectTrue("AC-4 empty list of zero-width ok", err == null);
        PackbinTest.expectEq("AC-4 empty list of zero-width value", java.util.List.of(), got[0].get("xs"));

        Scheme<Map> dict = Maps.scheme(1, Packbin.dict(Access.get("m"), Access.set("m"),
                Packbin.bytes(0, Access.identity(), Access.ignore(), 0)));
        Map[] dictGot = new Map[1];
        Object dictErr = BinaryPacker.unpack(PackbinTest.parseHex("010000"), dict.on(row -> dictGot[0] = row));
        PackbinTest.expectTrue("AC-4 empty dict of zero-width ok", dictErr == null);
        PackbinTest.expectEq("AC-4 empty dict of zero-width value", Map.of(), dictGot[0].get("m"));
    }

    private static void expectRefused(String label, Supplier<Scheme<Map>> build, String named) {
        try {
            build.get();
            PackbinTest.fail(label + ": scheme built, expected a construction error");
        } catch (IllegalArgumentException ex) {
            String message = ex.getMessage() == null ? "" : ex.getMessage();
            PackbinTest.expectEq(label + " message",
                    "flag bit " + named + " has no flagByte before it in the same scope", message);
        }
    }

    private static void orphanFlagBitIsConstructionError() {
        expectRefused("AC-5 byte inside a when, bit outside", () -> {
            packbin.Field fb = Packbin.flagByte();
            return Maps.scheme(1,
                    Packbin.u8(0, Access.get("sid"), Access.set("sid")),
                    Packbin.when(1, Packbin.eq(0, 9), fb),
                    fb.bit(Packbin.u8(1, Access.get("a"), Access.set("a"))));
        }, "U8 1");

        expectRefused("AC-5 byte outside the list element holding the bit", () -> {
            packbin.Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb, Packbin.list(Access.get("xs"), Access.set("xs"),
                    fb.bit(Packbin.u8(0, Access.identity(), Access.ignore()))));
        }, "U8 0");

        expectRefused("AC-5 byte outside the repeat holding the bit", () -> {
            packbin.Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb, Packbin.repeat(0,
                    fb.bit(Packbin.u8(0, Access.get("a"), Access.set("a")))));
        }, "U8 0");

        expectRefused("AC-5 byte outside the times round holding the bit", () -> {
            packbin.Field fb = Packbin.flagByte();
            return Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")), fb,
                    Packbin.times(1, 0, fb.bit(Packbin.u8(1, Access.get("a"), Access.set("a")))));
        }, "U8 1");

        expectRefused("AC-5 byte never in the scheme", () -> {
            packbin.Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb.bit(Packbin.u8(0, Access.get("a"), Access.set("a"))));
        }, "U8 0");

        expectRefused("AC-5 nested-row group bit, byte missing", () -> {
            packbin.Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb.bit(Packbin.group(Access.get("g"), Access.set("g"),
                    Packbin.u8(0, Access.get("a"), Access.set("a")))));
        }, "GROUP");

        expectRefused("AC-5 bit before its byte", () -> {
            packbin.Field fb = Packbin.flagByte();
            return Maps.scheme(1, fb.bit(Packbin.u8(0, Access.get("a"), Access.set("a"))), fb);
        }, "U8 0");
    }

    private static void sameScopeFlagBitStillBuilds() {
        packbin.Field top = Packbin.flagByte();
        Scheme<Map> topLevel = Maps.scheme(1,
                Packbin.u8(0, Access.get("sid"), Access.set("sid")),
                top,
                Packbin.when(1, Packbin.eq(0, 9), top.bit(Packbin.u8(1, Access.get("a"), Access.set("a")))),
                top.bit(Packbin.u16(2, Access.get("heading"), Access.set("heading"))));
        byte[] raw = BinaryPacker.pack(topLevel, Maps.map("sid", 9, "heading", 90));
        PackbinTest.expectEq("AC-5 same scope pack", "01" + "09" + "02" + "5a00",
                PackbinTest.toHex(raw));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(raw, topLevel.on(row -> got[0] = row));
        PackbinTest.expectTrue("AC-5 same scope unpack ok", err == null);
        PackbinTest.expectEq("AC-5 same scope row", Maps.map("sid", 9, "heading", 90), got[0]);

        packbin.Field inRound = Packbin.flagByte();
        Maps.scheme(1, Packbin.repeat(0, inRound, inRound.bit(Packbin.u8(0, Access.get("a"), Access.set("a")))));
        packbin.Field inTimes = Packbin.flagByte();
        Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")), Packbin.times(1, 0, inTimes,
                inTimes.bit(Packbin.u8(1, Access.get("a"), Access.set("a")))));
    }
}

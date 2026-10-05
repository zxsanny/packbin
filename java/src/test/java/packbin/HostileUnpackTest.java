package packbin;

import java.util.Map;

/** AZ-2074: crafted packets come back as error values, never as a hang or an exception. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileUnpackTest {
    private HostileUnpackTest() {}

    static void run() {
        zeroProgressRepeatEnds();
        zeroWidthTimesIsErrorValue();
        negativeCountIsErrorValue();
        oversizeCountIsShortPacket();
        countBehindClearFlagIsErrorValue();
        invalidUtf8IsErrorValue();
        validUtf8Unchanged();
    }

    /** Interim rule (C15): Java has no BadValue type, so any non-ok, non-exception result passes. */
    private static void expectErrorValue(String label, Scheme<Map> scheme, String hex) {
        HostileRun run = HostileRun.of(scheme, hex);
        PackbinTest.expectTrue(label + " -> " + run.kind() + " is an error value", run.isErrorValue());
    }

    private static void expectShort(String label, Scheme<Map> scheme, String hex, String field, int left) {
        HostileRun run = HostileRun.of(scheme, hex);
        PackbinTest.expectTrue(label + " -> " + run.kind() + " is ShortPacket", run.result instanceof Packbin.ShortPacket);
        PackbinTest.expectTrue(label + " handler not called", !run.handled);
        PackbinTest.expectTrue(label + " no exception (" + run.kind() + ")", run.thrown == null);
        if (run.result instanceof Packbin.ShortPacket packet) {
            PackbinTest.expectEq(label + " field", field, packet.field);
            PackbinTest.expectEq(label + " left", left, packet.left);
        }
    }

    private static void zeroProgressRepeatEnds() {
        Scheme<Map> zeroWidth = Maps.scheme(1, Packbin.repeat(
                0, Packbin.bytes(0, Access.get("b"), Access.set("b"), 0)));
        HostileRun run = HostileRun.of(zeroWidth, PackbinTest.parseHex("0109"), 2000);
        PackbinTest.expectTrue("AC-1 repeat thread finished", run.finished);
        PackbinTest.expectTrue("AC-1 repeat -> " + run.kind() + " is TrailingBytes", run.result instanceof Packbin.TrailingBytes);
        PackbinTest.expectTrue("AC-1 repeat handler not called", !run.handled);
        if (run.result instanceof Packbin.TrailingBytes trailing) {
            PackbinTest.expectEq("AC-1 repeat left", 1, trailing.left);
        }

        HostileRun two = HostileRun.of(zeroWidth, PackbinTest.parseHex("010909"), 2000);
        PackbinTest.expectTrue("AC-1 repeat two bytes -> " + two.kind(), two.result instanceof Packbin.TrailingBytes);
        if (two.result instanceof Packbin.TrailingBytes trailing) {
            PackbinTest.expectEq("AC-1 repeat two bytes left", 2, trailing.left);
        }

        Scheme<Map> mixed = Maps.scheme(1, Packbin.repeat(0, Packbin.u8(0, Access.get("v"), Access.set("v"))));
        HostileRun fine = HostileRun.of(mixed, PackbinTest.parseHex("01010203"), 2000);
        PackbinTest.expectTrue("AC-1 productive repeat still ok", fine.finished && fine.result == null && fine.handled);
    }

    /** A times round that reads 0 bytes is an error (interim ShortPacket: label "times", needed 0, left at round start). */
    private static void expectEmptyRound(String label, Scheme<Map> scheme, String hex, int left) {
        HostileRun run = HostileRun.of(scheme, PackbinTest.parseHex(hex), 2000);
        PackbinTest.expectTrue(label + " finished", run.finished);
        PackbinTest.expectTrue(label + " -> " + run.kind() + " is ShortPacket", run.result instanceof Packbin.ShortPacket);
        PackbinTest.expectTrue(label + " handler not called", !run.handled);
        if (run.result instanceof Packbin.ShortPacket packet) {
            PackbinTest.expectEq(label + " field", "times", packet.field);
            PackbinTest.expectEq(label + " needed", 0, packet.needed);
            PackbinTest.expectEq(label + " left", left, packet.left);
        }
    }

    private static void zeroWidthTimesIsErrorValue() {
        Scheme<Map> u64 = Maps.scheme(1,
                Packbin.u64(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.bytes(1, Access.get("b"), Access.set("b"), 0)));
        expectEmptyRound("AC-1 times u64 count, zero-width body", u64, "01ffffffffffffff7f", 0);

        Scheme<Map> u32 = Maps.scheme(1,
                Packbin.u32(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.bytes(1, Access.get("b"), Access.set("b"), 0)));
        expectEmptyRound("AC-1 times u32 count, zero-width body", u32, "01ffffffff", 0);

        Scheme<Map> never = Maps.scheme(1,
                Packbin.u8(0, Access.get("mode"), Access.set("mode")),
                Packbin.u32(1, Access.get("n"), Access.set("n")),
                Packbin.times(2, 1, Packbin.when(2, Packbin.eq(0, 1),
                        Packbin.u8(2, Access.get("v"), Access.set("v")))));
        expectEmptyRound("AC-1 times never-true when body", never, "0100ffffffff", 0);

        Scheme<Map> small = Maps.scheme(1,
                Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.bytes(1, Access.get("b"), Access.set("b"), 0)));
        expectEmptyRound("AC-1 times count 3, zero-width body", small, "0103", 0);
        expectEmptyRound("AC-1 times count 3, zero-width body, byte left", small, "010399", 1);

        HostileRun none = HostileRun.of(small, "0100");
        PackbinTest.expectTrue("AC-1 times count 0 still ok", none.finished && none.result == null && none.handled);
    }

    private static void negativeCountIsErrorValue() {
        Scheme<Map> sized = Maps.scheme(1,
                Packbin.i8(0, Access.get("n"), Access.set("n")),
                Packbin.sized(1, Access.get("p"), Access.set("p"), 0));
        expectErrorValue("AC-2 negative count sized", sized, "01ff");
        expectErrorValue("AC-2 negative count sized with payload", sized, "01ff61");

        Scheme<Map> bits = Maps.scheme(1,
                Packbin.i8(0, Access.get("n"), Access.set("n")),
                Packbin.bits(1, Access.get("p"), Access.set("p"), 0));
        expectErrorValue("AC-2 negative count bits", bits, "01ff");

        Scheme<Map> packed = Maps.scheme(1,
                Packbin.i8(0, Access.get("n"), Access.set("n")),
                Packbin.packed(2, 1, Access.get("k"), Access.set("k"), 0, 0));
        expectErrorValue("AC-2 negative count packed", packed, "01ff");

        Scheme<Map> times = Maps.scheme(1,
                Packbin.i8(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.u8(1, Access.get("x"), Access.set("x"))));
        expectErrorValue("AC-2 negative count times", times, "01ff");

        Scheme<Map> biased = Maps.scheme(1,
                Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.packed(1, 1, Access.get("k"), Access.set("k"), 0, -1));
        expectErrorValue("AC-2 count 0 with bias -1 packed", biased, "0100");

        Scheme<Map> i64 = Maps.scheme(1,
                Packbin.i64(0, Access.get("n"), Access.set("n")),
                Packbin.sized(1, Access.get("p"), Access.set("p"), 0));
        expectErrorValue("AC-2 i64 minimum count sized", i64, "010000000000000080");
    }

    private static void oversizeCountIsShortPacket() {
        Scheme<Map> u32Sized = Maps.scheme(1,
                Packbin.u32(0, Access.get("n"), Access.set("n")),
                Packbin.sized(1, Access.get("p"), Access.set("p"), 0));
        expectShort("AC-3 u32 max sized", u32Sized, "01ffffffff", "1", 0);
        expectShort("AC-3 u32 max sized one byte left", u32Sized, "01ffffffff61", "1", 1);
        expectShort("AC-3 u32 2^31 sized", u32Sized, "010000008061", "1", 1);

        Scheme<Map> u32Bits = Maps.scheme(1,
                Packbin.u32(0, Access.get("n"), Access.set("n")),
                Packbin.bits(1, Access.get("p"), Access.set("p"), 0));
        expectShort("AC-3 u32 2^31 bits", u32Bits, "0100000080", "1", 0);

        Scheme<Map> u32Packed = Maps.scheme(1,
                Packbin.u32(0, Access.get("n"), Access.set("n")),
                Packbin.packed(2, 1, Access.get("k"), Access.set("k"), 0, 0));
        expectShort("AC-3 u32 max packed", u32Packed, "01ffffffff", "1", 0);

        Scheme<Map> u32Times = Maps.scheme(1,
                Packbin.u32(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.u8(1, Access.get("x"), Access.set("x"))));
        expectShort("AC-3 u32 max times", u32Times, "01ffffffff00", "1", 0);

        Scheme<Map> u64Sized = Maps.scheme(1,
                Packbin.u64(0, Access.get("n"), Access.set("n")),
                Packbin.sized(1, Access.get("p"), Access.set("p"), 0));
        expectShort("AC-3 u64 max sized", u64Sized, "01ffffffffffffffff61", "1", 1);
        expectShort("AC-3 u64 long max sized", u64Sized, "01ffffffffffffff7f61", "1", 1);
        expectShort("AC-3 u64 2^32 sized wraps to 0 when narrowed", u64Sized, "01000000000100000061", "1", 1);

        Scheme<Map> u64Bits = Maps.scheme(1,
                Packbin.u64(0, Access.get("n"), Access.set("n")),
                Packbin.bits(1, Access.get("p"), Access.set("p"), 0));
        expectShort("AC-3 u64 long max bits", u64Bits, "01ffffffffffffff7f", "1", 0);

        Scheme<Map> u64Packed = Maps.scheme(1,
                Packbin.u64(0, Access.get("n"), Access.set("n")),
                Packbin.packed(1, 1, Access.get("k"), Access.set("k"), 0, 0));
        expectShort("AC-3 u64 long max packed", u64Packed, "01ffffffffffffff7f", "1", 0);

        Scheme<Map> list = Maps.scheme(1, Packbin.list(
                Access.get("xs"), Access.set("xs"), Packbin.u8(0, Access.identity(), Access.ignore())));
        expectShort("AC-3 list count 65535", list, "01ffff", "0", 0);
    }

    private static void countBehindClearFlagIsErrorValue() {
        Scheme<Map> sized = Maps.scheme(1,
                Packbin.flags(0, Packbin.u8(0, Access.get("n"), Access.set("n"))),
                Packbin.sized(1, Access.get("p"), Access.set("p"), 0));
        expectErrorValue("AC-4 count behind clear flag sized", sized, "010009");
        expectErrorValue("AC-4 count behind clear flag sized, no payload", sized, "0100");

        Scheme<Map> bits = Maps.scheme(1,
                Packbin.flags(0, Packbin.u8(0, Access.get("n"), Access.set("n"))),
                Packbin.bits(1, Access.get("p"), Access.set("p"), 0));
        expectErrorValue("AC-4 count behind clear flag bits", bits, "0100");

        Scheme<Map> packed = Maps.scheme(1,
                Packbin.flags(0, Packbin.u8(0, Access.get("n"), Access.set("n"))),
                Packbin.packed(1, 1, Access.get("k"), Access.set("k"), 0, 0));
        expectErrorValue("AC-4 count behind clear flag packed", packed, "0100");

        Scheme<Map> times = Maps.scheme(1,
                Packbin.flags(0, Packbin.u8(0, Access.get("n"), Access.set("n"))),
                Packbin.times(1, 0, Packbin.u8(1, Access.get("x"), Access.set("x"))));
        expectErrorValue("AC-4 count behind clear flag times", times, "0100");

        HostileRun set = HostileRun.of(sized, "01010109");
        PackbinTest.expectTrue("AC-4 count behind set flag still reads", set.finished && set.result == null && set.handled);
    }

    private static void invalidUtf8IsErrorValue() {
        Scheme<Map> name = Maps.scheme(1, Packbin.utf8(0, Access.get("name"), Access.set("name")));
        expectErrorValue("AC-5 utf8 ff fe", name, "010200fffe");
        expectErrorValue("AC-5 utf8 c3 28", name, "010200c328");
        expectErrorValue("AC-5 utf8 overlong c0 80", name, "010200c080");
        expectErrorValue("AC-5 utf8 encoded surrogate ed a0 80", name, "010300eda080");
        expectErrorValue("AC-5 utf8 truncated sequence e2 82", name, "010200e282");

        Scheme<Map> dict = Maps.scheme(1, Packbin.dict(
                Access.get("m"), Access.set("m"), Packbin.utf8(0, Access.identity(), Access.ignore())));
        expectErrorValue("AC-5 dict key ff", dict, "0101000100ff0000");

        Scheme<Map> list = Maps.scheme(1, Packbin.list(
                Access.get("xs"), Access.set("xs"), Packbin.utf8(0, Access.identity(), Access.ignore())));
        expectErrorValue("AC-5 list element ff", list, "0101000100ff");
    }

    private static void validUtf8Unchanged() {
        Scheme<Map> name = Maps.scheme(1, Packbin.utf8(0, Access.get("name"), Access.set("name")));
        String text = "héllo € 😀";
        byte[] raw = BinaryPacker.pack(name, Maps.map("name", text));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(raw, name.on(row -> got[0] = row));
        PackbinTest.expectTrue("AC-5 valid multibyte ok", err == null);
        PackbinTest.expectEq("AC-5 valid multibyte text", text, got[0].get("name"));
        PackbinTest.expectEq("AC-5 valid multibyte repack", PackbinTest.toHex(raw), PackbinTest.toHex(BinaryPacker.pack(name, got[0])));

        Scheme<Map> dict = Maps.scheme(1, Packbin.dict(
                Access.get("m"), Access.set("m"), Packbin.u8(0, Access.identity(), Access.ignore())));
        byte[] dictRaw = BinaryPacker.pack(dict, Maps.map("m", Map.of("é€", 7, "k", 1)));
        Map[] dictGot = new Map[1];
        Object dictErr = BinaryPacker.unpack(dictRaw, dict.on(row -> dictGot[0] = row));
        PackbinTest.expectTrue("AC-5 valid multibyte dict key ok", dictErr == null);
        PackbinTest.expectEq("AC-5 valid multibyte dict key", 7, ((Number) ((Map<?, ?>) dictGot[0].get("m")).get("é€")).intValue());
    }
}

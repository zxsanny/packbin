package packbin;

import java.math.BigDecimal;
import java.math.BigInteger;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * AZ-2190: pack writes an integer field only for a whole number inside its range and a float field only for a
 * number, and every refusal is an IllegalArgumentException that names the member by its field id.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class PackStrictTest {
    private PackStrictTest() {}

    static void run() {
        ac1WrappingBigIntegerIsRefused();
        ac2OutOfRangeIntegersAreRefused();
        ac3FractionsStringsAndBooleansAreRefusedForIntegers();
        ac4StringsAndBooleansAreRefusedForFloats();
        ac5F32OverflowIsRefusedAndSpecialsAreWritten();
        oversizeBigNumbersAreRefusedForBothFloats();
        oddNumbersAreRefusedForIntegers();
        ac6ValidRowsKeepTheirBytes();
        ac7SessionPackRefusesTheSame();
        refusalsReachEveryPlaceAScalarIsPacked();
    }

    private static Field scalar(String kind) {
        Getter get = Access.get("a");
        Setter set = Access.set("a");
        return switch (kind) {
            case "u8" -> Packbin.u8(0, get, set);
            case "i8" -> Packbin.i8(0, get, set);
            case "u16" -> Packbin.u16(0, get, set);
            case "i16" -> Packbin.i16(0, get, set);
            case "u32" -> Packbin.u32(0, get, set);
            case "i32" -> Packbin.i32(0, get, set);
            case "u64" -> Packbin.u64(0, get, set);
            case "i64" -> Packbin.i64(0, get, set);
            case "f32" -> Packbin.f32(0, get, set);
            case "f64" -> Packbin.f64(0, get, set);
            case "u16be" -> Packbin.be(Packbin.u16(0, get, set));
            default -> throw new IllegalArgumentException(kind);
        };
    }

    private static Scheme<Map> scheme(String kind) {
        return Maps.scheme(1, scalar(kind));
    }

    private static void expectRefused(String label, Scheme<Map> scheme, Object value) {
        byte[][] wrote = {null};
        try {
            wrote[0] = BinaryPacker.pack(scheme, Maps.map("a", value));
        } catch (IllegalArgumentException ex) {
            PackbinTest.expectTrue(label + ": exactly IllegalArgumentException, got " + ex.getClass().getName(),
                    ex.getClass() == IllegalArgumentException.class);
            PackbinTest.expectTrue(label + ": message names field 0: \"" + ex.getMessage() + "\"",
                    ex.getMessage() != null && ex.getMessage().startsWith("0: "));
            return;
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": threw " + ex + ", expected IllegalArgumentException");
            return;
        }
        PackbinTest.fail(label + ": packed " + PackbinTest.toHex(wrote[0]) + ", expected a refusal");
    }

    private static void expectRefused(String label, String kind, Object value) {
        expectRefused(label, scheme(kind), value);
    }

    private static void expectBytes(String label, String kind, Object value, String hex) {
        try {
            PackbinTest.expectEq(label, hex, PackbinTest.toHex(BinaryPacker.pack(scheme(kind), Maps.map("a", value))));
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": pack threw " + ex);
        }
    }

    private static void ac1WrappingBigIntegerIsRefused() {
        BigInteger two63 = BigInteger.ONE.shiftLeft(63);
        expectRefused("AC-1 i64 BigInteger 2^63", "i64", two63);
        expectRefused("AC-1 u8 BigInteger 2^64 + 5", "u8", BigInteger.ONE.shiftLeft(64).add(BigInteger.valueOf(5)));
        expectRefused("AC-1 i64 BigInteger -2^63 - 1", "i64", two63.negate().subtract(BigInteger.ONE));
        expectBytes("AC-1 i64 BigInteger -2^63 still packs", "i64", two63.negate(), "01" + "0000000000000080");
        expectBytes("AC-1 i64 BigInteger 2^63 - 1 still packs", "i64", two63.subtract(BigInteger.ONE), "01" + "ffffffffffffff7f");
        expectBytes("AC-1 u8 BigInteger 200 still packs", "u8", BigInteger.valueOf(200), "01c8");
    }

    private static void ac2OutOfRangeIntegersAreRefused() {
        expectRefused("AC-2 u8 300", "u8", 300);
        expectRefused("AC-2 u8 -1", "u8", -1);
        expectRefused("AC-2 i8 200", "i8", 200);
        expectRefused("AC-2 u16 65536", "u16", 65536);
        expectRefused("AC-2 i16 -32769", "i16", -32769);
        expectRefused("AC-2 u32 4294967296", "u32", 4294967296L);
        expectRefused("AC-2 i32 3000000000", "i32", 3000000000L);
        expectRefused("AC-2 u64 Integer -1", "u64", -1);
        expectRefused("AC-2 u16 big endian 65536", "u16be", 65536);
    }

    private static void ac3FractionsStringsAndBooleansAreRefusedForIntegers() {
        expectRefused("AC-3 u8 Double 1.7", "u8", 1.7);
        expectRefused("AC-3 u8 Float 1.7", "u8", 1.7f);
        expectRefused("AC-3 u8 BigDecimal 1.5", "u8", new BigDecimal("1.5"));
        expectRefused("AC-3 u8 \"5\"", "u8", "5");
        expectRefused("AC-3 u8 true", "u8", true);
        expectRefused("AC-3 i32 BigDecimal 1.5", "i32", new BigDecimal("1.5"));
        expectBytes("AC-3 a whole BigDecimal 5 still packs", "u8", new BigDecimal("5"), "0105");
        expectBytes("AC-3 a whole BigDecimal 5.0 still packs", "u8", new BigDecimal("5.0"), "0105");
        expectBytes("AC-3 an AtomicInteger still packs", "u16", new AtomicInteger(258), "010201");
        expectBytes("AC-3 a Short still packs", "i16", (short) -2, "01feff");
        expectRefused("AC-3 u8 BigDecimal 1E+999999999 is refused without being expanded", "u8", new BigDecimal("1E+999999999"));
        expectRefused("AC-3 u8 AtomicLong 300", "u8", new AtomicLong(300));
        expectRefused("AC-3 u8 BigDecimal 300", "u8", new BigDecimal("300"));
    }

    private static void ac4StringsAndBooleansAreRefusedForFloats() {
        for (String kind : new String[] {"f64", "f32"}) {
            expectRefused("AC-4 " + kind + " \"1.5\"", kind, "1.5");
            expectRefused("AC-4 " + kind + " \"abc\"", kind, "abc");
            expectRefused("AC-4 " + kind + " true", kind, true);
        }
        PackbinTest.expectThrows("AC-4 f32 null in a round names the member", () -> BinaryPacker.pack(
                Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")),
                        Packbin.times(1, 0, Packbin.f32(1, Access.get("a"), Access.set("a")))),
                Maps.map("n", 2, "a", java.util.Arrays.asList(1.5f, null))), "1: expected number, got null");
    }

    private static void ac5F32OverflowIsRefusedAndSpecialsAreWritten() {
        expectRefused("AC-5 f32 1e39", "f32", 1e39);
        expectRefused("AC-5 f32 -1e39", "f32", -1e39);
        expectBytes("AC-5 f32 Infinity", "f32", Double.POSITIVE_INFINITY, "01" + "0000807f");
        expectBytes("AC-5 f32 NaN", "f32", Double.NaN, "01" + "0000c07f");
        expectBytes("AC-5 f32 -Infinity", "f32", Float.NEGATIVE_INFINITY, "01" + "000080ff");
        expectBytes("AC-5 f64 1e39 is finite for f64", "f64", 1e39, "01" + doubleHex(1e39));
    }

    /** A finite BigInteger or BigDecimal past the double range is not an explicit infinity: both floats refuse it. */
    private static void oversizeBigNumbersAreRefusedForBothFloats() {
        BigDecimal hugeDecimal = new BigDecimal("1E+400");
        BigInteger hugeInteger = BigInteger.ONE.shiftLeft(100000);
        for (String kind : new String[] {"f32", "f64"}) {
            expectRefused("floats " + kind + " BigDecimal 1E+400", kind, hugeDecimal);
            expectRefused("floats " + kind + " BigDecimal -1E+400", kind, hugeDecimal.negate());
            expectRefused("floats " + kind + " BigInteger 2^100000", kind, hugeInteger);
            expectRefused("floats " + kind + " BigInteger -2^100000", kind, hugeInteger.negate());
        }
        expectBytes("floats f64 BigDecimal 1.5 still packs", "f64", new BigDecimal("1.5"), "01" + doubleHex(1.5));
        expectBytes("floats f32 BigInteger 2^100 is finite for f32", "f32", BigInteger.ONE.shiftLeft(100), "01" + "00008071");
        expectBytes("floats f32 Float.POSITIVE_INFINITY", "f32", Float.POSITIVE_INFINITY, "01" + "0000807f");
        expectBytes("floats f32 Double.NEGATIVE_INFINITY", "f32", Double.NEGATIVE_INFINITY, "01" + "000080ff");
        expectBytes("floats f32 NaN", "f32", Float.NaN, "01" + "0000c07f");
        expectBytes("floats f64 Float.POSITIVE_INFINITY", "f64", Float.POSITIVE_INFINITY, "01" + doubleHex(Double.POSITIVE_INFINITY));
        expectBytes("floats f64 Double.NEGATIVE_INFINITY", "f64", Double.NEGATIVE_INFINITY, "01" + doubleHex(Double.NEGATIVE_INFINITY));
        expectBytes("floats f64 NaN", "f64", Double.NaN, "01" + doubleHex(Double.NaN));
    }

    /** A Number that is no JDK type: its text decides, and a text that is missing or not a number is refused. */
    private static final class OddNumber extends Number {
        private final String text;

        OddNumber(String text) {
            this.text = text;
        }

        @Override public int intValue() { return 7; }
        @Override public long longValue() { return 7; }
        @Override public float floatValue() { return 7; }
        @Override public double doubleValue() { return 7; }
        @Override public String toString() { return text; }
    }

    private static void oddNumbersAreRefusedForIntegers() {
        expectRefused("odd Number whose text is null", "u8", new OddNumber(null));
        expectRefused("odd Number whose text is not a number", "u8", new OddNumber("seven"));
        expectBytes("odd Number whose text is 7 packs", "u8", new OddNumber("7"), "0107");
    }

    private static String doubleHex(double value) {
        long bits = Double.doubleToLongBits(value);
        StringBuilder out = new StringBuilder();
        for (int i = 0; i < 8; i++) {
            out.append(String.format("%02x", (bits >>> (8 * i)) & 0xFF));
        }
        return out.toString();
    }

    private static void ac6ValidRowsKeepTheirBytes() {
        expectBytes("AC-6 u8 0", "u8", 0, "0100");
        expectBytes("AC-6 u8 255", "u8", 255, "01ff");
        expectBytes("AC-6 i8 -128", "i8", -128, "0180");
        expectBytes("AC-6 i8 127", "i8", 127, "017f");
        expectBytes("AC-6 u16 65535", "u16", 65535, "01ffff");
        expectBytes("AC-6 u16 big endian 258", "u16be", 258, "010102");
        expectBytes("AC-6 u32 4294967295", "u32", 4294967295L, "01ffffffff");
        expectBytes("AC-6 i32 min", "i32", Integer.MIN_VALUE, "0100000080");
        expectBytes("AC-6 i64 min", "i64", Long.MIN_VALUE, "010000000000000080");
        expectBytes("AC-6 u64 Long -1", "u64", -1L, "01ffffffffffffffff");
        expectBytes("AC-6 u64 Integer 7", "u64", 7, "010700000000000000");
        expectBytes("AC-6 f32 3.5", "f32", 3.5, "01" + "00006040");
        expectBytes("AC-6 f64 1.5", "f64", 1.5, "01" + "000000000000f83f");
        expectBytes("AC-6 f64 Integer 2", "f64", 2, "01" + "0000000000000040");

        Scheme<Map> u64 = scheme("u64");
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("01ffffffffffffffff"), u64.on(r -> got[0] = r));
        PackbinTest.expectTrue("AC-6 u64 above 2^63 unpacks (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq("AC-6 unpack then repack of a u64 above 2^63", "01ffffffffffffffff",
                got[0] == null ? "" : PackbinTest.toHex(BinaryPacker.pack(u64, got[0])));
    }

    private static void ac7SessionPackRefusesTheSame() {
        byte[] seed = new byte[PackSession.SEED_SIZE];
        PackSession sender = PackSession.load(seed);
        PackSession reader = PackSession.load(seed);
        byte[] nonce = sender.start();
        PackbinTest.expectTrue("AC-7 session opens", nonce != null && reader.join(nonce));
        Scheme<Map> u8 = scheme("u8");
        Scheme<Map> f32 = scheme("f32");
        Scheme<Map> i64 = scheme("i64");
        expectSessionRefused("AC-7 u8 300", sender, u8, 300);
        expectSessionRefused("AC-7 u8 \"5\"", sender, u8, "5");
        expectSessionRefused("AC-7 u8 BigDecimal 1.5", sender, u8, new BigDecimal("1.5"));
        expectSessionRefused("AC-7 f32 1e39", sender, f32, 1e39);
        expectSessionRefused("AC-7 f32 true", sender, f32, true);
        expectSessionRefused("AC-7 i64 BigInteger 2^63", sender, i64, BigInteger.ONE.shiftLeft(63));

        Map[] got = new Map[1];
        byte[] sealed = sender.pack(u8, Maps.map("a", 7));
        Object err = reader.unpack(sealed, u8.on(r -> got[0] = r));
        PackbinTest.expectTrue("AC-7 the next valid row is read by the peer (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq("AC-7 a", 7, got[0] == null ? null : got[0].get("a"));
    }

    private static void expectSessionRefused(String label, PackSession session, Scheme<Map> scheme, Object value) {
        try {
            session.pack(scheme, Maps.map("a", value));
        } catch (IllegalArgumentException ex) {
            PackbinTest.expectTrue(label + ": names field 0: \"" + ex.getMessage() + "\"",
                    ex.getClass() == IllegalArgumentException.class && ex.getMessage().startsWith("0: "));
            return;
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": threw " + ex + ", expected IllegalArgumentException");
            return;
        }
        PackbinTest.fail(label + ": packed, expected a refusal");
    }

    /** The same check runs under flags and when, in repeat and times rounds, and in list and dict elements. */
    private static void refusalsReachEveryPlaceAScalarIsPacked() {
        Scheme<Map> flags = Maps.scheme(1, Packbin.flags(0, scalar("u8")));
        expectRefused("places: u8 300 under flags", flags, 300);

        Scheme<Map> when = Maps.scheme(1, Packbin.u8(0, Access.get("k"), Access.set("k")),
                Packbin.when(1, Packbin.eq(0, 1), Packbin.u8(1, Access.get("a"), Access.set("a"))));
        PackbinTest.expectThrows("places: u8 300 under when", () ->
                BinaryPacker.pack(when, Maps.map("k", 1, "a", 300)), "1: 300 does not fit");

        Scheme<Map> repeat = Maps.scheme(1, Packbin.repeat(0, scalar("u8")));
        expectRefused("places: u8 [1, 300] in a repeat round", repeat, List.of(1, 300));
        expectRefused("places: u8 [1, \"2\"] in a repeat round", repeat, List.of(1, "2"));
        Scheme<Map> times = Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.f32(1, Access.get("a"), Access.set("a"))));
        PackbinTest.expectThrows("places: f32 true in a times round", () ->
                BinaryPacker.pack(times, Maps.map("n", 1, "a", List.of(true))), "1: expected number, got Boolean");

        Scheme<Map> list = Maps.scheme(1, Packbin.list(Access.get("a"), Access.set("a"),
                Packbin.u8(0, Access.identity(), Access.ignore())));
        PackbinTest.expectThrows("places: u8 300 in a list element", () ->
                BinaryPacker.pack(list, Maps.map("a", List.of(1, 300))), "0: 300 does not fit");
        Scheme<Map> dict = Maps.scheme(1, Packbin.dict(Access.get("a"), Access.set("a"),
                Packbin.i8(0, Access.identity(), Access.ignore())));
        PackbinTest.expectThrows("places: i8 200 in a dict element", () ->
                BinaryPacker.pack(dict, Maps.map("a", Maps.map("k", 200))), "0: 200 does not fit");
    }
}

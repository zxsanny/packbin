package packbin;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** AZ-3503 AC-1 to AC-7: the percentage setting, the count and bytes, the round trip, the repair, the limit, dispatch. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class PercentSchemeTest {
    private static final int[] PERCENTS = {0, 10, 25, 50, 100};
    private static final int[] LENGTHS = {0, 1, 3, 10, 40, 100, 222};

    private PercentSchemeTest() {}

    static void run() {
        theSetting();
        countAndBytes();
        largestMessage();
        everyPairRoundTrips();
        impossibleLengthsAndLongBuffers();
        repairWithTheCountOfThatMessage();
        correctionLimit();
        dispatch();
        theSearchIsCheap();
    }

    /** The count by a loop, not by the shipped formula: the least n with n * 100 at least p * L, at most 32. */
    private static int countOf(int p, int length) {
        int n = 0;
        while (n < 32 && n * 100 < p * length) {
            n++;
        }
        return n;
    }

    private static int largestOf(int p) {
        int length = 0;
        while (length + 1 + countOf(p, length + 1) <= 254) {
            length++;
        }
        return length;
    }

    private static void theSetting() {
        // Arrange
        Scheme<PositionRow> plain = EccSupport.positionScheme(0);

        // Act
        Scheme<PositionRow> pct = plain.withParityPercent(25);
        Scheme<PositionRow> tuned = pct.withMaxBytes(100).withLimits(7, 50);

        // Assert
        PackbinTest.expectEq("PP-1 a scheme declares no percentage unless told to", 0, plain.parityPercent());
        PackbinTest.expectEq("PP-1 withParityPercent sets it", 25, pct.parityPercent());
        PackbinTest.expectEq("PP-1 the first scheme is unchanged", 0, plain.parityPercent());
        PackbinTest.expectEq("PP-1 the limit setters keep the percentage", 25, tuned.parityPercent());
        PackbinTest.expectEq("PP-1 withParityPercent keeps the limits", 7, tuned.withParityPercent(50).maxRounds());
        PackbinTest.expectEq("PP-1 the largest percentage is accepted", 100, plain.withParityPercent(100).parityPercent());
        PackbinTest.expectEq("PP-1 percentage 0 is accepted", 0, pct.withParityPercent(0).parityPercent());
        PackbinTest.expectThrows("PP-1 101", () -> plain.withParityPercent(101), "parity percentage must be 0 to 100, got 101");
        PackbinTest.expectThrows("PP-1 -1", () -> plain.withParityPercent(-1), "parity percentage must be 0 to 100, got -1");
        Scheme<PositionRow> count = EccSupport.positionScheme(4);
        PackbinTest.expectEq("PP-1 a percentage replaces the count", 0, count.withParityPercent(10).parity());
        PackbinTest.expectEq("PP-1 a count replaces the percentage", 0, pct.withParity(4).parityPercent());
        PackbinTest.expectEq("PP-1 and sets the count", 4, pct.withParity(4).parity());
        PackbinTest.expectEq("PP-1 the limit setters keep the count", 4, count.withMaxBytes(100).parity());
        PackbinTest.expectEq("PP-1 withParity 0 clears the percentage", 0, pct.withParity(0).parityPercent());
    }

    private static void countAndBytes() {
        for (int p : PERCENTS) {
            for (int length : LENGTHS) {
                // Arrange
                byte[] clear = new byte[length];
                for (int i = 0; i < length; i++) {
                    clear[i] = (byte) (i * 7 + 3);
                }
                int n = Math.min(32, countOf(p, length));

                // Act
                byte[] got = Ecc.protectPercent(clear, p);

                // Assert
                PackbinTest.expectEq("PP-2 p " + p + " L " + length + " sent length", length + n, got.length);
                PackbinTest.expectEq("PP-2 p " + p + " L " + length + " bytes equal the fixed count " + n,
                        EccSupport.hexOf(Ecc.protect(clear, n)), EccSupport.hexOf(got));
            }
        }
        // Through the scheme: the type byte is part of the clear message.
        byte[] viaScheme = BinaryPacker.pack(EccSupport.positionScheme(0).withParityPercent(50), EccSupport.positionRow());
        PackbinTest.expectEq("PP-2 a scheme packs the clear bytes then 7 parity bytes", 13 + 7, viaScheme.length);
        PackbinTest.expectEq("PP-2 same bytes as the fixed count of 7",
                EccSupport.hexOf(BinaryPacker.pack(EccSupport.positionScheme(7), EccSupport.positionRow())), EccSupport.hexOf(viaScheme));
        PackbinTest.expectEq("PP-2 percentage 0 sends the clear bytes only", EccSupport.POSITION_HEX,
                EccSupport.hexOf(BinaryPacker.pack(EccSupport.positionScheme(0).withParityPercent(0), EccSupport.positionRow())));
    }

    private static void largestMessage() {
        int[][] expected = {{1, 251}, {10, 230}, {25, 222}, {50, 222}, {100, 222}};
        for (int[] row : expected) {
            // Arrange
            int p = row[0];
            int over = row[1] + 1;
            String refusal = "the packet would be " + over + " bytes, above the limit of " + row[1] + " bytes for a parity of "
                    + p + " percent";
            byte[][] wrote = {null};
            Map<String, Object> value = Maps.map("b", new byte[over - 1]);

            // Act and Assert
            PackbinTest.expectEq("PP-3 largest clear of " + p, row[1], largestOf(p));
            PackbinTest.expectEq("PP-3 the largest is accepted", row[1] + Ecc.percentCount(p, row[1]),
                    BinaryPacker.pack(EccSupport.blob(row[1] - 1, 0).withParityPercent(p), Maps.map("b", new byte[row[1] - 1])).length);
            PackbinTest.expectThrows("PP-3 p " + p + " one above", () -> wrote[0] = BinaryPacker.pack(
                    EccSupport.blob(over - 1, 0).withParityPercent(p), value), refusal);
            PackbinTest.expectTrue("PP-3 p " + p + " wrote nothing", wrote[0] == null);
        }
        PackbinTest.expectEq("PP-3 percentage 0 has no limit", 1000,
                BinaryPacker.pack(EccSupport.blob(999, 0).withParityPercent(0), Maps.map("b", new byte[999])).length);
    }

    private static void everyPairRoundTrips() {
        int pairs = 0;
        int wrong = 0;
        for (int p = 0; p <= 100; p++) {
            int top = p == 0 ? 254 : largestOf(p);
            for (int length = 0; length <= top; length++) {
                pairs++;
                // Arrange
                byte[] clear = new byte[length];
                for (int i = 0; i < length; i++) {
                    clear[i] = (byte) (i * 31 + p);
                }
                int n = p == 0 ? 0 : Math.min(32, countOf(p, length));

                // Act
                byte[] sent = Ecc.protectPercent(clear, p);
                Object back = p == 0 ? new EccRepair.Fixed(sent, 0) : EccRepair.repairPercent(sent, p, 0);

                // Assert
                boolean ok = sent.length == length + n && back instanceof EccRepair.Fixed f && f.repaired == 0
                        && java.util.Arrays.equals(f.clear, clear);
                if (ok && length >= 1) {
                    List<Map> rows = new ArrayList<>();
                    byte[] body = new byte[length - 1];
                    System.arraycopy(clear, 1, body, 0, length - 1);
                    Scheme<Map> scheme = EccSupport.blob(length - 1, 0).withParityPercent(p);
                    byte[] packed = BinaryPacker.pack(scheme, Maps.map("b", body));
                    Object result = BinaryPacker.unpackRepair(packed, 0, scheme.on(rows::add));
                    ok = result instanceof Packbin.Repaired r
                            && r.count == 0 && rows.size() == 1;
                }
                if (!ok) {
                    wrong++;
                }
            }
        }
        PackbinTest.expectEq("PP-4 the (p, L) pairs", 22_752, pairs);
        PackbinTest.expectEq("PP-4 pairs that did not come back with a repaired count of 0", 0, wrong);
    }

    private static void impossibleLengthsAndLongBuffers() {
        // Arrange
        Scheme<Map> scheme = EccSupport.blob(4, 0).withParityPercent(100);
        List<Map> rows = new ArrayList<>();

        // Act
        Object odd = BinaryPacker.unpackRepair(new byte[7], 16, scheme.on(rows::add));
        Object longer = BinaryPacker.unpackRepair(new byte[255], 0, scheme.on(rows::add));
        Object longZero = BinaryPacker.unpackRepair(new byte[255], 0, EccSupport.blob(4, 0).withParityPercent(0).on(rows::add));

        // Assert
        PackbinTest.expectTrue("PP-4 a length that no clear length gives is uncorrectable", odd instanceof Packbin.Uncorrectable);
        PackbinTest.expectTrue("PP-4 a buffer above 254 bytes is too long",
                longer instanceof Packbin.TooLong t && t.length == 255 && t.limit == 254);
        PackbinTest.expectTrue("PP-4 percentage 0 checks nothing about the length", !(longZero instanceof Packbin.TooLong));
        PackbinTest.expectEq("PP-4 no row handed over", 0, rows.size());
    }

    private static void repairWithTheCountOfThatMessage() {
        int[][] cases = {{50, 20, 10}, {25, 10, 5}};
        for (int[] c : cases) {
            // Arrange
            Scheme<Map> scheme = EccSupport.blob(39, 0).withParityPercent(c[0]);
            byte[] body = new byte[39];
            for (int i = 0; i < 39; i++) {
                body[i] = (byte) (i * 5 + 1);
            }
            byte[] message = BinaryPacker.pack(scheme, Maps.map("b", body));
            int[] positions = new int[c[2]];
            int[] values = new int[c[2]];
            for (int i = 0; i < c[2]; i++) {
                positions[i] = i * 4;
                values[i] = 0x11 + i;
            }
            List<Map> rows = new ArrayList<>();

            // Act
            Object result = BinaryPacker.unpackRepair(EccSupport.corrupt(message, positions, values), c[2], scheme.on(rows::add));

            // Assert
            PackbinTest.expectEq("PP-5 p " + c[0] + " message length", 40 + c[1], message.length);
            PackbinTest.expectTrue("PP-5 p " + c[0] + " repaired " + c[2],
                    result instanceof Packbin.Repaired r && r.count == c[2] && rows.size() == 1);
        }
    }

    private static void correctionLimit() {
        // Arrange
        Scheme<Map> scheme = EccSupport.blob(39, 0).withParityPercent(25);
        byte[] message = BinaryPacker.pack(scheme, Maps.map("b", new byte[39]));
        List<Map> rows = new ArrayList<>();
        Scheme.Handler<Map> handler = scheme.on(rows::add);
        byte[] five = EccSupport.corrupt(message, new int[] {1, 9, 17, 25, 33}, new int[] {1, 2, 3, 4, 5});
        byte[] six = EccSupport.corrupt(message, new int[] {1, 9, 17, 25, 33, 40}, new int[] {1, 2, 3, 4, 5, 6});

        // Act and Assert
        PackbinTest.expectThrows("PP-6 limit -1", () -> BinaryPacker.unpackRepair(message, -1, handler),
                "correction limit must be 0 to 16, got -1");
        PackbinTest.expectThrows("PP-6 limit 17", () -> BinaryPacker.unpackRepair(message, 17, handler),
                "correction limit must be 0 to 16, got 17");
        PackbinTest.expectTrue("PP-6 limit 16 on 10 parity bytes behaves as 5",
                BinaryPacker.unpackRepair(five, 16, handler) instanceof Packbin.Repaired r && r.count == 5);
        PackbinTest.expectTrue("PP-6 six wrong bytes are refused under limit 16",
                BinaryPacker.unpackRepair(six, 16, handler) instanceof Packbin.Uncorrectable);
        PackbinTest.expectEq("PP-6 one row handed over", 1, rows.size());
        PackbinTest.expectThrows("PP-6 a fixed count keeps its exact rule",
                () -> BinaryPacker.unpackRepair(message, 6, EccSupport.blob(39, 10).on(rows::add)),
                "correction limit must be 0 to 5 for 10 parity bytes, got 6");
    }

    private static void dispatch() {
        // Arrange
        int[] ran = {0};
        Scheme<Map> a = Maps.scheme(0x21, MemberCases.u8(0, "a")).withParityPercent(100);
        Scheme<Map> b = Maps.scheme(0x22, MemberCases.u8(0, "a")).withParityPercent(100);
        Scheme<Map> other = Maps.scheme(0x23, MemberCases.u8(0, "a")).withParityPercent(25);
        Scheme<Map> count = Maps.scheme(0x24, MemberCases.u8(0, "a")).withParity(4);
        byte[] message = BinaryPacker.pack(b, Maps.map("a", 9));
        byte[] hit = EccSupport.corrupt(message, new int[] {1}, new int[] {0x55});
        List<Map> rows = new ArrayList<>();

        // Act
        Object same = BinaryPacker.unpackRepair(hit, 1, a.on(row -> ran[0]++), b.on(rows::add));

        // Assert
        PackbinTest.expectTrue("PP-7 handlers of one percentage dispatch after the repair",
                same instanceof Packbin.Repaired r && r.count == 1 && rows.equals(List.of(Maps.map("a", 9))) && ran[0] == 0);
        PackbinTest.expectThrows("PP-7 two percentages", () -> BinaryPacker.unpackRepair(message, 0, a.on(row -> ran[0]++),
                other.on(row -> ran[0]++)),
                "handlers declare 100 percent parity and 25 percent parity; they must declare the same count or percentage");
        PackbinTest.expectThrows("PP-7 a percentage with a count", () -> BinaryPacker.unpack(message, a.on(row -> ran[0]++),
                count.on(row -> ran[0]++)),
                "handlers declare 100 percent parity and 4 parity bytes; they must declare the same count or percentage");
        PackbinTest.expectThrows("PP-7 a count with a percentage", () -> BinaryPacker.unpack(message, count.on(row -> ran[0]++),
                a.on(row -> ran[0]++)),
                "handlers declare 4 parity bytes and 100 percent parity; they must declare the same count or percentage");
        PackbinTest.expectThrows("PP-7 a bad limit under a shared percentage", () -> BinaryPacker.unpackRepair(message, 17,
                a.on(row -> ran[0]++), b.on(row -> ran[0]++)), "correction limit must be 0 to 16, got 17");
        PackbinTest.expectEq("PP-7 no handler ran on a refusal", 0, ran[0]);
    }

    private static void theSearchIsCheap() {
        // Arrange
        Timing.Limit limit = Timing.bound(1.0);
        long sum = 0;
        long start = System.nanoTime();

        // Act
        for (int i = 0; i < 100_000; i++) {
            sum += Ecc.clearLength(1 + i % 100, i % 255);
        }
        long elapsed = System.nanoTime() - start;

        // Assert
        limit.expectWithinNanos("PP-NFR 100,000 searches for the clear length (sum " + sum + ")", elapsed);
    }
}

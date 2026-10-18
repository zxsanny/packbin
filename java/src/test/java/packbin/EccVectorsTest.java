package packbin;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * AZ-2683 AC-1, AC-2, AC-3 (report rows), AC-4 (rows 9 to 12), AC-5: every row of fixtures/ecc/vectors.txt against the
 * Java codec and schemes, and the position rows of the report.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class EccVectorsTest {
    private EccVectorsTest() {}

    static void run() {
        everyRowKindIsCovered();
        encRowsProtectExactly();
        fixRowsRepair();
        badRowsAreRefused();
        limRowsEnforceTheSizeLimit();
        parRowsRefuseTheScheme();
        lmtRowsRefuseTheLimit();
        positionRowsOfTheReport();
    }

    private static void everyRowKindIsCovered() {
        // Arrange
        List<String> kinds = new ArrayList<>();
        for (String[] row : EccSupport.allVectorRows()) {
            if (!kinds.contains(row[0])) {
                kinds.add(row[0]);
            }
        }
        kinds.sort(null);

        // Assert
        PackbinTest.expectEq("EC vectors: the row kinds of the file", List.of("bad", "enc", "fix", "lim", "lmt", "par"), kinds);
    }

    private static void encRowsProtectExactly() {
        for (String[] row : EccSupport.vectorRows("enc")) {
            // Arrange
            int n = Integer.parseInt(row[1]);
            byte[] clear = EccSupport.bytesOf(row[2]);

            // Act
            byte[] got = Ecc.protect(clear, n);

            // Assert
            PackbinTest.expectEq(row[0] + " protect appends exactly the vector parity",
                    row[3].equals("-") ? "" : row[3], EccSupport.hexOf(got));
        }
    }

    private static void fixRowsRepair() {
        for (String[] row : EccSupport.vectorRows("fix")) {
            // Arrange
            byte[] received = EccSupport.bytesOf(row[3]);
            byte[] before = received.clone();

            // Act
            Object got = EccRepair.repair(received, Integer.parseInt(row[1]), Integer.parseInt(row[2]));

            // Assert
            PackbinTest.expectTrue(row[0] + " is repaired (" + got + ")", got instanceof EccRepair.Fixed);
            if (got instanceof EccRepair.Fixed fixed) {
                PackbinTest.expectEq(row[0] + " clear", row[4].equals("-") ? "" : row[4], EccSupport.hexOf(fixed.clear));
                PackbinTest.expectEq(row[0] + " count", Integer.parseInt(row[5]), fixed.repaired);
            }
            PackbinTest.expectTrue(row[0] + " leaves the caller's buffer as it was", Arrays.equals(before, received));
        }
    }

    private static void badRowsAreRefused() {
        int wrong = 0;
        List<String[]> rows = EccSupport.vectorRows("bad");
        for (String[] row : rows) {
            // Arrange
            int n = Integer.parseInt(row[1]);
            byte[] received = EccSupport.bytesOf(row[3]);

            // Act
            Object got = EccRepair.repair(received, n, Integer.parseInt(row[2]));

            // Assert
            boolean matches = switch (row[4]) {
                case "uncorrectable" -> got instanceof Packbin.Uncorrectable;
                case "short" -> got instanceof Packbin.ShortPacket s
                        && s.field.equals("parity") && s.needed == n && s.left == received.length;
                case "too_long" -> got instanceof Packbin.TooLong t && t.length == received.length && t.limit == 254;
                default -> false;
            };
            if (!matches) {
                wrong++;
                PackbinTest.fail(row[0] + ": expected " + row[4] + ", got " + got);
            }
        }
        PackbinTest.expectTrue("EC vectors: bad rows read", rows.size() > 1000);
        PackbinTest.expectEq("EC vectors: bad rows refused as stated", 0, wrong);
    }

    private static void limRowsEnforceTheSizeLimit() {
        for (String[] row : EccSupport.vectorRows("lim")) {
            // Arrange
            int n = Integer.parseInt(row[1]);
            int length = Integer.parseInt(row[2]);
            boolean ok = row[3].equals("ok");
            String refusal = "the packet would be " + length + " bytes, above the limit of " + (254 - n) + " bytes for "
                    + n + " parity bytes";

            // Act and Assert
            if (ok) {
                PackbinTest.expectEq(row[0] + " protect", length + n, Ecc.protect(new byte[length], n).length);
                Map<String, Object> value = Maps.map("b", new byte[length - 1]);
                PackbinTest.expectEq(row[0] + " pack", length + n, BinaryPacker.pack(EccSupport.blob(length - 1, n), value).length);
            } else {
                PackbinTest.expectThrows(row[0] + " protect", () -> Ecc.protect(new byte[length], n), refusal);
                byte[][] wrote = {null};
                Map<String, Object> value = Maps.map("b", new byte[length - 1]);
                PackbinTest.expectThrows(row[0] + " pack", () -> wrote[0] = BinaryPacker.pack(EccSupport.blob(length - 1, n), value), refusal);
                PackbinTest.expectTrue(row[0] + " pack wrote nothing", wrote[0] == null);
            }
        }
    }

    private static void parRowsRefuseTheScheme() {
        for (String[] row : EccSupport.vectorRows("par")) {
            // Arrange
            int n = Integer.parseInt(row[1]);
            String refusal = "parity must be 0 to 32 bytes, got " + n;

            // Act and Assert
            PackbinTest.expectThrows(row[0] + " withParity", () -> EccSupport.positionScheme(0).withParity(n), refusal);
            PackbinTest.expectThrows(row[0] + " checkParity", () -> Ecc.checkParity(n), refusal);
        }
    }

    private static void lmtRowsRefuseTheLimit() {
        for (String[] row : EccSupport.vectorRows("lmt")) {
            // Arrange
            int n = Integer.parseInt(row[1]);
            int t = Integer.parseInt(row[2]);
            List<PositionRow> touched = new ArrayList<>();
            Scheme.Handler<PositionRow> handler = EccSupport.positionScheme(n).on(touched::add);
            byte[] message = BinaryPacker.pack(EccSupport.positionScheme(n), EccSupport.positionRow());
            String refusal = "correction limit must be 0 to " + n / 2 + " for " + n + " parity bytes, got " + t;

            // Act and Assert
            PackbinTest.expectThrows(row[0] + " unpackRepair", () -> BinaryPacker.unpackRepair(message, t, handler), refusal);
            PackbinTest.expectThrows(row[0] + " checkLimit", () -> Ecc.checkLimit(t, n), refusal);
            PackbinTest.expectEq(row[0] + " no row handed over", 0, touched.size());
        }
    }

    private static void positionRowsOfTheReport() {
        // Arrange
        String[][] expected = {{"1", "ab"}, {"2", "16bd"}, {"4", "ca856682"}, {"8", "6d4f38479f3f2472"},
            {"16", "4ace66ecd5e4a28ffa28098279f5f19d"}};

        // Act and Assert
        PackbinTest.expectEq("EC-1 a scheme without parity packs the clear bytes", EccSupport.POSITION_HEX,
                EccSupport.hexOf(BinaryPacker.pack(EccSupport.positionScheme(0), EccSupport.positionRow())));
        for (String[] row : expected) {
            PackbinTest.expectEq("EC-2 n = " + row[0] + " packs the report bytes", EccSupport.POSITION_HEX + row[1],
                    EccSupport.hexOf(BinaryPacker.pack(EccSupport.positionScheme(Integer.parseInt(row[0])), EccSupport.positionRow())));
        }
        PackbinTest.expectThrows("EC-3 n = 33 is not built, naming 33 and 32",
                () -> EccSupport.positionScheme(33), "parity must be 0 to 32 bytes, got 33");
        PackbinTest.expectThrows("EC-3 a negative count is not built",
                () -> EccSupport.positionScheme(-1), "parity must be 0 to 32 bytes, got -1");

        EccSupport.Run row7 = EccSupport.unpackPosition(EccSupport.bytesOf("4001000065cc1d00a3e111010016bd"), 2, 1);
        PackbinTest.expectTrue("EC-8 row 7: one wrong byte, n = 2, t = 1 is repaired", row7.recovered(1, 1));

        EccSupport.Run row8 = EccSupport.unpackPosition(EccSupport.bytesOf("40015a0065cd1d00a322110100ca856682"), 4, 2);
        PackbinTest.expectTrue("EC-8 row 8: two wrong bytes, n = 4, t = 2 are repaired", row8.recovered(2, 1));

        byte[] beyond = EccSupport.bytesOf("40015a0065cd1d00a322110100ca856682");
        EccSupport.Run row9 = EccSupport.unpackPosition(beyond, 4, 1);
        EccSupport.Run row10 = EccSupport.unpackPosition(beyond, 4, 0);
        PackbinTest.expectTrue("EC-8 row 9: two wrong bytes beyond t = 1 are refused", row9.uncorrectable());
        PackbinTest.expectTrue("EC-8 row 10: two wrong bytes beyond t = 0 are refused", row10.uncorrectable());
        PackbinTest.expectEq("EC-8 rows 9 and 10: 0 rows", 0, row9.rows.size() + row10.rows.size());

        EccSupport.Run row11 = EccSupport.unpackPosition(EccSupport.bytesOf("4001000065cd1d00a3e1110100ca856682"), 4, 2);
        PackbinTest.expectTrue("EC-8 row 11: an intact message reports 0 repaired", row11.recovered(0, 1));

        EccSupport.Run row12 = EccSupport.unpackPosition(EccSupport.bytesOf("400100"), 4, 2);
        EccSupport.Run empty = EccSupport.unpackPosition(new byte[0], 1, 0);
        PackbinTest.expectTrue("EC-8 row 12: shorter than n names the parity, the bytes needed and present",
                row12.result instanceof Packbin.ShortPacket s && s.field.equals("parity") && s.needed == 4 && s.left == 3);
        PackbinTest.expectTrue("EC-8 an empty buffer under n = 1 names the parity",
                empty.result instanceof Packbin.ShortPacket s && s.field.equals("parity") && s.needed == 1 && s.left == 0);
        PackbinTest.expectEq("EC-8 row 12: 0 rows", 0, row12.rows.size() + empty.rows.size());

        Scheme<PositionRow> plain = EccSupport.positionScheme(0);
        PackbinTest.expectTrue("EC-1 a scheme without parity unpacks as before, with the plain call returning null",
                BinaryPacker.unpack(EccSupport.bytesOf(EccSupport.POSITION_HEX), plain.on(r -> { })) == null);
        PackbinTest.expectEq("EC-1 the repair call reports 0 repaired for it", 0,
                EccSupport.unpackPosition(EccSupport.bytesOf(EccSupport.POSITION_HEX), 0, 0).repaired());
    }
}

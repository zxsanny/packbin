package packbin;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

/** AZ-3503 AC-7 (vector rows): every row of fixtures/ecc/percent-vectors.txt against the Java codec and schemes. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class PercentVectorsTest {
    private PercentVectorsTest() {}

    static void run() {
        PackbinTest.expectEq("percent vectors: the row kinds of the file",
                List.of("badp", "encp", "fixp", "inv", "limp", "lmtp", "parp", "pct"), new ArrayList<>(new TreeSet<>(kinds())));
        pctRowsGiveTheCount();
        encpRowsProtectExactly();
        invRowsFindTheClearLength();
        limpRowsEnforceTheSizeLimit();
        fixpRowsRepair();
        badpRowsAreRefused();
        parpRowsRefuseThePercentage();
        lmtpRowsRefuseTheLimit();
    }

    private static List<String> kinds() {
        List<String> out = new ArrayList<>();
        for (String[] row : allRows()) {
            out.add(row[0]);
        }
        return out;
    }

    private static List<String[]> allRows() {
        List<String[]> out = new ArrayList<>();
        try {
            for (String line : Files.readAllLines(Path.of("fixtures", "ecc", "percent-vectors.txt"), StandardCharsets.UTF_8)) {
                if (!line.isEmpty() && !line.startsWith("#")) {
                    out.add(line.split(" ", -1));
                }
            }
        } catch (IOException ex) {
            throw new IllegalStateException("fixtures/ecc/percent-vectors.txt: " + ex, ex);
        }
        return out;
    }

    /** The columns after the kind, the id first. */
    private static List<String[]> rows(String kind) {
        List<String[]> out = new ArrayList<>();
        for (String[] row : allRows()) {
            if (row[0].equals(kind)) {
                out.add(java.util.Arrays.copyOfRange(row, 1, row.length));
            }
        }
        PackbinTest.expectTrue("percent vectors: " + kind + " rows read", !out.isEmpty());
        return out;
    }

    private static void pctRowsGiveTheCount() {
        for (String[] row : rows("pct")) {
            PackbinTest.expectEq(row[0] + " count", Integer.parseInt(row[3]),
                    Ecc.percentCount(Integer.parseInt(row[1]), Integer.parseInt(row[2])));
        }
    }

    private static void encpRowsProtectExactly() {
        for (String[] row : rows("encp")) {
            // Arrange
            int p = Integer.parseInt(row[1]);
            byte[] clear = EccSupport.bytesOf(row[2]);

            // Act
            byte[] got = Ecc.protectPercent(clear, p);

            // Assert
            PackbinTest.expectEq(row[0] + " protect", row[3].equals("-") ? "" : row[3], EccSupport.hexOf(got));
        }
    }

    private static void invRowsFindTheClearLength() {
        for (String[] row : rows("inv")) {
            // Arrange
            int p = Integer.parseInt(row[1]);
            int sent = Integer.parseInt(row[2]);
            int expected = row[3].equals("none") ? -1 : Integer.parseInt(row[3]);

            // Act and Assert
            if (p == 0) {
                PackbinTest.expectEq(row[0] + " p 0 reads the bytes as they are", sent, expected);
            } else {
                PackbinTest.expectEq(row[0] + " clear length", expected, Ecc.clearLength(p, sent));
                Object got = EccRepair.repairPercent(expected < 0 ? new byte[sent] : Ecc.protectPercent(new byte[expected], p), p, 0);
                PackbinTest.expectEq(row[0] + " only an impossible length is refused for its length", expected < 0,
                        got instanceof Packbin.Uncorrectable);
            }
        }
    }

    private static void limpRowsEnforceTheSizeLimit() {
        for (String[] row : rows("limp")) {
            // Arrange
            int p = Integer.parseInt(row[1]);
            int length = Integer.parseInt(row[2]);
            boolean ok = row[3].equals("ok");
            String refusal = "the packet would be " + length + " bytes, above the limit of " + (ok ? 0 : Ecc.largestClear(p))
                    + " bytes for a parity of " + p + " percent";

            // Act and Assert
            if (ok) {
                PackbinTest.expectEq(row[0] + " protect", length + Ecc.percentCount(p, length),
                        Ecc.protectPercent(new byte[length], p).length);
            } else {
                PackbinTest.expectThrows(row[0] + " protect", () -> Ecc.protectPercent(new byte[length], p), refusal);
                byte[][] wrote = {null};
                Map<String, Object> value = Maps.map("b", new byte[length - 1]);
                PackbinTest.expectThrows(row[0] + " pack",
                        () -> wrote[0] = BinaryPacker.pack(EccSupport.blob(length - 1, 0).withParityPercent(p), value), refusal);
                PackbinTest.expectTrue(row[0] + " pack wrote nothing", wrote[0] == null);
            }
        }
    }

    private static void fixpRowsRepair() {
        for (String[] row : rows("fixp")) {
            // Arrange
            int p = Integer.parseInt(row[1]);
            int t = Integer.parseInt(row[2]);
            byte[] received = EccSupport.bytesOf(row[3]);
            byte[] before = received.clone();
            String clear = row[4].equals("-") ? "" : row[4];

            // Act
            Object got = p == 0 ? new EccRepair.Fixed(received, 0) : EccRepair.repairPercent(received, p, t);

            // Assert
            PackbinTest.expectTrue(row[0] + " is repaired (" + got + ")", got instanceof EccRepair.Fixed);
            if (got instanceof EccRepair.Fixed fixed) {
                PackbinTest.expectEq(row[0] + " clear", clear, EccSupport.hexOf(fixed.clear));
                PackbinTest.expectEq(row[0] + " count", Integer.parseInt(row[5]), fixed.repaired);
            }
            PackbinTest.expectTrue(row[0] + " leaves the caller's buffer as it was", java.util.Arrays.equals(before, received));
            if (row[0].contains(".pos.")) {
                EccSupport.Run run = new EccSupport.Run();
                run.result = BinaryPacker.unpackRepair(received, p == 0 ? 0 : t,
                        EccSupport.positionScheme(0).withParityPercent(p).on(run.rows::add));
                PackbinTest.expectTrue(row[0] + " unpackRepair hands over the row", run.recovered(Integer.parseInt(row[5]), 1));
            }
        }
    }

    private static void badpRowsAreRefused() {
        for (String[] row : rows("badp")) {
            // Arrange
            int p = Integer.parseInt(row[1]);
            int t = Integer.parseInt(row[2]);
            byte[] received = EccSupport.bytesOf(row[3]);

            // Act
            Object got = EccRepair.repairPercent(received, p, t);

            // Assert
            boolean matches = switch (row[4]) {
                case "uncorrectable" -> got instanceof Packbin.Uncorrectable;
                case "too_long" -> got instanceof Packbin.TooLong tl && tl.length == received.length && tl.limit == 254;
                default -> false;
            };
            PackbinTest.expectTrue(row[0] + ": expected " + row[4] + ", got " + got, matches);
        }
    }

    private static void parpRowsRefuseThePercentage() {
        for (String[] row : rows("parp")) {
            // Arrange
            int p = Integer.parseInt(row[1]);
            int n = Integer.parseInt(row[2]);

            // Act and Assert
            if (p < 0 || p > 100) {
                PackbinTest.expectThrows(row[0] + " withParityPercent",
                        () -> EccSupport.positionScheme(n).withParityPercent(p), "parity percentage must be 0 to 100, got " + p);
            } else {
                // A Java scheme is built by one setter at a time, so the last one wins: a count and a percentage
                // cannot meet in one constructor (AZ-3503 AC-1).
                Scheme<PositionRow> scheme = EccSupport.positionScheme(n).withParityPercent(p);
                PackbinTest.expectEq(row[0] + " the percentage replaces the count", 0, scheme.parity());
                PackbinTest.expectEq(row[0] + " the percentage is kept", p, scheme.parityPercent());
            }
        }
    }

    private static void lmtpRowsRefuseTheLimit() {
        for (String[] row : rows("lmtp")) {
            // Arrange
            int t = Integer.parseInt(row[1]);
            List<PositionRow> touched = new ArrayList<>();
            Scheme<PositionRow> scheme = EccSupport.positionScheme(0).withParityPercent(25);
            byte[] message = BinaryPacker.pack(scheme, EccSupport.positionRow());

            // Act and Assert
            PackbinTest.expectThrows(row[0] + " unpackRepair", () -> BinaryPacker.unpackRepair(message, t, scheme.on(touched::add)),
                    "correction limit must be 0 to 16, got " + t);
            PackbinTest.expectEq(row[0] + " no row handed over", 0, touched.size());
        }
    }
}

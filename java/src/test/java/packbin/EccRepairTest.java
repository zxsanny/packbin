package packbin;

import java.util.Arrays;
import java.util.Map;
import java.util.Random;

/** AZ-2683 AC-3, AC-4, AC-5, AC-7: repair of one and more wrong bytes, refusals, the size limit and the speed bound. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class EccRepairTest {
    private EccRepairTest() {}

    static void run() {
        n2EveryPositionAndValue();
        seededRepairs();
        aWrongByteCountsOnce();
        repairLeavesTheCallersBuffer();
        refusalsBeyondTheLimitHaveNoWrongRow();
        garbageIsAcceptedAtMostTwelveTimes();
        removedOrAddedTailBytesAreRefused();
        boundaryBytesAreRefused();
        theSizeLimit();
        speed();
    }

    private static void n2EveryPositionAndValue() {
        // Arrange
        byte[] message = BinaryPacker.pack(EccSupport.positionScheme(2), EccSupport.positionRow());
        int failures = 0;
        int cases = 0;

        // Act
        for (int p = 0; p < message.length; p++) {
            for (int v = 1; v <= 255; v++) {
                EccSupport.Run run = EccSupport.unpackPosition(EccSupport.corrupt(message, new int[] {p}, new int[] {v}), 2, 1);
                cases++;
                if (!run.recovered(1, 1)) {
                    failures++;
                }
            }
        }

        // Assert
        PackbinTest.expectEq("EC-5 n = 2 message length", 15, message.length);
        PackbinTest.expectEq("EC-5 n = 2 cases: 15 positions x 255 values", 15 * 255, cases);
        PackbinTest.expectEq("EC-5 n = 2 failures", 0, failures);
    }

    private static void seededRepairs() {
        for (int n : new int[] {4, 8, 16}) {
            // Arrange
            Random random = new Random(n);
            byte[] message = BinaryPacker.pack(EccSupport.positionScheme(n), EccSupport.positionRow());
            int t = n / 2;
            int failures = 0;

            // Act
            for (int i = 0; i < 1000; i++) {
                int count = 1 + (i % t);
                int[] positions = EccSupport.pickPositions(random, message.length, count);
                int[] values = EccSupport.pickValues(random, count);
                if (!EccSupport.unpackPosition(EccSupport.corrupt(message, positions, values), n, t).recovered(count, 1)) {
                    failures++;
                }
            }

            // Assert
            PackbinTest.expectEq("EC-5 n = " + n + ": 1,000 seeded cases of up to " + t + " wrong bytes, failures", 0, failures);
        }
    }

    private static void aWrongByteCountsOnce() {
        // Arrange
        byte[] message = BinaryPacker.pack(EccSupport.positionScheme(2), EccSupport.positionRow());

        // Act
        EccSupport.Run run = EccSupport.unpackPosition(EccSupport.corrupt(message, new int[] {6}, new int[] {0xff}), 2, 1);

        // Assert
        PackbinTest.expectTrue("EC-5 a wrong byte counts once however many of its bits differ", run.recovered(1, 1));
    }

    private static void repairLeavesTheCallersBuffer() {
        // Arrange
        byte[] message = EccSupport.corrupt(BinaryPacker.pack(EccSupport.positionScheme(4), EccSupport.positionRow()),
                new int[] {3, 9}, new int[] {0x55, 0x01});
        byte[] before = message.clone();

        // Act
        EccSupport.Run run = EccSupport.unpackPosition(message, 4, 2);

        // Assert
        PackbinTest.expectTrue("EC-5 two wrong bytes are repaired", run.recovered(2, 1));
        PackbinTest.expectTrue("EC-5 repair leaves the caller's buffer as it was", Arrays.equals(before, message));
    }

    private static void refusalsBeyondTheLimitHaveNoWrongRow() {
        for (int[] setup : new int[][] {{1, 2, 3, 61}, {0, 1, 4, 60}}) {
            // Arrange
            int t = setup[0];
            int lowest = setup[1];
            int span = setup[2];
            Random random = new Random(setup[3]);
            byte[] message = BinaryPacker.pack(EccSupport.positionScheme(4), EccSupport.positionRow());
            int accepted = 0;
            int wrongRows = 0;
            int otherErrors = 0;

            // Act
            for (int i = 0; i < 10_000; i++) {
                int count = lowest + (i % (span - lowest + 1));
                int[] positions = EccSupport.pickPositions(random, message.length, count);
                int[] values = EccSupport.pickValues(random, count);
                EccSupport.Run run = EccSupport.unpackPosition(EccSupport.corrupt(message, positions, values), 4, t);
                accepted += run.ok() ? 1 : 0;
                otherErrors += run.uncorrectable() || run.ok() ? 0 : 1;
                wrongRows += run.rows.size();
            }

            // Assert
            String label = "EC-6 n = 4, t = " + t + ": 10,000 seeded cases of " + lowest + " to " + span + " wrong bytes";
            PackbinTest.expectEq(label + ", accepted", 0, accepted);
            PackbinTest.expectEq(label + ", errors that are not uncorrectable", 0, otherErrors);
            PackbinTest.expectEq(label + ", rows handed over", 0, wrongRows);
        }
    }

    private static void garbageIsAcceptedAtMostTwelveTimes() {
        // Arrange
        Random random = new Random(7);
        byte[] buffer = new byte[15];
        int accepted = 0;

        // Act
        for (int i = 0; i < 200_000; i++) {
            random.nextBytes(buffer);
            if (EccRepair.repair(buffer, 2, 0) instanceof EccRepair.Fixed) {
                accepted++;
            }
        }

        // Assert
        PackbinTest.expectTrue("EC-7 n = 2, t = 0: at most 12 of 200,000 random buffers are accepted (" + accepted + ")", accepted <= 12);
    }

    private static void removedOrAddedTailBytesAreRefused() {
        // Arrange
        Random random = new Random(14);
        byte[] message = BinaryPacker.pack(EccSupport.positionScheme(4), EccSupport.positionRow());
        int accepted = 0;
        int wrongRows = 0;

        // Act
        for (int i = 0; i < 10_000; i++) {
            int k = 1 + (i % 3);
            byte[] changed;
            if (i % 2 == 0) {
                changed = Arrays.copyOf(message, message.length - k);
            } else {
                changed = Arrays.copyOf(message, message.length + k);
                for (int j = message.length; j < changed.length; j++) {
                    changed[j] = (byte) random.nextInt(256);
                }
            }
            EccSupport.Run run = EccSupport.unpackPosition(changed, 4, 0);
            accepted += run.ok() ? 1 : 0;
            wrongRows += run.rows.size();
        }

        // Assert
        PackbinTest.expectEq("EC-14 n = 4, t = 0: removed or added tail bytes accepted", 0, accepted);
        PackbinTest.expectEq("EC-14 n = 4, t = 0: removed or added tail bytes, rows", 0, wrongRows);
    }

    private static void boundaryBytesAreRefused() {
        // Arrange
        byte[] message = BinaryPacker.pack(EccSupport.positionScheme(4), EccSupport.positionRow());
        byte[] zeroParity = null;
        for (int sid = 0; zeroParity == null && sid < 65_536; sid++) {
            byte[] candidate = BinaryPacker.pack(EccSupport.positionScheme(4), EccSupport.positionRow(sid));
            if (candidate[candidate.length - 1] == 0) {
                zeroParity = candidate;
            }
        }
        PackbinTest.expectTrue("EC-14 a message whose last parity byte is 00 exists", zeroParity != null);

        // Act
        EccSupport.Run trailingZero = EccSupport.unpackPosition(Arrays.copyOf(message, message.length + 1), 4, 0);
        EccSupport.Run dropped = EccSupport.unpackPosition(Arrays.copyOf(message, message.length - 1), 4, 0);
        EccSupport.Run zeroPlusZero = EccSupport.unpackPosition(Arrays.copyOf(zeroParity, zeroParity.length + 1), 4, 0);
        EccSupport.Run zeroDropped = EccSupport.unpackPosition(Arrays.copyOf(zeroParity, zeroParity.length - 1), 4, 0);
        EccSupport.Run intact = EccSupport.unpackPosition(zeroParity, 4, 0);
        byte[] clear = BinaryPacker.pack(EccSupport.positionScheme(0), EccSupport.positionRow());
        EccSupport.Run unprotected = EccSupport.unpackPosition(clear, 4, 0);
        EccSupport.Run unprotectedRepair = EccSupport.unpackPosition(clear, 4, 2);
        EccSupport.Run readByPlain = EccSupport.unpackPosition(message, 0, 0);

        // Assert
        for (EccSupport.Run run : new EccSupport.Run[] {trailingZero, dropped, zeroPlusZero, zeroDropped, unprotected, unprotectedRepair}) {
            PackbinTest.expectTrue("EC-14 a damaged length is refused (" + run.result + ")", !run.ok());
            PackbinTest.expectEq("EC-14 a damaged length hands over no row", 0, run.rows.size());
        }
        PackbinTest.expectTrue("EC-14 the unprotected 13 bytes read by n = 4 are uncorrectable", unprotected.uncorrectable());
        PackbinTest.expectTrue("EC-14 a last parity byte of 00 is intact", intact.rows.size() == 1 && intact.repaired() == 0);
        PackbinTest.expectTrue("EC-14 a scheme without parity given a protected message returns the trailing-bytes error",
                readByPlain.result instanceof Packbin.TrailingBytes t && t.left == 4 && readByPlain.rows.isEmpty());
    }

    private static void theSizeLimit() {
        // Arrange
        Map<String, Object> fits = Maps.map("b", new byte[221]);
        Map<String, Object> over = Maps.map("b", new byte[222]);
        byte[][] wrote = {null};

        // Act
        byte[] packed = BinaryPacker.pack(EccSupport.blob(221, 32), fits);

        // Assert
        PackbinTest.expectEq("EC-4 n = 32: a clear message of 222 bytes is packed", 254, packed.length);
        PackbinTest.expectThrows("EC-4 n = 32: 223 bytes is refused naming both numbers",
                () -> wrote[0] = BinaryPacker.pack(EccSupport.blob(222, 32), over),
                "the packet would be 223 bytes, above the limit of 222 bytes for 32 parity bytes");
        PackbinTest.expectTrue("EC-4 a refused pack writes nothing", wrote[0] == null);
        EccSupport.Run tooLong = EccSupport.unpackPosition(new byte[255], 4, 2);
        PackbinTest.expectTrue("EC-4 a buffer above 254 bytes is refused as too long",
                tooLong.result instanceof Packbin.TooLong t && t.length == 255 && t.limit == 254);
        PackbinTest.expectEq("EC-4 a buffer above 254 bytes hands over no row", 0, tooLong.rows.size());
    }

    private static void speed() {
        // Arrange
        byte[] clear = new byte[238];
        for (int i = 0; i < clear.length; i++) {
            clear[i] = (byte) (i * 37 + 11);
        }
        byte[] message = Ecc.protect(clear, 16);
        byte[] wrong = EccSupport.corrupt(message, new int[] {0, 30, 60, 90, 120, 180, 220, 253}, new int[] {1, 2, 3, 4, 5, 6, 7, 8});
        Map<String, Object> value = Maps.map("b", Arrays.copyOfRange(clear, 1, clear.length));
        Scheme<Map> blob = EccSupport.blob(237, 16);
        int repaired = 0;
        Timing.Limit unpackLimit = Timing.bound(1.0);
        long unpackStart = System.nanoTime();

        // Act
        for (int i = 0; i < 1000; i++) {
            if (EccRepair.repair(wrong, 16, 8) instanceof EccRepair.Fixed fixed && fixed.repaired == 8) {
                repaired++;
            }
        }
        long unpackMs = (System.nanoTime() - unpackStart) / 1_000_000;
        Timing.Limit packLimit = Timing.bound(1.0);
        long packStart = System.nanoTime();
        byte[] last = null;
        for (int i = 0; i < 1000; i++) {
            last = BinaryPacker.pack(blob, value);
        }
        long packMs = (System.nanoTime() - packStart) / 1_000_000;

        // Assert
        PackbinTest.expectEq("EC-13 the 254-byte message repairs 1,000 times", 1000, repaired);
        PackbinTest.expectEq("EC-13 packing gives the 254-byte message", 254, last.length);
        unpackLimit.expectWithin("EC-13 the repair loop of 1,000", unpackMs / 1000.0);
        packLimit.expectWithin("EC-13 the pack loop of 1,000", packMs / 1000.0);
    }
}

package packbin;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/** Shared parts of the message ECC tests (AZ-2683): the position scheme, the vectors file and the corruption helpers. */
final class EccSupport {
    static final String POSITION_HEX = "4001000065cd1d00a3e1110100";

    private EccSupport() {}

    /** The position fixture as a scheme that declares {@code parity} parity bytes. */
    static Scheme<PositionRow> positionScheme(int parity) {
        return new Scheme<>(
                0x40,
                PositionRow.class,
                Packbin.u16(0, Access.get((PositionRow r) -> r.sid), Access.set((PositionRow r, Object v) -> r.sid = ((Number) v).intValue())),
                Packbin.i32(1, Access.get((PositionRow r) -> r.lat), Access.set((PositionRow r, Object v) -> r.lat = ((Number) v).intValue())),
                Packbin.i32(2, Access.get((PositionRow r) -> r.lon), Access.set((PositionRow r, Object v) -> r.lon = ((Number) v).intValue())),
                Packbin.u8(3, Access.get((PositionRow r) -> r.profile & 0xFF), Access.set((PositionRow r, Object v) -> r.profile = ((Number) v).byteValue())),
                Packbin.flags(
                        4,
                        Packbin.u16(4, Access.get((PositionRow r) -> r.heading), Access.set((PositionRow r, Object v) -> r.heading = v == null ? null : ((Number) v).intValue())),
                        Packbin.u8(5, Access.get((PositionRow r) -> r.speed), Access.set((PositionRow r, Object v) -> r.speed = v == null ? null : ((Number) v).intValue())),
                        Packbin.i16(6, Access.get((PositionRow r) -> r.altitude), Access.set((PositionRow r, Object v) -> r.altitude = v == null ? null : ((Number) v).intValue()))))
                .withParity(parity);
    }

    static PositionRow positionRow() {
        return positionRow(1);
    }

    static PositionRow positionRow(int sid) {
        PositionRow row = new PositionRow();
        row.sid = sid;
        row.lat = 500_000_000;
        row.lon = 300_000_000;
        row.profile = 1;
        return row;
    }

    static boolean isPosition(PositionRow row, int sid) {
        return row.sid == sid && row.lat == 500_000_000 && row.lon == 300_000_000 && row.profile == 1
                && row.heading == null && row.speed == null && row.altitude == null;
    }

    /** One unpack of the position scheme: what it returned and the rows the handler saw. */
    static final class Run {
        Object result;
        final List<PositionRow> rows = new ArrayList<>();

        boolean ok() {
            return result instanceof Packbin.Repaired;
        }

        int repaired() {
            return ok() ? ((Packbin.Repaired) result).count : -1;
        }

        boolean uncorrectable() {
            return result instanceof Packbin.Uncorrectable;
        }

        /** The unpack succeeded, repaired {@code count} bytes and handed over the row of {@code sid} once. */
        boolean recovered(int count, int sid) {
            return ok() && repaired() == count && rows.size() == 1 && isPosition(rows.get(0), sid);
        }
    }

    static Run unpackPosition(byte[] message, int parity, int limit) {
        Run run = new Run();
        run.result = BinaryPacker.unpackRepair(message, limit, positionScheme(parity).on(run.rows::add));
        return run;
    }

    /** A copy of {@code message} with the byte at each position XORed by the matching non-zero value. */
    static byte[] corrupt(byte[] message, int[] positions, int[] values) {
        byte[] out = message.clone();
        for (int i = 0; i < positions.length; i++) {
            out[positions[i]] ^= (byte) values[i];
        }
        return out;
    }

    /** {@code count} distinct positions below {@code size}. */
    static int[] pickPositions(Random random, int size, int count) {
        int[] out = new int[count];
        int taken = 0;
        while (taken < count) {
            int p = random.nextInt(size);
            boolean seen = false;
            for (int i = 0; i < taken; i++) {
                seen |= out[i] == p;
            }
            if (!seen) {
                out[taken++] = p;
            }
        }
        return out;
    }

    /** {@code count} non-zero XOR values. */
    static int[] pickValues(Random random, int count) {
        int[] out = new int[count];
        for (int i = 0; i < count; i++) {
            out[i] = 1 + random.nextInt(255);
        }
        return out;
    }

    static byte[] bytesOf(String hex) {
        return hex.equals("-") ? new byte[0] : PackbinTest.parseHex(hex);
    }

    static String hexOf(byte[] bytes) {
        return PackbinTest.toHex(bytes);
    }

    /** The rows of fixtures/ecc/vectors.txt of one kind: the columns after the kind, the id first. */
    static List<String[]> vectorRows(String kind) {
        List<String[]> out = new ArrayList<>();
        for (String[] row : allVectorRows()) {
            if (row[0].equals(kind)) {
                String[] cols = new String[row.length - 1];
                System.arraycopy(row, 1, cols, 0, cols.length);
                out.add(cols);
            }
        }
        return out;
    }

    /** Every data row of the vectors file, kind first. */
    static List<String[]> allVectorRows() {
        List<String[]> out = new ArrayList<>();
        try {
            for (String line : Files.readAllLines(Path.of("fixtures", "ecc", "vectors.txt"), StandardCharsets.UTF_8)) {
                if (!line.isEmpty() && !line.startsWith("#")) {
                    out.add(line.split(" ", -1));
                }
            }
        } catch (IOException ex) {
            throw new IllegalStateException("fixtures/ecc/vectors.txt: " + ex, ex);
        }
        return out;
    }

    /** A scheme whose only field is {@code size} fixed bytes, so a packed message is {@code size + 1} bytes. */
    @SuppressWarnings({"unchecked", "rawtypes"})
    static Scheme<java.util.Map> blob(int size, int parity) {
        return Maps.scheme(0, Packbin.bytes(0, Access.get("b"), Access.set("b"), size)).withParity(parity);
    }
}

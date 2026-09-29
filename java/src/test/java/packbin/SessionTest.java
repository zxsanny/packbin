package packbin;

public final class SessionTest {
    private static int failures;

    private static final String CIPHERTEXT_HEX = "b55d0a29c56c203712b241232e";
    private static final String GOLDEN_HEX = "4001000065cd1d00a3e1110100";
    private static final byte[] NONCE = PackbinTest.parseHex("01000000000000000000000000000000");

    private static final Scheme<PositionRow> POSITION = new Scheme<>(
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
                    Packbin.i16(6, Access.get((PositionRow r) -> r.altitude), Access.set((PositionRow r, Object v) -> r.altitude = v == null ? null : ((Number) v).intValue()))));

    public static void main(String[] args) {
        ac1CiphertextMatchesCsharp();
        ac2WaiterRecoversRow();
        ac3ClearPackUnchanged();
        ac4BadLengthsCreateNothing();
        if (failures > 0) {
            System.err.println(failures + " failure(s)");
            System.exit(1);
        }
        System.out.println("All session tests passed");
    }

    private static byte[] seed() {
        byte[] bytes = new byte[32];
        for (int i = 0; i < 32; i++) {
            bytes[i] = (byte) (i + 1);
        }
        return bytes;
    }

    private static PositionRow position() {
        PositionRow row = new PositionRow();
        row.sid = 1;
        row.lat = 500_000_000;
        row.lon = 300_000_000;
        row.profile = 1;
        return row;
    }

    private static int fieldMismatches(PositionRow row) {
        int n = 0;
        if (row.sid != 1) {
            n++;
        }
        if (row.lat != 500_000_000) {
            n++;
        }
        if (row.lon != 300_000_000) {
            n++;
        }
        if (row.profile != 1) {
            n++;
        }
        if (row.heading != null) {
            n++;
        }
        if (row.speed != null) {
            n++;
        }
        if (row.altitude != null) {
            n++;
        }
        return n;
    }

    private static void ac1CiphertextMatchesCsharp() {
        PackSession opener = PackSession.load(seed());
        expectTrue("AC-1 opener", opener != null);
        byte[] nonce = opener.start(NONCE);
        expectEq("AC-1 nonce", PackbinTest.toHex(NONCE), PackbinTest.toHex(nonce));
        byte[] payload = opener.pack(POSITION, position());
        expectTrue("AC-1 payload", payload != null);
        expectEq("AC-1 length", 13, payload.length);
        expectEq("AC-1 hex", CIPHERTEXT_HEX, PackbinTest.toHex(payload));
        expectEq(
                "AC-1 mismatched",
                0,
                PackbinTest.mismatchedBytes(payload, PackbinTest.parseHex(CIPHERTEXT_HEX)));
    }

    private static void ac2WaiterRecoversRow() {
        PackSession opener = PackSession.load(seed());
        PackSession waiter = PackSession.load(seed());
        expectTrue("AC-2 opener", opener != null);
        expectTrue("AC-2 waiter", waiter != null);
        expectEq("AC-2 start", PackbinTest.toHex(NONCE), PackbinTest.toHex(opener.start(NONCE)));
        expectTrue("AC-2 join", waiter.join(NONCE));
        byte[] payload = opener.pack(POSITION, position());
        expectTrue("AC-2 payload", payload != null);
        PositionRow[] got = new PositionRow[1];
        Object err = waiter.unpack(payload, POSITION.on(row -> got[0] = row));
        expectTrue("AC-2 ok", err == null);
        expectTrue("AC-2 row", got[0] != null);
        expectEq("AC-2 field mismatches", 0, fieldMismatches(got[0]));
    }

    private static void ac3ClearPackUnchanged() {
        byte[] bytes = BinaryPacker.pack(POSITION, position());
        expectEq("AC-3 hex", GOLDEN_HEX, PackbinTest.toHex(bytes));
        expectEq(
                "AC-3 mismatched",
                0,
                PackbinTest.mismatchedBytes(bytes, PackbinTest.parseHex(GOLDEN_HEX)));
    }

    private static void ac4BadLengthsCreateNothing() {
        int created = 0;
        if (PackSession.load(new byte[31]) != null) {
            created++;
        }
        if (PackSession.load(new byte[33]) != null) {
            created++;
        }
        PackSession loaded = PackSession.load(seed());
        expectTrue("AC-4 loaded", loaded != null);
        if (loaded.join(new byte[15])) {
            created++;
        }
        if (loaded.join(new byte[17])) {
            created++;
        }
        if (loaded.start(new byte[15]) != null) {
            created++;
        }
        expectEq("AC-4 sessions created", 0, created);
        expectTrue("AC-4 pack before open", loaded.pack(POSITION, position()) == null);
    }

    private static void expectEq(String label, Object expected, Object actual) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            fail(label + ": expected " + expected + ", got " + actual);
        }
    }

    private static void expectTrue(String label, boolean condition) {
        if (!condition) {
            fail(label + ": expected true");
        }
    }

    private static void fail(String message) {
        failures++;
        System.err.println("FAIL " + message);
    }
}

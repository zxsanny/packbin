package packbin;

import java.util.Locale;

public final class FieldIdBindingTest {
    private static int failures;

    public static final class MarkerRow {
        public int sid;
        public int lat;
        public int lon;
        public byte kind;
        public Integer kindId;
        public int title;
        public Boolean hidden;
        public Boolean delta;
    }

    public static final class PointsRow {
        public int sid;
        public java.util.List<Integer> points;
    }

    private static final String AC1_HEX = "2001000065cd1d00a3e111010000000000";

    private static final Scheme<MarkerRow> MARKER = new Scheme<>(
            0x20,
            MarkerRow.class,
            Packbin.u16(0, Access.get((MarkerRow r) -> r.sid), Access.set((MarkerRow r, Object v) -> r.sid = ((Number) v).intValue())),
            Packbin.i32(1, Access.get((MarkerRow r) -> r.lat), Access.set((MarkerRow r, Object v) -> r.lat = ((Number) v).intValue())),
            Packbin.i32(2, Access.get((MarkerRow r) -> r.lon), Access.set((MarkerRow r, Object v) -> r.lon = ((Number) v).intValue())),
            Packbin.u8(3, Access.get((MarkerRow r) -> r.kind & 0xFF), Access.set((MarkerRow r, Object v) -> r.kind = ((Number) v).byteValue())),
            Packbin.when(Packbin.eq(3, 1),
                    Packbin.u16(4, Access.get((MarkerRow r) -> r.kindId), Access.set((MarkerRow r, Object v) -> r.kindId = v == null ? null : ((Number) v).intValue()))),
            Packbin.u16(5, Access.get((MarkerRow r) -> r.title), Access.set((MarkerRow r, Object v) -> r.title = ((Number) v).intValue())),
            Packbin.flags(
                    Packbin.boolField(6, Access.get((MarkerRow r) -> r.hidden), Access.set((MarkerRow r, Object v) -> r.hidden = (Boolean) v)),
                    Packbin.boolField(7, Access.get((MarkerRow r) -> r.delta), Access.set((MarkerRow r, Object v) -> r.delta = (Boolean) v))));

    public static void main(String[] args) {
        ac1MemberNamesAreNotWireNames();
        ac2SiblingReferencesUseOrder();
        ac3FlagsUseChildAccessors();
        ac4NestedRowTypeHasOwnIds();
        ac5OrderMustMatchTheNumber();
        ac6Ac1BytesStable();
        if (failures > 0) {
            System.err.println(failures + " failure(s)");
            System.exit(1);
        }
        System.out.println("Field id binding tests passed");
    }

    private static MarkerRow marker() {
        MarkerRow row = new MarkerRow();
        row.sid = 1;
        row.lat = 500_000_000;
        row.lon = 300_000_000;
        row.kind = 1;
        row.kindId = 0;
        row.title = 0;
        return row;
    }

    private static void ac1MemberNamesAreNotWireNames() {
        byte[] bytes = BinaryPacker.pack(MARKER, marker());
        expectEq("AC-1 hex", AC1_HEX, toHex(bytes));
        expectEq("AC-1 type", 0x20, bytes[0] & 0xFF);
        int lat = (bytes[3] & 0xFF)
                | ((bytes[4] & 0xFF) << 8)
                | ((bytes[5] & 0xFF) << 16)
                | ((bytes[6] & 0xFF) << 24);
        expectEq("AC-1 lat bytes", 500_000_000, lat);
        Packbin.Bound<MarkerRow> back = BinaryPacker.unpack(MARKER, bytes);
        expectTrue("AC-1 ok", back.ok);
        expectEq("AC-1 Lat", 500_000_000, back.value.lat);
        expectEq("AC-1 Sid", 1, back.value.sid);
        expectEq("AC-1 Lon", 300_000_000, back.value.lon);
        expectEq("AC-1 Kind", (byte) 1, back.value.kind);
    }

    private static void ac2SiblingReferencesUseOrder() {
        MarkerRow withKind = new MarkerRow();
        withKind.sid = 1;
        withKind.kind = 1;
        withKind.kindId = 9;
        byte[] hit = BinaryPacker.pack(MARKER, withKind);
        int kindId = (hit[12] & 0xFF) | ((hit[13] & 0xFF) << 8);
        expectEq("AC-2 kindId bytes", 9, kindId);
        Packbin.Bound<MarkerRow> backHit = BinaryPacker.unpack(MARKER, hit);
        expectTrue("AC-2 hit ok", backHit.ok);
        expectEq("AC-2 KindId", 9, backHit.value.kindId);

        MarkerRow without = new MarkerRow();
        without.sid = 1;
        without.kind = 0;
        byte[] miss = BinaryPacker.pack(MARKER, without);
        expectEq("AC-2 omitted", hit.length - 2, miss.length);
        Packbin.Bound<MarkerRow> backMiss = BinaryPacker.unpack(MARKER, miss);
        expectTrue("AC-2 miss ok", backMiss.ok);
        expectTrue("AC-2 KindId null", backMiss.value.kindId == null);
    }

    private static void ac3FlagsUseChildAccessors() {
        MarkerRow row = new MarkerRow();
        row.sid = 1;
        row.kind = 0;
        row.hidden = true;
        byte[] bytes = BinaryPacker.pack(MARKER, row);
        expectEq("AC-3 flag byte", 0x01, bytes[bytes.length - 1] & 0xFF);
        Packbin.Bound<MarkerRow> back = BinaryPacker.unpack(MARKER, bytes);
        expectTrue("AC-3 ok", back.ok);
        expectEq("AC-3 Hidden", Boolean.TRUE, back.value.hidden);
        expectTrue("AC-3 Delta null", back.value.delta == null);
    }

    private static void ac4NestedRowTypeHasOwnIds() {
        Scheme<PointsRow> scheme = new Scheme<>(
                0x20,
                PointsRow.class,
                Packbin.u16(0, Access.get((PointsRow r) -> r.sid), Access.set((PointsRow r, Object v) -> r.sid = ((Number) v).intValue())),
                Packbin.list(
                        Access.get((PointsRow r) -> r.points),
                        Access.set((PointsRow r, Object v) -> r.points = (java.util.List<Integer>) v),
                        Packbin.u16(0, Access.identity(), Access.ignore())));
        PointsRow row = new PointsRow();
        row.sid = 1;
        row.points = java.util.List.of(7, 8);
        byte[] bytes = BinaryPacker.pack(scheme, row);
        expectEq("AC-4 type", 0x20, bytes[0] & 0xFF);
        expectEq("AC-4 sid", 1, (bytes[1] & 0xFF) | ((bytes[2] & 0xFF) << 8));
        expectEq("AC-4 count", 2, (bytes[3] & 0xFF) | ((bytes[4] & 0xFF) << 8));
        expectEq("AC-4 p0", 7, (bytes[5] & 0xFF) | ((bytes[6] & 0xFF) << 8));
        expectEq("AC-4 p1", 8, (bytes[7] & 0xFF) | ((bytes[8] & 0xFF) << 8));
    }

    private static void ac5OrderMustMatchTheNumber() {
        expectThrows(() -> new Scheme<>(0x20, MarkerRow.class,
                Packbin.i32(2, Access.get((MarkerRow r) -> r.lat), Access.set((MarkerRow r, Object v) -> r.lat = ((Number) v).intValue()))));
        expectThrows(() -> new Scheme<>(0x20, MarkerRow.class,
                Packbin.u16(0, Access.get((MarkerRow r) -> r.sid), Access.set((MarkerRow r, Object v) -> r.sid = ((Number) v).intValue())),
                Packbin.i32(0, Access.get((MarkerRow r) -> r.lat), Access.set((MarkerRow r, Object v) -> r.lat = ((Number) v).intValue()))));
        expectThrows(() -> new Scheme<>(0x20, MarkerRow.class,
                Packbin.u16(0, Access.get((MarkerRow r) -> r.sid), Access.set((MarkerRow r, Object v) -> r.sid = ((Number) v).intValue())),
                Packbin.i32(2, Access.get((MarkerRow r) -> r.lat), Access.set((MarkerRow r, Object v) -> r.lat = ((Number) v).intValue()))));
    }

    private static void ac6Ac1BytesStable() {
        byte[] bytes = BinaryPacker.pack(MARKER, marker());
        expectEq("AC-6 mismatched", 0, PackbinTest.mismatchedBytes(bytes, PackbinTest.parseHex(AC1_HEX)));
        Packbin.Bound<MarkerRow> back = BinaryPacker.unpack(MARKER, bytes);
        expectEq("AC-6 Lat", 500_000_000, back.value.lat);
    }

    private static void expectThrows(Runnable action) {
        try {
            action.run();
            fail("expected exception");
        } catch (IllegalArgumentException ex) {
        }
    }

    private static String toHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format(Locale.ROOT, "%02x", b & 0xFF));
        }
        return sb.toString();
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

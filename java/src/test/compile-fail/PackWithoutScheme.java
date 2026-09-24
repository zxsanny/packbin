package packbin;

final class PackWithoutScheme {
    static final class MarkerRow {
        public byte sid;
    }

    public static void main(String[] args) {
        MarkerRow row = new MarkerRow();
        row.sid = 23;
        BinaryPacker.pack(row);
    }
}

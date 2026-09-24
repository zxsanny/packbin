import java.util.HashMap;
import java.util.Map;
import packbin.Pack;
import packbin.Packbin;
import packbin.Scheme;

public final class Position {
    private static final class Row {}

    public static void main(String[] args) {
        Scheme<Row> scheme = new Scheme<>(
                0x40,
                Row.class,
                Packbin.u16("sid"),
                Packbin.i32("lat"),
                Packbin.i32("lon"),
                Packbin.u8("profile"),
                Packbin.flags(
                        "motion",
                        Packbin.u16("heading"),
                        Packbin.u8("speed"),
                        Packbin.i16("altitude")));
        Map<String, Object> values = new HashMap<>();
        values.put("sid", 1);
        values.put("lat", 500_000_000);
        values.put("lon", 300_000_000);
        values.put("profile", 1);
        byte[] raw = Pack.run(scheme, values);
        StringBuilder hex = new StringBuilder();
        for (byte b : raw) {
            hex.append(String.format("%02x", b));
        }
        System.out.println(hex);
    }
}

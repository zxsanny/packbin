import java.util.HashMap;
import java.util.Map;
import packbin.Packbin;

public final class Position {
    public static void main(String[] args) {
        Packbin.Packet packet = Packbin.packet(
                Packbin.u8("type"),
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
        values.put("type", 0x40);
        values.put("sid", 1);
        values.put("lat", 500_000_000);
        values.put("lon", 300_000_000);
        values.put("profile", 1);
        byte[] raw = Packbin.pack(packet, values);
        StringBuilder hex = new StringBuilder();
        for (byte b : raw) {
            hex.append(String.format("%02x", b));
        }
        System.out.println(hex);
    }
}

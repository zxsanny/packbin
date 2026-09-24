import java.util.HashMap;
import java.util.Map;
import packbin.Access;
import packbin.BinaryPacker;
import packbin.Packbin;
import packbin.Scheme;

public final class Position {
    @SuppressWarnings({"unchecked", "rawtypes"})
    public static void main(String[] args) {
        Scheme<Map> scheme = new Scheme<>(
                0x40,
                (Class) Map.class,
                Packbin.u16(0, Access.get("sid"), Access.set("sid")),
                Packbin.i32(1, Access.get("lat"), Access.set("lat")),
                Packbin.i32(2, Access.get("lon"), Access.set("lon")),
                Packbin.u8(3, Access.get("profile"), Access.set("profile")),
                Packbin.flags(
                        Packbin.u16(4, Access.get("heading"), Access.set("heading")),
                        Packbin.u8(5, Access.get("speed"), Access.set("speed")),
                        Packbin.i16(6, Access.get("altitude"), Access.set("altitude"))));
        Map<String, Object> values = new HashMap<>();
        values.put("sid", 1);
        values.put("lat", 500_000_000);
        values.put("lon", 300_000_000);
        values.put("profile", 1);
        byte[] raw = BinaryPacker.pack(scheme, values);
        StringBuilder hex = new StringBuilder();
        for (byte b : raw) {
            hex.append(String.format("%02x", b));
        }
        System.out.println(hex);
    }
}

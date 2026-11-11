package packbin;

import java.util.*;

@SuppressWarnings({"unchecked", "rawtypes"})
public final class Probe102 {
    static String hex(byte[] b) { StringBuilder s = new StringBuilder(); for (byte x : b) s.append(String.format("%02x", x & 0xff)); return s.toString(); }
    static String units(String k) { StringBuilder s = new StringBuilder(); for (char c : k.toCharArray()) s.append(String.format("U+%04X ", (int) c)); return s.toString().trim(); }
    static String err(Object e) {
        if (e == null) return "null";
        if (e instanceof Packbin.ShortPacket p) return "ShortPacket(field=\"" + p.field + "\", needed=" + p.needed + ", left=" + p.left + ")";
        if (e instanceof Packbin.TrailingBytes t) return "TrailingBytes(left=" + t.left + ")";
        return e.getClass().getSimpleName() + " " + e;
    }
    static void roundTrip(Scheme<Map> scheme, byte[] pkt, String key) {
        Map[] got = new Map[1];
        Object e;
        try {
            e = BinaryPacker.unpack(pkt, scheme.on(row -> got[0] = row));
        } catch (RuntimeException ex) { System.out.println("  unpack THREW " + ex); return; }
        System.out.println("  unpack error=" + err(e));
        if (got[0] != null) {
            Object v = got[0].get(key);
            if (v instanceof Map<?, ?> m) {
                for (Object k : m.keySet()) System.out.println("  key read back: " + units((String) k) + " -> " + m.get(k));
                System.out.println("  count=" + m.size());
            } else System.out.println("  value: " + v + (v instanceof String s ? " units: " + units(s) : ""));
        } else System.out.println("  no row delivered");
    }
    static void dictCase(String label, String[] keys, Object[] vals) {
        System.out.println("CASE " + label);
        Scheme<Map> scheme = new Scheme<>(1, (Class) Map.class, Packbin.dict(Access.get("d"), Access.set("d"),
                Packbin.u8(0, Access.identity(), Access.ignore())));
        Map<String, Object> d = new LinkedHashMap<>();
        for (int i = 0; i < keys.length; i++) d.put(keys[i], vals[i]);
        Map<String, Object> row = new HashMap<>(); row.put("d", d);
        byte[] pkt;
        try { pkt = BinaryPacker.pack(scheme, row); } catch (Throwable t) { System.out.println("  pack THREW " + t.getClass().getName() + ": " + t.getMessage()); return; }
        System.out.println("  pack hex=" + hex(pkt));
        roundTrip(scheme, pkt, "d");
    }
    public static void main(String[] a) {
        dictCase("A", new String[]{"\uD800", "\uDC00"}, new Object[]{1, 2});
        dictCase("B", new String[]{"�", "\uD800"}, new Object[]{1, 2});
        dictCase("C", new String[]{"?", "\uD800"}, new Object[]{1, 2});
        dictCase("D", new String[]{"\uD800"}, new Object[]{1});
        System.out.println("CASE E");
        Scheme<Map> s = new Scheme<>(1, (Class) Map.class, Packbin.utf8(0, Access.get("s"), Access.set("s")));
        Map<String, Object> row = new HashMap<>(); row.put("s", "\uD800");
        try { byte[] pkt = BinaryPacker.pack(s, row); System.out.println("  pack hex=" + hex(pkt)); roundTrip(s, pkt, "s"); }
        catch (Throwable t) { System.out.println("  pack THREW " + t.getClass().getName() + ": " + t.getMessage()); }
    }
}

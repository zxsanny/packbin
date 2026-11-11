package packbin;

import java.nio.file.*;
import java.util.*;

@SuppressWarnings({"unchecked", "rawtypes"})
public final class Diff103 {
    static String key(String u) { if (u.equals("-")) return ""; StringBuilder sb = new StringBuilder(); for (int i = 0; i < u.length(); i += 4) sb.append((char) Integer.parseInt(u.substring(i, i + 4), 16)); return sb.toString(); }
    static String hex(byte[] b) { StringBuilder s = new StringBuilder(); for (byte x : b) s.append(String.format("%02x", x & 0xff)); return s.toString(); }
    public static void main(String[] a) throws Exception {
        Scheme<Map> scheme = new Scheme<>(1, (Class) Map.class, Packbin.dict(Access.get("d"), Access.set("d"), Packbin.u8(0, Access.identity(), Access.ignore())));
        int same = 0, diff = 0, refused = 0;
        for (String line : Files.readAllLines(Path.of(a[0]))) {
            if (line.isEmpty()) continue;
            String[] f = line.split("\t", -1);
            String[] ks = f[0].split(","), vs = f[1].split(",");
            Map<String, Object> d = new LinkedHashMap<>();
            for (int i = 0; i < ks.length; i++) d.put(key(ks[i]), Integer.parseInt(vs[i]));
            Map<String, Object> row = new HashMap<>(); row.put("d", d);
            String got;
            try { got = hex(BinaryPacker.pack(scheme, row)); }
            catch (IllegalArgumentException e) { if (e.getMessage().contains("two keys are the same")) { got = "REFUSED"; refused++; } else got = "OTHER " + e.getMessage(); }
            if (got.equals(f[2])) same++; else { diff++; if (diff < 6) System.out.println("DIFF keys=" + f[0] + " ts=" + f[2] + " java=" + got); }
        }
        System.out.println("java vs typescript: " + same + " same, " + diff + " different, " + refused + " refused");
    }
}

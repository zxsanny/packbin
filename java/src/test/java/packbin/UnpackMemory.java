package packbin;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * AZ-2415: the worst-case unpack shapes of reference_loop22.md section 2 (F10 and wide), and a main for the memory
 * A/B: {@code java -Xmx4g -cp main:test packbin.UnpackMemory f10|wide [maxSlots]} prints the outcome, the unpack
 * time and the resident set size before ("idle") and after the unpack (peak comes from {@code /usr/bin/time -l}).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class UnpackMemory {
    private UnpackMemory() {}

    private static final int ITEMS = 65_535;

    /** list items, group item { id0 u8 n; id1 times (count id0) { 64 u8 members k0 to k63 } }. */
    static Scheme<Map> f10() {
        Field[] members = new Field[64];
        for (int i = 0; i < members.length; i++) {
            members[i] = Packbin.u8(i + 1, Access.get("k" + i), Access.set("k" + i));
        }
        return Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"),
                Packbin.group(0, Packbin.u8(0, Access.get("n"), Access.set("n")), Packbin.times(1, 0, members))));
    }

    /** Type byte, list count ffff, then 65 535 items of n = 1 and one round of 64 values: 4 259 778 bytes. */
    static byte[] f10Packet() {
        byte[] packet = new byte[3 + 65 * ITEMS];
        Arrays.fill(packet, (byte) 1);
        packet[1] = (byte) 0xff;
        packet[2] = (byte) 0xff;
        return packet;
    }

    /** u32 n; times(n) { 65 u8 }. */
    static Scheme<Map> wide() {
        Field[] members = new Field[65];
        for (int i = 0; i < members.length; i++) {
            members[i] = Packbin.u8(i + 1, Access.get("m" + i), Access.set("m" + i));
        }
        return Maps.scheme(1, Packbin.u32(0, Access.get("n"), Access.set("n")), Packbin.times(1, 0, members));
    }

    /** Type byte, n = 65 535, then 65 535 rounds of 65 values: 4 259 780 bytes. */
    static byte[] widePacket() {
        byte[] packet = new byte[5 + 65 * ITEMS];
        Arrays.fill(packet, (byte) 1);
        packet[1] = (byte) 0xff;
        packet[2] = (byte) 0xff;
        packet[3] = 0;
        packet[4] = 0;
        return packet;
    }

    public static void main(String[] args) throws Exception {
        boolean wide = args[0].equals("wide");
        Scheme<Map> scheme = wide ? wide() : f10();
        if (args.length > 1) {
            scheme = scheme.withLimits(Scheme.DEFAULT_MAX_ROUNDS, Long.parseLong(args[1]));
        }
        byte[] packet = wide ? widePacket() : f10Packet();
        List<Object> rows = new ArrayList<>();
        long idle = rssKilobytes();
        long start = System.nanoTime();
        Object err = BinaryPacker.unpack(packet, scheme.on(rows::add));
        long ms = (System.nanoTime() - start) / 1_000_000;
        String outcome = err == null ? "ok rows=" + rows.size()
                : err instanceof Packbin.ShortPacket s ? "ShortPacket " + s.field + " left=" + s.left : String.valueOf(err);
        System.out.println(args[0] + " packet=" + packet.length + " outcome=" + outcome + " unpack_ms=" + ms
                + " idle_rss_mb=" + idle / 1024 + " after_rss_mb=" + rssKilobytes() / 1024);
    }

    private static long rssKilobytes() throws Exception {
        Process ps = new ProcessBuilder("ps", "-o", "rss=", "-p", String.valueOf(ProcessHandle.current().pid()))
                .redirectInput(ProcessBuilder.Redirect.from(new java.io.File("/dev/null"))).start();
        try (BufferedReader in = new BufferedReader(new InputStreamReader(ps.getInputStream()))) {
            return Long.parseLong(in.readLine().trim());
        }
    }
}

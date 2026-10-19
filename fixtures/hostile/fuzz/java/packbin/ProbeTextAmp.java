package packbin;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * AC-1 probe (c): how much one payload byte can decode to, and the time and memory of the largest texts. Run one case
 * per JVM under /usr/bin/time -l to read its peak RSS ("baseline" is the JVM with nothing decoded).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ProbeTextAmp {
    private static final TextModes.Mode RU = TextModes.MODES[1];

    private ProbeTextAmp() {}

    static void run(String which) {
        switch (which) {
            case "baseline" -> System.out.println("baseline: schemes built, nothing decoded");
            case "max" -> max();
            case "over" -> over();
            case "silent" -> silent();
            case "packet1m" -> packet(1 << 20);
            case "packet16m" -> packet(16 << 20);
            case "dict" -> dict();
            case "collide" -> collide();
            default -> AuditProbe.fail("unknown text-amp case " + which);
        }
    }

    /** A field of {@code chars} Russian 'о' (code 000: 3 bits for 2 UTF-8 bytes, the densest symbol), then spaces. */
    static byte[] russianO(int chars, int spaces) {
        ProbeBits w = new ProbeBits(1);
        int o = ProbeBits.indexOf(RU.letters, 'о');
        for (int i = 0; i < chars; i++) {
            w.symbol(RU, o);
        }
        for (int i = 0; i < spaces; i++) {
            w.symbol(RU, RU.sharedBase);
        }
        return w.field();
    }

    static int payloadLength(byte[] field) {
        int count = 0;
        for (int k = 0; k < 3; k++) {
            count |= (field[k] & 0x7f) << (7 * k);
            if ((field[k] & 0x80) == 0) {
                break;
            }
        }
        return count;
    }

    private static void max() {
        byte[] field = russianO(32_767, 1);
        int payload = payloadLength(field);
        byte[] packet = AuditProbe.concat(new byte[] {1}, field);
        Object[] got = {null};
        Scheme.Handler<?> handler = AuditProbe.SINGLE.on(row -> got[0] = ((Map) row).get("s"));
        double[] m = measure(() -> BinaryPacker.unpack(packet, handler), 30);
        int utf8 = got[0] == null ? 0 : AuditProbe.utf8Count((String) got[0]);
        System.out.printf("max: payload %d B decodes to %d UTF-8 bytes (%.3f per payload byte, bound 6N+8 = %d); unpack median %.2f ms, "
                + "max %.2f ms, allocated %.0f KiB per call%n", payload, utf8, (double) utf8 / payload, 6 * payload + 8, m[0], m[1], m[2] / 1024);
        AuditProbe.check(utf8 == 65_535, "max: the 65,535-byte compact text is accepted");
        byte[] over = AuditProbe.concat(new byte[] {1}, russianO(32_768, 0));
        Object[] error = {null};
        double[] m2 = measure(() -> error[0] = BinaryPacker.unpack(over, handler), 30);
        System.out.printf("max+1: 32,768 x 'о' (65,536 B) refused in median %.2f ms, max %.2f ms, allocated %.0f KiB%n", m2[0], m2[1], m2[2] / 1024);
        AuditProbe.check(error[0] instanceof Packbin.ShortPacket, "max+1: a compact text of 65,536 bytes is refused");
    }

    private static void over() {
        byte[] payload = new byte[2_097_151];
        payload[0] = (byte) ((((8 * payload.length - 6) % 3) << 5) | (1 << 2));
        byte[] packet = AuditProbe.concat(new byte[] {1}, AuditProbe.varint(payload.length), payload);
        Object[] error = {null};
        Scheme.Handler<?> handler = AuditProbe.SINGLE.on(row -> {});
        double[] m = measure(() -> error[0] = BinaryPacker.unpack(packet, handler), 30);
        System.out.printf("over: count 2,097,151, a payload of 'о' codes (%d B packet): %s, median %.2f ms, max %.2f ms, allocated %.0f KiB per call%n",
                packet.length, error[0] == null ? "ok" : error[0].getClass().getSimpleName(), m[0], m[1], m[2] / 1024);
        AuditProbe.check(error[0] instanceof Packbin.ShortPacket, "over: refused at the 65,535-byte limit");
    }

    private static void silent() {
        ProbeBits w = new ProbeBits(0);
        TextModes.Mode ua = TextModes.MODES[0];
        TextModes.Mode num = TextModes.MODES[3];
        while (w.size() < 8 * 2_097_151 - 14 - 7) {
            w.symbol(ua, ProbeBits.switchSymbol(ua, 0, 3));
            w.symbol(num, num.swBase);
        }
        byte[] field = w.field();
        int length = payloadLength(field);
        byte[] packet = AuditProbe.concat(new byte[] {1}, field);
        Object[] got = {null};
        Object[] error = {null};
        Scheme.Handler<?> handler = AuditProbe.SINGLE.on(row -> got[0] = ((Map) row).get("s"));
        double[] m = measure(() -> error[0] = BinaryPacker.unpack(packet, handler), 10);
        System.out.printf("silent: payload %d B of switch pairs -> %s '%s', median %.1f ms, max %.1f ms, allocated %.0f KiB per call (%.1f ns per payload byte)%n",
                length, error[0] == null ? "ok" : error[0].getClass().getSimpleName(), got[0], m[0], m[1], m[2] / 1024, m[0] * 1e6 / length);
        AuditProbe.check(error[0] == null && "".equals(got[0]), "silent: a payload of switches only decodes to the empty text");
    }

    private static void packet(int size) {
        byte[] field = russianO(32_767, 1);
        int k = Math.min(65_535, (size - 3) / field.length);
        List<byte[]> parts = new ArrayList<>();
        parts.add(new byte[] {3, (byte) k, (byte) (k >> 8)});
        for (int i = 0; i < k; i++) {
            parts.add(field);
        }
        byte[] packet = AuditProbe.concat(parts.toArray(new byte[0][]));
        long[] decoded = {0};
        Object[] error = {null};
        Scheme.Handler<?> handler = AuditProbe.LIST.on(row -> {
            long total = 0;
            for (Object e : (List) ((Map) row).get("l")) {
                total += AuditProbe.utf8Count((String) e);
            }
            decoded[0] = total;
        });
        double[] m = measure(() -> error[0] = BinaryPacker.unpack(packet, handler), 3);
        Runtime rt = Runtime.getRuntime();
        System.out.printf("packet: %d B list of %d texts -> %s, decoded %d UTF-8 B (%.2f per packet byte); median %.0f ms, max %.0f ms, "
                + "allocated %.0f MiB per call; heap used now %d MiB%n", packet.length, k,
                error[0] == null ? "ok" : error[0].getClass().getSimpleName(), decoded[0], (double) decoded[0] / packet.length,
                m[0], m[1], m[2] / 1048576, (rt.totalMemory() - rt.freeMemory()) / 1048576);
        AuditProbe.check(error[0] == null, "packet: the " + packet.length + "-byte list of 65,535-byte texts unpacks");
    }

    private static void dict() {
        List<byte[]> parts = new ArrayList<>();
        parts.add(new byte[] {2, (byte) 0xff, (byte) 0xff});
        for (int i = 0; i < 65_535; i++) {
            parts.add(new byte[] {5, 0x10, (byte) ('a' + i % 26), (byte) ('a' + i / 26 % 26), (byte) ('a' + i / 676 % 26),
                (byte) ('a' + i / 17_576), 1});
        }
        byte[] packet = AuditProbe.concat(parts.toArray(new byte[0][]));
        Object[] error = {null};
        int[] keys = {0};
        Scheme.Handler<?> handler = AuditProbe.MAP.on(row -> keys[0] = ((Map) ((Map) row).get("m")).size());
        double[] m = measure(() -> error[0] = BinaryPacker.unpack(packet, handler), 5);
        System.out.printf("dict: %d B, 65,535 keys -> %s (%d keys), median %.1f ms, max %.1f ms, allocated %.1f MiB per call%n", packet.length,
                error[0] == null ? "ok" : error[0].getClass().getSimpleName(), keys[0], m[0], m[1], m[2] / 1048576);
        List<byte[]> same = new ArrayList<>();
        same.add(new byte[] {2, (byte) 0xff, (byte) 0xff});
        for (int i = 0; i < 65_535; i++) {
            same.add(new byte[] {2, 0x10, 0x61, 1});
        }
        byte[] dup = AuditProbe.concat(same.toArray(new byte[0][]));
        double[] m2 = measure(() -> error[0] = BinaryPacker.unpack(dup, handler), 5);
        System.out.printf("dict: 65,535 copies of key 'a' -> %s, median %.3f ms, max %.3f ms%n",
                error[0] == null ? "ok" : error[0].getClass().getSimpleName(), m2[0], m2[1]);
        AuditProbe.check(error[0] instanceof Packbin.ShortPacket, "dict: a repeated key is refused");
    }

    /** 65,535 distinct 32-byte keys with one String.hashCode ("Aa" and "BB" blocks): the hash-collision angle. */
    private static void collide() {
        List<byte[]> parts = new ArrayList<>();
        parts.add(new byte[] {2, (byte) 0xff, (byte) 0xff});
        int hash = 0;
        for (int i = 0; i < 65_535; i++) {
            StringBuilder key = new StringBuilder();
            for (int j = 0; j < 16; j++) {
                key.append(((i >> j) & 1) != 0 ? "Aa" : "BB");
            }
            hash = key.toString().hashCode();
            parts.add(AuditProbe.concat(new byte[] {33, 0x10}, key.toString().getBytes(java.nio.charset.StandardCharsets.US_ASCII), new byte[] {1}));
        }
        byte[] packet = AuditProbe.concat(parts.toArray(new byte[0][]));
        Object[] error = {null};
        int[] keys = {0};
        Scheme.Handler<?> handler = AuditProbe.MAP.on(row -> keys[0] = ((Map) ((Map) row).get("m")).size());
        double[] m = measure(() -> error[0] = BinaryPacker.unpack(packet, handler), 5);
        System.out.printf("collide: %d B, 65,535 keys with hashCode %d -> %s (%d keys), median %.1f ms, max %.1f ms, allocated %.1f MiB per call%n",
                packet.length, hash, error[0] == null ? "ok" : error[0].getClass().getSimpleName(), keys[0], m[0], m[1], m[2] / 1048576);
        AuditProbe.check(error[0] == null && keys[0] == 65_535 && m[0] < 1000, "collide: 65,535 colliding keys unpack in under 1 s");
    }

    /** {median ms, max ms, bytes allocated per call} after 2 warm-up calls. */
    static double[] measure(Supplier<Object> call, int runs) {
        call.get();
        call.get();
        double[] times = new double[runs];
        long before = AuditProbe.allocated();
        for (int i = 0; i < runs; i++) {
            long t0 = System.nanoTime();
            call.get();
            times[i] = (System.nanoTime() - t0) / 1e6;
        }
        long alloc = (AuditProbe.allocated() - before) / runs;
        Arrays.sort(times);
        return new double[] {times[runs / 2], times[runs - 1], alloc};
    }
}

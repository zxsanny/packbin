package packbin;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * AC-2 probe (a): seeded random and corrupted protected messages against EccRepair.repair and the public unpackRepair
 * (dispatch after repair, then the text decoder). Seeds: fixtures/ecc/vectors.txt.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ProbeFuzzEcc {
    private static final Scheme<Map>[] SINGLE = new Scheme[33];
    private static final Scheme.Handler<?>[][] HANDLERS = new Scheme.Handler[33][];

    private ProbeFuzzEcc() {}

    static void run(int seed, int count) throws IOException {
        Random r = new Random(seed);
        for (int n = 0; n <= 32; n++) {
            SINGLE[n] = AuditProbe.SINGLE.withParity(n);
            HANDLERS[n] = new Scheme.Handler<?>[] {SINGLE[n].on(x -> {}), AuditProbe.MAP.withParity(n).on(x -> {}),
                AuditProbe.LIST.withParity(n).on(x -> {}), AuditProbe.MAP_TEXT.withParity(n).on(x -> {})};
        }
        List<Object[]> vectors = vectors();
        System.out.println("vector rows " + vectors.size() + ", iterations " + count);
        AuditProbe.Stats repair = new AuditProbe.Stats("EccRepair.repair");
        AuditProbe.Stats unpack = new AuditProbe.Stats("unpackRepair (4 handlers)");
        long[] c = new long[4]; // repaired ok, count differs, missed, miscorrected
        for (Object[] v : vectors) {
            repairOnce((byte[]) v[2], (int) v[0], (int) v[1], null, -1, repair, c);
        }
        for (int i = 0; i < count; i++) {
            int n = r.nextInt(5) == 0 ? new int[] {1, 2, 31, 32}[r.nextInt(4)] : 1 + r.nextInt(32);
            int t = r.nextInt(3) == 0 ? n / 2 : r.nextInt(n / 2 + 1);
            byte[] clear = clear(r, n);
            byte[] sent = ProbeGf.protect(clear, n);
            byte[][] holder = {sent.clone()};
            int k = damage(r, holder, n, t, clear);
            byte[] received = holder[0];
            repairOnce(received, n, t, k >= 0 ? sent : null, k, repair, c);
            if (i % 4 == 0) {
                int nn = n;
                int tt = t;
                unpack.contextN = n;
                unpack.contextT = t;
                ProbeFuzzText.runUnpack(received, unpack, () -> BinaryPacker.unpackRepair(received, tt, HANDLERS[nn]));
            }
        }
        repair.retime(b -> EccRepair.repair(b, repair.slowN, repair.slowT));
        unpack.retime(b -> BinaryPacker.unpackRepair(b, unpack.slowT, HANDLERS[unpack.slowN]));
        repair.print();
        unpack.print();
        System.out.printf("repairs that returned a word: %d; changed bytes != repaired count: %d; damage within t not repaired: %d; "
                + "repaired to another code word (beyond n - t, R06): %d%n",
                c[0], c[1], c[2], c[3]);
        if (c[2] > 0) {
            AuditProbe.fail(c[2] + " messages with at most t wrong bytes were not repaired");
        }
    }

    private static void repairOnce(byte[] received, int n, int t, byte[] sent, int k, AuditProbe.Stats stats, long[] c) {
        byte[] copy = received.clone();
        Object result;
        stats.contextN = n;
        stats.contextT = t;
        long t0 = System.nanoTime();
        try {
            result = EccRepair.repair(received, n, t);
        } catch (RuntimeException | Error ex) {
            stats.threw(ex, received);
            stats.time(t0, received);
            return;
        }
        stats.time(t0, received);
        stats.outcome(result);
        if (!Arrays.equals(copy, received)) {
            AuditProbe.fail("EccRepair.repair wrote its input");
        }
        String tag = "n=" + n + " t=" + t + " N=" + received.length + " " + AuditProbe.hex(received, 16);
        if ((received.length > Ecc.MAX_BLOCK) != (result instanceof Packbin.TooLong)) {
            AuditProbe.fail("too_long mismatch: " + result.getClass().getSimpleName() + " for " + tag);
        }
        if (received.length <= Ecc.MAX_BLOCK
                && (received.length < n) != (result instanceof Packbin.ShortPacket s && s.field.equals("parity"))) {
            AuditProbe.fail("short mismatch: " + result.getClass().getSimpleName() + " for " + tag);
        }
        byte[] word = null;
        int repaired = -1;
        if (result instanceof EccRepair.Fixed fixed) {
            c[0]++;
            repaired = fixed.repaired;
            // The package returns only the clear part; rebuild the word from it to check it is a code word.
            word = ProbeGf.protect(fixed.clear, n);
            if (repaired < 0 || repaired > t || word.length != received.length) {
                AuditProbe.fail("bad repair result: repaired " + repaired + " for " + tag);
            }
            int changed = 0;
            for (int i = 0; i < Math.min(word.length, received.length); i++) {
                changed += word[i] != received[i] ? 1 : 0;
            }
            if (changed != repaired) {
                c[1]++;
            }
            if (changed > repaired) {
                AuditProbe.fail("changed " + changed + " bytes but reports " + repaired + " for " + tag);
            }
            if (sent != null && !Arrays.equals(word, sent)) {
                c[3]++;
            }
        }
        if (sent != null && k <= t && (word == null || !Arrays.equals(word, sent) || repaired != k)) {
            c[2]++;
        }
    }

    private static int damage(Random r, byte[][] holder, int n, int t, byte[] clear) {
        int pick = r.nextInt(12);
        if (pick < 7) {
            int k = new int[] {0, t, t + 1, n - t, n - t + 1, n, n + 1, r.nextInt(n + 4)}[r.nextInt(8)];
            ProbeGf.corrupt(holder[0], Math.max(0, k), r);
            return Math.min(Math.max(0, k), holder[0].length);
        }
        if (pick == 7) {
            holder[0] = Arrays.copyOf(holder[0], Math.max(0, holder[0].length - 1 - r.nextInt(3)));
        } else if (pick == 8) {
            byte[] extra = new byte[1 + r.nextInt(3)];
            r.nextBytes(extra);
            holder[0] = AuditProbe.concat(holder[0], extra);
        } else if (pick == 9) {
            holder[0] = new byte[r.nextInt(300)];
            r.nextBytes(holder[0]);
        } else if (pick == 10) {
            holder[0] = new byte[r.nextInt(257)];
            if (r.nextInt(2) == 0) {
                Arrays.fill(holder[0], (byte) 0xff);
            }
        } else {
            holder[0] = ProbeGf.encode(clear.length ^ (1 + r.nextInt(255)), clear, n);
            ProbeGf.corrupt(holder[0], r.nextInt(Math.max(1, t)), r);
        }
        return -1;
    }

    /** A packet of the single-text scheme (type 1) or random bytes. */
    private static byte[] clear(Random r, int n) {
        int room = Ecc.MAX_BLOCK - n;
        if (r.nextInt(2) == 0) {
            int chars = r.nextInt(Math.max(1, room / 3));
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < chars; i++) {
                int k = r.nextInt(4);
                sb.append(k == 0 ? (char) ('а' + r.nextInt(32)) : k == 1 ? ' ' : k == 2 ? (char) ('0' + r.nextInt(10)) : (char) ('a' + r.nextInt(26)));
            }
            Map<String, Object> row = new HashMap<>();
            row.put("s", sb.toString());
            byte[] packet = BinaryPacker.packClear(AuditProbe.SINGLE, row);
            if (packet.length <= room) {
                return packet;
            }
        }
        byte[] clear = new byte[r.nextInt(room + 1)];
        r.nextBytes(clear);
        return clear;
    }

    private static List<Object[]> vectors() throws IOException {
        List<Object[]> out = new ArrayList<>();
        for (String[] row : AuditProbe.rows("fixtures/ecc/vectors.txt")) {
            if ((row[0].equals("fix") || row[0].equals("bad")) && row.length > 4) {
                out.add(new Object[] {Integer.parseInt(row[2]), Integer.parseInt(row[3]), AuditProbe.bytes(row[4])});
            }
        }
        return out;
    }
}

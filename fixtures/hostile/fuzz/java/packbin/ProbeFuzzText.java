package packbin;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;
import java.util.function.Supplier;

/**
 * AC-1 probe (a): seeded random and mutated text fields against TextDecoder.read and the public unpack (single, list,
 * dict). Seeds: every field and buffer of fixtures/text/vectors.txt and every body of fixtures/hostile/fuzz/corpus.txt.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ProbeFuzzText {
    private static final int[] INTERESTING = {0x00, 0x01, 0x10, 0x7f, 0x80, 0x81, 0xbf, 0xc0, 0xc2, 0xe0, 0xed, 0xef, 0xf0, 0xf4, 0xf5, 0xff};

    private ProbeFuzzText() {}

    static void run(int seed, int count) throws IOException {
        Random r = new Random(seed);
        List<byte[]> seeds = loadSeeds();
        System.out.println("seeds " + seeds.size() + ", iterations " + count);
        AuditProbe.Stats direct = new AuditProbe.Stats("TextDecoder.read");
        AuditProbe.Stats single = new AuditProbe.Stats("unpack single utf8");
        AuditProbe.Stats collections = new AuditProbe.Stats("unpack list/dict");
        long[] roundTrips = {0};
        double[] maxRatio = {0};
        Scheme.Handler<?> singleHandler = AuditProbe.SINGLE.on(row -> {});
        Scheme.Handler<?>[] many = {AuditProbe.MAP.on(row -> {}), AuditProbe.LIST.on(row -> {}), AuditProbe.MAP_TEXT.on(row -> {})};
        for (int i = 0; i < count; i++) {
            byte[] field = make(r, seeds);
            if (r.nextInt(4) == 0) {
                field = AuditProbe.concat(field, new byte[] {0x5a});
            }
            readDirect(field, direct, roundTrips, maxRatio);
            byte[] one = AuditProbe.concat(new byte[] {1}, field);
            runUnpack(one, single, () -> BinaryPacker.unpack(one, singleHandler));
            if (i % 4 == 0) {
                byte[] packet = collection(r, seeds);
                runUnpack(packet, collections, () -> BinaryPacker.unpack(packet, many));
            }
        }
        direct.retime(b -> TextDecoder.read("x", b, new Cursor(0, 65535, 1 << 20)));
        single.retime(b -> BinaryPacker.unpack(b, singleHandler));
        collections.retime(b -> BinaryPacker.unpack(b, many));
        direct.print();
        single.print();
        collections.print();
        System.out.printf("accepted texts round-tripped through the encoder: %d; most decoded UTF-8 bytes per payload byte: %.3f%n",
                roundTrips[0], maxRatio[0]);
    }

    static void runUnpack(byte[] packet, AuditProbe.Stats stats, Supplier<Object> call) {
        byte[] copy = packet.clone();
        long t0 = System.nanoTime();
        try {
            stats.outcome(call.get());
        } catch (RuntimeException | Error ex) {
            stats.threw(ex, packet);
        }
        stats.time(t0, packet);
        if (!Arrays.equals(copy, packet)) {
            AuditProbe.fail(packet.length + "-byte packet was written by unpack");
        }
    }

    private static void readDirect(byte[] field, AuditProbe.Stats stats, long[] roundTrips, double[] maxRatio) {
        Cursor cur = new Cursor(0, 65535, 1 << 20);
        Object got;
        long t0 = System.nanoTime();
        try {
            got = TextDecoder.read("x", field, cur);
        } catch (RuntimeException | Error ex) {
            stats.threw(ex, field);
            stats.time(t0, field);
            return;
        }
        stats.time(t0, field);
        stats.outcome(got);
        if (!(got instanceof String text)) {
            if (cur.pos != 0) {
                AuditProbe.fail("refused read moved the cursor to " + cur.pos + ": " + AuditProbe.hex(field));
            }
            return;
        }
        int[] hc = header(field);
        if (cur.pos != hc[0] + hc[1]) {
            AuditProbe.fail("accepted read ended at " + cur.pos + ", header " + hc[0] + " + payload " + hc[1] + ": " + AuditProbe.hex(field));
        }
        if (!AuditProbe.wellFormed(text)) {
            AuditProbe.fail("accepted text has a lone surrogate: " + AuditProbe.hex(field));
        }
        int utf8 = AuditProbe.utf8Count(text);
        if (utf8 > 65_535 || utf8 > 6 * hc[1] + 8) {
            AuditProbe.fail("accepted text of " + utf8 + " UTF-8 bytes from a " + hc[1] + "-byte payload: " + AuditProbe.hex(field));
        }
        if (hc[1] > 0) {
            maxRatio[0] = Math.max(maxRatio[0], (double) utf8 / hc[1]);
        }
        if (utf8 <= 4096) {
            byte[] again = TextEncoder.encode(text.getBytes(StandardCharsets.UTF_8));
            Cursor c2 = new Cursor(0, 65535, 1 << 20);
            Object back = TextDecoder.read("x", again, c2);
            if (!text.equals(back) || c2.pos != again.length) {
                AuditProbe.fail("encode/decode round trip differs for " + AuditProbe.hex(field));
            }
            roundTrips[0]++;
        }
    }

    /** {header length, count} of a field the decoder accepted. */
    private static int[] header(byte[] field) {
        int count = 0;
        for (int k = 0; k < 3; k++) {
            count |= (field[k] & 0x7f) << (7 * k);
            if ((field[k] & 0x80) == 0) {
                return new int[] {k + 1, count};
            }
        }
        return new int[] {3, count};
    }

    static List<byte[]> loadSeeds() throws IOException {
        List<byte[]> seeds = new ArrayList<>();
        for (String[] row : AuditProbe.rows("fixtures/text/vectors.txt")) {
            switch (row[0]) {
                case "enc", "alt" -> {
                    if (row.length > 3) {
                        seeds.add(AuditProbe.bytes(row[3]));
                    }
                }
                case "bad" -> seeds.add(row.length > 3 ? AuditProbe.bytes(row[3]) : new byte[0]);
                case "ref" -> {
                    if (row.length > 2) {
                        byte[] p = AuditProbe.bytes(row[2]);
                        seeds.add(Arrays.copyOfRange(p, 1, p.length));
                    }
                }
                default -> { }
            }
        }
        for (String[] row : AuditProbe.rows("fixtures/hostile/fuzz/corpus.txt")) {
            byte[] p = AuditProbe.bytes(row[2]);
            if (p.length > 1) {
                seeds.add(Arrays.copyOfRange(p, 1, p.length));
            }
        }
        return seeds;
    }

    static byte[] make(Random r, List<byte[]> seeds) {
        int pick = r.nextInt(10);
        if (pick < 5) {
            return mutate(seeds.get(r.nextInt(seeds.size())), r);
        }
        if (pick < 7) {
            return fresh(r);
        }
        if (pick < 8) {
            return mutate(AuditProbe.concat(seeds.get(r.nextInt(seeds.size())), seeds.get(r.nextInt(seeds.size()))), r);
        }
        byte[] body = mutate(seeds.get(r.nextInt(seeds.size())), r);
        byte[] payload = body.length > 1 ? Arrays.copyOfRange(body, 1, body.length) : body;
        int c = payload.length + (r.nextInt(4) == 0 ? r.nextInt(5) - 2 : 0);
        return AuditProbe.concat(AuditProbe.varint(Math.max(0, c)), payload);
    }

    private static byte[] fresh(Random r) {
        int k = r.nextInt(10);
        int length = k < 6 ? 1 + r.nextInt(23) : k < 9 ? 24 + r.nextInt(576) : 600 + r.nextInt(69_400);
        byte[] payload = new byte[length];
        r.nextBytes(payload);
        if (r.nextInt(3) == 0) {
            Arrays.fill(payload, 1, payload.length, (byte) 0);
        }
        payload[0] = r.nextInt(6) == 0 ? 0x10 : (byte) ((r.nextInt(8) << 5) | (r.nextInt(r.nextInt(5) == 0 ? 8 : 4) << 2));
        if (payload[0] == 0x10 && r.nextInt(2) == 0) {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < length; i++) {
                sb.append((char) (r.nextInt(3) == 0 ? 'а' + r.nextInt(32) : 'a' + r.nextInt(26)));
            }
            byte[] utf8 = sb.toString().getBytes(StandardCharsets.UTF_8);
            System.arraycopy(utf8, 0, payload, 1, Math.min(length - 1, utf8.length));
        }
        return AuditProbe.concat(AuditProbe.varint(length), payload);
    }

    static byte[] mutate(byte[] source, Random r) {
        List<Byte> b = new ArrayList<>(source.length + 16);
        for (byte x : source) {
            b.add(x);
        }
        int ops = 1 + r.nextInt(4);
        for (int k = 0; k < ops; k++) {
            int op = r.nextInt(9);
            int size = b.size();
            if (op == 0 && size > 0) {
                int at = r.nextInt(size);
                b.set(at, (byte) (b.get(at) ^ (1 << r.nextInt(8))));
            } else if (op == 1 && size > 0) {
                b.set(r.nextInt(size), (byte) r.nextInt(256));
            } else if (op == 2) {
                b.add(r.nextInt(size + 1), (byte) r.nextInt(256));
            } else if (op == 3 && size > 0) {
                b.remove(r.nextInt(size));
            } else if (op == 4 && size > 0) {
                int cut = r.nextInt(size + 1);
                b.subList(cut, size).clear();
            } else if (op == 5) {
                for (int j = 1 + r.nextInt(16); j > 0; j--) {
                    b.add((byte) r.nextInt(256));
                }
            } else if (op == 6 && size > 1) {
                int from = r.nextInt(size);
                int len = 1 + r.nextInt(Math.min(32, size - from));
                b.addAll(r.nextInt(size + 1), new ArrayList<>(b.subList(from, from + len)));
            } else if (op == 7 && size > 0) {
                b.set(r.nextInt(size), (byte) INTERESTING[r.nextInt(INTERESTING.length)]);
            } else if (op == 8 && size > 1) {
                b.set(1, (byte) ((r.nextInt(8) << 5) | (r.nextInt(8) << 2) | r.nextInt(4)));
            }
        }
        byte[] out = new byte[b.size()];
        for (int i = 0; i < out.length; i++) {
            out[i] = b.get(i);
        }
        return out;
    }

    /** A list (type 3), dict-of-u8 (type 2) or dict-of-text (type 4) packet of 1 to 4 random fields. */
    private static byte[] collection(Random r, List<byte[]> seeds) {
        int kind = r.nextInt(3);
        int n = 1 + r.nextInt(4);
        byte type = (byte) (kind == 0 ? 3 : kind == 1 ? 2 : 4);
        List<byte[]> parts = new ArrayList<>();
        parts.add(new byte[] {type, (byte) n, 0});
        byte[] previous = null;
        for (int i = 0; i < n; i++) {
            byte[] field = previous != null && r.nextInt(4) == 0 ? previous : make(r, seeds);
            previous = field;
            parts.add(field);
            if (kind == 1) {
                parts.add(new byte[] {(byte) r.nextInt(256)});
            } else if (kind == 2) {
                parts.add(make(r, seeds));
            }
        }
        return AuditProbe.concat(parts.toArray(new byte[0][]));
    }
}

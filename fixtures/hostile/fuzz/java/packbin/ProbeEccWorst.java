package packbin;

import java.util.Map;
import java.util.Random;
import java.util.TreeMap;
import java.util.function.Function;
import java.util.function.Supplier;

/**
 * AC-2 probe (b): the per-call time of the costliest repairs, N = 254 sent bytes and n = 32 parity bytes. Each case
 * has {@code count} distinct inputs; every input runs 5 times as warm-up (JIT), then 5 timed times: median, p99, max.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ProbeEccWorst {
    private static final int N = 254;
    private static final int PARITY = 32;

    private ProbeEccWorst() {}

    static void run(int seed, int count) {
        Random r = new Random(seed);
        Scheme<Map> blob = AuditProbe.scheme(9, Packbin.bytes(0, Access.get("b"), Access.set("b"), N - PARITY - 1))
                .withParity(PARITY);
        Scheme.Handler<?> handler = blob.on(x -> {});
        Object[][] cases = {
            {"t=16, 16 wrong bytes (repaired: every step runs)", 16, (Supplier<byte[]>) () -> wrong(r, 16)},
            {"t=16, 15 wrong bytes + wrong unsent length byte (degree 16, 15 roots: near miss)", 16, (Supplier<byte[]>) () -> nearMiss(r)},
            {"t=16, random 254 bytes (degree ~16, full root search)", 16, (Supplier<byte[]>) () -> random254(r)},
            {"t=16, 17 wrong bytes (degree above t)", 16, (Supplier<byte[]>) () -> wrong(r, 17)},
            {"t=16, intact", 16, (Supplier<byte[]>) () -> wrong(r, 0)},
            {"t=0 (default), 1 wrong byte (detect only)", 0, (Supplier<byte[]>) () -> wrong(r, 1)},
            {"t=0 (default), random 254 bytes", 0, (Supplier<byte[]>) () -> random254(r)},
        };
        System.out.println("N=" + N + " n=" + PARITY + ", " + count + " inputs per case, 5 warm-up + 5 timed runs each; load " + AuditProbe.load());
        for (Object[] cs : cases) {
            String name = (String) cs[0];
            int t = (int) cs[1];
            Supplier<byte[]> make = (Supplier<byte[]>) cs[2];
            byte[][] inputs = new byte[count][];
            Map<String, Integer> outcomes = new TreeMap<>();
            for (int i = 0; i < count; i++) {
                inputs[i] = make.get();
                Object o = EccRepair.repair(inputs[i], PARITY, t);
                outcomes.merge(o instanceof EccRepair.Fixed ? "ok" : o.getClass().getSimpleName(), 1, Integer::sum);
            }
            report("EccRepair.repair    " + name, inputs, b -> EccRepair.repair(b, PARITY, t), outcomes);
            report("unpackRepair(blob)  " + name, inputs, b -> BinaryPacker.unpackRepair(b, t, handler), null);
        }
        System.out.println("load after " + AuditProbe.load());
    }

    private static void report(String name, byte[][] inputs, Function<byte[], Object> call, Map<String, Integer> outcomes) {
        for (int w = 0; w < 5; w++) {
            for (byte[] in : inputs) {
                call.apply(in);
            }
        }
        double[] s = new double[inputs.length * 5];
        int at = 0;
        long before = AuditProbe.allocated();
        for (int rep = 0; rep < 5; rep++) {
            for (byte[] in : inputs) {
                long t0 = System.nanoTime();
                call.apply(in);
                s[at++] = (System.nanoTime() - t0) / 1e3;
            }
        }
        long alloc = (AuditProbe.allocated() - before) / (inputs.length * 5L);
        java.util.Arrays.sort(s);
        System.out.printf("%s: median %.1f us, p99 %.1f us, max %.1f us over %d calls; %d B allocated per call%s%n", name,
                s[s.length / 2], s[(int) (s.length * 0.99)], s[s.length - 1], s.length, alloc,
                outcomes == null ? "" : "; outcomes: " + outcomes);
    }

    private static byte[] clear(Random r) {
        byte[] clear = new byte[N - PARITY];
        r.nextBytes(clear);
        clear[0] = 9;
        return clear;
    }

    private static byte[] wrong(Random r, int k) {
        byte[] word = ProbeGf.protect(clear(r), PARITY);
        ProbeGf.corrupt(word, k, r);
        return word;
    }

    private static byte[] nearMiss(Random r) {
        byte[] clear = clear(r);
        byte[] word = ProbeGf.encode(clear.length ^ (1 + r.nextInt(255)), clear, PARITY);
        ProbeGf.corrupt(word, 15, r);
        return word;
    }

    private static byte[] random254(Random r) {
        byte[] b = new byte[N];
        r.nextBytes(b);
        return b;
    }
}

/*
 * AZ-2666 hostile-input probes for the Java package: compact text decoder and message ECC unpack (loop 41 audit).
 * The probes sit in package packbin, so they can call the package-private decoder (TextDecoder.read, EccRepair.repair)
 * as well as the public unpack. Compile outside the repository, with the package sources:
 *   javac --release 17 -encoding UTF-8 -d /tmp/probe-java <repo>/java/src/main/java/packbin/*.java <this dir>/packbin/*.java
 * Run (from any directory; the repository path is the first argument, fixtures are read from it):
 *   java -Xmx1g -cp /tmp/probe-java packbin.AuditProbe <repo> <probe> [seed] [count]
 *   probes: fuzz-text, fuzz-ecc, ecc-worst, text-amp <case>, edges (as the C# probe of the same audit)
 *   text-amp cases: max, over, silent, packet1m, packet16m, dict, collide, baseline
 * Peak RSS of a run: /usr/bin/time -l java ...  Exit 0 when nothing unexpected happened, 1 when a check failed.
 */
package packbin;

import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

@SuppressWarnings({"unchecked", "rawtypes"})
public final class AuditProbe {
    static String repo = "";
    static int failures;

    static final Scheme<Map> SINGLE = scheme(1, Packbin.utf8(0, Access.get("s"), Access.set("s")));
    static final Scheme<Map> MAP = scheme(2, Packbin.dict(Access.get("m"), Access.set("m"),
            Packbin.u8(0, Access.identity(), Access.ignore())));
    static final Scheme<Map> LIST = scheme(3, Packbin.list(Access.get("l"), Access.set("l"),
            Packbin.utf8(0, Access.identity(), Access.ignore())));
    static final Scheme<Map> MAP_TEXT = scheme(4, Packbin.dict(Access.get("m"), Access.set("m"),
            Packbin.utf8(0, Access.identity(), Access.ignore())));

    private AuditProbe() {}

    static Scheme<Map> scheme(int type, Field... fields) {
        return new Scheme<>(type, (Class) Map.class, fields);
    }

    public static void main(String[] args) throws IOException {
        if (args.length < 2) {
            System.err.println("usage: AuditProbe <repo> <probe> [seed] [count]");
            System.exit(2);
        }
        repo = args[0];
        int seed = args.length > 2 && args[2].matches("-?\\d+") ? Integer.parseInt(args[2]) : 41;
        int count = args.length > 3 ? Integer.parseInt(args[3]) : 0;
        System.out.println("probe=" + args[1] + " seed=" + seed + " java=" + System.getProperty("java.version")
                + " maxHeap=" + Runtime.getRuntime().maxMemory() / 1048576 + "MiB load=" + load());
        long start = System.nanoTime();
        switch (args[1]) {
            case "fuzz-text" -> ProbeFuzzText.run(seed, count == 0 ? 300_000 : count);
            case "fuzz-ecc" -> ProbeFuzzEcc.run(seed, count == 0 ? 300_000 : count);
            case "ecc-worst" -> ProbeEccWorst.run(seed, count == 0 ? 2_000 : count);
            case "text-amp" -> ProbeTextAmp.run(args.length > 2 ? args[2] : "max");
            case "edges" -> {
                ProbeEdgesText.run();
                ProbeEdgesEcc.run();
            }
            default -> {
                System.err.println("unknown probe " + args[1]);
                System.exit(2);
            }
        }
        System.out.printf("done in %.2f s, failures=%d, load=%s%n", (System.nanoTime() - start) / 1e9, failures, load());
        System.exit(failures == 0 ? 0 : 1);
    }

    static String load() {
        return String.format("%.2f", ManagementFactory.getOperatingSystemMXBean().getSystemLoadAverage());
    }

    static void fail(String what) {
        failures++;
        if (failures <= 40) {
            System.out.println("FAIL " + what);
        }
    }

    static void check(boolean ok, String what) {
        if (ok) {
            System.out.println("PASS " + what);
        } else {
            fail(what);
        }
    }

    static long allocated() {
        return ((com.sun.management.ThreadMXBean) ManagementFactory.getThreadMXBean()).getCurrentThreadAllocatedBytes();
    }

    static String hex(byte[] b) {
        return hex(b, 48);
    }

    static String hex(byte[] b, int max) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < Math.min(b.length, max); i++) {
            sb.append(String.format("%02x", b[i] & 0xff));
        }
        if (b.length > max) {
            sb.append("..(+").append(b.length - max).append(")");
        }
        return sb.toString();
    }

    static byte[] bytes(String hex) {
        if (hex.equals("-") || hex.isEmpty()) {
            return new byte[0];
        }
        byte[] out = new byte[hex.length() / 2];
        for (int i = 0; i < out.length; i++) {
            out[i] = (byte) Integer.parseInt(hex.substring(2 * i, 2 * i + 2), 16);
        }
        return out;
    }

    static List<String[]> rows(String relative) throws IOException {
        List<String[]> out = new ArrayList<>();
        for (String line : Files.readAllLines(Path.of(repo, relative), StandardCharsets.UTF_8)) {
            if (line.isEmpty() || line.charAt(0) == '#') {
                continue;
            }
            out.add(line.trim().split("\\s+"));
        }
        return out;
    }

    static byte[] varint(int count) {
        byte[] tmp = new byte[3];
        int n = 0;
        do {
            int b = count & 0x7f;
            count >>>= 7;
            tmp[n++] = (byte) (count != 0 ? b | 0x80 : b);
        } while (count != 0);
        return java.util.Arrays.copyOf(tmp, n);
    }

    static byte[] concat(byte[]... parts) {
        int total = 0;
        for (byte[] p : parts) {
            total += p.length;
        }
        byte[] all = new byte[total];
        int at = 0;
        for (byte[] p : parts) {
            System.arraycopy(p, 0, all, at, p.length);
            at += p.length;
        }
        return all;
    }

    static boolean wellFormed(String s) {
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (Character.isHighSurrogate(c)) {
                if (i + 1 >= s.length() || !Character.isLowSurrogate(s.charAt(i + 1))) {
                    return false;
                }
                i++;
            } else if (Character.isLowSurrogate(c)) {
                return false;
            }
        }
        return true;
    }

    /** The UTF-8 length of a well-formed string, without allocating (a lone surrogate counts 3, as the encoder's '?'). */
    static int utf8Count(String s) {
        int n = 0;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c < 0x80) {
                n += 1;
            } else if (c < 0x800) {
                n += 2;
            } else if (Character.isHighSurrogate(c) && i + 1 < s.length() && Character.isLowSurrogate(s.charAt(i + 1))) {
                n += 4;
                i++;
            } else {
                n += 3;
            }
        }
        return n;
    }

    static boolean documented(Object result) {
        return result == null || result instanceof Packbin.Repaired || result instanceof Packbin.ShortPacket
                || result instanceof Packbin.TrailingBytes || result instanceof Packbin.TypeMismatch
                || result instanceof Packbin.Uncorrectable || result instanceof Packbin.TooLong;
    }

    /** Per-run counters: calls, accepted, refused, thrown, and the slowest call with its input. */
    static final class Stats {
        final String name;
        long calls;
        long accepted;
        long refused;
        long thrown;
        double slowestMs;
        String slowestInput = "";
        byte[] slowestBytes = new byte[0];
        int contextN;
        int contextT;
        int slowN;
        int slowT;
        double retimedMs = -1;
        final Map<String, Long> kinds = new TreeMap<>();

        Stats(String name) {
            this.name = name;
        }

        void time(long startNanos, byte[] input) {
            double ms = (System.nanoTime() - startNanos) / 1e6;
            calls++;
            if (ms > slowestMs) {
                slowestMs = ms;
                slowestInput = input.length + " B " + hex(input, 24)
                        + (contextN > 0 ? " (n=" + contextN + ", t=" + contextT + ")" : "");
                slowestBytes = input;
                slowN = contextN;
                slowT = contextT;
            }
        }

        void outcome(Object result) {
            if (result == null || result instanceof Packbin.Repaired || result instanceof String
                    || result instanceof EccRepair.Fixed) {
                accepted++;
                return;
            }
            refused++;
            kinds.merge(result.getClass().getSimpleName(), 1L, Long::sum);
            if (!documented(result)) {
                fail(name + ": undocumented result type " + result.getClass().getName());
            }
        }

        void threw(Throwable ex, byte[] input) {
            thrown++;
            fail(name + ": " + ex.getClass().getName() + " escaped: " + ex.getMessage() + " input " + hex(input));
        }

        void retime(java.util.function.Function<byte[], Object> call) {
            double[] times = new double[5];
            for (int i = 0; i < 5; i++) {
                long t0 = System.nanoTime();
                try {
                    call.apply(slowestBytes);
                } catch (RuntimeException | Error ex) {
                    threw(ex, slowestBytes);
                }
                times[i] = (System.nanoTime() - t0) / 1e6;
            }
            java.util.Arrays.sort(times);
            retimedMs = times[2];
        }

        void print() {
            StringBuilder k = new StringBuilder();
            kinds.forEach((key, v) -> k.append(k.length() > 0 ? ", " : "").append(key).append(' ').append(v));
            System.out.printf("%s: calls %d, accepted %d, refused %d (%s), thrown %d, slowest %.3f ms on %s%s%n", name, calls,
                    accepted, refused, k, thrown, slowestMs, slowestInput,
                    retimedMs >= 0 ? String.format(" (re-run warm: median %.3f ms)", retimedMs) : "");
        }
    }
}

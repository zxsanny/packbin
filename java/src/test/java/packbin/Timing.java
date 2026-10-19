package packbin;

/**
 * Load-aware wall-clock bounds (AZ-2723). A bound is the nominal figure times the load factor: the smallest of three runs
 * of a fixed integer loop, measured right before the timed code, over the time that loop takes on an idle host, never below
 * 1 and capped at {@link #MAX_FACTOR}. A host as fast as the idle one keeps the nominal bound; a host busy with other work
 * gets more time, but a real slowdown beyond the cap still fails.
 */
final class Timing {
    /** The loop on the arm64 Mac after the warm-up: the smallest of 24 fresh JVMs was 0.0307 s (AZ-2723 calibration). */
    static final double REFERENCE_SECONDS = 0.0307;
    static final double MAX_FACTOR = 8.0;

    private static final int ITERATIONS = 12_000_000;
    private static final int WARM_UPS = 8;
    private static final int RUNS = 3;
    private static final long RECENT_NANOS = 2_000_000_000L;

    private static boolean warm;
    private static long recentAt;
    private static double recentFactor = 1.0;
    private static volatile long sink;

    private Timing() {
    }

    /** The bound for a timed section that starts now: measures the load factor first. */
    static Limit bound(double nominalSeconds) {
        return new Limit(nominalSeconds, factor());
    }

    /** The bound for a probe that starts many times: the factor of the last two seconds, measured again after that. */
    static synchronized Limit recentBound(double nominalSeconds) {
        long now = System.nanoTime();
        if (recentAt == 0 || now - recentAt >= RECENT_NANOS) {
            recentFactor = factor();
            recentAt = System.nanoTime();
        }
        return new Limit(nominalSeconds, recentFactor);
    }

    static double factor() {
        return Math.min(MAX_FACTOR, Math.max(1.0, referenceLoopSeconds() / REFERENCE_SECONDS));
    }

    static synchronized double referenceLoopSeconds() {
        if (!warm) {
            for (int i = 0; i < WARM_UPS; i++) {
                spin();
            }
            warm = true;
        }
        double best = Double.MAX_VALUE;
        for (int run = 0; run < RUNS; run++) {
            long start = System.nanoTime();
            spin();
            best = Math.min(best, (System.nanoTime() - start) / 1e9);
        }
        return best;
    }

    private static void spin() {
        long x = 0x9E3779B97F4A7C15L;
        for (int i = 0; i < ITERATIONS; i++) {
            x ^= x << 13;
            x ^= x >>> 7;
            x ^= x << 17;
            x += i;
        }
        sink = x;
    }

    /** One nominal bound with the load factor measured when it was made. */
    static final class Limit {
        final double nominalSeconds;
        final double factor;

        Limit(double nominalSeconds, double factor) {
            this.nominalSeconds = nominalSeconds;
            this.factor = factor;
        }

        double seconds() {
            return nominalSeconds * factor;
        }

        long millis() {
            return (long) Math.ceil(seconds() * 1000.0);
        }

        boolean within(double elapsedSeconds) {
            return elapsedSeconds <= seconds();
        }

        /** Checks {@code elapsedSeconds} against the bound; the message prints the nominal bound, the factor and the elapsed time. */
        void expectWithin(String what, double elapsedSeconds) {
            PackbinTest.expectTrue(describe(what, elapsedSeconds), within(elapsedSeconds));
        }

        void expectWithinNanos(String what, long elapsedNanos) {
            expectWithin(what, elapsedNanos / 1e9);
        }

        String describe(String what, double elapsedSeconds) {
            return String.format(java.util.Locale.ROOT, "%s: %.3f s elapsed, nominal bound %.3f s x load factor %.2f = %.3f s", what, elapsedSeconds,
                    nominalSeconds, factor, seconds());
        }
    }
}

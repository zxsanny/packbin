package packbin;

import java.util.Map;

/** One unpack on a daemon thread: a hang shows as {@code finished == false} instead of stalling CI. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileRun {
    static final long LIMIT_MS = 1000;

    final boolean finished;
    final Object result;
    final Throwable thrown;
    final boolean handled;

    private HostileRun(boolean finished, Object result, Throwable thrown, boolean handled) {
        this.finished = finished;
        this.result = result;
        this.thrown = thrown;
        this.handled = handled;
    }

    static HostileRun of(Scheme<Map> scheme, String hex) {
        return of(scheme, PackbinTest.parseHex(hex), LIMIT_MS);
    }

    static HostileRun of(Scheme<Map> scheme, byte[] bytes, long limitMs) {
        Object[] out = new Object[1];
        Throwable[] thrown = new Throwable[1];
        boolean[] handled = new boolean[1];
        Thread worker = new Thread(() -> {
            try {
                out[0] = BinaryPacker.unpack(bytes, scheme.on(row -> handled[0] = true));
            } catch (RuntimeException | Error ex) {
                thrown[0] = ex;
            }
        });
        worker.setDaemon(true);
        worker.start();
        try {
            worker.join(limitMs);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("interrupted while waiting for unpack", ex);
        }
        boolean finished = !worker.isAlive();
        return new HostileRun(finished, out[0], thrown[0], handled[0]);
    }

    /** True when unpack returned a non-ok value with no exception, no handler call, inside the limit. */
    boolean isErrorValue() {
        return finished && thrown == null && result != null && !handled;
    }

    String kind() {
        if (!finished) {
            return "hang";
        }
        if (thrown != null) {
            return "threw " + thrown;
        }
        return result == null ? "ok" : result.getClass().getSimpleName();
    }
}

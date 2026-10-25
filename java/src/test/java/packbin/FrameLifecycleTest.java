package packbin;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

/** AZ-3233 AC-10 (wipe and use after release) and AC-11 (concurrent seal). */
public final class FrameLifecycleTest {
    private static final int THREADS = 8;
    private static final int PER_THREAD = 1000;

    private FrameLifecycleTest() {}

    public static void main(String[] args) throws InterruptedException {
        run();
        FrameSupport.finish("FrameLifecycleTest");
    }

    static void run() throws InterruptedException {
        closeWipesKeysAndRefusesUse();
        macKeyCloseWipesAndRefusesUse();
        concurrentSealEqualsSingleThreadSeal();
    }

    private static boolean allZero(List<byte[]> arrays) {
        return arrays.stream().allMatch(FrameCrypto::isZero);
    }

    private static void closeWipesKeysAndRefusesUse() {
        // Arrange
        byte[] key = new byte[32];
        Arrays.fill(key, (byte) 0x44);
        byte[] prevKey = new byte[32];
        Arrays.fill(prevKey, (byte) 0x45);
        MsgContext ctx = new MsgContext(new byte[8], 2);
        FrameSession s = FrameSession.load(key, 5, 8, 1, 2, 3);
        s.setPrevious(prevKey, 4);
        byte[] body = new byte[40];
        Object sealed = s.seal(1, ctx, null, null, new byte[5], body);
        List<byte[]> live = new ArrayList<>();
        for (int d = 1; d <= 3; d++) {
            for (boolean previous : new boolean[] {false, true}) {
                live.add(s.encKeyForTest(d, previous));
                live.add(s.macKeyForTest(d, previous));
            }
        }
        boolean nonZeroBefore = live.stream().noneMatch(FrameCrypto::isZero);

        // Act
        s.close();
        s.close();

        // Assert
        PackbinTest.expectTrue("sealed before close", sealed instanceof FrameSession.Sealed);
        PackbinTest.expectEq("12 key arrays held", 12, live.size());
        PackbinTest.expectTrue("keys were not zero before close", nonZeroBefore);
        PackbinTest.expectTrue("derived keys and MAC keys read all zero after close", allZero(live));
        PackbinTest.expectTrue("seal after close is BadValue", s.seal(1, ctx, null, null, new byte[5], new byte[40]) instanceof Packbin.BadValue);
        PackbinTest.expectTrue("open after close is BadValue", s.open(1, ctx, null, body, 0, null, 0, new byte[5]) instanceof Packbin.BadValue);
        PackbinTest.expectTrue("setPrevious after close is false", !s.setPrevious(prevKey, 4));
        PackbinTest.expectTrue("the previous slot is gone", s.encKeyForTest(1, true) == null);
        PackbinTest.expectTrue("the caller's key array is not retained", !FrameCrypto.isZero(key));
    }

    private static void macKeyCloseWipesAndRefusesUse() {
        // Arrange
        MacKey mac = MacKey.derive(new byte[32], 1, new byte[] {'n'});
        byte[] live = mac.keyForTest();
        byte[] tag = new byte[4];
        mac.tag(tag, new byte[2]);
        boolean nonZeroBefore = !FrameCrypto.isZero(live);

        // Act
        mac.close();

        // Assert
        PackbinTest.expectTrue("MAC key was not zero before close", nonZeroBefore);
        PackbinTest.expectTrue("MAC key reads all zero after close", FrameCrypto.isZero(live));
        PackbinTest.expectTrue("tag after close is BadValue", mac.tag(new byte[4], new byte[2]) instanceof Packbin.BadValue);
        PackbinTest.expectTrue("verify after close is false", !mac.verify(tag, new byte[2]));
    }

    private static byte[] idFor(int thread, int i) {
        byte[] id = new byte[8];
        id[0] = (byte) thread;
        id[1] = (byte) (i >>> 8);
        id[2] = (byte) i;
        return id;
    }

    private static byte[] plainFor(int thread, int i) {
        byte[] plain = new byte[(i % 40) + 1];
        Arrays.fill(plain, (byte) (thread * 31 + i));
        return plain;
    }

    private static byte[] sealOne(FrameSession s, int thread, int i) {
        byte[] out = new byte[255];
        Object result = s.seal(1, new MsgContext(idFor(thread, i), i & 15), new byte[] {(byte) thread}, null, plainFor(thread, i), out);
        return result instanceof FrameSession.Sealed sealed ? Arrays.copyOf(out, sealed.length) : null;
    }

    private static void concurrentSealEqualsSingleThreadSeal() throws InterruptedException {
        // Arrange
        byte[] key = new byte[32];
        Arrays.fill(key, (byte) 0x77);
        Timing.Limit limit = Timing.bound(20.0);
        byte[][][] bodies = new byte[THREADS][PER_THREAD][];
        AtomicReference<Throwable> failure = new AtomicReference<>();
        try (FrameSession s = FrameSession.load(key, 9, 4, 1, 2, 3)) {
            Thread[] threads = new Thread[THREADS];
            long start = System.nanoTime();

            // Act
            for (int t = 0; t < THREADS; t++) {
                final int thread = t;
                threads[t] = new Thread(() -> {
                    try {
                        for (int i = 0; i < PER_THREAD; i++) {
                            bodies[thread][i] = sealOne(s, thread, i);
                        }
                    } catch (Throwable ex) {
                        failure.compareAndSet(null, ex);
                    }
                });
                threads[t].start();
            }
            for (Thread thread : threads) {
                thread.join();
            }
            long elapsed = System.nanoTime() - start;

            // Assert
            PackbinTest.expectTrue("no thread failed: " + failure.get(), failure.get() == null);
            int differing = 0;
            int notOpened = 0;
            for (int t = 0; t < THREADS; t++) {
                for (int i = 0; i < PER_THREAD; i++) {
                    byte[] single = sealOne(s, t, i);
                    differing += Arrays.equals(single, bodies[t][i]) ? 0 : 1;
                    Object opened = s.open(1, new MsgContext(idFor(t, i), i & 15), new byte[] {(byte) t}, bodies[t][i], 0, null, 0,
                            new byte[255]);
                    notOpened += opened instanceof FrameSession.Opened ? 0 : 1;
                }
            }
            PackbinTest.expectEq("bodies differing from the single-thread seal", 0, differing);
            PackbinTest.expectEq("bodies that did not open Ok", 0, notOpened);
            limit.expectWithinNanos("8 threads x 1000 seals", elapsed);
        }
    }
}

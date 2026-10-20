package packbin;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * AZ-2735 AC-1 and AC-2 (CS-S3, TW-1): eight threads pack and unpack different texts at the same time with one built
 * scheme. Every packed field of a vector row is its reference bytes, every other packed field is the bytes a lone
 * sequential pack gives, and every unpacked text is the worker's own input. The workers only count; the main thread
 * asserts, because the test helpers are not thread safe.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class TextConcurrencyTest {
    private static final int WORKERS = 8;
    private static final int RANDOM_TEXTS = 200;
    private static final int PASSES = 4;
    private static final long HANG_LIMIT_MILLIS = 120_000;
    private static final String POOL = "абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ"
            + "ёъыэЁЪЫЭabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ,.-:!?;()\"%/@+=*#&_$\n"
            + "éßłżą中文\t\u0000\u0001";
    private static final int[] EMOJI = {0x1F600, 0x1F468, 0x10FFFF, 0xFFFF, 0x7FF, 0x800};

    private TextConcurrencyTest() {}

    static void run() throws InterruptedException {
        eightWorkersWithOneSchemeGetReferenceBytesAndTheirOwnTexts();
    }

    /** One worker's texts, the bytes each must pack to, and what the worker counted. */
    private static final class Worker implements Runnable {
        final Scheme<Map> scheme;
        final String[] texts;
        final byte[][] expected;
        final CountDownLatch ready;
        final CountDownLatch start;
        int roundTrips;
        int mismatches;
        int errors;
        String firstProblem = "";

        Worker(Scheme<Map> scheme, String[] texts, byte[][] expected, CountDownLatch ready, CountDownLatch start) {
            this.scheme = scheme;
            this.texts = texts;
            this.expected = expected;
            this.ready = ready;
            this.start = start;
        }

        @Override
        public void run() {
            ready.countDown();
            try {
                start.await();
                for (int pass = 0; pass < PASSES; pass++) {
                    for (int k = 0; k < texts.length; k++) {
                        int i = pass % 2 == 0 ? k : texts.length - 1 - k;
                        roundTrip(i);
                    }
                }
            } catch (InterruptedException ex) {
                Thread.currentThread().interrupt();
                problem(true, "interrupted before it finished");
            } catch (RuntimeException | Error ex) {
                problem(true, "threw " + ex);
            }
        }

        private void roundTrip(int i) {
            byte[] packed = BinaryPacker.pack(scheme, Maps.map("s", texts[i]));
            if (!Arrays.equals(packed, expected[i])) {
                problem(false, "text " + i + " packed to " + PackbinTest.toHex(packed) + ", expected " + PackbinTest.toHex(expected[i]));
            }
            TextVectorsTest.Outcome got = TextVectorsTest.unpack(scheme, packed);
            if (got.error != null || got.thrown != null || got.row == null) {
                problem(true, "text " + i + " did not unpack (" + got.error + ", " + got.thrown + ")");
            } else if (!texts[i].equals(got.row.get("s"))) {
                problem(false, "text " + i + " unpacked to another text");
            }
            roundTrips++;
        }

        private void problem(boolean error, String what) {
            if (error) {
                errors++;
            } else {
                mismatches++;
            }
            if (firstProblem.isEmpty()) {
                firstProblem = what;
            }
        }
    }

    private static Scheme<Map> scheme() {
        return Maps.scheme(1, Packbin.utf8(0, Access.get("s"), Access.set("s")));
    }

    private static String randomText(Random random) {
        int[] points = POOL.codePoints().toArray();
        int length = random.nextInt(201);
        StringBuilder out = new StringBuilder();
        for (int i = 0; i < length; i++) {
            out.appendCodePoint(random.nextInt(25) == 0 ? EMOJI[random.nextInt(EMOJI.length)] : points[random.nextInt(points.length)]);
        }
        return out.toString();
    }

    /** The worker's texts: every enc row of the vectors, rotated by worker, then its own random texts. */
    private static Worker workerFor(int index, Scheme<Map> shared, List<TextVectors.Row> vectors, CountDownLatch ready, CountDownLatch start) {
        int rows = vectors.size();
        String[] texts = new String[rows + RANDOM_TEXTS];
        byte[][] expected = new byte[texts.length][];
        for (int k = 0; k < rows; k++) {
            TextVectors.Row row = vectors.get((k + index * 37) % rows);
            texts[k] = row.text();
            expected[k] = PackbinTest.parseHex("01" + row.cols[2]);
        }
        Random random = new Random(2735L + index);
        for (int k = rows; k < texts.length; k++) {
            texts[k] = randomText(random);
            expected[k] = BinaryPacker.pack(scheme(), Maps.map("s", texts[k]));
        }
        return new Worker(shared, texts, expected, ready, start);
    }

    // AZ-2735 AC-1, AC-2.
    private static void eightWorkersWithOneSchemeGetReferenceBytesAndTheirOwnTexts() throws InterruptedException {
        // Arrange
        Scheme<Map> shared = scheme();
        List<TextVectors.Row> vectors = TextVectors.ofKind("enc");
        CountDownLatch ready = new CountDownLatch(WORKERS);
        CountDownLatch start = new CountDownLatch(1);
        Worker[] workers = new Worker[WORKERS];
        Thread[] threads = new Thread[WORKERS];
        for (int w = 0; w < WORKERS; w++) {
            workers[w] = workerFor(w, shared, vectors, ready, start);
            threads[w] = new Thread(workers[w], "text-concurrency-" + w);
            threads[w].setDaemon(true);
            threads[w].start();
        }
        boolean allReady = ready.await(HANG_LIMIT_MILLIS, TimeUnit.MILLISECONDS);
        Timing.Limit limit = Timing.bound(1.0);

        // Act
        long began = System.nanoTime();
        start.countDown();
        long deadline = began + HANG_LIMIT_MILLIS * 1_000_000L;
        for (Thread thread : threads) {
            thread.join(Math.max(1L, (deadline - System.nanoTime()) / 1_000_000L));
        }
        long elapsedNanos = System.nanoTime() - began;

        // Assert
        PackbinTest.expectTrue("AZ-2735 AC-1 all " + WORKERS + " workers were waiting at the start", allReady);
        PackbinTest.expectTrue("AZ-2735 AC-1 at least 250 enc rows of vectors.txt are in play: " + vectors.size(), vectors.size() >= 250);
        int mismatches = 0;
        int errors = 0;
        int roundTrips = 0;
        for (int w = 0; w < WORKERS; w++) {
            PackbinTest.expectTrue("AZ-2735 AC-1 worker " + w + " finished within " + HANG_LIMIT_MILLIS + " ms", !threads[w].isAlive());
            Set<String> different = new HashSet<>(Arrays.asList(workers[w].texts));
            PackbinTest.expectTrue("AZ-2735 AC-1 worker " + w + " has at least 200 different texts: " + different.size(), different.size() >= 200);
            PackbinTest.expectEq("AZ-2735 AC-1 worker " + w + " ran every round trip", PASSES * workers[w].texts.length, workers[w].roundTrips);
            PackbinTest.expectEq("AZ-2735 AC-1 worker " + w + " first problem", "", workers[w].firstProblem);
            mismatches += workers[w].mismatches;
            errors += workers[w].errors;
            roundTrips += workers[w].roundTrips;
        }
        PackbinTest.expectEq("AZ-2735 AC-1 mismatches over " + roundTrips + " round trips", 0, mismatches);
        PackbinTest.expectEq("AZ-2735 AC-1 errors over " + roundTrips + " round trips", 0, errors);
        System.out.println("AZ-2735 " + WORKERS + " workers, " + roundTrips + " round trips: " + elapsedNanos / 1e9 + " s");
        limit.expectWithinNanos("AZ-2735 AC-2 " + WORKERS + " workers x " + PASSES + " passes", elapsedNanos);
    }
}

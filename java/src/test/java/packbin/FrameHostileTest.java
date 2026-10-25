package packbin;

import java.util.Arrays;
import java.util.Random;

/** AZ-3233 AC-8: 1,000 random hostile bodies, lengths and clear_len values (fixed seed) cause no exception. */
public final class FrameHostileTest {
    private static final int ROUNDS = 1000;

    private FrameHostileTest() {}

    public static void main(String[] args) {
        run();
        FrameSupport.finish("FrameHostileTest");
    }

    static void run() {
        hostileOpenAndSealRaiseNothing();
    }

    private static void hostileOpenAndSealRaiseNothing() {
        // Arrange
        Random random = new Random(0x5EEDL);
        byte[] key = new byte[32];
        random.nextBytes(key);
        int exceptions = 0;
        int opened = 0;
        int unknown = 0;
        int[] counts = new int[16];
        try (FrameSession s4 = FrameSession.load(key, 3, 4, 1, 2, 3);
                FrameSession s16 = FrameSession.load(key, 3, 16, 1, 3)) {
            s4.setPrevious(key, 2);
            ReplayWindow window = new ReplayWindow();
            for (int i = 0; i < ROUNDS; i++) {
                FrameSession s = random.nextBoolean() ? s4 : s16;
                byte[] msgId = new byte[random.nextInt(10)];
                random.nextBytes(msgId);
                MsgContext ctx = random.nextInt(8) == 0 ? null : new MsgContext(msgId, random.nextInt(20) - 2);
                byte[] ad = random.nextInt(6) == 0 ? null : randomBytes(random, 300);
                byte[] body = random.nextInt(8) == 0 ? null : randomBytes(random, 300);
                int dir = random.nextInt(7) - 1;
                int clearLen = random.nextInt(320) - 10;
                int bodyOff = random.nextInt(8) == 0 ? random.nextInt(400) - 20 : 0;
                int bodyLen = random.nextInt(8) == 0 ? random.nextInt(400) - 20 : (body == null ? 0 : body.length);
                byte[] out = random.nextInt(10) == 0 ? null : new byte[random.nextInt(300)];
                long counter = random.nextLong();
                try {
                    // Act
                    Object result = s.open(dir, ctx, ad, body, bodyOff, bodyLen, clearLen, random.nextBoolean() ? window : null,
                            counter, out, random.nextInt(4) == 0 ? random.nextInt(20) - 5 : 0);
                    Object sealed = s.seal(dir, ctx, ad, randomBytes(random, 300), randomBytes(random, 300), out,
                            random.nextInt(4) == 0 ? random.nextInt(20) - 5 : 0);

                    // Assert
                    for (Object r : new Object[] {result, sealed}) {
                        String kind = FrameSupport.kind(r);
                        unknown += kind.startsWith("other") ? 1 : 0;
                        counts[Math.min(kind.length(), 15)]++;
                    }
                    opened += result instanceof FrameSession.Opened ? 1 : 0;
                } catch (RuntimeException ex) {
                    exceptions++;
                    System.err.println("hostile round " + i + ": " + ex);
                }
            }
        }
        PackbinTest.expectEq("hostile run: unhandled exceptions", 0, exceptions);
        PackbinTest.expectEq("hostile run: results outside the contract's kinds", 0, unknown);
        PackbinTest.expectEq("hostile run: random bodies that opened", 0, opened);
        PackbinTest.expectTrue("hostile run: several kinds seen " + Arrays.toString(counts),
                Arrays.stream(counts).filter(c -> c > 0).count() >= 4);
    }

    private static byte[] randomBytes(Random random, int max) {
        byte[] bytes = new byte[random.nextInt(max + 1)];
        random.nextBytes(bytes);
        return bytes;
    }
}

package packbin;

import java.util.Arrays;

/**
 * AZ-3233 AC-4 (tampering never yields plaintext), AC-5 (replay is refused before any MAC) and AC-6 (previous slot).
 */
public final class FrameTamperReplayTest {
    private FrameTamperReplayTest() {}

    public static void main(String[] args) {
        run();
        FrameSupport.finish("FrameTamperReplayTest");
    }

    static void run() {
        everyBitFlipAndFieldChangeIsATagMismatch();
        sealedBodiesEqualTheFixtureBytes();
        duplicateAndOldCountersComputeNoMac();
        aFreshTamperedBodyDoesNotCommit();
        previousSlotOpensOldBodiesAndTheCurrentOnesToo();
        aFrameOpenedUnderThePreviousKeyCommitsIntoTheWindow();
        theWindowClearsTheRestoredStateRules();
    }

    private static Object open(FrameSession s, int dir, MsgContext ctx, byte[] ad, byte[] body,
            int clearLen, ReplayWindow window, long counter, byte[] out) {
        return s.open(dir, ctx, ad, body, clearLen, window, counter, out);
    }

    private static void expectTagMismatch(String label, FrameSession s, int dir, MsgContext ctx, byte[] ad,
            byte[] body, int clearLen) {
        // Arrange
        ReplayWindow window = ReplayWindow.fromParts(100, 1);
        byte[] out = FrameSupport.filled(300);

        // Act
        Object result = open(s, dir, ctx, ad, body, clearLen, window, 101, out);

        // Assert
        PackbinTest.expectTrue(label + ": " + FrameSupport.kind(result), result instanceof Packbin.TagMismatch);
        PackbinTest.expectTrue(label + ": output untouched", FrameSupport.allSentinel(out));
        PackbinTest.expectTrue(label + ": window unchanged", window.equals(ReplayWindow.fromParts(100, 1)));
    }

    private static void everyBitFlipAndFieldChangeIsATagMismatch() {
        for (FrameExamples e : FrameExamples.all()) {
            try (FrameSession s = e.session(4)) {
                byte[] body = e.sealed(s);
                for (int i = 0; i < e.ad.length * 8; i++) {
                    byte[] ad = e.ad.clone();
                    ad[i / 8] ^= (byte) (1 << (i % 8));
                    expectTagMismatch("E" + e.dir + " ad bit " + i, s, e.dir, e.ctx, ad, body, e.clear.length);
                }
                for (int i = 0; i < body.length * 8; i++) {
                    byte[] changed = body.clone();
                    changed[i / 8] ^= (byte) (1 << (i % 8));
                    expectTagMismatch("E" + e.dir + " body bit " + i, s, e.dir, e.ctx, e.ad, changed, e.clear.length);
                }
                byte[] otherId = e.ctx.msgId.clone();
                otherId[0] ^= 1;
                expectTagMismatch("E" + e.dir + " msg_id", s, e.dir, new MsgContext(otherId, e.ctx.kind), e.ad, body,
                        e.clear.length);
                expectTagMismatch("E" + e.dir + " kind", s, e.dir, new MsgContext(e.ctx.msgId, e.ctx.kind ^ 1), e.ad, body,
                        e.clear.length);
                expectTagMismatch("E" + e.dir + " direction", s, e.dir == 1 ? 2 : 1, e.ctx, e.ad, body, e.clear.length);
                expectTagMismatch("E" + e.dir + " clear_len + 1", s, e.dir, e.ctx, e.ad, body, e.clear.length + 1);
                try (FrameSession otherEpoch = FrameSession.load(e.key, e.epoch + 1, 4, 1, 2, 3)) {
                    expectTagMismatch("E" + e.dir + " epoch", otherEpoch, e.dir, e.ctx, e.ad, body, e.clear.length);
                }
                byte[] otherKey = e.key.clone();
                otherKey[0] ^= 1;
                try (FrameSession other = FrameSession.load(otherKey, e.epoch, 4, 1, 2, 3)) {
                    expectTagMismatch("E" + e.dir + " key", other, e.dir, e.ctx, e.ad, body, e.clear.length);
                }
            }
        }
    }

    private static void sealedBodiesEqualTheFixtureBytes() {
        for (FrameExamples e : FrameExamples.all()) {
            // Arrange
            try (FrameSession s = e.session(4)) {
                // Act
                byte[] body = e.sealed(s);

                // Assert
                PackbinTest.expectEq("E" + e.dir + " body", e.body4, FrameSupport.unhex(body));
            }
        }
    }

    private static void duplicateAndOldCountersComputeNoMac() {
        // Arrange
        FrameExamples e = FrameExamples.all()[0];
        try (FrameSession s = e.session(4)) {
            byte[] body = e.sealed(s);
            ReplayWindow window = new ReplayWindow();
            window.commit(100);
            ReplayWindow expected = ReplayWindow.fromParts(100, 1);
            long before = FrameSession.macComputationsForTest();
            byte[] out = FrameSupport.filled(300);

            // Act
            Object dup = open(s, e.dir, e.ctx, e.ad, body, 0, window, 100, out);
            Object old = open(s, e.dir, e.ctx, e.ad, body, 0, window, 36, out);
            long computed = FrameSession.macComputationsForTest() - before;

            // Assert
            PackbinTest.expectTrue("seen counter is Duplicate", dup instanceof Packbin.Duplicate);
            PackbinTest.expectTrue("counter 64 behind is TooOld", old instanceof Packbin.TooOld);
            PackbinTest.expectEq("MAC computations for Duplicate and TooOld", 0L, computed);
            PackbinTest.expectTrue("window unchanged by the refusals", window.equals(expected));
            PackbinTest.expectTrue("output untouched by the refusals", FrameSupport.allSentinel(out));

            // Act: a fresh valid counter does compute a MAC and commits
            Object fresh = open(s, e.dir, e.ctx, e.ad, body, 0, window, 101, out);

            // Assert
            PackbinTest.expectTrue("fresh valid body opens", fresh instanceof FrameSession.Opened);
            PackbinTest.expectTrue("MAC computed for the fresh body", FrameSession.macComputationsForTest() > before);
            PackbinTest.expectEq("committed counter is now a duplicate", ReplayWindow.Freshness.DUPLICATE, window.check(101));
        }
    }

    private static void aFreshTamperedBodyDoesNotCommit() {
        // Arrange
        FrameExamples e = FrameExamples.all()[0];
        try (FrameSession s = e.session(4)) {
            byte[] body = e.sealed(s);
            body[0] ^= 1;
            ReplayWindow window = new ReplayWindow();
            window.commit(100);

            // Act
            Object result = open(s, e.dir, e.ctx, e.ad, body, 0, window, 101, new byte[300]);

            // Assert
            PackbinTest.expectTrue("tampered body is TagMismatch", result instanceof Packbin.TagMismatch);
            PackbinTest.expectEq("tampered counter stays fresh", ReplayWindow.Freshness.FRESH, window.check(101));
        }
    }

    private static byte[] sealUnder(byte fill, int epoch, MsgContext ctx, byte[] ad, byte[] plain) {
        byte[] key = new byte[32];
        Arrays.fill(key, fill);
        try (FrameSession s = FrameSession.load(key, epoch, 4, FrameSession.DOWN)) {
            byte[] out = new byte[64];
            FrameSession.Sealed sealed = (FrameSession.Sealed) s.seal(FrameSession.DOWN, ctx, ad, null, plain, out);
            return Arrays.copyOf(out, sealed.length);
        }
    }

    private static void previousSlotOpensOldBodiesAndTheCurrentOnesToo() {
        // Arrange
        MsgContext ctx = new MsgContext(new byte[] {7, 7, 7, 7, 7, 7, 7, 7}, 5);
        byte[] ad = {1, 2, 3};
        byte[] plain = "hello frame".getBytes(java.nio.charset.StandardCharsets.US_ASCII);
        byte[] oldBody = sealUnder((byte) 0xAA, 6, ctx, ad, plain);
        byte[] newBody = sealUnder((byte) 0xBB, 7, ctx, ad, plain);
        byte[] b = new byte[32];
        Arrays.fill(b, (byte) 0xBB);
        byte[] a = new byte[32];
        Arrays.fill(a, (byte) 0xAA);
        try (FrameSession two = FrameSession.load(b, 7, 4, FrameSession.DOWN);
                FrameSession one = FrameSession.load(b, 7, 4, FrameSession.DOWN)) {
            PackbinTest.expectTrue("previous slot set", two.setPrevious(a, 6));

            // Act
            Object rOld = two.open(FrameSession.DOWN, ctx, ad, oldBody, 0, null, 0, new byte[64]);
            Object rNew = two.open(FrameSession.DOWN, ctx, ad, newBody, 0, null, 0, new byte[64]);
            Object rNone = one.open(FrameSession.DOWN, ctx, ad, oldBody, 0, null, 0, new byte[64]);

            // Assert
            PackbinTest.expectEq("old body slot", FrameSession.Slot.PREVIOUS, ((FrameSession.Opened) rOld).slot);
            PackbinTest.expectEq("new body slot", FrameSession.Slot.CURRENT, ((FrameSession.Opened) rNew).slot);
            PackbinTest.expectTrue("no previous slot: old body is TagMismatch", rNone instanceof Packbin.TagMismatch);

            // Act
            two.clearPrevious();
            Object cleared = two.open(FrameSession.DOWN, ctx, ad, oldBody, 0, null, 0, new byte[64]);

            // Assert
            PackbinTest.expectTrue("cleared previous: old body is TagMismatch", cleared instanceof Packbin.TagMismatch);
            PackbinTest.expectTrue("previous epoch out of range", !two.setPrevious(a, 0x1000000));
        }
    }

    private static void aFrameOpenedUnderThePreviousKeyCommitsIntoTheWindow() {
        // Arrange
        MsgContext ctx = new MsgContext(new byte[8], 1);
        byte[] oldBody = sealUnder((byte) 0xAA, 6, ctx, null, new byte[] {1, 2, 3});
        byte[] a = new byte[32];
        Arrays.fill(a, (byte) 0xAA);
        byte[] b = new byte[32];
        Arrays.fill(b, (byte) 0xBB);
        ReplayWindow window = new ReplayWindow();
        try (FrameSession s = FrameSession.load(b, 7, 4, FrameSession.DOWN)) {
            s.setPrevious(a, 6);

            // Act
            Object first = s.open(FrameSession.DOWN, ctx, null, oldBody, 0, window, 5, new byte[8]);
            Object again = s.open(FrameSession.DOWN, ctx, null, oldBody, 0, window, 5, new byte[8]);

            // Assert
            PackbinTest.expectTrue("previous slot opens", first instanceof FrameSession.Opened);
            PackbinTest.expectTrue("same counter again is a duplicate", again instanceof Packbin.Duplicate);
        }
    }

    private static void theWindowClearsTheRestoredStateRules() {
        // Arrange
        ReplayWindow restored = ReplayWindow.fromParts(1000, 0);

        // Act
        ReplayWindow.Freshness fresh = restored.check(5);
        restored.commit(5);

        // Assert
        PackbinTest.expectEq("bits 0 is empty whatever top is", ReplayWindow.Freshness.FRESH, fresh);
        PackbinTest.expectEq("commit on an empty window sets top", "5:1", restored.toString());
    }
}

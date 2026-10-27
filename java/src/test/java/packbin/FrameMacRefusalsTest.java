package packbin;

import static packbin.FrameDirection.DOWN;
import static packbin.FrameDirection.GROUP;
import static packbin.FrameDirection.UP;

import java.util.Arrays;

/** AZ-3233 AC-7 (MAC-only), AC-8 (every refusal kind) and AC-9 (tag compare); AZ-3255 AC-3 (per-key MAC count). */
public final class FrameMacRefusalsTest {
    private static final byte[] NET = {'n', 'e', 't'};

    private FrameMacRefusalsTest() {}

    public static void main(String[] args) {
        run();
        FrameSupport.finish("FrameMacRefusalsTest");
    }

    static void run() {
        macOnlyTagsDoNotDependOnTheSplit();
        macOnlyRefusals();
        eachMacKeyCountsOnlyItsOwnMacs();
        loadRefusals();
        sealRefusalsWriteNothing();
        openRefusals();
        tagCompareFoldsEveryByte();
    }

    private static byte[] key(int fill) {
        byte[] key = new byte[32];
        Arrays.fill(key, (byte) fill);
        return key;
    }

    private static void macOnlyTagsDoNotDependOnTheSplit() {
        // Arrange
        byte[] message = FrameSupport.hex("e8030000c0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3");
        byte[] e5 = FrameSupport.hex("636865636b");
        try (MacKey e4Key = MacKey.derive(key(0x22), 7, NET); MacKey e5Key = MacKey.derive(key(0x22), 8, NET)) {
            byte[][][] splits = {
                {message},
                {Arrays.copyOfRange(message, 0, 4), Arrays.copyOfRange(message, 4, message.length)},
                {Arrays.copyOfRange(message, 0, 3), Arrays.copyOfRange(message, 3, 8), Arrays.copyOfRange(message, 8, message.length)},
            };
            for (byte[][] parts : splits) {
                // Act
                byte[] tag = new byte[4];
                Object result = e4Key.tag(tag, parts);

                // Assert
                PackbinTest.expectTrue("E4 tag call " + parts.length + " parts", result == null);
                PackbinTest.expectEq("E4 tag over " + parts.length + " parts", "56db9bec", FrameSupport.unhex(tag));
                PackbinTest.expectTrue("E4 verify over " + parts.length + " parts", e4Key.verify(tag, parts));
                for (int bit = 0; bit < 32; bit++) {
                    byte[] flipped = tag.clone();
                    flipped[bit / 8] ^= (byte) (1 << (bit % 8));
                    PackbinTest.expectTrue("E4 flipped tag bit " + bit, !e4Key.verify(flipped, parts));
                }
            }
            byte[] tag5 = new byte[4];
            e5Key.tag(tag5, e5);
            PackbinTest.expectEq("E5 tag", "3cf8e8c5", FrameSupport.unhex(tag5));
            PackbinTest.expectTrue("E5 verify with an empty and a null part",
                    e5Key.verify(tag5, new byte[0], e5, null));
            byte[] full = new byte[32];
            e4Key.tag(full, message);
            PackbinTest.expectEq("tag of 32 starts with the tag of 4", "56db9bec", FrameSupport.unhex(Arrays.copyOf(full, 4)));
            PackbinTest.expectTrue("verify with a wrong length is false", !e4Key.verify(new byte[5], message));
        }
    }

    private static void macOnlyRefusals() {
        // Arrange
        byte[] key = key(0x22);

        // Act and Assert
        PackbinTest.expectTrue("label of 0 bytes", MacKey.derive(key, 7, new byte[0]) == null);
        PackbinTest.expectTrue("label of 33 bytes", MacKey.derive(key, 7, new byte[33]) == null);
        PackbinTest.expectTrue("label of 1 byte", MacKey.derive(key, 7, new byte[1]) != null);
        PackbinTest.expectTrue("label of 32 bytes", MacKey.derive(key, 7, new byte[32]) != null);
        PackbinTest.expectTrue("epoch 0x1000000", MacKey.derive(key, 0x1000000, NET) == null);
        PackbinTest.expectTrue("epoch 0xFFFFFF", MacKey.derive(key, 0xFFFFFF, NET) != null);
        PackbinTest.expectTrue("key of 31 bytes", MacKey.derive(new byte[31], 7, NET) == null);
        try (MacKey mac = MacKey.derive(key, 7, NET)) {
            for (int n : new int[] {0, 2, 5, 3, 33}) {
                byte[] tag = FrameSupport.filled(n);
                PackbinTest.expectTrue("n = " + n + " is BadValue", mac.tag(tag, new byte[3]) instanceof Packbin.BadValue);
                PackbinTest.expectTrue("n = " + n + " writes nothing", FrameSupport.allSentinel(tag));
            }
            for (int n : new int[] {4, 8, 16, 32}) {
                PackbinTest.expectTrue("n = " + n + " is accepted", mac.tag(new byte[n], new byte[3]) == null);
            }
        }
    }

    private static void eachMacKeyCountsOnlyItsOwnMacs() {
        // Arrange
        try (MacKey a = MacKey.derive(key(0x22), 7, NET); MacKey b = MacKey.derive(key(0x22), 7, NET)) {
            byte[] tag = new byte[4];
            long bBefore = b.macComputationsForTest();

            // Act
            a.tag(tag, NET);
            a.verify(tag, NET);
            a.tag(new byte[5], NET);

            // Assert
            PackbinTest.expectEq("A counts its tag and verify, not the refused length", 2L, a.macComputationsForTest());
            PackbinTest.expectEq("B's count does not move while A computes", 0L, b.macComputationsForTest() - bBefore);
        }
    }

    private static void loadRefusals() {
        byte[] key = key(1);
        FrameConfig up4 = new FrameConfig(4, FrameDirections.of(UP));
        PackbinTest.expectTrue("epoch 0x1000000", FrameSession.load(key, 0x1000000, up4) == null);
        PackbinTest.expectTrue("epoch -1", FrameSession.load(key, -1, up4) == null);
        PackbinTest.expectTrue("epoch 0xFFFFFF", FrameSession.load(key, 0xFFFFFF, up4) != null);
        for (int tag : new int[] {0, 5, 32, 3, 17}) {
            PackbinTest.expectTrue("tag_len " + tag, FrameSession.load(key, 1, new FrameConfig(tag, FrameDirections.of(UP))) == null);
        }
        for (int tag : new int[] {4, 8, 16}) {
            PackbinTest.expectTrue("tag_len " + tag, FrameSession.load(key, 1, new FrameConfig(tag, FrameDirections.of(UP))) != null);
        }
        PackbinTest.expectTrue("key of 31 bytes", FrameSession.load(new byte[31], 1, up4) == null);
        PackbinTest.expectTrue("null key", FrameSession.load(null, 1, up4) == null);
    }

    private static void expectSealRefusal(String label, Class<?> expected, FrameSession s, FrameDirection dir, MsgContext ctx,
            byte[] ad, byte[] clear, byte[] plain, int outLen) {
        // Arrange
        byte[] out = FrameSupport.filled(outLen);

        // Act
        Object result = s.seal(dir, ctx, ad, clear, plain, out);

        // Assert
        PackbinTest.expectTrue(label + ": " + FrameSupport.kind(result), expected.isInstance(result));
        PackbinTest.expectTrue(label + ": nothing written", FrameSupport.allSentinel(out));
    }

    private static void sealRefusalsWriteNothing() {
        MsgContext ctx = new MsgContext(new byte[8], 3);
        try (FrameSession s = FrameSession.load(key(9), 2, new FrameConfig(4, FrameDirections.of(UP, DOWN)))) {
            expectSealRefusal("null direction", Packbin.BadValue.class, s, null, ctx, null, null, new byte[3], 300);
            expectSealRefusal("direction not loaded", Packbin.BadValue.class, s, GROUP, ctx, null, null, new byte[3], 300);
            expectSealRefusal("kind 16", Packbin.BadValue.class, s, UP, new MsgContext(new byte[8], 16), null, null, new byte[3], 300);
            expectSealRefusal("kind -1", Packbin.BadValue.class, s, UP, new MsgContext(new byte[8], -1), null, null, new byte[3], 300);
            expectSealRefusal("msg_id of 7 bytes", Packbin.BadValue.class, s, UP, new MsgContext(new byte[7], 1), null, null, new byte[3], 300);
            expectSealRefusal("null context", Packbin.BadValue.class, s, UP, null, null, null, new byte[3], 300);
            expectSealRefusal("ad of 256 bytes", Packbin.TooLong.class, s, UP, ctx, new byte[256], null, new byte[3], 300);
            expectSealRefusal("body of 256 bytes", Packbin.TooLong.class, s, UP, ctx, null, new byte[100], new byte[152], 300);
            expectSealRefusal("buffer one byte short", Packbin.BufferFull.class, s, UP, ctx, null, new byte[2], new byte[3], 8);
            expectSealRefusal("null buffer", Packbin.BufferFull.class, s, UP, ctx, null, null, new byte[3], 0);
            byte[] edge = new byte[255];
            PackbinTest.expectTrue("body of exactly 255 bytes seals",
                    s.seal(UP, ctx, new byte[255], new byte[100], new byte[151], edge) instanceof FrameSealed);
            PackbinTest.expectTrue("offset past the buffer", s.seal(UP, ctx, null, null, new byte[1], new byte[8], 9) instanceof Packbin.BadValue);
            byte[] shifted = FrameSupport.filled(12);
            Object placed = s.seal(UP, ctx, null, null, new byte[3], shifted, 4);
            PackbinTest.expectTrue("seal at an offset", placed instanceof FrameSealed);
            PackbinTest.expectTrue("bytes before and after the body are untouched",
                    shifted[3] == FrameSupport.SENTINEL && shifted[11] == FrameSupport.SENTINEL);
            Object rangedOpen = s.open(UP, ctx, null, shifted, 4, 7, 0, null, 0, new byte[3], 0);
            PackbinTest.expectTrue("open of a range", rangedOpen instanceof FrameOpened);
        }
    }

    private static void openRefusals() {
        MsgContext ctx = new MsgContext(new byte[8], 3);
        try (FrameSession s = FrameSession.load(key(9), 2, new FrameConfig(4, FrameDirections.of(UP, DOWN)))) {
            byte[] body = new byte[20];
            Object sealed = s.seal(UP, ctx, null, new byte[2], new byte[14], body);
            PackbinTest.expectTrue("sealed 20 bytes", sealed instanceof FrameSealed);
            expectOpen("direction not loaded", Packbin.BadValue.class, s.open(GROUP, ctx, null, body, 2, null, 0, new byte[14]));
            expectOpen("null direction", Packbin.BadValue.class, s.open(null, ctx, null, body, 2, null, 0, new byte[14]));
            expectOpen("kind 16", Packbin.BadValue.class, s.open(UP, new MsgContext(new byte[8], 16), null, body, 2, null, 0, new byte[14]));
            expectOpen("ad 256", Packbin.TooLong.class, s.open(UP, ctx, new byte[256], body, 2, null, 0, new byte[14]));
            expectOpen("body 256", Packbin.TooLong.class, s.open(UP, ctx, null, new byte[256], 2, null, 0, new byte[300]));
            expectOpen("clear_len 256", Packbin.TooLong.class, s.open(UP, ctx, null, body, 256, null, 0, new byte[14]));
            expectOpen("body shorter than clear_len + tag", Packbin.ShortPacket.class, s.open(UP, ctx, null, body, 17, null, 0, new byte[14]));
            expectOpen("empty body", Packbin.ShortPacket.class, s.open(UP, ctx, null, new byte[0], 0, null, 0, new byte[14]));
            expectOpen("null body", Packbin.ShortPacket.class, s.open(UP, ctx, null, null, 0, null, 0, new byte[14]));
            expectOpen("output one byte short", Packbin.BufferFull.class, s.open(UP, ctx, null, body, 2, null, 0, new byte[13]));
            expectOpen("tag changed", Packbin.TagMismatch.class,
                    s.open(UP, ctx, null, withLast(body), 2, null, 0, new byte[14]));
            ReplayWindow window = new ReplayWindow();
            window.commit(100);
            expectOpen("Duplicate", Packbin.Duplicate.class, s.open(UP, ctx, null, body, 2, window, 100, new byte[14]));
            expectOpen("TooOld", Packbin.TooOld.class, s.open(UP, ctx, null, body, 2, window, 36, new byte[14]));
            expectOpen("range outside the body", Packbin.BadValue.class, s.open(UP, ctx, null, body, 10, 20, 2, null, 0, new byte[14], 0));
        }
    }

    private static byte[] withLast(byte[] body) {
        byte[] copy = body.clone();
        copy[copy.length - 1] ^= 1;
        return copy;
    }

    private static void expectOpen(String label, Class<?> expected, Object result) {
        PackbinTest.expectTrue("open " + label + ": " + FrameSupport.kind(result), expected.isInstance(result));
    }

    private static void tagCompareFoldsEveryByte() {
        // Arrange
        byte[] a = new byte[16];
        Arrays.fill(a, (byte) 7);
        byte[] firstDiffers = a.clone();
        firstDiffers[0] ^= 1;
        byte[] lastDiffers = a.clone();
        lastDiffers[15] ^= 0x80;
        byte[] shorter = Arrays.copyOf(a, 15);

        // Act and Assert
        PackbinTest.expectTrue("equal tags", FrameCrypto.constantTimeEquals(a, a.clone()));
        PackbinTest.expectTrue("first byte differs", !FrameCrypto.constantTimeEquals(a, firstDiffers));
        PackbinTest.expectTrue("last byte differs", !FrameCrypto.constantTimeEquals(a, lastDiffers));
        PackbinTest.expectTrue("lengths differ", !FrameCrypto.constantTimeEquals(a, shorter));
        PackbinTest.expectTrue("empty tags are equal", FrameCrypto.constantTimeEquals(new byte[0], new byte[0]));
        PackbinTest.expectTrue("ranges of a larger buffer",
                FrameCrypto.constantTimeEquals(new byte[] {1, 2, 3, 4}, 1, new byte[] {9, 2, 3, 8}, 1, 2));
        PackbinTest.expectTrue("high bit bytes differ", !FrameCrypto.constantTimeEquals(new byte[] {(byte) 0x80}, new byte[] {0}));
    }
}

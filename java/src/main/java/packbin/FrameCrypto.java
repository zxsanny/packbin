package packbin;

import javax.crypto.Mac;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicLong;

/** The pieces of frame mode shared by {@link FrameSession} and {@link MacKey}: salt, nonce, HMAC and the tag compare. */
final class FrameCrypto {
    static final int MAX_BODY = 255;
    static final int MAX_EPOCH = 0xFFFFFF;
    private static final byte[] LABEL = "packbin-frame".getBytes(StandardCharsets.US_ASCII);

    /** Test-only: the number of HMAC computations started (a replay refusal must not start one). */
    private static final AtomicLong MAC_COMPUTATIONS = new AtomicLong();

    private FrameCrypto() {}

    static long macComputations() {
        return MAC_COMPUTATIONS.get();
    }

    /** {@code "packbin-frame"} followed by the epoch as a 32-bit little-endian integer. */
    static byte[] salt(int epoch) {
        byte[] out = new byte[LABEL.length + 4];
        System.arraycopy(LABEL, 0, out, 0, LABEL.length);
        for (int i = 0; i < 4; i++) {
            out[LABEL.length + i] = (byte) (epoch >>> (8 * i));
        }
        return out;
    }

    /** HKDF(IKM = key, salt of the epoch, info, L = 32). */
    static byte[] derive(byte[] key, int epoch, byte[] info) {
        return SessionPad.hkdfSha256(key, salt(epoch), info, 32);
    }

    /** {@code msg_id ‖ ((kind << 4) | direction) ‖ epoch} as 24 bits, 12 bytes. */
    static byte[] nonce(byte[] msgId, int kind, int direction, int epoch) {
        byte[] n = new byte[12];
        System.arraycopy(msgId, 0, n, 0, 8);
        n[8] = (byte) ((kind << 4) | direction);
        n[9] = (byte) epoch;
        n[10] = (byte) (epoch >>> 8);
        n[11] = (byte) (epoch >>> 16);
        return n;
    }

    /** A keyed HMAC-SHA256, counted. */
    static Mac mac(byte[] key) {
        MAC_COMPUTATIONS.incrementAndGet();
        return SessionPad.hmac(key);
    }

    static void update(Mac mac, byte[] bytes) {
        if (bytes != null) {
            mac.update(bytes, 0, bytes.length);
        }
    }

    /**
     * True when the two ranges are equal. Every byte is folded into one accumulator, with no early exit and no branch on
     * the data, so the time does not depend on where the ranges differ. Constant time is best effort: the JIT may
     * change the code, and the platform gives no guarantee. The lengths are not secret.
     */
    static boolean constantTimeEquals(byte[] a, int aOff, byte[] b, int bOff, int len) {
        int diff = 0;
        for (int i = 0; i < len; i++) {
            diff |= a[aOff + i] ^ b[bOff + i];
        }
        return diff == 0;
    }

    static boolean constantTimeEquals(byte[] a, byte[] b) {
        return a.length == b.length && constantTimeEquals(a, 0, b, 0, a.length);
    }

    static boolean isZero(byte[] bytes) {
        int acc = 0;
        for (byte b : bytes) {
            acc |= b;
        }
        return acc == 0;
    }
}

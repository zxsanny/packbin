package packbin;

import javax.crypto.Mac;
import java.util.Arrays;

/**
 * The MAC-only call of frame mode (contract {@code pack-session.md} 2.0.0): a tag without encryption, for a per-hop
 * network check and for key fingerprints. {@code K_label = HKDF(key, "packbin-frame" ‖ epoch, 0x00 ‖ label)} and the tag
 * is the first n bytes of {@code HMAC(K_label, message)}; the message is hashed in parts with no joined copy, and the
 * tag does not depend on how it is split.
 *
 * <p>The object holds the 32-byte HMAC key {@code K_label} (the platform HMAC computes the pads per call; Java does
 * not keep a pad state). {@link #close()} overwrites it, best effort: the platform may hold copies in its own key and
 * digest objects, and the garbage collector may have copied the array before; that is a limit of the runtime. After
 * {@code close}, {@code tag} gives {@link Packbin.BadValue} and {@code verify} gives false. Thread-safe for
 * {@code tag} and {@code verify}; do not call {@code close} while they run.
 */
public final class MacKey implements AutoCloseable {
    private final int epoch;
    private final byte[] key;
    private volatile boolean closed;

    private MacKey(int epoch, byte[] key) {
        this.epoch = epoch;
        this.key = key;
    }

    /** The key for {@code label} (1 to 32 bytes) at {@code epoch} (0 to 0xFFFFFF), or null (the contract's BadValue). */
    public static MacKey derive(byte[] key, int epoch, byte[] label) {
        if (key == null || key.length != 32 || label == null || label.length < 1 || label.length > 32
                || epoch < 0 || epoch > FrameCrypto.MAX_EPOCH) {
            return null;
        }
        byte[] info = new byte[label.length + 1];
        System.arraycopy(label, 0, info, 1, label.length);
        return new MacKey(epoch, FrameCrypto.derive(key, epoch, info));
    }

    public int epoch() {
        return epoch;
    }

    /**
     * Writes the first {@code out.length} bytes of the HMAC of {@code parts} joined into {@code out}, which is 4, 8, 16
     * or 32 bytes. Returns null on success, or {@link Packbin.BadValue} (nothing written) for any other length or a
     * closed key. A null part is empty.
     */
    public Object tag(byte[] out, byte[]... parts) {
        if (closed || out == null || !tagLength(out.length)) {
            return new Packbin.BadValue("tag length");
        }
        byte[] full = full(parts);
        System.arraycopy(full, 0, out, 0, out.length);
        return null;
    }

    /** True when {@code tag} (4, 8, 16 or 32 bytes) is the tag of the message; compares every byte without an early exit. */
    public boolean verify(byte[] tag, byte[]... parts) {
        if (closed || tag == null || !tagLength(tag.length)) {
            return false;
        }
        byte[] full = full(parts);
        return FrameCrypto.constantTimeEquals(full, 0, tag, 0, tag.length);
    }

    /** Overwrites the key (best effort, see the class note). Closing twice is harmless. */
    @Override
    public void close() {
        closed = true;
        Arrays.fill(key, (byte) 0);
    }

    private byte[] full(byte[][] parts) {
        Mac mac = FrameCrypto.mac(key);
        if (parts != null) {
            for (byte[] part : parts) {
                FrameCrypto.update(mac, part);
            }
        }
        return mac.doFinal();
    }

    private static boolean tagLength(int n) {
        return n == 4 || n == 8 || n == 16 || n == 32;
    }

    /** Test access: the live key array, to see the wipe. */
    byte[] keyForTest() {
        return key;
    }

    @Override
    public String toString() {
        return "MacKey[epoch=" + epoch + "]";
    }
}

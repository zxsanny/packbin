package packbin;

import javax.crypto.Mac;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/**
 * Frame mode of the pack session (contract {@code pack-session.md} 2.0.0): sealed, authenticated frames for links that
 * lose, reorder and duplicate messages. A frame body is {@code clear ‖ ciphertext ‖ tag}: ChaCha20 under a key per
 * (key, epoch, direction) from HKDF-SHA256, a nonce built from the caller's 8-byte message id, the 4-bit {@code kind}, the
 * direction and the epoch, and a tag that is the first 4, 8 or 16 bytes of HMAC-SHA256 over the nonce, the associated data,
 * the clear part and the ciphertext (encrypt, then MAC). It is separate from the stream {@link PackSession}, which is
 * unchanged. All results are the package's error objects: {@link Sealed} or {@link Opened} on success, otherwise
 * {@link Packbin.BadValue}, {@link Packbin.TooLong}, {@link Packbin.BufferFull}, {@link Packbin.ShortPacket},
 * {@link Packbin.TagMismatch}, {@link Packbin.Duplicate} or {@link Packbin.TooOld}.
 *
 * <p><b>Uniqueness rule (the caller's duty): for one (key, epoch, direction), a message id is never sealed twice with
 * different contents.</b> Reuse breaks the confidentiality of both messages and the library cannot check it. A new epoch
 * derives new keys and nonces.
 *
 * <p>{@code seal} is deterministic, stateless and thread-safe; {@code open} may run from many threads too, but the
 * {@link ReplayWindow} it updates is not thread-safe. {@code setPrevious}, {@code clearPrevious} and {@code close} replace or
 * overwrite keys that {@code seal} and {@code open} read: call them only while no other call is running. Load once, never
 * per message: the keys are derived at load.
 *
 * <p>Limits of the runtime, stated once: the derived keys are overwritten at {@link #close()} (best effort), but the
 * platform HMAC and the garbage collector may hold copies the library cannot reach, and nothing wipes them if you never
 * call {@code close} (there is no cleaner). The tag compare is {@code MessageDigest.isEqual}; the platform may still change
 * the timing.
 */
public final class FrameSession implements AutoCloseable {
    public static final int UP = 1;
    public static final int DOWN = 2;
    public static final int GROUP = 3;

    /** Which loaded key opened a frame. */
    public enum Slot { CURRENT, PREVIOUS }

    /** The result of a successful seal: the body is {@code out[offset, offset + length)}. */
    public static final class Sealed {
        public final int length;

        Sealed(int length) {
            this.length = length;
        }
    }

    /** The result of a successful open. */
    public static final class Opened {
        public final Slot slot;
        public final int clearLength;
        public final int plainLength;

        Opened(Slot slot, int clearLength, int plainLength) {
            this.slot = slot;
            this.clearLength = clearLength;
            this.plainLength = plainLength;
        }
    }

    /** The keys of one (key, epoch): encryption and MAC key per loaded direction (index 1 to 3). */
    private static final class Keys {
        final int epoch;
        final byte[][] enc = new byte[4][];
        final byte[][] mac = new byte[4][];

        Keys(byte[] key, int epoch, int directions) {
            this.epoch = epoch;
            byte[] salt = FrameCrypto.salt(epoch);
            for (int d = UP; d <= GROUP; d++) {
                if ((directions & (1 << d)) != 0) {
                    enc[d] = SessionPad.hkdfSha256(key, salt, info(d, "enc"), 32);
                    mac[d] = SessionPad.hkdfSha256(key, salt, info(d, "mac"), 32);
                }
            }
        }

        void wipe() {
            for (int d = UP; d <= GROUP; d++) {
                if (enc[d] != null) {
                    Arrays.fill(enc[d], (byte) 0);
                    Arrays.fill(mac[d], (byte) 0);
                }
            }
        }
    }

    private final int tagLen;
    private final int directions;
    private final Keys current;
    private volatile Keys previous;
    private final Object previousLock = new Object();
    private volatile boolean closed;

    private FrameSession(Keys current, int tagLen, int directions) {
        this.current = current;
        this.tagLen = tagLen;
        this.directions = directions;
    }

    /**
     * A frame session for the 32-byte {@code key} at {@code epoch} (0 to 0xFFFFFF), with {@code tagLen} 4, 8 or 16 bytes,
     * fixed for the lifetime of the key (one tag length is used per key and epoch across all devices), and the directions
     * it may seal and open ({@link #UP}, {@link #DOWN}, {@link #GROUP}; a call in another direction is refused). Returns
     * null for anything out of range (the contract's BadValue); the key is copied.
     */
    public static FrameSession load(byte[] key, int epoch, int tagLen, int... directionList) {
        if (key == null || key.length != 32 || epoch < 0 || epoch > FrameCrypto.MAX_EPOCH
                || (tagLen != 4 && tagLen != 8 && tagLen != 16) || directionList == null) {
            return null;
        }
        int mask = 0;
        for (int d : directionList) {
            if (d < UP || d > GROUP) {
                return null;
            }
            mask |= 1 << d;
        }
        return new FrameSession(new Keys(key, epoch, mask), tagLen, mask);
    }

    /**
     * Keeps a previous (key, epoch) that {@code open} tries when the current key's tag does not match (the key just
     * replaced). Seal never uses it. Returns false (BadValue) for a closed session or an argument out of range. A frame that
     * opens under the previous key commits into the same window: call {@link #clearPrevious()} when the changeover ends.
     */
    public boolean setPrevious(byte[] key, int epoch) {
        if (closed || key == null || key.length != 32 || epoch < 0 || epoch > FrameCrypto.MAX_EPOCH) {
            return false;
        }
        Keys next = new Keys(key, epoch, directions);
        synchronized (previousLock) {
            Keys old = previous;
            previous = next;
            if (old != null) {
                old.wipe();
            }
        }
        return true;
    }

    /** Drops the previous (key, epoch) and overwrites its keys. */
    public void clearPrevious() {
        synchronized (previousLock) {
            Keys old = previous;
            previous = null;
            if (old != null) {
                old.wipe();
            }
        }
    }

    /**
     * Seals {@code clear ‖ plain} into {@code out} starting at 0; see {@link #seal(int, MsgContext, byte[], byte[], byte[],
     * byte[], int)}.
     */
    public Object seal(int direction, MsgContext ctx, byte[] ad, byte[] clear, byte[] plain, byte[] out) {
        return seal(direction, ctx, ad, clear, plain, out, 0);
    }

    /**
     * Seals {@code clear ‖ plain} into {@code out} at {@code outOffset} as {@code clear ‖ ciphertext ‖ tag} and returns
     * {@link Sealed} with the body length. A null array is empty. The same inputs give the same bytes; the session does not
     * change and the previous key is never used. A closed session, a direction not loaded, a context that is not valid
     * (id not 8 bytes, {@code kind} outside 0 to 15) or an offset outside {@code out} is {@link Packbin.BadValue}; {@code ad}
     * above 255 bytes, or {@code clear + plain + tag} above 255 bytes, is {@link Packbin.TooLong}; room for fewer bytes than
     * the body is {@link Packbin.BufferFull}. On any refusal nothing is written.
     *
     * <p><b>Never seal two different messages with the same message id under one key, epoch and direction.</b> The library
     * cannot check it, and a reused id breaks the confidentiality of both messages.
     */
    public Object seal(int direction, MsgContext ctx, byte[] ad, byte[] clear, byte[] plain, byte[] out, int outOffset) {
        Object bad = callChecks(direction, ctx, ad);
        if (bad != null) {
            return bad;
        }
        byte[] adBytes = orEmpty(ad);
        byte[] clearBytes = orEmpty(clear);
        byte[] plainBytes = orEmpty(plain);
        long bodyLong = (long) clearBytes.length + plainBytes.length + tagLen;
        if (bodyLong > FrameCrypto.MAX_BODY) {
            return new Packbin.TooLong((int) Math.min(bodyLong, Integer.MAX_VALUE), FrameCrypto.MAX_BODY);
        }
        int body = (int) bodyLong;
        if (out == null ? outOffset != 0 : outOffset < 0 || outOffset > out.length) {
            return new Packbin.BadValue("out offset");
        }
        if ((out == null ? 0 : out.length - outOffset) < body) {
            return new Packbin.BufferFull(body);
        }
        Keys keys = current;
        byte[] nonce = FrameCrypto.nonce(ctx.msgId, ctx.kind, direction, keys.epoch);
        byte[] cipher = plainBytes.clone();
        SessionPad.xor(keys.enc[direction], nonce, 0, cipher);
        byte[] tag = tagOver(keys.mac[direction], nonce, adBytes, clearBytes, cipher, 0, cipher.length);
        System.arraycopy(clearBytes, 0, out, outOffset, clearBytes.length);
        System.arraycopy(cipher, 0, out, outOffset + clearBytes.length, cipher.length);
        System.arraycopy(tag, 0, out, outOffset + clearBytes.length + cipher.length, tagLen);
        return new Sealed(body);
    }

    /** Opens a whole {@code body}; see the ranged form. */
    public Object open(int direction, MsgContext ctx, byte[] ad, byte[] body, int clearLength, ReplayWindow window,
            long counter, byte[] out) {
        return open(direction, ctx, ad, body, 0, body == null ? 0 : body.length, clearLength, window, counter, out, 0);
    }

    /**
     * Opens {@code body[bodyOffset, bodyOffset + bodyLength)} ({@code clear ‖ ciphertext ‖ tag}, the first
     * {@code clearLength} bytes clear) in the contract's order: argument checks, the replay window (when {@code window} is
     * not null, with the message's {@code counter}: {@link Packbin.Duplicate} or {@link Packbin.TooOld} before any MAC is
     * computed), the tag with the current key and then once with the previous key ({@link Packbin.TagMismatch}), decryption
     * into {@code out} at {@code outOffset}, and only then the window commit. Returns {@link Opened} with the slot, the clear
     * length and the plaintext length. A closed session, a direction not loaded, an invalid context or ranges outside the
     * arrays is {@link Packbin.BadValue}; {@code ad}, the body or {@code clearLength} above 255 is {@link Packbin.TooLong}
     * (before any MAC); a body shorter than {@code clearLength} plus the tag is {@link Packbin.ShortPacket}; room for fewer
     * bytes than the plaintext is {@link Packbin.BufferFull}. The clear part is not copied: the caller has it in
     * {@code body}. {@code out} is not written unless the result is {@link Opened}, and a refused open leaves the window as
     * it was.
     *
     * <p><b>The counter must come from bytes the tag covers</b> (the message id or the associated data), never from an
     * unauthenticated field of the wire: it is not part of the tag, so a captured frame replayed under a counter the attacker
     * chooses would open and could move the window.
     */
    public Object open(int direction, MsgContext ctx, byte[] ad, byte[] body, int bodyOffset, int bodyLength,
            int clearLength, ReplayWindow window, long counter, byte[] out, int outOffset) {
        Object bad = callChecks(direction, ctx, ad);
        if (bad != null) {
            return bad;
        }
        byte[] adBytes = orEmpty(ad);
        byte[] bodyBytes = body == null ? new byte[0] : body;
        int bodyStart = body == null ? 0 : bodyOffset;
        int bodyLen = body == null ? 0 : bodyLength;
        if (bodyStart < 0 || bodyLen < 0 || bodyStart > bodyBytes.length || bodyLen > bodyBytes.length - bodyStart
                || clearLength < 0) {
            return new Packbin.BadValue("body range");
        }
        if (bodyLen > FrameCrypto.MAX_BODY || clearLength > FrameCrypto.MAX_BODY) {
            return new Packbin.TooLong(Math.max(bodyLen, clearLength), FrameCrypto.MAX_BODY);
        }
        int framing = clearLength + tagLen;
        if (bodyLen < framing) {
            return new Packbin.ShortPacket("body", framing, bodyLen);
        }
        int plainLen = bodyLen - framing;
        if (out == null ? outOffset != 0 : outOffset < 0 || outOffset > out.length) {
            return new Packbin.BadValue("out offset");
        }
        if ((out == null ? 0 : out.length - outOffset) < plainLen) {
            return new Packbin.BufferFull(plainLen);
        }
        if (window != null) {
            ReplayWindow.Freshness fresh = window.check(counter);
            if (fresh == ReplayWindow.Freshness.DUPLICATE) {
                return new Packbin.Duplicate();
            }
            if (fresh == ReplayWindow.Freshness.TOO_OLD) {
                return new Packbin.TooOld();
            }
        }
        // One read of the caller's buffer: the tag is checked and the text decrypted from the same bytes, even when the
        // buffer changes while we work.
        bodyBytes = Arrays.copyOfRange(bodyBytes, bodyStart, bodyStart + bodyLen);
        bodyStart = 0;
        int cipherAt = bodyStart + clearLength;
        int tagAt = cipherAt + plainLen;
        byte[] clearBytes = Arrays.copyOfRange(bodyBytes, bodyStart, cipherAt);
        Slot slot = Slot.CURRENT;
        Keys keys = current;
        byte[] nonce = matching(keys, direction, ctx, adBytes, clearBytes, bodyBytes, cipherAt, plainLen, tagAt);
        if (nonce == null) {
            keys = previous;
            slot = Slot.PREVIOUS;
            nonce = keys == null ? null
                    : matching(keys, direction, ctx, adBytes, clearBytes, bodyBytes, cipherAt, plainLen, tagAt);
            if (nonce == null) {
                return new Packbin.TagMismatch();
            }
        }
        if (plainLen > 0) {
            System.arraycopy(bodyBytes, cipherAt, out, outOffset, plainLen);
            SessionPad.xor(keys.enc[direction], nonce, 0, out, outOffset, plainLen);
        }
        if (window != null) {
            window.commit(counter);
        }
        return new Opened(slot, clearLength, plainLen);
    }

    /** Overwrites the derived keys, the previous slot included (best effort, see the class note). Later calls are BadValue. */
    @Override
    public void close() {
        closed = true;
        current.wipe();
        clearPrevious();
    }

    /** The nonce when the slot's tag matches the received one, else null. */
    private byte[] matching(Keys keys, int direction, MsgContext ctx, byte[] ad, byte[] clear, byte[] body, int cipherAt,
            int cipherLen, int tagAt) {
        byte[] nonce = FrameCrypto.nonce(ctx.msgId, ctx.kind, direction, keys.epoch);
        byte[] full = tagOver(keys.mac[direction], nonce, ad, clear, body, cipherAt, cipherLen);
        return FrameCrypto.constantTimeEquals(full, 0, body, tagAt, tagLen) ? nonce : null;
    }

    private static byte[] tagOver(byte[] macKey, byte[] nonce, byte[] ad, byte[] clear, byte[] cipher, int cipherAt,
            int cipherLen) {
        Mac mac = FrameCrypto.mac(macKey);
        mac.update(nonce);
        mac.update((byte) ad.length);
        FrameCrypto.update(mac, ad);
        mac.update((byte) clear.length);
        FrameCrypto.update(mac, clear);
        mac.update(cipher, cipherAt, cipherLen);
        return mac.doFinal();
    }

    private Object callChecks(int direction, MsgContext ctx, byte[] ad) {
        if (closed || ctx == null || !ctx.valid() || direction < UP || direction > GROUP
                || (directions & (1 << direction)) == 0) {
            return new Packbin.BadValue("direction, kind or message id");
        }
        if (ad != null && ad.length > 255) {
            return new Packbin.TooLong(ad.length, 255);
        }
        return null;
    }

    private static byte[] orEmpty(byte[] bytes) {
        return bytes == null ? new byte[0] : bytes;
    }

    private static byte[] info(int direction, String usage) {
        byte[] text = usage.getBytes(StandardCharsets.US_ASCII);
        byte[] info = new byte[text.length + 1];
        info[0] = (byte) direction;
        System.arraycopy(text, 0, info, 1, text.length);
        return info;
    }

    /** Test access: the live encryption key of a slot and direction (null when not loaded), to see the wipe. */
    byte[] encKeyForTest(int direction, boolean previousSlot) {
        Keys keys = previousSlot ? previous : current;
        return keys == null ? null : keys.enc[direction];
    }

    /** Test access: the live MAC key (the 32-byte HMAC key the pads come from) of a slot and direction. */
    byte[] macKeyForTest(int direction, boolean previousSlot) {
        Keys keys = previousSlot ? previous : current;
        return keys == null ? null : keys.mac[direction];
    }

    /** Test-only: the number of HMAC computations the package started so far. */
    static long macComputationsForTest() {
        return FrameCrypto.macComputations();
    }
}

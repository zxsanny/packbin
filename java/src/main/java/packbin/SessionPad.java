package packbin;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.Arrays;

final class SessionPad {
    private static final byte[] INFO = "packbin".getBytes(StandardCharsets.US_ASCII);
    private static final int[] CONSTANTS = {
            0x61707865, 0x3320646e, 0x79622d32, 0x6b206574
    };

    private SessionPad() {}

    /** HKDF-SHA256 with the stream session's fixed info {@code "packbin"}. */
    static byte[] hkdfSha256(byte[] ikm, byte[] salt, int length) {
        return hkdfSha256(ikm, salt, INFO, length);
    }

    static byte[] hkdfSha256(byte[] ikm, byte[] salt, byte[] info, int length) {
        byte[] prk = hkdfExtract(salt, ikm);
        byte[] out = hkdfExpand(prk, info, length);
        Arrays.fill(prk, (byte) 0);
        return out;
    }

    /** RFC 5869 extract; an empty salt is the RFC's string of 32 zeros. */
    static byte[] hkdfExtract(byte[] salt, byte[] ikm) {
        byte[] key = salt.length == 0 ? new byte[32] : salt;
        Mac mac = hmac(key);
        return mac.doFinal(ikm);
    }

    /** RFC 5869 expand of {@code length} bytes (at most 255 blocks). */
    static byte[] hkdfExpand(byte[] prk, byte[] info, int length) {
        Mac mac = hmac(prk);
        byte[] out = new byte[length];
        byte[] block = new byte[0];
        int offset = 0;
        int counter = 1;
        while (offset < length) {
            mac.update(block);
            mac.update(info);
            mac.update((byte) counter);
            block = mac.doFinal();
            int n = Math.min(block.length, length - offset);
            System.arraycopy(block, 0, out, offset, n);
            offset += n;
            counter++;
        }
        Arrays.fill(block, (byte) 0);
        return out;
    }

    /**
     * An HMAC-SHA256 instance keyed with {@code key}. An empty key is the same MAC as one zero byte (HMAC pads the
     * key with zeros), and the platform refuses an empty key, so a single zero byte stands in for it.
     */
    static Mac hmac(byte[] key) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key.length == 0 ? new byte[1] : key, "HmacSHA256"));
            return mac;
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HMAC-SHA256 unavailable", e);
        }
    }

    static void xor(byte[] key, long packet, byte[] data) {
        byte[] nonce = new byte[12];
        writeU64Le(nonce, 0, packet);
        xor(key, nonce, 0, data);
    }

    static void xor(byte[] key, byte[] nonce, int counter, byte[] data) {
        xor(key, nonce, counter, data, 0, data.length);
    }

    /** ChaCha20 over {@code data[from, from + length)} in place, the first block using {@code counter}. */
    static void xor(byte[] key, byte[] nonce, int counter, byte[] data, int from, int length) {
        byte[] block = new byte[64];
        int offset = 0;
        int blockCounter = counter;
        while (offset < length) {
            block(key, nonce, blockCounter, block);
            int n = Math.min(64, length - offset);
            for (int i = 0; i < n; i++) {
                data[from + offset + i] ^= block[i];
            }
            offset += n;
            blockCounter++;
        }
        Arrays.fill(block, (byte) 0);
    }

    static void block(byte[] key, byte[] nonce, int counter, byte[] output) {
        int[] state = new int[16];
        state[0] = CONSTANTS[0];
        state[1] = CONSTANTS[1];
        state[2] = CONSTANTS[2];
        state[3] = CONSTANTS[3];
        for (int i = 0; i < 8; i++) {
            state[4 + i] = readU32Le(key, i * 4);
        }
        state[12] = counter;
        state[13] = readU32Le(nonce, 0);
        state[14] = readU32Le(nonce, 4);
        state[15] = readU32Le(nonce, 8);

        int[] work = Arrays.copyOf(state, 16);
        for (int i = 0; i < 10; i++) {
            quarter(work, 0, 4, 8, 12);
            quarter(work, 1, 5, 9, 13);
            quarter(work, 2, 6, 10, 14);
            quarter(work, 3, 7, 11, 15);
            quarter(work, 0, 5, 10, 15);
            quarter(work, 1, 6, 11, 12);
            quarter(work, 2, 7, 8, 13);
            quarter(work, 3, 4, 9, 14);
        }
        for (int i = 0; i < 16; i++) {
            writeU32Le(output, i * 4, work[i] + state[i]);
        }
    }

    private static void quarter(int[] w, int a, int b, int c, int d) {
        w[a] += w[b];
        w[d] = rot(w[d] ^ w[a], 16);
        w[c] += w[d];
        w[b] = rot(w[b] ^ w[c], 12);
        w[a] += w[b];
        w[d] = rot(w[d] ^ w[a], 8);
        w[c] += w[d];
        w[b] = rot(w[b] ^ w[c], 7);
    }

    private static int rot(int value, int bits) {
        return (value << bits) | (value >>> (32 - bits));
    }

    private static int readU32Le(byte[] buf, int offset) {
        return (buf[offset] & 0xFF)
                | ((buf[offset + 1] & 0xFF) << 8)
                | ((buf[offset + 2] & 0xFF) << 16)
                | ((buf[offset + 3] & 0xFF) << 24);
    }

    private static void writeU32Le(byte[] buf, int offset, int value) {
        buf[offset] = (byte) value;
        buf[offset + 1] = (byte) (value >>> 8);
        buf[offset + 2] = (byte) (value >>> 16);
        buf[offset + 3] = (byte) (value >>> 24);
    }

    private static void writeU64Le(byte[] buf, int offset, long value) {
        for (int i = 0; i < 8; i++) {
            buf[offset + i] = (byte) (value >>> (8 * i));
        }
    }
}

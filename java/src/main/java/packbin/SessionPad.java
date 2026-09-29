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

    static byte[] hkdfSha256(byte[] ikm, byte[] salt, int length) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(salt, "HmacSHA256"));
            byte[] prk = mac.doFinal(ikm);
            byte[] out = new byte[length];
            byte[] block = new byte[0];
            int offset = 0;
            int counter = 1;
            while (offset < length) {
                mac.init(new SecretKeySpec(prk, "HmacSHA256"));
                mac.update(block);
                mac.update(INFO);
                mac.update((byte) counter);
                block = mac.doFinal();
                int n = Math.min(block.length, length - offset);
                System.arraycopy(block, 0, out, offset, n);
                offset += n;
                counter++;
            }
            Arrays.fill(prk, (byte) 0);
            return out;
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HKDF-SHA256 unavailable", e);
        }
    }

    static void xor(byte[] key, long packet, byte[] data) {
        byte[] nonce = new byte[12];
        writeU64Le(nonce, 0, packet);
        xor(key, nonce, 0, data);
    }

    static void xor(byte[] key, byte[] nonce, int counter, byte[] data) {
        byte[] block = new byte[64];
        int offset = 0;
        int blockCounter = counter;
        while (offset < data.length) {
            block(key, nonce, blockCounter, block);
            int n = Math.min(64, data.length - offset);
            for (int i = 0; i < n; i++) {
                data[offset + i] ^= block[i];
            }
            offset += n;
            blockCounter++;
        }
        Arrays.fill(block, (byte) 0);
    }

    private static void block(byte[] key, byte[] nonce, int counter, byte[] output) {
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

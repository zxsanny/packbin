package packbin;

import java.util.BitSet;

/** Writes a compact payload bit by bit with the package's own canonical codes (TextModes.MODES[m].codes / bits). */
final class ProbeBits {
    private final BitSet bits = new BitSet();
    private int count;

    ProbeBits(int mode) {
        count = 3;
        for (int i = 2; i >= 0; i--) {
            raw(((mode >> i) & 1) != 0);
        }
    }

    int size() {
        return count;
    }

    void raw(boolean bit) {
        if (bit) {
            bits.set(count);
        }
        count++;
    }

    void symbol(TextModes.Mode mode, int symbol) {
        int code = mode.codes[symbol];
        for (int i = mode.bits[symbol] - 1; i >= 0; i--) {
            raw(((code >> i) & 1) != 0);
        }
    }

    void writeByte(int value) {
        for (int i = 7; i >= 0; i--) {
            raw(((value >> i) & 1) != 0);
        }
    }

    /** The payload: the pad written into the first 3 bits, the last byte filled with zero bits. */
    byte[] payload() {
        int pad = (8 - count % 8) % 8;
        byte[] out = new byte[(count + 7) / 8];
        for (int i = bits.nextSetBit(0); i >= 0; i = bits.nextSetBit(i + 1)) {
            out[i >> 3] |= (byte) (0x80 >> (i & 7));
        }
        out[0] = (byte) ((out[0] & 0x1f) | (pad << 5));
        return out;
    }

    byte[] field() {
        return field(payload());
    }

    static byte[] field(byte[] payload) {
        return AuditProbe.concat(AuditProbe.varint(payload.length), payload);
    }

    /** The SW symbol of mode {@code self} that leads to {@code target}. */
    static int switchSymbol(TextModes.Mode mode, int self, int target) {
        return mode.swBase + (self == 3 || target < self ? target : target - 1);
    }

    static int indexOf(int[] values, int value) {
        for (int i = 0; i < values.length; i++) {
            if (values[i] == value) {
                return i;
            }
        }
        return -1;
    }
}

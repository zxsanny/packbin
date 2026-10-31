package packbin;

import java.util.Arrays;
import java.util.Objects;

/**
 * Message error correction (contract message-ecc 1.0.0): a Reed-Solomon code over GF(256) with the field polynomial
 * 0x11D, alpha = 2 and generator roots alpha^0 .. alpha^(n-1). The code word is one byte longer than the sent bytes:
 * the clear length comes first, is covered by the code and is not sent; the parity follows the clear bytes.
 */
final class Ecc {
    static final int MAX_PARITY = 32;

    /** Sent bytes of one protected message; the code word is 255, one byte of it (the clear length) is not sent. */
    static final int MAX_BLOCK = 254;

    private static final int POLYNOMIAL = 0x11D;

    /** Doubled, so a sum of two logarithms indexes it without a modulo. */
    static final int[] EXP = new int[512];
    static final int[] LOG = new int[256];

    private static final int[][] GENERATORS = new int[MAX_PARITY + 1][];

    static {
        int x = 1;
        for (int i = 0; i < 255; i++) {
            EXP[i] = x;
            LOG[x] = i;
            x <<= 1;
            if ((x & 0x100) != 0) {
                x ^= POLYNOMIAL;
            }
        }
        for (int i = 255; i < EXP.length; i++) {
            EXP[i] = EXP[i - 255];
        }
        for (int n = 0; n <= MAX_PARITY; n++) {
            GENERATORS[n] = generator(n);
        }
    }

    private Ecc() {}

    static int mul(int a, int b) {
        return a == 0 || b == 0 ? 0 : EXP[LOG[a] + LOG[b]];
    }

    static int inverse(int a) {
        return EXP[255 - LOG[a]];
    }

    /** Monic, highest degree first. */
    private static int[] generator(int n) {
        int[] g = {1};
        for (int i = 0; i < n; i++) {
            int[] next = new int[g.length + 1];
            for (int j = 0; j < g.length; j++) {
                next[j] ^= g[j];
                next[j + 1] ^= mul(g[j], EXP[i]);
            }
            g = next;
        }
        return g;
    }

    static void checkParity(int n) {
        if (n < 0 || n > MAX_PARITY) {
            throw new IllegalArgumentException("parity must be 0 to " + MAX_PARITY + " bytes, got " + n);
        }
    }

    static void checkPercent(int p) {
        if (p < 0 || p > 100) {
            throw new IllegalArgumentException("parity percentage must be 0 to 100, got " + p);
        }
    }

    /** The parity count of a clear message of {@code length} bytes under percentage p: integer arithmetic only. */
    static int percentCount(int p, int length) {
        return Math.min(MAX_PARITY, (p * length + 99) / 100);
    }

    /** The largest clear length under percentage 1 to 100: the sent length stays within {@link #MAX_BLOCK}. */
    static int largestClear(int p) {
        int length = 0;
        while (length + 1 + percentCount(p, length + 1) <= MAX_BLOCK) {
            length++;
        }
        return length;
    }

    /** The one clear length whose protected message is {@code sent} bytes long under p (1 to 100), or -1. */
    static int clearLength(int p, int sent) {
        for (int length = 0; length <= Math.min(sent, MAX_BLOCK); length++) {
            if (length + percentCount(p, length) == sent) {
                return length;
            }
        }
        return -1;
    }

    /** The limit of a percentage scheme is 0 to 16 whatever the count; it is lowered to n / 2 once n is known. */
    static void checkPercentLimit(int t) {
        if (t < 0 || t > MAX_PARITY / 2) {
            throw new IllegalArgumentException("correction limit must be 0 to " + MAX_PARITY / 2 + ", got " + t);
        }
    }

    static void checkLimit(int t, int n) {
        if (t < 0 || t > n / 2) {
            throw new IllegalArgumentException(
                    "correction limit must be 0 to " + n / 2 + " for " + n + " parity bytes, got " + t);
        }
    }

    /** A clear message above 254 - n bytes is refused, naming its length and the limit. */
    static void checkSize(int length, int n) {
        if (n > 0 && length > MAX_BLOCK - n) {
            throw new IllegalArgumentException("the packet would be " + length + " bytes, above the limit of "
                    + (MAX_BLOCK - n) + " bytes for " + n + " parity bytes");
        }
    }

    /**
     * The scheme of the first handler, whose parity setting (a count or a percentage) every handler declares.
     * Handlers with different settings could not share one repair, so a mix is refused, naming both; the limit is
     * checked against the shared setting. Throws before any byte is read.
     */
    static Scheme<?> sharedSetting(Scheme.Handler<?>[] handlers, int limit) {
        Objects.requireNonNull(handlers, "handlers");
        Scheme<?> first = null;
        for (int i = 0; i < handlers.length; i++) {
            Scheme<?> declared = Objects.requireNonNull(handlers[i], "handler").scheme;
            if (i == 0) {
                first = declared;
            } else if (declared.parity != first.parity || declared.parityPercent != first.parityPercent) {
                if (first.parityPercent == 0 && declared.parityPercent == 0) {
                    throw new IllegalArgumentException("handlers declare " + first.parity + " and " + declared.parity
                            + " parity bytes; they must declare the same count");
                }
                throw new IllegalArgumentException("handlers declare " + describe(first) + " and " + describe(declared)
                        + "; they must declare the same count or percentage");
            }
        }
        if (first.parityPercent > 0) {
            checkPercentLimit(limit);
        } else {
            checkLimit(limit, first.parity);
        }
        return first;
    }

    private static String describe(Scheme<?> scheme) {
        return scheme.parityPercent > 0 ? scheme.parityPercent + " percent parity" : scheme.parity + " parity bytes";
    }

    /** The clear message followed by its parity under percentage p; the clear message itself when p is 0. */
    static byte[] protectPercent(byte[] clear, int p) {
        if (p == 0) {
            return clear;
        }
        int n = percentCount(p, clear.length);
        if (clear.length + n > MAX_BLOCK) {
            throw new IllegalArgumentException("the packet would be " + clear.length + " bytes, above the limit of "
                    + largestClear(p) + " bytes for a parity of " + p + " percent");
        }
        return protect(clear, n);
    }

    /** The clear message followed by its n parity bytes; the clear message itself when n is 0. */
    static byte[] protect(byte[] clear, int n) {
        if (n == 0) {
            return clear;
        }
        checkSize(clear.length, n);
        int[] g = GENERATORS[n];
        int[] rem = new int[clear.length + 1 + n];
        rem[0] = clear.length;
        for (int i = 0; i < clear.length; i++) {
            rem[i + 1] = clear[i] & 0xFF;
        }
        for (int i = 0; i <= clear.length; i++) {
            int c = rem[i];
            if (c == 0) {
                continue;
            }
            int lc = LOG[c];
            for (int j = 1; j <= n; j++) {
                if (g[j] != 0) {
                    rem[i + j] ^= EXP[LOG[g[j]] + lc];
                }
            }
        }
        byte[] out = Arrays.copyOf(clear, clear.length + n);
        for (int j = 0; j < n; j++) {
            out[clear.length + j] = (byte) rem[clear.length + 1 + j];
        }
        return out;
    }
}

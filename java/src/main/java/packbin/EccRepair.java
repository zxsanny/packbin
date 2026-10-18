package packbin;

import java.util.Arrays;

/** The check and the repair of a protected message (contract message-ecc 1.0.0); the encoder is {@link Ecc}. */
final class EccRepair {
    /** The clear bytes of a message that passed, and the number of wrong bytes repaired. */
    static final class Fixed {
        final byte[] clear;
        final int repaired;

        Fixed(byte[] clear, int repaired) {
            this.clear = clear;
            this.repaired = repaired;
        }
    }

    private static final Packbin.Uncorrectable UNCORRECTABLE = new Packbin.Uncorrectable();

    private EccRepair() {}

    /**
     * Checks {@code received} against n parity bytes and repairs up to t wrong bytes. Returns a {@link Fixed}, or the
     * error value: ShortPacket, TooLong or Uncorrectable. The input is never written and nothing throws on hostile
     * bytes; n and t are the caller's and are checked first.
     */
    static Object repair(byte[] received, int n, int t) {
        int size = received.length;
        if (size > Ecc.MAX_BLOCK) {
            return new Packbin.TooLong(size, Ecc.MAX_BLOCK);
        }
        if (size < n) {
            return new Packbin.ShortPacket("parity", n, size);
        }
        int[] synd = syndromes(received, n);
        if (allZero(synd)) {
            return new Fixed(Arrays.copyOf(received, size - n), 0);
        }
        if (t == 0) {
            return UNCORRECTABLE;
        }
        int[] lam = locator(synd, n);
        int degree = degree(lam);
        if (degree == 0 || degree > t) {
            return UNCORRECTABLE;
        }
        // Position p (0 = first byte sent) has locator X = alpha^(size-1-p); the unsent length byte is one place before it.
        int[] roots = new int[degree];
        int found = 0;
        for (int p = 0; p < size; p++) {
            if (evaluate(lam, degree, Ecc.EXP[(255 - (size - 1 - p)) % 255]) == 0) {
                if (found == degree) {
                    return UNCORRECTABLE;
                }
                roots[found++] = p;
            }
        }
        if (found != degree) {
            return UNCORRECTABLE;
        }
        // The error evaluator omega = (synd * lam) mod x^n, lowest degree first.
        int[] omega = new int[n];
        for (int i = 0; i < n; i++) {
            for (int j = 0; j <= degree && i + j < n; j++) {
                omega[i + j] ^= Ecc.mul(synd[i], lam[j]);
            }
        }
        // The derivative in characteristic 2 keeps the odd-degree terms.
        int[] dlam = new int[degree];
        for (int i = 1; i <= degree; i++) {
            dlam[i - 1] = i % 2 == 1 ? lam[i] : 0;
        }
        byte[] word = Arrays.copyOf(received, size);
        for (int p : roots) {
            int x = Ecc.EXP[(size - 1 - p) % 255];
            int xi = Ecc.inverse(x);
            int den = evaluate(dlam, dlam.length - 1, xi);
            if (den == 0) {
                return UNCORRECTABLE;
            }
            int value = Ecc.mul(x, Ecc.mul(evaluate(omega, n - 1, xi), Ecc.inverse(den)));
            word[p] ^= (byte) value;
        }
        if (!allZero(syndromes(word, n))) {
            return UNCORRECTABLE;
        }
        return new Fixed(Arrays.copyOf(word, size - n), degree);
    }

    /** The syndromes of the code word: the clear length (word length minus n), then the word. */
    private static int[] syndromes(byte[] word, int n) {
        int[] out = new int[n];
        int length = word.length - n;
        for (int i = 0; i < n; i++) {
            int s = length;
            for (byte b : word) {
                s = (s == 0 ? 0 : Ecc.EXP[Ecc.LOG[s] + i]) ^ (b & 0xFF);
            }
            out[i] = s;
        }
        return out;
    }

    private static boolean allZero(int[] values) {
        for (int v : values) {
            if (v != 0) {
                return false;
            }
        }
        return true;
    }

    /** {@code p} lowest degree first, terms 0 to {@code top}. */
    private static int evaluate(int[] p, int top, int x) {
        int y = 0;
        for (int i = top; i >= 0; i--) {
            y = Ecc.mul(y, x) ^ p[i];
        }
        return y;
    }

    private static int degree(int[] p) {
        int d = p.length - 1;
        while (d > 0 && p[d] == 0) {
            d--;
        }
        return d;
    }

    /** Berlekamp-Massey: the error locator, lowest degree first, n + 1 terms. */
    private static int[] locator(int[] synd, int n) {
        int[] lam = new int[n + 1];
        int[] prev = new int[n + 1];
        int[] before = new int[n + 1];
        lam[0] = 1;
        prev[0] = 1;
        int l = 0;
        int m = 1;
        int b = 1;
        for (int r = 0; r < n; r++) {
            int d = synd[r];
            for (int i = 1; i <= l; i++) {
                d ^= Ecc.mul(lam[i], synd[r - i]);
            }
            if (d == 0) {
                m++;
                continue;
            }
            System.arraycopy(lam, 0, before, 0, n + 1);
            int coef = Ecc.mul(d, Ecc.inverse(b));
            for (int i = 0; i + m <= n; i++) {
                lam[i + m] ^= Ecc.mul(coef, prev[i]);
            }
            if (2 * l <= r) {
                l = r + 1 - l;
                System.arraycopy(before, 0, prev, 0, n + 1);
                b = d;
                m = 1;
            } else {
                m++;
            }
        }
        return lam;
    }
}

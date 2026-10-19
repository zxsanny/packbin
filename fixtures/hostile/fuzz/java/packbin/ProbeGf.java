package packbin;

import java.util.HashSet;
import java.util.Random;
import java.util.Set;

/**
 * An independent GF(256) Reed-Solomon reference (polynomial 0x11D, alpha = 2), written from message-ecc.md and not
 * shared with the package: it builds hostile inputs (any first symbol, errors at the unsent length byte) and checks the
 * package's repaired words. Part of the AZ-2666 probes (see AuditProbe).
 */
final class ProbeGf {
    static final int[] EXP = new int[512];
    static final int[] LOG = new int[256];

    static {
        int x = 1;
        for (int i = 0; i < 255; i++) {
            EXP[i] = x;
            LOG[x] = i;
            x <<= 1;
            if ((x & 0x100) != 0) {
                x ^= 0x11D;
            }
        }
        for (int i = 255; i < 512; i++) {
            EXP[i] = EXP[i - 255];
        }
    }

    private ProbeGf() {}

    static int mul(int a, int b) {
        return a == 0 || b == 0 ? 0 : EXP[LOG[a] + LOG[b]];
    }

    static int[] generator(int n) {
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

    /** The sent bytes of a code word whose unsent first symbol is {@code first}. */
    static byte[] encode(int first, byte[] clear, int n) {
        int[] g = generator(n);
        int[] rem = new int[1 + clear.length + n];
        rem[0] = first;
        for (int i = 0; i < clear.length; i++) {
            rem[i + 1] = clear[i] & 0xff;
        }
        for (int i = 0; i <= clear.length; i++) {
            int c = rem[i];
            if (c == 0) {
                continue;
            }
            for (int j = 1; j <= n; j++) {
                rem[i + j] ^= mul(g[j], c);
            }
        }
        byte[] sent = new byte[clear.length + n];
        System.arraycopy(clear, 0, sent, 0, clear.length);
        for (int j = 0; j < n; j++) {
            sent[clear.length + j] = (byte) rem[clear.length + 1 + j];
        }
        return sent;
    }

    static byte[] protect(byte[] clear, int n) {
        return encode(clear.length, clear, n);
    }

    static boolean valid(byte[] word, int n) {
        for (int i = 0; i < n; i++) {
            int s = word.length - n;
            for (byte b : word) {
                s = (s == 0 ? 0 : EXP[LOG[s] + i]) ^ (b & 0xff);
            }
            if (s != 0) {
                return false;
            }
        }
        return true;
    }

    static void corrupt(byte[] word, int count, Random r) {
        Set<Integer> picked = new HashSet<>();
        count = Math.min(count, word.length);
        while (picked.size() < count) {
            picked.add(r.nextInt(word.length));
        }
        for (int p : picked) {
            word[p] ^= (byte) (1 + r.nextInt(255));
        }
    }
}

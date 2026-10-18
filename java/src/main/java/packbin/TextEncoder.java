package packbin;

import static packbin.TextModes.CODABLE;
import static packbin.TextModes.INF;
import static packbin.TextModes.MAX_TEXT;
import static packbin.TextModes.MODES;
import static packbin.TextModes.RAW_PREFIX;
import static packbin.TextModes.SHORTEST_CODE;
import static packbin.TextModes.SHORTEST_ESC;
import static packbin.TextModes.STATES;
import static packbin.TextModes.TABLE_SPAN;
import static packbin.TextModes.utf8Length;

import packbin.TextModes.Mode;

/** The encoder of the compact text format: the optimal parse of the contract, then the raw escape when it is not smaller. */
final class TextEncoder {
    private TextEncoder() {}

    /** The field bytes (count, then payload) of a text given as the UTF-8 bytes the package already produces. */
    static byte[] encode(byte[] utf8) {
        if (utf8.length == 0) {
            return new byte[] {0};
        }
        if (utf8.length > MAX_TEXT) {
            throw new IllegalArgumentException("text longer than " + MAX_TEXT + " UTF-8 bytes");
        }
        if (cannotBeatRaw(utf8)) {
            return rawField(utf8);
        }
        Parse parse = new Parse(utf8);
        int size = (6 + parse.total + 7) / 8;
        if (size >= 1 + utf8.length) {
            return rawField(utf8);
        }
        int head = varintLength(size);
        byte[] out = new byte[head + size];
        putVarint(out, size);
        parse.write(out, head, size);
        return out;
    }

    /**
     * A lower bound on the compact size: a character no table can code costs at least its ESC and bytes, any other at
     * least the shortest code. When even that is not smaller than the raw payload, the parse cannot win.
     */
    private static boolean cannotBeatRaw(byte[] utf8) {
        long bits = 6;
        int i = 0;
        while (i < utf8.length) {
            int b = utf8[i] & 0xff;
            int cp;
            int len;
            if (b < 0x80) {
                cp = b;
                len = 1;
            } else if (b < 0xe0) {
                cp = ((b & 0x1f) << 6) | (utf8[i + 1] & 0x3f);
                len = 2;
            } else if (b < 0xf0) {
                cp = 0x800;
                len = 3;
            } else {
                cp = 0x10000;
                len = 4;
            }
            i += len;
            bits += cp < TABLE_SPAN && CODABLE[cp] ? SHORTEST_CODE : SHORTEST_ESC + 8 * len;
        }
        return (bits + 7) / 8 >= 1 + (long) utf8.length;
    }

    private static byte[] rawField(byte[] utf8) {
        int size = 1 + utf8.length;
        int head = varintLength(size);
        byte[] out = new byte[head + size];
        putVarint(out, size);
        out[head] = RAW_PREFIX;
        System.arraycopy(utf8, 0, out, head + 1, utf8.length);
        return out;
    }

    private static int varintLength(int n) {
        return n < 0x80 ? 1 : n < 0x4000 ? 2 : 3;
    }

    private static void putVarint(byte[] out, int n) {
        int i = 0;
        while (n >= 0x80) {
            out[i++] = (byte) (n | 0x80);
            n >>>= 7;
        }
        out[i] = (byte) n;
    }

    /** The optimal parse: cheapest finish cost per (position, mode, lock), ties to the smallest first symbol. */
    private static final class Parse {
        final int[] cps;
        final int[] cost;
        final int start;
        final int total;
        private int edges;
        private final int[] first = new int[4];
        private final int[] second = new int[4];
        private final int[] cost4 = new int[4];

        Parse(byte[] utf8) {
            cps = codePoints(utf8);
            int n = cps.length;
            cost = new int[(n + 1) * STATES];
            for (int i = n - 1; i >= 0; i--) {
                solve(i);
            }
            int best = 0;
            for (int m = 1; m < 4; m++) {
                if (cost[m * 2] < cost[best * 2]) {
                    best = m;
                }
            }
            start = best;
            total = cost[best * 2];
        }

        private static int[] codePoints(byte[] utf8) {
            int[] out = new int[utf8.length];
            int n = 0;
            int i = 0;
            while (i < utf8.length) {
                int b = utf8[i] & 0xff;
                int cp;
                if (b < 0x80) {
                    cp = b;
                    i += 1;
                } else if (b < 0xe0) {
                    cp = ((b & 0x1f) << 6) | (utf8[i + 1] & 0x3f);
                    i += 2;
                } else if (b < 0xf0) {
                    cp = ((b & 0x0f) << 12) | ((utf8[i + 1] & 0x3f) << 6) | (utf8[i + 2] & 0x3f);
                    i += 3;
                } else {
                    cp = ((b & 0x07) << 18) | ((utf8[i + 1] & 0x3f) << 12) | ((utf8[i + 2] & 0x3f) << 6)
                            | (utf8[i + 3] & 0x3f);
                    i += 4;
                }
                out[n++] = cp;
            }
            int[] exact = new int[n];
            System.arraycopy(out, 0, exact, 0, n);
            return exact;
        }

        /** Fills {@code first}, {@code second}, {@code cost4} with the edges that consume {@code c}; returns the count. */
        private int emissions(int m, int k, int c) {
            Mode mode = MODES[m];
            edges = 0;
            if (c < TABLE_SPAN) {
                int at = mode.letterAt[c];
                if (at != 0 && (mode.upper[at - 1] == 0 || k == 0)) {
                    add(at - 1, -1, mode.bits[at - 1]);
                }
                at = mode.capitalAt[c];
                if (at != 0) {
                    if (k == 1) {
                        add(at - 1, -1, mode.bits[at - 1]);
                    } else {
                        add(mode.cap, at - 1, mode.bits[mode.cap] + mode.bits[at - 1]);
                    }
                }
                at = mode.sharedAt[c];
                if (at != 0) {
                    int sym = mode.sharedBase + at - 1;
                    add(sym, -1, mode.bits[sym]);
                }
            }
            add(mode.esc, -1, mode.bits[mode.esc] + 8 * utf8Length(c));
            return edges;
        }

        private void add(int firstSymbol, int secondSymbol, int bits) {
            first[edges] = firstSymbol;
            second[edges] = secondSymbol;
            cost4[edges] = bits;
            edges++;
        }

        private void solve(int i) {
            int c = cps[i];
            int here = i * STATES;
            int next = here + STATES;
            for (int s = 0; s < STATES; s++) {
                int n = emissions(s >> 1, s & 1, c);
                int best = INF;
                for (int e = 0; e < n; e++) {
                    best = Math.min(best, cost4[e] + cost[next + s]);
                }
                cost[here + s] = best;
            }
            boolean changed = true;
            while (changed) {
                changed = false;
                for (int s = 0; s < STATES; s++) {
                    Mode mode = MODES[s >> 1];
                    for (int t = 0; t < 4; t++) {
                        if (t != (s >> 1) && relax(here, s, t * 2 + (s & 1), switchSymbol(s >> 1, t), mode)) {
                            changed = true;
                        }
                    }
                    if (mode.lock >= 0 && relax(here, s, s ^ 1, mode.lock, mode)) {
                        changed = true;
                    }
                }
            }
        }

        private boolean relax(int here, int from, int to, int symbol, Mode mode) {
            int v = mode.bits[symbol] + cost[here + to];
            if (v < cost[here + from]) {
                cost[here + from] = v;
                return true;
            }
            return false;
        }

        private static int switchSymbol(int m, int target) {
            return MODES[m].swBase + (m == 3 || target < m ? target : target - 1);
        }

        /** Walks the winning parse and writes the payload: pad and start mode, then the codes. */
        void write(byte[] out, int base, int size) {
            Bits sink = new Bits(out, base);
            int pad = 8 * size - 6 - total;
            sink.put(pad, 3);
            sink.put(start, 3);
            int state = start * 2;
            int i = 0;
            int n = cps.length;
            while (i < n) {
                int m = state >> 1;
                int k = state & 1;
                Mode mode = MODES[m];
                int want = cost[i * STATES + state];
                int bestFirst = Integer.MAX_VALUE;
                int bestKind = 0;
                int bestArg = 0;
                for (int t = 0; t < 4; t++) {
                    if (t == m) {
                        continue;
                    }
                    int sym = switchSymbol(m, t);
                    if (sym < bestFirst && mode.bits[sym] + cost[i * STATES + t * 2 + k] == want) {
                        bestFirst = sym;
                        bestKind = 1;
                        bestArg = t * 2 + k;
                    }
                }
                if (mode.lock >= 0 && mode.lock < bestFirst
                        && mode.bits[mode.lock] + cost[i * STATES + (state ^ 1)] == want) {
                    bestFirst = mode.lock;
                    bestKind = 1;
                    bestArg = state ^ 1;
                }
                int n4 = emissions(m, k, cps[i]);
                for (int e = 0; e < n4; e++) {
                    if (first[e] < bestFirst && cost4[e] + cost[(i + 1) * STATES + state] == want) {
                        bestFirst = first[e];
                        bestKind = 2;
                        bestArg = e;
                    }
                }
                if (bestKind == 0) {
                    throw new IllegalStateException("no optimal edge");
                }
                sink.put(mode.codes[bestFirst], mode.bits[bestFirst]);
                if (bestKind == 1) {
                    state = bestArg;
                    continue;
                }
                if (second[bestArg] >= 0) {
                    sink.put(mode.codes[second[bestArg]], mode.bits[second[bestArg]]);
                } else if (bestFirst == mode.esc) {
                    putUtf8(sink, cps[i]);
                }
                i++;
            }
        }

        private static void putUtf8(Bits sink, int cp) {
            if (cp < 0x80) {
                sink.put(cp, 8);
            } else if (cp < 0x800) {
                sink.put(0xc0 | (cp >> 6), 8);
                sink.put(0x80 | (cp & 0x3f), 8);
            } else if (cp < 0x10000) {
                sink.put(0xe0 | (cp >> 12), 8);
                sink.put(0x80 | ((cp >> 6) & 0x3f), 8);
                sink.put(0x80 | (cp & 0x3f), 8);
            } else {
                sink.put(0xf0 | (cp >> 18), 8);
                sink.put(0x80 | ((cp >> 12) & 0x3f), 8);
                sink.put(0x80 | ((cp >> 6) & 0x3f), 8);
                sink.put(0x80 | (cp & 0x3f), 8);
            }
        }
    }

    /** Most significant bit first, into a zeroed array. */
    private static final class Bits {
        private final byte[] out;
        private final int base;
        private int pos;

        Bits(byte[] out, int base) {
            this.out = out;
            this.base = base;
        }

        void put(int value, int count) {
            for (int b = count - 1; b >= 0; b--) {
                if (((value >> b) & 1) != 0) {
                    out[base + (pos >> 3)] |= (byte) (0x80 >> (pos & 7));
                }
                pos++;
            }
        }
    }
}

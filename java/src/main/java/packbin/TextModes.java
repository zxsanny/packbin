package packbin;

/**
 * The compact text format of every string (contract compact-text 1.0.0): a LEB128 count, then a payload that is either
 * Huffman-coded symbols in one of four modes or the raw UTF-8 escape ({@code 0x10} then the text).
 */
final class TextModes {
    static final int MAX_TEXT = 65535;
    static final int MAX_CODE = 16;
    static final int RAW_PREFIX = 0x10;
    static final int INF = 1 << 29;
    static final int STATES = 8;
    static final int TABLE_SPAN = 0x530;

    /** One mode: its code lengths and codes by symbol index, and the canonical decoding arrays. */
    static final class Mode {
        final int[] letters;
        final int[] upper;
        final int[] shared;
        final int sharedBase;
        final int swBase;
        final int cap;
        final int lock;
        final int esc;
        final int[] bits;
        final int[] codes;
        final int[] firstCode = new int[MAX_CODE + 2];
        final int[] firstSlot = new int[MAX_CODE + 2];
        final int[] countOf = new int[MAX_CODE + 2];
        final int[] bySlot;
        final byte[] letterAt = new byte[TABLE_SPAN];
        final byte[] capitalAt = new byte[TABLE_SPAN];
        final byte[] sharedAt = new byte[TABLE_SPAN];

        Mode(int[] letters, int[] upper, int[] shared, int[] lengths, boolean text) {
            this.letters = letters;
            this.upper = upper;
            this.shared = shared;
            sharedBase = letters.length;
            swBase = sharedBase + shared.length;
            cap = text ? swBase + 3 : -1;
            lock = text ? swBase + 4 : -1;
            esc = text ? swBase + 5 : swBase + 3;
            if (lengths.length != esc + 1) {
                throw new IllegalStateException("text table has " + lengths.length + " lengths");
            }
            bits = lengths;
            codes = new int[lengths.length];
            bySlot = new int[lengths.length];
            build();
            for (int i = 0; i < letters.length; i++) {
                if (letters[i] < TABLE_SPAN) {
                    letterAt[letters[i]] = (byte) (i + 1);
                }
                if (upper[i] != 0 && upper[i] < TABLE_SPAN) {
                    capitalAt[upper[i]] = (byte) (i + 1);
                }
            }
            for (int i = 0; i < shared.length; i++) {
                if (shared[i] < TABLE_SPAN) {
                    sharedAt[shared[i]] = (byte) (i + 1);
                }
            }
        }

        /** Canonical Huffman: symbols by (length, index); each code is the previous plus 1, shifted by the growth. */
        private void build() {
            int slot = 0;
            int code = 0;
            int prev = 0;
            for (int len = 1; len <= MAX_CODE; len++) {
                firstSlot[len] = slot;
                for (int sym = 0; sym < bits.length; sym++) {
                    if (bits[sym] != len) {
                        continue;
                    }
                    if (countOf[len] == 0) {
                        code <<= len - prev;
                        prev = len;
                        firstCode[len] = code;
                    }
                    codes[sym] = code++;
                    bySlot[slot++] = sym;
                    countOf[len]++;
                }
            }
        }

        /** The mode a SW symbol of this table leads to. */
        int switchTarget(int sym, int self) {
            int j = sym - swBase;
            return self == 3 || j < self ? j : j + 1;
        }
    }

    static final Mode[] MODES = {
        new Mode(TextTables.UA, TextTables.UA_UPPER, TextTables.SHARED, TextTables.LENGTHS_UA, true),
        new Mode(TextTables.RU, TextTables.RU_UPPER, TextTables.SHARED, TextTables.LENGTHS_RU, true),
        new Mode(TextTables.EN, TextTables.EN_UPPER, TextTables.SHARED, TextTables.LENGTHS_EN, true),
        new Mode(new int[0], new int[0], TextTables.NUMSET, TextTables.LENGTHS_NUM, false),
    };

    static final boolean[] CODABLE = new boolean[TABLE_SPAN];
    static final int SHORTEST_CODE;
    static final int SHORTEST_ESC;

    static {
        int code = MAX_CODE;
        int esc = Integer.MAX_VALUE;
        for (Mode mode : MODES) {
            for (int len : mode.bits) {
                code = Math.min(code, len);
            }
            esc = Math.min(esc, mode.bits[mode.esc]);
            for (int c = 0; c < TABLE_SPAN; c++) {
                if (mode.letterAt[c] != 0 || mode.capitalAt[c] != 0 || mode.sharedAt[c] != 0) {
                    CODABLE[c] = true;
                }
            }
        }
        SHORTEST_CODE = code;
        SHORTEST_ESC = esc;
    }

    private TextModes() {}

    static int utf8Length(int cp) {
        return cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4;
    }
}

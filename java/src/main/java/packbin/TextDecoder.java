package packbin;

import static packbin.TextModes.MAX_TEXT;
import static packbin.TextModes.MODES;
import static packbin.TextModes.RAW_PREFIX;
import static packbin.TextModes.utf8Length;

import packbin.TextModes.Mode;

/** The decoder of the compact text format: accepts every stream the rules allow; its work is bounded by the payload. */
final class TextDecoder {
    private static final int MAX_CODE = TextModes.MAX_CODE;

    private TextDecoder() {}

    /**
     * Reads one string at {@code cur.pos}. Returns the text and moves {@code cur.pos} past it, or a
     * {@link Packbin.ShortPacket} naming {@code label} when the buffer is short or the payload is refused.
     */
    static Object read(String label, byte[] data, Cursor cur) {
        int at = cur.pos;
        int count = 0;
        for (int k = 0; k < 3; k++) {
            if (at + k >= data.length) {
                return new Packbin.ShortPacket(label, k + 1, data.length - cur.pos);
            }
            int b = data[at + k] & 0xff;
            count |= (b & 0x7f) << (7 * k);
            if ((b & 0x80) == 0) {
                if (k > 0 && b == 0) {
                    return refused(label, count);
                }
                at += k + 1;
                break;
            }
            if (k == 2) {
                return refused(label, count);
            }
        }
        if (count == 0) {
            cur.pos = at;
            return "";
        }
        int left = data.length - at;
        if (left < count) {
            return new Packbin.ShortPacket(label, count, left);
        }
        String text = decodePayload(data, at, count);
        if (text == null) {
            return refused(label, count);
        }
        cur.pos = at + count;
        return text;
    }

    private static Packbin.ShortPacket refused(String label, int count) {
        return new Packbin.ShortPacket(label, count, 0);
    }

    /** The text of one payload, or null when the payload is refused. */
    private static String decodePayload(byte[] data, int from, int count) {
        int first = data[from] & 0xff;
        int startMode = (first >> 2) & 7;
        if (startMode == 4) {
            if (first != RAW_PREFIX || count - 1 > MAX_TEXT) {
                return null;
            }
            return count == 1 ? "" : VarFields.decodeUtf8(data, from + 1, count - 1);
        }
        if (startMode > 4) {
            return null;
        }
        int pad = first >> 5;
        int total = 8 * count - pad;
        if (total < 6 || (data[from + count - 1] & ((1 << pad) - 1)) != 0) {
            return null;
        }
        StringBuilder out = new StringBuilder();
        int size = 0;
        int pos = 6;
        int mode = startMode;
        boolean lock = false;
        boolean pending = false;
        while (pos < total) {
            Mode table = MODES[mode];
            int code = 0;
            int len = 0;
            int sym = -1;
            while (len < MAX_CODE) {
                if (pos + len >= total) {
                    return null;
                }
                int p = pos + len;
                code = (code << 1) | ((data[from + (p >> 3)] >> (7 - (p & 7))) & 1);
                len++;
                int into = code - table.firstCode[len];
                if (table.countOf[len] > 0 && into >= 0 && into < table.countOf[len]) {
                    sym = table.bySlot[table.firstSlot[len] + into];
                    break;
                }
            }
            if (sym < 0) {
                return null;
            }
            pos += len;
            int cp;
            if (sym < table.sharedBase) {
                cp = table.letters[sym];
                int up = table.upper[sym];
                if (pending) {
                    if (up == 0) {
                        return null;
                    }
                    cp = up;
                    pending = false;
                } else if (lock && up != 0) {
                    cp = up;
                }
            } else if (sym < table.swBase) {
                if (pending) {
                    return null;
                }
                cp = table.shared[sym - table.sharedBase];
            } else if (sym < table.swBase + 3) {
                if (pending) {
                    return null;
                }
                mode = table.switchTarget(sym, mode);
                continue;
            } else if (sym == table.cap) {
                if (lock || pending) {
                    return null;
                }
                pending = true;
                continue;
            } else if (sym == table.lock) {
                if (pending) {
                    return null;
                }
                lock = !lock;
                continue;
            } else {
                if (pending) {
                    return null;
                }
                cp = readEscaped(data, from, pos, total);
                if (cp < 0) {
                    return null;
                }
                pos += 8 * utf8Length(cp);
            }
            size += utf8Length(cp);
            if (size > MAX_TEXT) {
                return null;
            }
            out.appendCodePoint(cp);
        }
        return pending ? null : out.toString();
    }

    private static int byteAt(byte[] data, int from, int pos) {
        int shift = pos & 7;
        int index = from + (pos >> 3);
        int high = (data[index] & 0xff) << shift;
        if (shift == 0) {
            return high & 0xff;
        }
        return (high | ((data[index + 1] & 0xff) >> (8 - shift))) & 0xff;
    }

    /** One scalar of 1 to 4 UTF-8 bytes at bit {@code pos}, 8 bits each; -1 when cut short or not valid UTF-8. */
    private static int readEscaped(byte[] data, int from, int pos, int total) {
        if (pos + 8 > total) {
            return -1;
        }
        int b0 = byteAt(data, from, pos);
        int n = b0 < 0x80 ? 1 : (b0 >> 5) == 6 ? 2 : (b0 >> 4) == 14 ? 3 : (b0 >> 3) == 30 ? 4 : 0;
        if (n == 0 || pos + 8 * n > total) {
            return -1;
        }
        int cp = n == 1 ? b0 : n == 2 ? b0 & 0x1f : n == 3 ? b0 & 0x0f : b0 & 0x07;
        for (int j = 1; j < n; j++) {
            int b = byteAt(data, from, pos + 8 * j);
            if ((b & 0xc0) != 0x80) {
                return -1;
            }
            cp = (cp << 6) | (b & 0x3f);
        }
        boolean overlong = cp < (n == 2 ? 0x80 : n == 3 ? 0x800 : n == 4 ? 0x10000 : 0);
        if (overlong || (cp >= 0xd800 && cp <= 0xdfff) || cp > 0x10ffff) {
            return -1;
        }
        return cp;
    }
}

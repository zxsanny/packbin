package packbin;

/**
 * The replay window of frame mode: the highest counter a sender's frames reached and which of the 64 counters up to it
 * were committed. The caller owns one per sender and passes the counter with each open; counters are unsigned 64-bit
 * values held in a {@code long}. Not thread-safe: a caller that opens frames of one sender on several threads
 * synchronizes on the window.
 *
 * <p>The counter must come from bytes the tag covers (the message id or the associated data), never from an
 * unauthenticated field of the wire: it is an argument of open and not part of the tag, so a captured frame replayed
 * under a counter the attacker chooses would open and could move the window. A window serves one sender and one key
 * lifetime; a frame that opens under the previous key commits into the same window.
 */
public final class ReplayWindow {
    /** What the window says about a counter. */
    public enum Freshness { FRESH, DUPLICATE, TOO_OLD }

    private long top;
    private long bits;

    /** An empty window: every counter is fresh. */
    public ReplayWindow() {}

    /**
     * A window restored from stored values. {@code bits == 0} is an empty window whatever {@code top} is, so replay
     * protection is off until the next commit; a caller that restores a window checks that bit 0 is set when
     * {@code bits} is not 0.
     */
    public static ReplayWindow fromParts(long top, long bits) {
        ReplayWindow window = new ReplayWindow();
        window.top = top;
        window.bits = bits;
        return window;
    }

    public long top() {
        return top;
    }

    public long bits() {
        return bits;
    }

    /** What the window says about {@code counter}. Never changes the state. */
    public Freshness check(long counter) {
        if (bits == 0 || Long.compareUnsigned(counter, top) > 0) {
            return Freshness.FRESH;
        }
        long behind = top - counter;
        if (Long.compareUnsigned(behind, 64) >= 0) {
            return Freshness.TOO_OLD;
        }
        return ((bits >>> behind) & 1L) == 1L ? Freshness.DUPLICATE : Freshness.FRESH;
    }

    /** Records {@code counter}; a counter 64 or more behind the highest is ignored. {@code open} calls this only after Ok. */
    public void commit(long counter) {
        if (bits == 0) {
            top = counter;
            bits = 1;
        } else if (Long.compareUnsigned(counter, top) > 0) {
            long shift = counter - top;
            bits = (Long.compareUnsigned(shift, 64) >= 0 ? 0L : bits << shift) | 1L;
            top = counter;
        } else {
            long behind = top - counter;
            if (Long.compareUnsigned(behind, 64) < 0) {
                bits |= 1L << behind;
            }
        }
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof ReplayWindow w && w.top == top && w.bits == bits;
    }

    @Override
    public int hashCode() {
        return Long.hashCode(top) * 31 + Long.hashCode(bits);
    }

    @Override
    public String toString() {
        return Long.toHexString(top) + ":" + Long.toHexString(bits);
    }
}

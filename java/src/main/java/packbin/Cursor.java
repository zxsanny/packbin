package packbin;

/**
 * The state of one unpack call: the read position and the slots its rounds have created so far, shared by every
 * field of the call (rows, list and dict elements included), checked against the limits of the scheme.
 */
final class Cursor {
    int pos;
    private final int maxRounds;
    private final long maxSlots;
    private long slots;

    Cursor(int pos, int maxRounds, long maxSlots) {
        this.pos = pos;
        this.maxRounds = maxRounds;
        this.maxSlots = maxSlots;
    }

    /** Takes the slots of one round that is about to start; false when it would pass either limit. */
    boolean startRound(long roundsStarted, int roundSlots) {
        if (roundsStarted >= maxRounds || roundSlots > maxSlots - slots) {
            return false;
        }
        slots += roundSlots;
        return true;
    }
}

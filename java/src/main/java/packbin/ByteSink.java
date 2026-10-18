package packbin;

import java.nio.ByteBuffer;
import java.util.List;

/**
 * The output of one pack call and the limits of its scheme: the most rounds a {@code times} or {@code repeat} may
 * write, the most slots all rounds of the call may hold, and the most bytes the packet may have (type byte
 * included). A write that would pass the byte limit is refused before it is made, naming the member written.
 */
final class ByteSink {
    /** The largest array a JVM reliably allocates; the packet cannot grow past it whatever {@code maxBytes} says. */
    static final int MAX_ARRAY = Integer.MAX_VALUE - 8;

    final int maxRounds;
    private final long maxSlots;
    private final long maxBytes;
    private long slots;
    private byte[] buf = new byte[32];
    private int size;

    ByteSink(int maxRounds, long maxSlots, long maxBytes) {
        this.maxRounds = maxRounds;
        this.maxSlots = maxSlots;
        this.maxBytes = maxBytes;
    }

    void write(Field member, byte b) {
        ensure(member, 1);
        buf[size++] = b;
    }

    void write(Field member, byte[] src) {
        ensure(member, src.length);
        System.arraycopy(src, 0, buf, size, src.length);
        size += src.length;
    }

    void write(Field member, ByteBuffer src) {
        int n = src.remaining();
        ensure(member, n);
        src.get(buf, size, n);
        size += n;
    }

    /** A text or a dictionary key, as the compact text format writes it: a count, then the payload, as one append. */
    void writeText(Field member, byte[] utf8) {
        write(member, TextEncoder.encode(utf8));
    }

    /** The 2-byte count of a list or dict. */
    void writeCount(Field member, int count) {
        ensure(member, 2);
        buf[size++] = (byte) count;
        buf[size++] = (byte) (count >> 8);
    }

    /**
     * Takes the slots of one round that is about to start, before any byte of it is written; refuses the round
     * when the slots of all rounds of this call would pass the limit. {@code width} is {@link Rounds#width}, the
     * slots unpack charges for the same round.
     */
    void startRound(Field round, List<Field> values, int width) {
        if (width > maxSlots - slots) {
            throw new IllegalArgumentException(Rounds.roundName(round, values) + ": the rounds would hold " + (slots + width)
                    + " slots, above the limit of " + maxSlots + " slots");
        }
        slots += width;
    }

    int size() {
        return size;
    }

    void set(int index, byte b) {
        buf[index] = b;
    }

    byte[] toArray() {
        byte[] out = new byte[size];
        System.arraycopy(buf, 0, out, 0, size);
        return out;
    }

    void ensure(Field member, long extra) {
        long needed = size + extra;
        if (needed > maxBytes) {
            throw new IllegalArgumentException(Rounds.nameOf(member) + ": the packet would be " + needed
                    + " bytes, above the limit of " + maxBytes + " bytes");
        }
        if (needed <= buf.length) {
            return;
        }
        int next = grown(buf.length, needed, Math.min(maxBytes, MAX_ARRAY));
        if (next < 0) {
            throw new IllegalArgumentException(Rounds.nameOf(member) + ": the packet would be " + needed
                    + " bytes, above the largest array of " + MAX_ARRAY + " bytes");
        }
        byte[] grownBuf = new byte[next];
        System.arraycopy(buf, 0, grownBuf, 0, size);
        buf = grownBuf;
    }

    /**
     * The length of the buffer after growing it for {@code needed} bytes: double, but never past {@code cap} (the
     * budget or the array limit), in long arithmetic so a buffer near 2^30 does not overflow. -1 when {@code needed}
     * is above the array limit.
     */
    static int grown(int length, long needed, long cap) {
        if (needed > MAX_ARRAY) {
            return -1;
        }
        long next = Math.max(length * 2L, needed);
        return (int) Math.min(next, Math.max(cap, needed));
    }
}

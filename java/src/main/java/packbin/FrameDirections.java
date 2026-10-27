package packbin;

import java.util.StringJoiner;

/**
 * The directions a frame session is loaded for: an immutable set of {@link FrameDirection}, as {@code FrameDirections} in
 * the other packages. {@link #ALL} holds the three; {@link #of} makes any other set. A session derives keys only for the
 * directions of its set, and a call in another direction is {@link Packbin.BadValue}.
 */
public final class FrameDirections {
    /** Up, down and group. */
    public static final FrameDirections ALL = new FrameDirections(bit(FrameDirection.UP) | bit(FrameDirection.DOWN)
            | bit(FrameDirection.GROUP));

    private final int mask;

    private FrameDirections(int mask) {
        this.mask = mask;
    }

    /**
     * The set of {@code directions}; a direction listed twice counts once, and no direction gives the empty set (a session
     * loaded with it refuses every call). Returns null for a null list or a null direction, so that a session loaded with it
     * is refused too; it never throws.
     */
    public static FrameDirections of(FrameDirection... directions) {
        if (directions == null) {
            return null;
        }
        int mask = 0;
        for (FrameDirection direction : directions) {
            if (direction == null) {
                return null;
            }
            mask |= bit(direction);
        }
        return new FrameDirections(mask);
    }

    /** Whether {@code direction} is in the set; false for null. */
    public boolean contains(FrameDirection direction) {
        return direction != null && (mask & bit(direction)) != 0;
    }

    /** Whether the set holds no direction. */
    public boolean isEmpty() {
        return mask == 0;
    }

    private static int bit(FrameDirection direction) {
        return 1 << direction.wire;
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof FrameDirections d && d.mask == mask;
    }

    @Override
    public int hashCode() {
        return mask;
    }

    /** The directions in wire order, as {@code [UP, GROUP]}. */
    @Override
    public String toString() {
        StringJoiner names = new StringJoiner(", ", "[", "]");
        for (FrameDirection direction : FrameDirection.values()) {
            if (contains(direction)) {
                names.add(direction.name());
            }
        }
        return names.toString();
    }
}

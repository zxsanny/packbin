package packbin;

/**
 * The direction of a frame (contract {@code pack-session.md} 2.0.0, frame mode): the byte {@code d} of the key schedule
 * and of the nonce, 1 for up, 2 for down and 3 for group. A session seals and opens only in the {@link FrameDirections}
 * of its {@link FrameConfig}; another direction, or null, is {@link Packbin.BadValue}.
 */
public enum FrameDirection {
    UP(1),
    DOWN(2),
    GROUP(3);

    /** The direction byte {@code d}: 1, 2 or 3. */
    final int wire;

    FrameDirection(int wire) {
        this.wire = wire;
    }
}

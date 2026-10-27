package packbin;

/** What {@link FrameSession#seal} returns for a sealed frame: the body is {@code out[offset, offset + length)}. */
public final class FrameSealed {
    public final int length;

    FrameSealed(int length) {
        this.length = length;
    }
}

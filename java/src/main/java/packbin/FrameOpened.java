package packbin;

/** What {@link FrameSession#open} returns for a frame that opened. */
public final class FrameOpened {
    public final FrameSlot slot;
    public final int clearLength;
    public final int plainLength;

    FrameOpened(FrameSlot slot, int clearLength, int plainLength) {
        this.slot = slot;
        this.clearLength = clearLength;
        this.plainLength = plainLength;
    }
}

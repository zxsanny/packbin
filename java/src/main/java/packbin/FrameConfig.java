package packbin;

/**
 * What a frame session is loaded with besides the key and the epoch, as {@code FrameConfig} in the other packages: the tag
 * length ({@code tagLength}, 4, 8 or 16 bytes, fixed for the lifetime of the key: one tag length per key and epoch across
 * all devices) and the {@link FrameDirections} the session seals and opens in. The constructor never throws:
 * {@link FrameSession#load} returns null for a tag length other than 4, 8 or 16 and for a null set.
 */
public final class FrameConfig {
    public final int tagLength;
    public final FrameDirections directions;

    public FrameConfig(int tagLength, FrameDirections directions) {
        this.tagLength = tagLength;
        this.directions = directions;
    }
}

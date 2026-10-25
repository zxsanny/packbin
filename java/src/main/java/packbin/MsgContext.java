package packbin;

/**
 * What the caller supplies per frame besides the buffers: the 8-byte {@code msgId} and the 4-bit {@code kind}.
 *
 * <p><b>For one (key, epoch, direction), a {@code msgId} is never sealed twice with different contents.</b> Reuse
 * breaks the confidentiality of both messages, and the library cannot check it. A new epoch derives new keys and
 * nonces. (meshbell builds the id from the source, the id field and the creation wave, so it is unique by
 * construction.)
 *
 * <p>The constructor never throws: a {@code msgId} that is not 8 bytes or a {@code kind} outside 0 to 15 is refused
 * by {@code seal} and {@code open} as {@link Packbin.BadValue}. The id is copied.
 */
public final class MsgContext {
    final byte[] msgId;
    final int kind;

    public MsgContext(byte[] msgId, int kind) {
        this.msgId = msgId == null ? null : msgId.clone();
        this.kind = kind;
    }

    boolean valid() {
        return msgId != null && msgId.length == 8 && kind >= 0 && kind <= 15;
    }
}

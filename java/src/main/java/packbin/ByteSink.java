package packbin;

import java.nio.ByteBuffer;

final class ByteSink {
    private byte[] buf = new byte[32];
    private int size;

    void write(byte b) {
        ensure(1);
        buf[size++] = b;
    }

    void write(byte[] src) {
        ensure(src.length);
        System.arraycopy(src, 0, buf, size, src.length);
        size += src.length;
    }

    void write(ByteBuffer src) {
        int n = src.remaining();
        ensure(n);
        src.get(buf, size, n);
        size += n;
    }

    byte[] toArray() {
        byte[] out = new byte[size];
        System.arraycopy(buf, 0, out, 0, size);
        return out;
    }

    private void ensure(int extra) {
        if (size + extra <= buf.length) {
            return;
        }
        int next = Math.max(buf.length * 2, size + extra);
        byte[] grown = new byte[next];
        System.arraycopy(buf, 0, grown, 0, size);
        buf = grown;
    }
}

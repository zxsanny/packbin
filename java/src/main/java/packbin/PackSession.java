package packbin;

import java.security.SecureRandom;
import java.util.Arrays;
import java.util.concurrent.atomic.AtomicLong;

public final class PackSession {
    public static final int SEED_SIZE = 32;
    public static final int NONCE_SIZE = 16;

    private byte[] seed;
    private byte[] send;
    private byte[] recv;
    private final AtomicLong sendCount = new AtomicLong();
    private long recvCount;

    private PackSession(byte[] seed) {
        this.seed = seed;
    }

    public static PackSession load(byte[] seed) {
        if (seed == null || seed.length != SEED_SIZE) {
            return null;
        }
        return new PackSession(Arrays.copyOf(seed, seed.length));
    }

    public byte[] start() {
        if (send != null || seed == null) {
            return null;
        }
        byte[] nonce = new byte[NONCE_SIZE];
        new SecureRandom().nextBytes(nonce);
        return start(nonce);
    }

    public byte[] start(byte[] nonce) {
        if (!open(nonce, true)) {
            return null;
        }
        return Arrays.copyOf(nonce, nonce.length);
    }

    public boolean join(byte[] nonce) {
        return open(nonce, false);
    }

    public <T> byte[] pack(Scheme<T> scheme, T value) {
        if (send == null) {
            return null;
        }
        byte[] clear = BinaryPacker.pack(scheme, value);
        SessionPad.xor(send, sendCount.getAndIncrement(), clear);
        return clear;
    }

    public Object unpack(byte[] bytes, Scheme.Handler<?>... handlers) {
        if (recv == null) {
            return new Packbin.ShortPacket("", 1, 0);
        }
        byte[] clear = Arrays.copyOf(bytes, bytes.length);
        SessionPad.xor(recv, recvCount, clear);
        recvCount++;
        return BinaryPacker.unpack(clear, handlers);
    }

    private boolean open(byte[] nonce, boolean initiator) {
        if (seed == null || send != null || nonce == null || nonce.length != NONCE_SIZE) {
            return false;
        }
        byte[] both = SessionPad.hkdfSha256(seed, nonce, SEED_SIZE * 2);
        byte[] first = Arrays.copyOfRange(both, 0, SEED_SIZE);
        byte[] second = Arrays.copyOfRange(both, SEED_SIZE, SEED_SIZE * 2);
        send = initiator ? first : second;
        recv = initiator ? second : first;
        Arrays.fill(both, (byte) 0);
        Arrays.fill(seed, (byte) 0);
        seed = null;
        return true;
    }
}

package packbin;

import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Map;
import java.util.Objects;
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
        byte[] clear = BinaryPacker.packClear(scheme, value);
        Ecc.checkSize(clear.length, scheme.parity);
        SessionPad.xor(send, sendCount.getAndIncrement(), clear);
        // The code covers the padded bytes, so the receiver repairs before it removes the pad.
        return Ecc.protect(clear, scheme.parity);
    }

    public Object unpack(byte[] bytes, Scheme.Handler<?>... handlers) {
        Object result = unpackRepair(bytes, 0, handlers);
        return result instanceof Packbin.Repaired ? null : result;
    }

    /**
     * As {@link BinaryPacker#unpackRepair}: the payload is repaired (up to {@code limit} wrong bytes) before the pad
     * is removed. The receive index advances for every payload read, a refused one included; a limit or a mix of
     * handlers that is refused with an exception reads nothing.
     */
    public Object unpackRepair(byte[] bytes, int limit, Scheme.Handler<?>... handlers) {
        if (recv == null) {
            return new Packbin.ShortPacket("", 1, 0);
        }
        Objects.requireNonNull(bytes, "bytes");
        Map<Integer, Scheme.Handler<?>> byType = BinaryPacker.byType(handlers);
        int parity = Ecc.sharedParity(handlers, limit);
        long index = recvCount++;
        byte[] clear;
        int repaired = 0;
        if (parity == 0) {
            clear = Arrays.copyOf(bytes, bytes.length);
        } else {
            Object checked = EccRepair.repair(bytes, parity, limit);
            if (!(checked instanceof EccRepair.Fixed)) {
                return checked;
            }
            clear = ((EccRepair.Fixed) checked).clear;
            repaired = ((EccRepair.Fixed) checked).repaired;
        }
        SessionPad.xor(recv, index, clear);
        Object err = BinaryPacker.unpackClear(clear, byType);
        return err != null ? err : new Packbin.Repaired(repaired);
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

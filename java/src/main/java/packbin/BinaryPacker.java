package packbin;

import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

public final class BinaryPacker {
    private BinaryPacker() {}

    public static <T> byte[] pack(Scheme<T> scheme, T row) {
        return Ecc.protect(packClear(scheme, row), scheme.parity);
    }

    /** The packed fields without parity: what an unprotected scheme writes. */
    static <T> byte[] packClear(Scheme<T> scheme, T row) {
        Objects.requireNonNull(scheme, "scheme");
        Objects.requireNonNull(row, "row");
        ByteSink sink = new ByteSink(scheme.maxRounds, scheme.maxSlots, scheme.maxBytes);
        sink.write(null, (byte) scheme.typeNumber);
        Walker.packFields(scheme.fields, row, sink, new HashMap<>(), null);
        return sink.toArray();
    }

    /** Detect only: a protected message with any wrong byte is refused as {@link Packbin.Uncorrectable}. Null when it unpacks. */
    public static Object unpack(byte[] data, Scheme.Handler<?>... handlers) {
        Object result = unpackRepair(data, 0, handlers);
        return result instanceof Packbin.Repaired ? null : result;
    }

    /**
     * Repairs up to {@code limit} wrong bytes (0 to parity / 2) before the type byte picks the handler. All handlers
     * declare the same parity; a mix, or a limit out of range, is refused with an IllegalArgumentException before any
     * byte is read. Returns a {@link Packbin.Repaired} when the message unpacks (0 when it was intact or unprotected),
     * and the error value otherwise.
     */
    public static Object unpackRepair(byte[] data, int limit, Scheme.Handler<?>... handlers) {
        Objects.requireNonNull(data, "data");
        Map<Integer, Scheme.Handler<?>> byType = byType(handlers);
        int parity = Ecc.sharedParity(handlers, limit);
        int repaired = 0;
        byte[] clear = data;
        if (parity > 0) {
            Object checked = EccRepair.repair(data, parity, limit);
            if (!(checked instanceof EccRepair.Fixed)) {
                return checked;
            }
            clear = ((EccRepair.Fixed) checked).clear;
            repaired = ((EccRepair.Fixed) checked).repaired;
        }
        Object err = unpackClear(clear, byType);
        return err != null ? err : new Packbin.Repaired(repaired);
    }

    /**
     * The handlers by type number; an empty list or two handlers of one number are refused, before the parity counts
     * and the limit are checked and before a receive index advances.
     */
    static Map<Integer, Scheme.Handler<?>> byType(Scheme.Handler<?>[] handlers) {
        Objects.requireNonNull(handlers, "handlers");
        if (handlers.length == 0) {
            throw new IllegalArgumentException("unpack needs at least one handler");
        }
        Map<Integer, Scheme.Handler<?>> byType = new HashMap<>();
        for (Scheme.Handler<?> handler : handlers) {
            Objects.requireNonNull(handler, "handler");
            int typeNumber = handler.scheme.typeNumber;
            if (byType.put(typeNumber, handler) != null) {
                throw new IllegalArgumentException("duplicate type number " + typeNumber);
            }
        }
        return byType;
    }

    /** The unprotected walk: the type byte picks the handler. Null when the bytes unpack. */
    static Object unpackClear(byte[] data, Map<Integer, Scheme.Handler<?>> byType) {
        if (data.length < 1) {
            return new Packbin.ShortPacket("", 1, 0);
        }
        int actual = data[0] & 0xFF;
        Scheme.Handler<?> matched = byType.get(actual);
        if (matched == null) {
            return new Packbin.TypeMismatch(-1, actual);
        }
        return dispatch(matched, data);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static Object dispatch(Scheme.Handler<?> matched, byte[] data) {
        Packbin.Bound bound = decode(matched.scheme, data);
        if (!bound.ok) {
            return bound.error;
        }
        ((Scheme.Handler) matched).handler.accept(bound.value);
        return null;
    }

    private static <T> Packbin.Bound<T> decode(Scheme<T> scheme, byte[] data) {
        Objects.requireNonNull(scheme, "scheme");
        Objects.requireNonNull(data, "data");
        if (data.length < 1) {
            return Packbin.Bound.fail(new Packbin.ShortPacket("", 1, 0));
        }
        int actual = data[0] & 0xFF;
        if (actual != scheme.typeNumber) {
            return Packbin.Bound.fail(new Packbin.TypeMismatch(scheme.typeNumber, actual));
        }
        T row = newRow(scheme.type);
        Cursor cur = new Cursor(1, scheme.maxRounds, scheme.maxSlots);
        Object err = Walker.unpackFields(scheme.fields, data, cur, row, new HashMap<>(), false);
        if (err != null) {
            return Packbin.Bound.fail(err);
        }
        int left = data.length - cur.pos;
        if (left > 0) {
            return Packbin.Bound.fail(new Packbin.TrailingBytes(left));
        }
        return Packbin.Bound.ok(row);
    }

    private static <T> T newRow(Class<T> type) {
        if (type == Map.class || Map.class.isAssignableFrom(type)) {
            @SuppressWarnings("unchecked")
            T map = (T) new HashMap<String, Object>();
            return map;
        }
        try {
            var ctor = type.getDeclaredConstructor();
            ctor.setAccessible(true);
            return ctor.newInstance();
        } catch (ReflectiveOperationException ex) {
            throw new IllegalStateException("Cannot create " + type.getName(), ex);
        }
    }
}

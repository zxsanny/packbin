package packbin;

import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

public final class Unpack {
    private Unpack() {}

    public static <T> Packbin.Bound<T> run(Scheme<T> scheme, byte[] data) {
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
        int[] offset = {1};
        Object err = Walker.unpackFields(scheme.fields, data, offset, row, new HashMap<>(), false);
        if (err != null) {
            return Packbin.Bound.fail(err);
        }
        int left = data.length - offset[0];
        if (left > 0) {
            return Packbin.Bound.fail(new Packbin.TrailingBytes(left));
        }
        return Packbin.Bound.ok(row);
    }

    public static Object run(byte[] data, Scheme.Handler<?>... handlers) {
        Objects.requireNonNull(data, "data");
        Objects.requireNonNull(handlers, "handlers");
        Map<Integer, Scheme.Handler<?>> byType = new HashMap<>();
        for (Scheme.Handler<?> handler : handlers) {
            Objects.requireNonNull(handler, "handler");
            int typeNumber = handler.scheme.typeNumber;
            if (byType.put(typeNumber, handler) != null) {
                throw new IllegalArgumentException("duplicate type number " + typeNumber);
            }
        }
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
        Packbin.Bound bound = run(matched.scheme, data);
        if (!bound.ok) {
            return bound.error;
        }
        ((Scheme.Handler) matched).handler.accept(bound.value);
        return null;
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

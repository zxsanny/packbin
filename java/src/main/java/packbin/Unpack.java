package packbin;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;

public final class Unpack {
    private Unpack() {}

    public static <T> Packbin.Bound<T> run(Scheme<T> scheme, byte[] data) {
        Packbin.UnpackResult raw = values(scheme, data);
        if (!raw.ok) {
            return Packbin.Bound.fail(raw.error);
        }
        return Packbin.Bound.ok(ObjectValues.write(scheme.type, raw.value));
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

    public static Packbin.UnpackResult values(Scheme<?> scheme, byte[] data) {
        Objects.requireNonNull(scheme, "scheme");
        Objects.requireNonNull(data, "data");
        if (data.length < 1) {
            return Packbin.UnpackResult.fail(new Packbin.ShortPacket("", 1, 0));
        }
        int actual = data[0] & 0xFF;
        if (actual != scheme.typeNumber) {
            return Packbin.UnpackResult.fail(new Packbin.TypeMismatch(scheme.typeNumber, actual));
        }
        LinkedHashMap<String, Object> out = new LinkedHashMap<>();
        int[] offset = {1};
        for (Field field : scheme.fields) {
            Object err = Walker.unpackField(field, data, offset, out, false);
            if (err != null) {
                return Packbin.UnpackResult.fail(err);
            }
        }
        int left = data.length - offset[0];
        if (left > 0) {
            return Packbin.UnpackResult.fail(new Packbin.TrailingBytes(left));
        }
        return Packbin.UnpackResult.ok(out);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static Object dispatch(Scheme.Handler<?> matched, byte[] data) {
        Packbin.UnpackResult raw = values(matched.scheme, data);
        if (!raw.ok) {
            return raw.error;
        }
        Object row = ObjectValues.write(matched.scheme.type, raw.value);
        ((Scheme.Handler) matched).handler.accept(row);
        return null;
    }
}

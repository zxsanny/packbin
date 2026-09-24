package packbin;

import java.util.Map;
import java.util.function.BiConsumer;
import java.util.function.Function;

public final class Access {
    private Access() {}

    public static Getter get(String key) {
        return row -> {
            if (row instanceof Map<?, ?> map) {
                return map.get(key);
            }
            throw new IllegalArgumentException("expected map");
        };
    }

    public static Setter set(String key) {
        return (row, value) -> {
            if (row instanceof Map<?, ?> map) {
                @SuppressWarnings("unchecked")
                Map<Object, Object> out = (Map<Object, Object>) map;
                out.put(key, value);
                return;
            }
            throw new IllegalArgumentException("expected map");
        };
    }

    public static Getter identity() {
        return row -> row;
    }

    public static Setter ignore() {
        return (row, value) -> {};
    }

    public static <T> Getter get(Function<T, ?> fn) {
        return row -> fn.apply(cast(row));
    }

    public static <T> Setter set(BiConsumer<T, Object> fn) {
        return (row, value) -> fn.accept(cast(row), value);
    }

    @SuppressWarnings("unchecked")
    private static <T> T cast(Object row) {
        return (T) row;
    }
}

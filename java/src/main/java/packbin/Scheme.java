package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.function.Consumer;

public final class Scheme<T> {
    final int typeNumber;
    final Class<T> type;
    final List<Field> fields;

    @SafeVarargs
    public Scheme(int typeNumber, Class<T> type, Field... fields) {
        if (typeNumber < 0 || typeNumber > 255) {
            throw new IllegalArgumentException("type number must be 0..255");
        }
        this.typeNumber = typeNumber;
        this.type = Objects.requireNonNull(type, "type");
        this.fields = List.copyOf(Arrays.asList(Objects.requireNonNull(fields, "fields")));
        SchemeOrder.validate(this.fields);
    }

    public Handler<T> on(Consumer<T> handler) {
        return new Handler<>(this, Objects.requireNonNull(handler, "handler"));
    }

    public static final class Handler<T> {
        final Scheme<T> scheme;
        final Consumer<T> handler;

        Handler(Scheme<T> scheme, Consumer<T> handler) {
            this.scheme = scheme;
            this.handler = handler;
        }
    }
}

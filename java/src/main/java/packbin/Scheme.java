package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Consumer;

public final class Scheme<T> {
    public static final int DEFAULT_MAX_ROUNDS = 65_535;
    public static final long DEFAULT_MAX_SLOTS = 4_194_304L;

    final int typeNumber;
    final Class<T> type;
    final List<Field> fields;
    final int maxRounds;
    final long maxSlots;

    @SafeVarargs
    public Scheme(int typeNumber, Class<T> type, Field... fields) {
        if (typeNumber < 0 || typeNumber > 255) {
            throw new IllegalArgumentException("type number must be 0..255");
        }
        this.typeNumber = typeNumber;
        this.type = Objects.requireNonNull(type, "type");
        this.fields = Field.immutableCopy(Arrays.asList(Objects.requireNonNull(fields, "fields")));
        SchemeOrder.validate(this.fields, !Map.class.isAssignableFrom(type));
        this.maxRounds = DEFAULT_MAX_ROUNDS;
        this.maxSlots = DEFAULT_MAX_SLOTS;
    }

    private Scheme(Scheme<T> base, int maxRounds, long maxSlots) {
        if (maxRounds < 1) {
            throw new IllegalArgumentException("maxRounds must be at least 1");
        }
        if (maxSlots < 1) {
            throw new IllegalArgumentException("maxSlots must be at least 1");
        }
        this.typeNumber = base.typeNumber;
        this.type = base.type;
        this.fields = base.fields;
        this.maxRounds = maxRounds;
        this.maxSlots = maxSlots;
    }

    public int maxRounds() {
        return maxRounds;
    }

    public long maxSlots() {
        return maxSlots;
    }

    /**
     * The most rounds one repeat or times field may start, and the most slots all rounds of one unpack may create;
     * a packet past either is refused. Returns a new scheme; this one is unchanged.
     */
    public Scheme<T> withLimits(int maxRounds, long maxSlots) {
        return new Scheme<>(this, maxRounds, maxSlots);
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

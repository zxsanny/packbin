package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Consumer;

public final class Scheme<T> {
    public static final int DEFAULT_MAX_ROUNDS = 65_535;
    public static final long DEFAULT_MAX_SLOTS = 4_194_304L;
    public static final long DEFAULT_MAX_BYTES = 16_777_216L;

    final int typeNumber;
    final Class<T> type;
    final List<Field> fields;
    final int maxRounds;
    final long maxSlots;
    final long maxBytes;

    @SafeVarargs
    public Scheme(int typeNumber, Class<T> type, Field... fields) {
        if (typeNumber < 0 || typeNumber > 255) {
            throw new IllegalArgumentException("type number must be 0..255");
        }
        this.typeNumber = typeNumber;
        this.type = Objects.requireNonNull(type, "type");
        List<Field> declared = Field.immutableCopy(Arrays.asList(Objects.requireNonNull(fields, "fields")));
        SchemeOrder.validate(declared, !Map.class.isAssignableFrom(type));
        this.fields = Field.immutableCopy(SchemeOrder.bindFlagBits(declared));
        this.maxRounds = DEFAULT_MAX_ROUNDS;
        this.maxSlots = DEFAULT_MAX_SLOTS;
        this.maxBytes = DEFAULT_MAX_BYTES;
        MemberNames.validate(this.fields);
    }

    private Scheme(Scheme<T> base, int maxRounds, long maxSlots, long maxBytes) {
        if (maxRounds < 1) {
            throw new IllegalArgumentException("maxRounds must be at least 1");
        }
        if (maxSlots < 1) {
            throw new IllegalArgumentException("maxSlots must be at least 1");
        }
        if (maxBytes < 1) {
            throw new IllegalArgumentException("maxBytes must be at least 1");
        }
        this.typeNumber = base.typeNumber;
        this.type = base.type;
        this.fields = base.fields;
        this.maxRounds = maxRounds;
        this.maxSlots = maxSlots;
        this.maxBytes = maxBytes;
    }

    public int maxRounds() {
        return maxRounds;
    }

    public long maxSlots() {
        return maxSlots;
    }

    /** The most bytes one packed packet may have, type byte included; pack only. */
    public long maxBytes() {
        return maxBytes;
    }

    /**
     * The most rounds one repeat or times field may start, and the most slots all rounds of one pack or unpack call
     * may create; a packet past either is refused. A limit left out takes its default: the result has the default
     * {@link #DEFAULT_MAX_BYTES}, not this scheme's maxBytes. Returns a new scheme; this one is unchanged.
     */
    public Scheme<T> withLimits(int maxRounds, long maxSlots) {
        return new Scheme<>(this, maxRounds, maxSlots, DEFAULT_MAX_BYTES);
    }

    /**
     * The most bytes one pack call may write, type byte included; a call that would pass it is refused before the
     * write. Keeps this scheme's other limits. Returns a new scheme; this one is unchanged.
     */
    public Scheme<T> withMaxBytes(long maxBytes) {
        return new Scheme<>(this, maxRounds, maxSlots, maxBytes);
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

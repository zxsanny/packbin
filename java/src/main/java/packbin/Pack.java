package packbin;

import java.util.HashMap;
import java.util.Objects;

public final class Pack {
    private Pack() {}

    public static <T> byte[] run(Scheme<T> scheme, T row) {
        Objects.requireNonNull(scheme, "scheme");
        Objects.requireNonNull(row, "row");
        ByteSink sink = new ByteSink();
        sink.write((byte) scheme.typeNumber);
        Walker.packFields(scheme.fields, row, sink, new HashMap<>(), null);
        return sink.toArray();
    }
}

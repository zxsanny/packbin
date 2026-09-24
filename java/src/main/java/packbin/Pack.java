package packbin;

import java.util.Map;
import java.util.Objects;

public final class Pack {
    private Pack() {}

    public static byte[] run(Scheme<?> scheme, Map<String, Object> values) {
        Objects.requireNonNull(scheme, "scheme");
        Map<String, Object> map = values == null ? Map.of() : values;
        ByteSink sink = new ByteSink();
        sink.write((byte) scheme.typeNumber);
        for (Field field : scheme.fields) {
            Walker.packField(field, map, sink);
        }
        return sink.toArray();
    }

    public static byte[] run(Scheme<?> scheme, Object values) {
        if (values instanceof Map<?, ?> map) {
            return run(scheme, ObjectValues.asMap(map));
        }
        return run(scheme, ObjectValues.read(values));
    }
}

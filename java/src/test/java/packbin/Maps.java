package packbin;

import java.util.HashMap;
import java.util.Map;

@SuppressWarnings({"unchecked", "rawtypes"})
final class Maps {
    private Maps() {}

    static Scheme<Map> scheme(int typeNumber, Field... fields) {
        return new Scheme<>(typeNumber, (Class) Map.class, fields);
    }

    static Map<String, Object> map(Object... kv) {
        Map<String, Object> out = new HashMap<>();
        for (int i = 0; i < kv.length; i += 2) {
            out.put((String) kv[i], kv[i + 1]);
        }
        return out;
    }
}

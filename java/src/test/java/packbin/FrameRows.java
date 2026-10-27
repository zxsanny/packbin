package packbin;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Runs one row of fixtures/frame/vectors.txt through the public frame API and returns its output fields. */
final class FrameRows {
    private FrameRows() {}

    private static int integer(Map<String, String> row, String name) {
        return Integer.parseInt(row.get(name));
    }

    private static FrameDirection[] directions(Map<String, String> row) {
        String dirs = row.getOrDefault("dirs", "123");
        FrameDirection[] out = new FrameDirection[dirs.length()];
        for (int i = 0; i < out.length; i++) {
            out[i] = FrameSupport.direction(dirs.charAt(i) - '0');
        }
        return out;
    }

    private static FrameDirection dir(Map<String, String> row) {
        return FrameSupport.direction(integer(row, "dir"));
    }

    private static FrameSession load(Map<String, String> row) {
        return FrameSession.load(FrameSupport.hex(row.get("key")), integer(row, "epoch"), integer(row, "tag_len"),
                directions(row));
    }

    private static MsgContext ctx(Map<String, String> row) {
        return new MsgContext(FrameSupport.hex(row.get("msg_id")), integer(row, "kind"));
    }

    static Map<String, String> keys(Map<String, String> row) {
        Map<String, String> out = new HashMap<>();
        byte[] key = FrameSupport.hex(row.get("key"));
        int epoch = integer(row, "epoch");
        if (row.containsKey("label")) {
            try (MacKey mac = MacKey.derive(key, epoch, FrameSupport.hex(row.get("label")))) {
                out.put("k_label", FrameSupport.unhex(mac.keyForTest()));
            }
            return out;
        }
        FrameDirection dir = dir(row);
        try (FrameSession session = FrameSession.load(key, epoch, 4, FrameDirection.values())) {
            out.put("k_enc", FrameSupport.unhex(session.encKeyForTest(dir, false)));
            out.put("k_mac", FrameSupport.unhex(session.macKeyForTest(dir, false)));
        }
        return out;
    }

    static Map<String, String> seal(Map<String, String> row) {
        Map<String, String> out = new HashMap<>();
        FrameSession session = load(row);
        if (session == null) {
            out.put("result", "BadValue");
            return out;
        }
        try (FrameSession s = session) {
            byte[] buf = FrameSupport.filled(row.containsKey("out_len") ? integer(row, "out_len") : 300);
            Object result = s.seal(dir(row), ctx(row), FrameSupport.hex(row.get("ad")),
                    FrameSupport.hex(row.get("clear")), FrameSupport.hex(row.get("plain")), buf);
            if (result instanceof FrameSealed sealed) {
                out.put("body", FrameSupport.unhex(java.util.Arrays.copyOf(buf, sealed.length)));
                byte[] rest = java.util.Arrays.copyOfRange(buf, sealed.length, buf.length);
                if (!FrameSupport.allSentinel(rest)) {
                    out.put("result", "wrote past the body");
                }
            } else {
                out.put("result", FrameSupport.kind(result));
                if (!FrameSupport.allSentinel(buf)) {
                    out.put("result", "refused seal wrote bytes");
                }
            }
        }
        return out;
    }

    static Map<String, String> open(Map<String, String> row) {
        Map<String, String> out = new HashMap<>();
        ReplayWindow window = null;
        if (row.containsKey("window")) {
            String[] parts = row.get("window").split(":");
            window = ReplayWindow.fromParts(Long.parseUnsignedLong(parts[0], 16), Long.parseUnsignedLong(parts[1], 16));
        }
        ReplayWindow before = window == null ? null : ReplayWindow.fromParts(window.top(), window.bits());
        Object result = openRow(row, window, out);
        if (window != null) {
            if (!(result instanceof FrameOpened) && !window.equals(before)) {
                out.put("result", "a failed open changed the window");
            }
            out.put("window_after", window.toString());
        }
        return out;
    }

    private static Object openRow(Map<String, String> row, ReplayWindow window, Map<String, String> out) {
        FrameSession session = load(row);
        if (session == null) {
            out.put("result", "BadValue");
            return new Packbin.BadValue("load");
        }
        try (FrameSession s = session) {
            if (row.containsKey("prev_key")
                    && !s.setPrevious(FrameSupport.hex(row.get("prev_key")), integer(row, "prev_epoch"))) {
                out.put("result", "BadValue");
                return new Packbin.BadValue("previous");
            }
            byte[] buf = FrameSupport.filled(row.containsKey("out_len") ? integer(row, "out_len") : 300);
            boolean replay = window != null && row.containsKey("counter");
            long counter = replay ? Long.parseUnsignedLong(row.get("counter")) : 0;
            Object result = s.open(dir(row), ctx(row), FrameSupport.hex(row.get("ad")),
                    FrameSupport.hex(row.get("body")), integer(row, "clear_len"), replay ? window : null, counter, buf);
            out.put("result", FrameSupport.kind(result));
            if (result instanceof FrameOpened opened) {
                out.put("slot", opened.slot == FrameSlot.CURRENT ? "current" : "previous");
                out.put("plain", FrameSupport.unhex(java.util.Arrays.copyOf(buf, opened.plainLength)));
                byte[] rest = java.util.Arrays.copyOfRange(buf, opened.plainLength, buf.length);
                if (!FrameSupport.allSentinel(rest)) {
                    out.put("result", "wrote past the plaintext");
                }
            } else if (!FrameSupport.allSentinel(buf)) {
                out.put("result", "refused open wrote bytes");
            }
            return result;
        }
    }

    static Map<String, String> mac(Map<String, String> row) {
        Map<String, String> out = new HashMap<>();
        MacKey key = MacKey.derive(FrameSupport.hex(row.get("key")), integer(row, "epoch"), FrameSupport.hex(row.get("label")));
        if (key == null) {
            out.put("result", "BadValue");
            return out;
        }
        List<byte[]> parts = new ArrayList<>();
        if (row.containsKey("parts")) {
            for (String piece : row.get("parts").split("\\|", -1)) {
                parts.add(FrameSupport.hex(piece));
            }
        } else {
            parts.add(FrameSupport.hex(row.get("message")));
        }
        byte[][] array = parts.toArray(new byte[0][]);
        try (MacKey k = key) {
            if (row.containsKey("verify")) {
                out.put("valid", Boolean.toString(k.verify(FrameSupport.hex(row.get("verify")), array)));
            } else {
                byte[] tag = new byte[integer(row, "n")];
                Object result = k.tag(tag, array);
                out.put(result == null ? "tag" : "result", result == null ? FrameSupport.unhex(tag) : FrameSupport.kind(result));
            }
        }
        return out;
    }

    static Map<String, String> replay(Map<String, String> row) {
        ReplayWindow window = new ReplayWindow();
        List<String> results = new ArrayList<>();
        List<String> states = new ArrayList<>();
        for (String step : row.get("steps").split(",")) {
            String[] parts = step.split(":");
            long n = Long.parseUnsignedLong(parts[1]);
            if (parts[0].equals("check")) {
                switch (window.check(n)) {
                    case FRESH -> results.add("Fresh");
                    case DUPLICATE -> results.add("Duplicate");
                    default -> results.add("TooOld");
                }
            } else {
                window.commit(n);
                states.add(window.toString());
            }
        }
        Map<String, String> out = new HashMap<>();
        out.put("results", String.join(",", results));
        out.put("states", states.isEmpty() ? "-" : String.join(",", states));
        return out;
    }
}

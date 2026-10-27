package packbin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Helpers shared by the frame-mode and primitive test classes: fixture lookup, row parsing, hex, result names. */
final class FrameSupport {
    static final byte SENTINEL = (byte) 0xA5;

    private FrameSupport() {}

    /** The fixture file, found from the working directory upwards (tests run from the repository root). */
    static Path fixture(String relative) throws IOException {
        Path dir = Path.of(System.getProperty("user.dir")).toAbsolutePath().normalize();
        while (dir != null) {
            Path candidate = dir.resolve("fixtures").resolve(relative);
            if (Files.isRegularFile(candidate)) {
                return candidate;
            }
            dir = dir.getParent();
        }
        throw new IOException("fixtures/" + relative + " not found");
    }

    static byte[] hex(String text) {
        return text.equals("-") ? new byte[0] : PackbinTest.parseHex(text);
    }

    static String unhex(byte[] bytes) {
        return bytes.length == 0 ? "-" : PackbinTest.toHex(bytes);
    }

    /** The data lines of a vector file as name-to-value maps: split on spaces, then on the first '='. */
    static List<Map<String, String>> parseRows(List<String> lines) {
        List<Map<String, String>> rows = new ArrayList<>();
        for (String line : lines) {
            if (line.isBlank() || line.startsWith("#")) {
                continue;
            }
            Map<String, String> row = new HashMap<>();
            String[] tokens = line.trim().split(" ");
            for (int i = 0; i < tokens.length; i++) {
                int eq = tokens[i].indexOf('=');
                if (eq > 0) {
                    row.put(tokens[i].substring(0, eq), tokens[i].substring(eq + 1));
                } else {
                    row.put("#" + i, tokens[i]);
                }
            }
            rows.add(row);
        }
        return rows;
    }

    /** The contract's name of a result object, "Ok" for a success. */
    static String kind(Object result) {
        if (result == null || result instanceof FrameSealed || result instanceof FrameOpened) {
            return "Ok";
        }
        if (result instanceof Packbin.BadValue) {
            return "BadValue";
        }
        if (result instanceof Packbin.TooLong) {
            return "TooLong";
        }
        if (result instanceof Packbin.BufferFull) {
            return "BufferFull";
        }
        if (result instanceof Packbin.ShortPacket) {
            return "ShortPacket";
        }
        if (result instanceof Packbin.TagMismatch) {
            return "TagMismatch";
        }
        if (result instanceof Packbin.Duplicate) {
            return "Duplicate";
        }
        if (result instanceof Packbin.TooOld) {
            return "TooOld";
        }
        return "other:" + result.getClass().getName();
    }

    /** The direction with byte {@code wire} (1 to 3), or null for any other number (a direction the API cannot name). */
    static FrameDirection direction(int wire) {
        for (FrameDirection direction : FrameDirection.values()) {
            if (direction.wire == wire) {
                return direction;
            }
        }
        return null;
    }

    static byte[] filled(int length) {
        byte[] buf = new byte[length];
        Arrays.fill(buf, SENTINEL);
        return buf;
    }

    static boolean allSentinel(byte[] buf) {
        for (byte b : buf) {
            if (b != SENTINEL) {
                return false;
            }
        }
        return true;
    }

    /** Exits non-zero when a check of this process failed. */
    static void finish(String name) {
        if (PackbinTest.failureCount() > 0) {
            System.err.println(name + ": " + PackbinTest.failureCount() + " failure(s)");
            System.exit(1);
        }
        System.out.println(name + " passed");
    }
}

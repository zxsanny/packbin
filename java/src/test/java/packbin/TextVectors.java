package packbin;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/** The rows of fixtures/text/vectors.txt (AZ-2647), read from the repository root the tests run in. */
final class TextVectors {
    /** One row: its kind (enc, alt, bad, ref, flip) and its space separated columns after the kind. */
    static final class Row {
        final String kind;
        final String[] cols;

        Row(String kind, String[] cols) {
            this.kind = kind;
            this.cols = cols;
        }

        String id() {
            return cols[0];
        }

        /** The text column of an enc or alt row; "-" is the empty text. */
        String text() {
            return fromHex(cols[1]);
        }
    }

    private static List<Row> rows;

    private TextVectors() {}

    static synchronized List<Row> rows() {
        if (rows == null) {
            List<Row> read = new ArrayList<>();
            try {
                for (String line : Files.readAllLines(Path.of("fixtures", "text", "vectors.txt"), StandardCharsets.UTF_8)) {
                    if (line.isEmpty() || line.startsWith("#")) {
                        continue;
                    }
                    String[] parts = line.split(" ", -1);
                    String[] cols = new String[parts.length - 1];
                    System.arraycopy(parts, 1, cols, 0, cols.length);
                    read.add(new Row(parts[0], cols));
                }
            } catch (IOException ex) {
                throw new IllegalStateException("fixtures/text/vectors.txt: " + ex, ex);
            }
            rows = read;
        }
        return rows;
    }

    static List<Row> ofKind(String kind) {
        List<Row> out = new ArrayList<>();
        for (Row row : rows()) {
            if (row.kind.equals(kind)) {
                out.add(row);
            }
        }
        return out;
    }

    static Row byId(String id) {
        for (Row row : rows()) {
            if (row.id().equals(id)) {
                return row;
            }
        }
        throw new IllegalStateException("no vector row " + id);
    }

    /** The packet of a ref row, as hex. */
    static String ref(String id) {
        return byId(id).cols[1];
    }

    static String fromHex(String hex) {
        return hex.equals("-") ? "" : new String(PackbinTest.parseHex(hex), StandardCharsets.UTF_8);
    }
}

package packbin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * AZ-3233 AC-1 and AC-3: every keys, seal, open, mac and replay row of fixtures/frame/vectors.txt through the public frame
 * API, comparing every output field, and the same loader on a copy with one expected byte changed.
 */
public final class FrameVectorsTest {
    private FrameVectorsTest() {}

    public static void main(String[] args) throws IOException {
        run();
        FrameSupport.finish("FrameVectorsTest");
    }

    static void run() throws IOException {
        everyRowMatches();
        loaderFailsOnACorruptedCopyOfEachOp();
    }

    private static void everyRowMatches() throws IOException {
        // Arrange
        List<String> lines = Files.readAllLines(FrameSupport.fixture("frame/vectors.txt"));

        // Act
        List<String> mismatches = new ArrayList<>();
        int checked = check(lines, mismatches);
        System.out.println("frame vectors: " + checked + " rows checked, " + mismatches.size() + " mismatches");

        // Assert
        PackbinTest.expectTrue("frame vectors: mismatches " + mismatches, mismatches.isEmpty());
        PackbinTest.expectTrue("frame vectors: rows checked " + checked, checked >= 150);
        for (String name : new String[] {"E1.seal", "E2.seal", "E3.seal", "E3.seal16", "E4.mac", "E5.mac"}) {
            PackbinTest.expectTrue("frame vectors: row " + name + " present",
                    lines.stream().anyMatch(l -> l.contains(" case=" + name + " ")));
        }
    }

    private static void loaderFailsOnACorruptedCopyOfEachOp() throws IOException {
        List<String> original = Files.readAllLines(FrameSupport.fixture("frame/vectors.txt"));
        String[][] targets = {
            {"keys", "k_enc"}, {"seal", "body"}, {"open", "plain"}, {"mac", "tag"}, {"replay", "states"}};
        for (String[] target : targets) {
            // Arrange
            List<String> copy = new ArrayList<>(original);
            String caseName = corruptFirst(copy, target[0], target[1]);
            Path temp = Files.createTempFile("frame-vectors", ".txt");
            try {
                Files.write(temp, copy);

                // Act
                List<String> mismatches = new ArrayList<>();
                check(Files.readAllLines(temp), mismatches);

                // Assert
                PackbinTest.expectTrue("corrupted " + target[0] + " row " + caseName + " is reported by name: " + mismatches,
                        mismatches.size() == 1 && mismatches.get(0).startsWith(caseName + " "));
            } finally {
                Files.deleteIfExists(temp);
            }
        }
    }

    /** Changes the last hex digit of the field in the first row of the op that has it; returns the row's case. */
    private static String corruptFirst(List<String> lines, String op, String field) {
        for (int i = 0; i < lines.size(); i++) {
            String line = lines.get(i);
            String key = " " + field + "=";
            int at = line.indexOf(key);
            if (!line.startsWith("op=" + op + " ") || at < 0) {
                continue;
            }
            int end = line.indexOf(' ', at + 1);
            end = end < 0 ? line.length() : end;
            char last = line.charAt(end - 1);
            if (last == '-' || last == '=') {
                continue;
            }
            char changed = last == '0' ? '1' : '0';
            lines.set(i, line.substring(0, end - 1) + changed + line.substring(end));
            return FrameSupport.parseRows(List.of(line)).get(0).get("case");
        }
        throw new IllegalStateException("no " + op + " row with " + field);
    }

    /** Runs every row; appends "case field: expected X, got Y" per mismatch; returns the number of non-keys-or-keys rows run. */
    static int check(List<String> lines, List<String> mismatches) {
        int checked = 0;
        for (Map<String, String> row : FrameSupport.parseRows(lines)) {
            String name = row.get("case");
            try {
                Map<String, String> got = run(row);
                for (Map.Entry<String, String> e : got.entrySet()) {
                    if (!e.getValue().equals(row.get(e.getKey()))) {
                        mismatches.add(name + " " + e.getKey() + ": expected " + row.get(e.getKey()) + ", got " + e.getValue());
                    }
                }
                for (String output : outputs(row.get("op"))) {
                    if (row.containsKey(output) && !got.containsKey(output)) {
                        mismatches.add(name + " " + output + ": the row has it and the call gave none");
                    }
                }
            } catch (RuntimeException ex) {
                mismatches.add(name + " exception: " + ex);
            }
            checked++;
        }
        return checked;
    }

    private static String[] outputs(String op) {
        switch (op) {
            case "keys": return new String[] {"k_enc", "k_mac", "k_label"};
            case "seal": return new String[] {"body", "result"};
            case "open": return new String[] {"result", "slot", "plain", "window_after"};
            case "mac": return new String[] {"tag", "valid", "result"};
            default: return new String[] {"results", "states"};
        }
    }

    private static Map<String, String> run(Map<String, String> row) {
        switch (row.get("op")) {
            case "keys": return FrameRows.keys(row);
            case "seal": return FrameRows.seal(row);
            case "open": return FrameRows.open(row);
            case "mac": return FrameRows.mac(row);
            case "replay": return FrameRows.replay(row);
            default: throw new IllegalStateException("unknown op " + row.get("op"));
        }
    }
}

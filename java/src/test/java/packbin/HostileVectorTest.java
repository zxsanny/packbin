package packbin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** AZ-2074: replays every {@code unpack} case of fixtures/hostile/cases.txt through BinaryPacker.unpack. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileVectorTest {
    private HostileVectorTest() {}

    private record Case(String id, List<String> expected, String hex) {}

    static void run() throws IOException {
        Set<String> seen = new HashSet<>();
        for (Case c : readUnpackCases()) {
            seen.add(c.id);
            replay(c);
        }
        for (String id : List.of(
                "zero_progress_repeat_bool", "zero_progress_repeat_when", "negative_count", "oversize_count",
                "oversize_count_times", "oversize_list_count", "invalid_utf8", "invalid_utf8_dict_key",
                "count_behind_clear_flag", "count_behind_clear_flag_bits")) {
            PackbinTest.expectTrue("hostile vector " + id + " present in cases.txt", seen.contains(id));
        }
    }

    private static void replay(Case c) {
        Scheme<Map> scheme;
        try {
            scheme = schemeFor(c.id);
            if (scheme == null) {
                PackbinTest.fail("hostile case " + c.id + " has no Java scheme in HostileVectorTest");
                return;
            }
        } catch (IllegalArgumentException ex) {
            PackbinTest.expectTrue(c.id + " -> scheme_error accepted by " + c.expected, c.expected.contains("scheme_error"));
            return;
        }
        HostileRun run = HostileRun.of(scheme, c.hex);
        String label = c.id + " -> " + run.kind();
        System.out.println("hostile vector " + label + " (expected " + String.join("|", c.expected) + ")");
        PackbinTest.expectTrue(c.id + " returns within " + HostileRun.LIMIT_MS + " ms (hang?)", run.finished);
        PackbinTest.expectTrue(label + " does not throw", run.thrown == null);
        PackbinTest.expectTrue(label + " is a non-ok result", run.result != null);
        PackbinTest.expectTrue(label + " leaves the handler uncalled", !run.handled);
        PackbinTest.expectTrue(label + " is a kind Java can report", kindAccepted(c, run.result));
    }

    /** Java has no BadValue/TooMany type yet (C15): any non-ok, non-exception result passes the interim rule. */
    private static boolean kindAccepted(Case c, Object result) {
        if (result instanceof Packbin.TrailingBytes) {
            return c.expected.contains("trailing_bytes") || interim(c);
        }
        if (result instanceof Packbin.ShortPacket) {
            return c.expected.contains("short_packet") || interim(c);
        }
        return result != null && interim(c);
    }

    private static boolean interim(Case c) {
        for (String kind : c.expected) {
            if (kind.equals("bad_value") || kind.equals("too_many")) {
                return true;
            }
        }
        return false;
    }

    private static Scheme<Map> schemeFor(String id) {
        return switch (id) {
            case "zero_progress_repeat_bool" -> Maps.scheme(1,
                    Packbin.repeat(0, Packbin.boolField(0, Access.get("on"), Access.set("on"))));
            case "zero_progress_repeat_when" -> Maps.scheme(1,
                    Packbin.u8(0, Access.get("mode"), Access.set("mode")),
                    Packbin.repeat(1, Packbin.when(1, Packbin.eq(0, 1),
                            Packbin.u8(1, Access.get("v"), Access.set("v")))));
            case "negative_count" -> Maps.scheme(1,
                    Packbin.i8(0, Access.get("n"), Access.set("n")),
                    Packbin.sized(1, Access.get("payload"), Access.set("payload"), 0));
            case "oversize_count" -> Maps.scheme(1,
                    Packbin.u32(0, Access.get("n"), Access.set("n")),
                    Packbin.sized(1, Access.get("payload"), Access.set("payload"), 0));
            case "oversize_count_times" -> Maps.scheme(1,
                    Packbin.u32(0, Access.get("n"), Access.set("n")),
                    Packbin.times(1, 0, Packbin.u8(1, Access.get("v"), Access.set("v"))));
            case "oversize_list_count" -> Maps.scheme(1, Packbin.list(
                    Access.get("xs"), Access.set("xs"), Packbin.u8(0, Access.identity(), Access.ignore())));
            case "invalid_utf8" -> Maps.scheme(1, Packbin.utf8(0, Access.get("name"), Access.set("name")));
            case "invalid_utf8_dict_key" -> Maps.scheme(1, Packbin.dict(
                    Access.get("m"), Access.set("m"), Packbin.u8(0, Access.identity(), Access.ignore())));
            case "count_behind_clear_flag" -> Maps.scheme(1,
                    Packbin.flags(0, Packbin.u8(0, Access.get("n"), Access.set("n"))),
                    Packbin.sized(1, Access.get("payload"), Access.set("payload"), 0));
            case "count_behind_clear_flag_bits" -> Maps.scheme(1,
                    Packbin.flags(0, Packbin.u8(0, Access.get("n"), Access.set("n"))),
                    Packbin.bits(1, Access.get("segs"), Access.set("segs"), 0));
            default -> null;
        };
    }

    private static List<Case> readUnpackCases() throws IOException {
        List<Case> cases = new ArrayList<>();
        for (String line : Files.readAllLines(findCases())) {
            String text = line.trim();
            if (text.isEmpty() || text.startsWith("#")) {
                continue;
            }
            String[] parts = text.split("\\s+");
            if (parts.length == 4 && parts[1].equals("unpack")) {
                cases.add(new Case(parts[0], List.of(parts[2].split("\\|")), parts[3]));
            }
        }
        return cases;
    }

    private static Path findCases() throws IOException {
        Path dir = Path.of(System.getProperty("user.dir")).toAbsolutePath().normalize();
        while (dir != null) {
            Path candidate = dir.resolve("fixtures").resolve("hostile").resolve("cases.txt");
            if (Files.isRegularFile(candidate)) {
                return candidate;
            }
            dir = dir.getParent();
        }
        throw new IOException("fixtures/hostile/cases.txt not found");
    }
}

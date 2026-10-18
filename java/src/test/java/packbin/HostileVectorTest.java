package packbin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Consumer;
import java.util.function.Supplier;

/**
 * AZ-2074: replays every {@code unpack} case of fixtures/hostile/cases.txt through BinaryPacker.unpack.
 * AZ-2089: every {@code construct} case must fail at scheme construction.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileVectorTest {
    private HostileVectorTest() {}

    private record Case(String id, String stage, List<String> expected, String hex) {}

    static void run() throws IOException {
        Set<String> seen = new HashSet<>();
        Set<String> packRefused = new HashSet<>();
        Set<String> constructed = new HashSet<>();
        for (Case c : readCases()) {
            seen.add(c.id);
            if (c.stage.equals("pack") && c.expected.equals(List.of("pack_error"))) {
                packRefused.add(c.id);
            } else if (c.stage.equals("construct")) {
                constructed.add(c.id);
            }
            if (c.stage.equals("construct")) {
                replayConstruct(c, HostileRefusals.CONSTRUCT, PackbinTest::fail);
            } else if (c.stage.equals("unpack")) {
                replay(c);
            } else if (c.stage.equals("limit")) {
                replayLimit(c);
            } else if (c.stage.equals("pack")) {
                replayPack(c, HostileRefusals.PACK, PackbinTest::fail);
            } else {
                PackbinTest.fail("hostile case " + c.id + " has unknown stage " + c.stage);
            }
        }
        for (String id : List.of(
                "zero_progress_repeat_bool", "zero_progress_repeat_when", "negative_count", "oversize_count",
                "oversize_count_times", "oversize_list_count", "invalid_utf8", "invalid_utf8_dict_key",
                "count_behind_clear_flag", "count_behind_clear_flag_bits", "nine_flag_bits", "nine_flag_bits_split",
                "when_names_later_field", "count_names_later_field", "when_names_outer_field_in_repeat",
                "bool_outside_flags", "empty_group_outside_flags", "eq_bool_false", "eq_out_of_range",
                "repeat_rounds_over_limit", "times_rounds_over_limit",
                "pack_out_of_range_integer", "pack_missing_required_value", "pack_times_list_too_long",
                "pack_times_list_too_short", "pack_aligned_round_row", "pack_times_count_over_limit",
                "pack_times_zero_with_values", "pack_split_when_source_after_byte",
                "pack_split_times_count_after_byte", "pack_split_times_count_skipped", "pack_lone_bytes_in_round",
                "pack_split_false_condition_silent", "pack_lone_utf8_under_times_over_budget",
                "pack_element_times_over_budget", "pack_slots_over_limit", "pack_repeat_over_limit",
                "pack_split_count_zero_after_byte_list", "pack_split_count_zero_after_byte_scalar",
                "pack_flags_skipped_count_with_values")) {
            PackbinTest.expectTrue("hostile vector " + id + " present in cases.txt", seen.contains(id));
        }
        PackbinTest.expectEq("refusal rules cover exactly the pack_error pack cases", new java.util.TreeSet<>(packRefused),
                new java.util.TreeSet<>(HostileRefusals.PACK.keySet()));
        PackbinTest.expectEq("refusal rules cover exactly the construct cases", new java.util.TreeSet<>(constructed),
                new java.util.TreeSet<>(HostileRefusals.CONSTRUCT.keySet()));
        for (String id : HostileLoop21.IDS) {
            PackbinTest.expectTrue("hostile vector " + id + " present in cases.txt", seen.contains(id));
        }
        for (String id : HostileLoop22.IDS) {
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
            System.out.println("hostile vector " + c.id + " -> scheme_error: " + ex.getMessage()
                    + " (expected " + String.join("|", c.expected) + ")");
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

    /** Rounds the scheme of a {@code limit} case allows; maxSlots stays at its default. */
    private static final int LOW_ROUNDS = 3;

    /**
     * A limit case is unpacked with a scheme whose maxRounds is {@value #LOW_ROUNDS}. It must come back as the interim
     * bad-value error of the round that would start: no bytes needed, the one byte of that round left, no handler call.
     */
    private static void replayLimit(Case c) {
        Scheme<Map> scheme = limitSchemeFor(c.id);
        if (scheme == null) {
            PackbinTest.fail("hostile case " + c.id + " has no Java scheme in HostileVectorTest");
            return;
        }
        HostileRun run = HostileRun.of(scheme, c.hex);
        String label = c.id + " -> " + run.kind();
        System.out.println("hostile vector " + label + " (expected " + String.join("|", c.expected) + ")");
        PackbinTest.expectTrue(c.id + " returns within " + HostileRun.LIMIT_MS + " ms (hang?)", run.finished);
        PackbinTest.expectTrue(label + " does not throw", run.thrown == null);
        PackbinTest.expectTrue(label + " leaves the handler uncalled", !run.handled);
        PackbinTest.expectTrue(label + " is a kind Java can report", kindAccepted(c, run.result));
        if (run.result instanceof Packbin.ShortPacket refusal) {
            PackbinTest.expectEq(c.id + " needed", 0, refusal.needed);
            PackbinTest.expectEq(c.id + " left", 1, refusal.left);
        } else {
            PackbinTest.fail(label + " is not the interim bad-value error (ShortPacket with needed 0)");
        }
    }

    private static Scheme<Map> limitSchemeFor(String id) {
        return switch (id) {
            case "repeat_rounds_over_limit" -> Maps.scheme(1,
                    Packbin.repeat(0, Packbin.u8(0, Access.get("v"), Access.set("v"))))
                    .withLimits(LOW_ROUNDS, Scheme.DEFAULT_MAX_SLOTS);
            case "times_rounds_over_limit" -> Maps.scheme(1,
                    Packbin.u8(0, Access.get("n"), Access.set("n")),
                    Packbin.times(1, 0, Packbin.u8(1, Access.get("v"), Access.set("v"))))
                    .withLimits(LOW_ROUNDS, Scheme.DEFAULT_MAX_SLOTS);
            default -> null;
        };
    }

    /**
     * AZ-2194: a pack case packs the row its README section gives. {@code bytes} must equal the hex; {@code pack_error}
     * must throw and return no bytes, by the rule HostileRefusals names for the case (AZ-2392). Java runs every pack case.
     */
    private static void replayPack(Case c, Map<String, HostileRefusals.Rule> rules, Consumer<String> failure) {
        Supplier<byte[]> pack = packFor(c.id);
        if (pack == null) {
            failure.accept("hostile case " + c.id + " has no Java scheme in HostileVectorTest");
            return;
        }
        if (c.expected.equals(List.of("bytes"))) {
            PackbinTest.expectEq("hostile pack " + c.id, c.hex, PackbinTest.toHex(pack.get()));
        } else if (c.expected.equals(List.of("pack_error"))) {
            PackbinTest.expectTrue("hostile pack " + c.id + " has hex '-'", c.hex.equals("-"));
            try {
                pack.get();
            } catch (IllegalArgumentException | IllegalStateException ex) {
                System.out.println("hostile vector " + c.id + " -> pack_error: " + ex.getMessage());
                refusedByRule(rules.get(c.id), c.id, ex, failure);
                return;
            }
            failure.accept("hostile vector " + c.id + ": packed without error, expected pack_error");
        } else {
            PackbinTest.fail("hostile pack case " + c.id + " expects " + c.expected + ", not bytes or pack_error");
        }
    }

    /** AZ-2392: the refusal must come from the rule the table names for this case, not from some other rule. */
    private static void refusedByRule(
            HostileRefusals.Rule rule, String id, RuntimeException ex, Consumer<String> failure) {
        String problem = HostileRefusals.mismatch(id, rule, ex);
        if (problem != null) {
            failure.accept("hostile vector " + problem);
        }
    }

    /**
     * AZ-2418: replays the one refusal case {@code id} of cases.txt against the given rule tables and returns the
     * failures instead of counting them, so a test can feed the loader a wrong rule and see it fail.
     */
    static List<String> replayRefusal(
            String id, Map<String, HostileRefusals.Rule> pack, Map<String, HostileRefusals.Rule> construct)
            throws IOException {
        List<String> failures = new ArrayList<>();
        for (Case c : readCases()) {
            if (!c.id.equals(id)) {
                continue;
            }
            if (c.stage.equals("construct")) {
                replayConstruct(c, construct, failures::add);
            } else if (c.stage.equals("pack") && c.expected.equals(List.of("pack_error"))) {
                replayPack(c, pack, failures::add);
            } else {
                failures.add("hostile case " + id + " is not a refusal case");
            }
            return failures;
        }
        failures.add("hostile case " + id + " not found in cases.txt");
        return failures;
    }

    private static Supplier<byte[]> packFor(String id) {
        return switch (id) {
            case "pack_out_of_range_integer" -> () -> BinaryPacker.pack(Maps.scheme(1, u8(0, "a")), Maps.map("a", 300));
            case "pack_missing_required_value" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, u8(0, "a"), u8(1, "b")), Maps.map("a", 1));
            case "pack_times_list_too_long" -> () -> BinaryPacker.pack(
                    timesScheme(), Maps.map("a", 2, "x", List.of(1, 2, 3)));
            case "pack_times_list_too_short" -> () -> BinaryPacker.pack(
                    timesScheme(), Maps.map("a", 2, "x", List.of(1)));
            case "pack_aligned_round_row" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, Packbin.repeat(0, Packbin.flags(0,
                            Packbin.boolField(0, Access.get("on"), Access.set("on")), u8(1, "n")))),
                    Maps.map("on", List.of(true, false, true), "n", List.of(1, 2, 3)));
            case "pack_times_count_over_limit" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, Packbin.u32(0, Access.get("n"), Access.set("n")), Packbin.times(1, 0, u8(1, "x"))),
                    Maps.map("n", 65_536, "x", 7));
            case "pack_times_zero_with_values" -> () -> BinaryPacker.pack(timesScheme(), Maps.map("a", 0, "x", List.of(5)));
            case "pack_split_when_source_after_byte" -> () -> {
                Field fb = Packbin.flagByte();
                return BinaryPacker.pack(Maps.scheme(1, fb, u8(0, "mode"),
                        fb.bit(Packbin.when(1, Packbin.eq(0, 1), u8(1, "speed")))), Maps.map("mode", 1, "speed", 7));
            };
            case "pack_split_times_count_after_byte" -> () -> {
                Field fb = Packbin.flagByte();
                return BinaryPacker.pack(Maps.scheme(1, fb, u8(0, "n"), fb.bit(Packbin.times(1, 0, u8(1, "pt")))),
                        Maps.map("n", 2, "pt", List.of(5, 6)));
            };
            case "pack_split_times_count_skipped" -> () -> {
                Field fb = Packbin.flagByte();
                return BinaryPacker.pack(Maps.scheme(1, u8(0, "sel"), fb, Packbin.when(1, Packbin.eq(0, 1), u8(1, "n")),
                        fb.bit(Packbin.times(2, 1, u8(2, "pt")))), Maps.map("sel", 0, "pt", List.of(5)));
            };
            case "pack_lone_bytes_in_round" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, u8(0, "n"),
                            Packbin.times(1, 0, Packbin.bytes(1, Access.get("d"), Access.set("d"), 2))),
                    Maps.map("n", 2, "d", new byte[] {1, 2}));
            case "pack_split_false_condition_silent" -> () -> {
                Field fb = Packbin.flagByte();
                return BinaryPacker.pack(Maps.scheme(1, u8(0, "mode"), fb,
                        fb.bit(Packbin.when(1, Packbin.eq(0, 1), u8(1, "speed"))),
                        fb.bit(Packbin.u16(2, Access.get("heading"), Access.set("heading")))),
                        Maps.map("mode", 0, "speed", 7, "heading", 90));
            };
            case "pack_lone_utf8_under_times_over_budget" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, Packbin.u32(0, Access.get("n"), Access.set("n")),
                            Packbin.times(1, 0, Packbin.utf8(1, Access.get("s"), Access.set("s")))),
                    Maps.map("n", 65_535, "s", String.valueOf((char) 1).repeat(65_535)));
            case "pack_element_times_over_budget" -> () -> {
                List<Object> items = new ArrayList<>();
                for (int i = 0; i < 40; i++) {
                    items.add(Maps.map("n", 65_535, "k", 5));
                }
                return BinaryPacker.pack(Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"),
                        Packbin.group(0, Packbin.u32(0, Access.get("n"), Access.set("n")),
                                Packbin.times(1, 0, Packbin.u64(1, Access.get("k"), Access.set("k")))))),
                        Maps.map("items", items));
            };
            case "pack_slots_over_limit" -> () -> {
                Field[] members = new Field[65];
                Map<String, Object> row = Maps.map("n", 65_535);
                for (int i = 0; i < 65; i++) {
                    members[i] = u8(i + 1, "m" + i);
                    row.put("m" + i, 1);
                }
                return BinaryPacker.pack(Maps.scheme(1, Packbin.u32(0, Access.get("n"), Access.set("n")),
                        Packbin.times(1, 0, members)), row);
            };
            case "pack_repeat_over_limit" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, Packbin.repeat(0, u8(0, "k"))), Maps.map("k", Collections.nCopies(65_536, 7)));
            case "pack_split_count_zero_after_byte_list" -> () -> BinaryPacker.pack(
                    splitCountAfterByte(), Maps.map("n", 0, "pt", List.of(5, 6)));
            case "pack_split_count_zero_after_byte_scalar" -> () -> BinaryPacker.pack(
                    splitCountAfterByte(), Maps.map("n", 0, "pt", 5));
            case "pack_flags_skipped_count_with_values" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, Packbin.flags(0, u8(0, "n"), Packbin.times(1, 0, u8(1, "pt")))),
                    Maps.map("pt", List.of(5, 6)));
            default -> orElse(HostileLoop21.packFor(id), () -> HostileLoop22.packFor(id));
        };
    }

    private static <T> T orElse(T first, Supplier<T> next) {
        return first != null ? first : next.get();
    }

    private static Scheme<Map> splitCountAfterByte() {
        Field fb = Packbin.flagByte();
        return Maps.scheme(1, fb, u8(0, "n"), fb.bit(Packbin.times(1, 0, u8(1, "pt"))));
    }

    private static Scheme<Map> timesScheme() {
        return Maps.scheme(1, u8(0, "a"), Packbin.times(1, 0, u8(1, "x")));
    }

    /** A construct case passes only when building its scheme throws IllegalArgumentException: 0 schemes. */
    private static void replayConstruct(Case c, Map<String, HostileRefusals.Rule> rules, Consumer<String> failure) {
        PackbinTest.expectTrue(c.id + " construct case expects scheme_error", c.expected.contains("scheme_error"));
        Supplier<Scheme<Map>> build = constructFor(c.id);
        if (build == null) {
            failure.accept("hostile case " + c.id + " has no Java scheme in HostileVectorTest");
            return;
        }
        try {
            build.get();
        } catch (IllegalArgumentException ex) {
            System.out.println("hostile vector " + c.id + " -> scheme_error: " + ex.getMessage());
            refusedByRule(rules.get(c.id), c.id, ex, failure);
            return;
        }
        failure.accept("hostile vector " + c.id + ": scheme built, expected scheme_error");
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    /** Java numbering: a flag byte takes no order id, so the split-form bits are ids 0 to 8. */
    private static Supplier<Scheme<Map>> constructFor(String id) {
        return switch (id) {
            case "nine_flag_bits" -> () -> Maps.scheme(1, Packbin.flags(0,
                    u8(0, "f0"), u8(1, "f1"), u8(2, "f2"), u8(3, "f3"), u8(4, "f4"),
                    u8(5, "f5"), u8(6, "f6"), u8(7, "f7"), u8(8, "f8")));
            case "nine_flag_bits_split" -> () -> {
                Field fb = Packbin.flagByte();
                Field[] fields = new Field[10];
                fields[0] = fb;
                for (int i = 0; i < 9; i++) {
                    fields[i + 1] = fb.bit(u8(i, "f" + i));
                }
                return Maps.scheme(1, fields);
            };
            case "when_names_later_field" -> () -> Maps.scheme(1,
                    u8(0, "a"), Packbin.when(1, Packbin.eq(2, 1), u8(1, "b")), u8(2, "c"));
            case "count_names_later_field" -> () -> Maps.scheme(1,
                    Packbin.sized(0, Access.get("payload"), Access.set("payload"), 1),
                    Packbin.u16(1, Access.get("n"), Access.set("n")));
            case "when_names_outer_field_in_repeat" -> () -> Maps.scheme(1,
                    u8(0, "mode"), Packbin.repeat(1, Packbin.when(1, Packbin.eq(0, 1), u8(1, "v"))));
            case "bool_outside_flags" -> () -> Maps.scheme(1,
                    u8(0, "a"), Packbin.boolField(1, Access.get("on"), Access.set("on")));
            case "empty_group_outside_flags" -> () -> Maps.scheme(1, u8(0, "a"), Packbin.group(1));
            case "eq_bool_false" -> () -> Maps.scheme(1,
                    Packbin.flags(0, Packbin.boolField(0, Access.get("on"), Access.set("on"))),
                    Packbin.when(1, Packbin.eq(0, false), u8(1, "v")));
            case "eq_out_of_range" -> () -> Maps.scheme(1,
                    u8(0, "a"), Packbin.when(1, Packbin.eq(0, 300), u8(1, "v")));
            default -> orElse(HostileLoop21.constructFor(id), () -> HostileLoop22.constructFor(id));
        };
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

    private static List<Case> readCases() throws IOException {
        List<Case> cases = new ArrayList<>();
        for (String line : Files.readAllLines(findCases())) {
            String text = line.trim();
            if (text.isEmpty() || text.startsWith("#")) {
                continue;
            }
            String[] parts = text.split("\\s+");
            if (parts.length != 4) {
                PackbinTest.fail("hostile cases line is not 'id stage expected hex': " + text);
                continue;
            }
            cases.add(new Case(parts[0], parts[1], List.of(parts[2].split("\\|")), parts[3]));
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

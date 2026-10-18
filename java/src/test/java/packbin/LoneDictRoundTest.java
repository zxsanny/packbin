package packbin;

import java.util.List;
import java.util.Map;

/** AZ-2308: a lone Map for a dict member in a repeat or times round is refused; a list of Maps, one per round, packs. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class LoneDictRoundTest {
    private LoneDictRoundTest() {}

    private static final String REFUSED = "d: a lone dictionary is not a list of rounds; give one dictionary per round in a list";

    static void run() {
        loneDictInARoundIsRefused();
        listOfDictsPerRoundStillPacks();
        loneUtf8StillBroadcasts();
    }

    private static Field dict() {
        return Packbin.dict(Access.get("d"), Access.set("d"), Packbin.u8(0, Access.identity(), Access.ignore()));
    }

    private static Scheme<Map> times() {
        return Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")), Packbin.times(1, 0, dict()));
    }

    private static Scheme<Map> repeat() {
        return Maps.scheme(1, Packbin.repeat(0, dict()));
    }

    private static void loneDictInARoundIsRefused() {
        PackbinTest.expectThrows("AZ-2308 AC-2 times, lone dictionary", () ->
                BinaryPacker.pack(times(), Maps.map("n", 2, "d", Map.of("a", 1))), REFUSED);
        PackbinTest.expectThrows("AZ-2308 AC-2 repeat, lone dictionary", () ->
                BinaryPacker.pack(repeat(), Maps.map("d", Map.of("a", 1))), REFUSED);
        PackbinTest.expectThrows("AZ-2308 AC-2 repeat inside a round, lone dictionary", () ->
                BinaryPacker.pack(Maps.scheme(1, Packbin.repeat(0, Packbin.u8(0, Access.get("k"), Access.set("k")),
                        Packbin.repeat(1, dict()))), Maps.map("k", List.of(1), "d", List.of(Map.of("a", 1)))), REFUSED);
        PackbinTest.expectThrows("AZ-2308 AC-2 typed accessor is named by the kind", () ->
                BinaryPacker.pack(Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")), Packbin.times(1, 0,
                        Packbin.dict(Access.get((Map<String, Object> r) -> r.get("d")),
                                Access.set((Map<String, Object> r, Object v) -> r.put("d", v)),
                                Packbin.u8(0, Access.identity(), Access.ignore())))),
                        Maps.map("n", 2, "d", Map.of("a", 1))),
                "dict: a lone dictionary is not a list of rounds; give one dictionary per round in a list");
    }

    private static void listOfDictsPerRoundStillPacks() {
        Map<String, Object> row = Maps.map("n", 2, "d", List.of(Map.of("a", 1), Map.of("b", 2)));
        PackbinTest.expectEq("AZ-2308 AC-3 times, one dictionary per round", "0102010002106101010002106202",
                PackbinTest.toHex(BinaryPacker.pack(times(), row)));
        PackbinTest.expectEq("AZ-2308 AC-3 repeat, one dictionary per round", "01010002106101010002106202",
                PackbinTest.toHex(BinaryPacker.pack(repeat(), Maps.map("d", List.of(Map.of("a", 1), Map.of("b", 2))))));
        PackbinTest.expectEq("AZ-2308 AC-3 a dictionary outside a round", "0101000210" + "6101",
                PackbinTest.toHex(BinaryPacker.pack(Maps.scheme(1, dict()), Maps.map("d", Map.of("a", 1)))));
    }

    private static void loneUtf8StillBroadcasts() {
        Scheme<Map> utf8 = Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, Packbin.utf8(1, Access.get("s"), Access.set("s"))));
        PackbinTest.expectEq("AZ-2308 excluded: lone utf8 broadcasts", "0102021078021078",
                PackbinTest.toHex(BinaryPacker.pack(utf8, Maps.map("n", 2, "s", "x"))));
    }
}

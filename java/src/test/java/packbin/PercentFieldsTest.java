package packbin;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * AZ-3512: a parity percentage over a message whose length varies by an optional field (AC-17, S12b), over a string
 * field read after the repair (AC-18, S12c), and the refusal of a dispatch mix naming the percentage (AC-19, D4).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class PercentFieldsTest {
    private PercentFieldsTest() {}

    static void run() {
        optionalField();
        stringField();
        dispatchMix();
    }

    private static Scheme<Map> optional() {
        return Maps.scheme(1, Packbin.u32(0, Access.get("a"), Access.set("a")), Packbin.u32(1, Access.get("b"), Access.set("b")),
                Packbin.flags(2, MemberCases.u16(2, "h"), MemberCases.u8(3, "s"))).withParityPercent(25);
    }

    private static void optionalField() {
        // Arrange
        Object[][] cases = {
            {"with the field", Maps.map("a", 1, "b", 2, "h", 3, "s", 4), 13, 4},
            {"without the field", Maps.map("a", 1, "b", 2), 10, 3},
        };

        for (Object[] c : cases) {
            String name = "PF-1 " + c[0];
            Map<String, Object> row = (Map<String, Object>) c[1];
            int clear = (Integer) c[2];
            int parity = (Integer) c[3];
            byte[] sent = BinaryPacker.pack(optional(), row);
            byte[] damaged = EccSupport.corrupt(sent, parity == 4 ? new int[] {1, 6} : new int[] {1}, parity == 4 ? new int[] {0x5A, 0x33} : new int[] {0x5A});
            List<Map> intact = new ArrayList<>();
            List<Map> repaired = new ArrayList<>();

            // Act
            Object intactResult = BinaryPacker.unpackRepair(sent, 0, optional().on(intact::add));
            Object repairedResult = BinaryPacker.unpackRepair(damaged, parity / 2, optional().on(repaired::add));

            // Assert
            PackbinTest.expectEq(name + " sent length", clear + parity, sent.length);
            PackbinTest.expectTrue(name + " intact round trip", intactResult instanceof Packbin.Repaired r && r.count == 0 && sameRow(intact, row));
            PackbinTest.expectTrue(name + " repaired round trip",
                    repairedResult instanceof Packbin.Repaired r && r.count == parity / 2 && sameRow(repaired, row));
        }
    }

    private static boolean sameRow(List<Map> got, Map<String, Object> row) {
        if (got.size() != 1) {
            return false;
        }
        for (String key : new String[] {"a", "b", "h", "s"}) {
            Object want = row.get(key);
            Object have = got.get(0).get(key);
            if (want == null ? have != null : have == null || ((Number) want).longValue() != ((Number) have).longValue()) {
                return false;
            }
        }
        return true;
    }

    private static void stringField() {
        // Arrange
        Scheme<Map> note = Maps.scheme(1, Packbin.utf8(0, Access.get("text"), Access.set("text")), MemberCases.u8(1, "n"))
                .withParityPercent(25);

        for (String text : new String[] {"pack bin ecc 0123456789", "Олександр, диспетчер", "gps_fix 48.46"}) {
            Map<String, Object> row = Maps.map("text", text, "n", 200);
            byte[] sent = BinaryPacker.pack(note, row);
            int wrong = 0;

            // Act
            for (int place = 0; place < sent.length; place++) {
                List<Map> rows = new ArrayList<>();
                Object result = BinaryPacker.unpackRepair(EccSupport.corrupt(sent, new int[] {place}, new int[] {0x5A}), 1, note.on(rows::add));
                if (!(result instanceof Packbin.Repaired r && r.count == 1 && rows.size() == 1 && rows.get(0).equals(row))) {
                    wrong++;
                }
            }

            // Assert
            PackbinTest.expectEq("PF-2 one wrong byte anywhere, the original string \"" + text + "\" comes back", 0, wrong);
        }
    }

    private static void dispatchMix() {
        // Arrange
        int[] ran = {0};
        Scheme<Map> percent = Maps.scheme(0x40, MemberCases.u8(0, "a")).withParityPercent(25);
        Scheme<Map> count = Maps.scheme(0x41, MemberCases.u8(0, "a")).withParity(25);
        byte[] message = new byte[20];

        // Act / Assert
        PackbinTest.expectThrows("PF-3 25 percent with a count of 25", () -> BinaryPacker.unpack(message, percent.on(row -> ran[0]++),
                count.on(row -> ran[0]++)),
                "handlers declare 25 percent parity and 25 parity bytes; they must declare the same count or percentage");
        PackbinTest.expectThrows("PF-3 a count of 25 with 25 percent", () -> BinaryPacker.unpack(message, count.on(row -> ran[0]++),
                percent.on(row -> ran[0]++)),
                "handlers declare 25 parity bytes and 25 percent parity; they must declare the same count or percentage");
        PackbinTest.expectEq("PF-3 no handler ran on a refusal", 0, ran[0]);
    }
}

package packbin;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * AZ-2683 AC-1 (the setting), AC-6 (compact text, dispatch) and the hostile-bytes rule for protected schemes.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class EccSchemeTest {
    private EccSchemeTest() {}

    static void run() {
        theSettingAndItsDefault();
        compactTextAfterRepair();
        compactTextDetectOnly();
        dispatchReachesTheRightHandler();
        dispatchOfMixedParityIsRefused();
        dispatchWithoutParityIsUnchanged();
        hostileBytesNeverThrow();
    }

    private static void theSettingAndItsDefault() {
        // Arrange
        Scheme<PositionRow> plain = EccSupport.positionScheme(0);

        // Act
        Scheme<PositionRow> protectedScheme = plain.withParity(4);
        Scheme<PositionRow> tuned = protectedScheme.withMaxBytes(100).withLimits(7, 50);

        // Assert
        PackbinTest.expectEq("EC-1 a scheme declares no parity bytes unless told to", 0, plain.parity());
        PackbinTest.expectEq("EC-1 withParity sets the count", 4, protectedScheme.parity());
        PackbinTest.expectEq("EC-1 withParity leaves the first scheme unchanged", 0, plain.parity());
        PackbinTest.expectEq("EC-1 the limit setters keep the count", 4, tuned.parity());
        PackbinTest.expectEq("EC-1 withParity keeps the limits", 7, tuned.withParity(2).maxRounds());
        PackbinTest.expectEq("EC-3 the largest count is accepted", 32, plain.withParity(32).parity());
    }

    private static Scheme<Map> note() {
        return Maps.scheme(0x21, MemberCases.u8(0, "id"), Packbin.utf8(1, Access.get("text"), Access.set("text")),
                MemberCases.u16(2, "tail")).withParity(4);
    }

    private static Map<String, Object> noteRow() {
        return Maps.map("id", 7, "text", "packbin ecc 0123456789", "tail", 4660);
    }

    private static void compactTextAfterRepair() {
        // Arrange
        Random random = new Random(11);
        byte[] message = BinaryPacker.pack(note(), noteRow());
        int cases = 0;
        int wrong = 0;

        // Act
        for (int a = 0; a < message.length; a++) {
            for (int b = a + 1; b < message.length; b++) {
                for (int k = 0; k < 6; k++) {
                    byte[] damaged = EccSupport.corrupt(message, new int[] {a, b}, EccSupport.pickValues(random, 2));
                    List<Map> rows = new ArrayList<>();
                    Object result = BinaryPacker.unpackRepair(damaged, 2, note().on(rows::add));
                    cases++;
                    if (!(result instanceof Packbin.Repaired r && r.count == 2 && rows.size() == 1 && rows.get(0).equals(noteRow()))) {
                        wrong++;
                    }
                }
            }
        }

        // Assert
        PackbinTest.expectTrue("EC-11 n = 4: cases of 2 wrong bytes anywhere (" + cases + ")", cases > 1000);
        PackbinTest.expectEq("EC-11 n = 4: the original row and string come back", 0, wrong);
    }

    private static void compactTextDetectOnly() {
        // Arrange
        byte[] message = BinaryPacker.pack(note(), noteRow());
        List<Map> rows = new ArrayList<>();

        // Act
        Object result = BinaryPacker.unpack(EccSupport.corrupt(message, new int[] {4}, new int[] {0x10}), note().on(rows::add));

        // Assert
        PackbinTest.expectTrue("EC-11 detect only: a wrong byte in the string payload is refused", result instanceof Packbin.Uncorrectable);
        PackbinTest.expectEq("EC-11 detect only: the handler does not run", 0, rows.size());
        PackbinTest.expectTrue("EC-11 an intact protected message unpacks with the plain call returning null",
                BinaryPacker.unpack(message, note().on(rows::add)) == null && rows.size() == 1);
    }

    private static Scheme<Map>[] dispatchSchemes(int parity) {
        Scheme<Map>[] out = new Scheme[3];
        for (int i = 0; i < 3; i++) {
            out[i] = Maps.scheme(0x11 + i, MemberCases.u16(0, "a"), MemberCases.u8(1, "b")).withParity(parity);
        }
        return out;
    }

    private static void dispatchReachesTheRightHandler() {
        // Arrange
        Random random = new Random(16);
        Scheme<Map>[] schemes = dispatchSchemes(4);
        int[] calls = new int[3];
        Scheme.Handler<?>[] handlers = new Scheme.Handler<?>[3];
        for (int i = 0; i < 3; i++) {
            int which = i;
            handlers[i] = schemes[i].on(row -> calls[which]++);
        }
        int missed = 0;
        int wrongHandlers = 0;

        // Act
        for (int i = 0; i < 1000; i++) {
            int which = i % 3;
            byte[] message = BinaryPacker.pack(schemes[which], Maps.map("a", i, "b", which));
            int extra = i % 2;
            int[] positions = new int[1 + extra];
            if (extra == 1) {
                positions[1] = 1 + random.nextInt(message.length - 1);
            }
            int[] values = EccSupport.pickValues(random, positions.length);
            java.util.Arrays.fill(calls, 0);
            Object result = BinaryPacker.unpackRepair(EccSupport.corrupt(message, positions, values), 2, handlers);
            if (!(result instanceof Packbin.Repaired r && r.count == positions.length)) {
                missed++;
            }
            for (int j = 0; j < 3; j++) {
                if (calls[j] != (j == which ? 1 : 0)) {
                    wrongHandlers++;
                }
            }
        }

        // Assert
        PackbinTest.expectEq("EC-16 1,000 cases with the type byte among 1 to 2 wrong bytes, not repaired", 0, missed);
        PackbinTest.expectEq("EC-16 1,000 cases, calls to a wrong handler", 0, wrongHandlers);
    }

    private static void dispatchOfMixedParityIsRefused() {
        // Arrange
        int[] ran = {0};
        Scheme<Map> four = dispatchSchemes(4)[0];
        Scheme<Map> two = Maps.scheme(0x21, MemberCases.u8(0, "a")).withParity(2);
        Scheme<Map> none = Maps.scheme(0x22, MemberCases.u8(0, "a"));
        byte[] message = BinaryPacker.pack(four, Maps.map("a", 1, "b", 2));

        // Act and Assert
        PackbinTest.expectThrows("EC-16 handlers of 4 and 2 parity bytes", () -> BinaryPacker.unpackRepair(message, 0,
                four.on(row -> ran[0]++), two.on(row -> ran[0]++)),
                "handlers declare 4 and 2 parity bytes; they must declare the same count");
        PackbinTest.expectThrows("EC-16 handlers of 4 and 0 parity bytes", () -> BinaryPacker.unpack(message,
                four.on(row -> ran[0]++), none.on(row -> ran[0]++)),
                "handlers declare 4 and 0 parity bytes; they must declare the same count");
        PackbinTest.expectEq("EC-16 no handler ran", 0, ran[0]);
    }

    private static void dispatchWithoutParityIsUnchanged() {
        // Arrange
        Scheme<Map> plain = Maps.scheme(0x31, MemberCases.u8(0, "a"));
        List<Map> rows = new ArrayList<>();

        // Act
        Object result = BinaryPacker.unpack(BinaryPacker.pack(plain, Maps.map("a", 5)), plain.on(rows::add));

        // Assert
        PackbinTest.expectTrue("EC-16 a plain dispatch of schemes without parity returns null", result == null);
        PackbinTest.expectEq("EC-16 a plain dispatch hands over the row", Maps.map("a", 5), rows.get(0));
    }

    private static void hostileBytesNeverThrow() {
        // Arrange
        Random random = new Random(99);
        Scheme.Handler<PositionRow> handler = EccSupport.positionScheme(16).on(row -> { });
        byte[] valid = BinaryPacker.pack(EccSupport.positionScheme(16), EccSupport.positionRow());
        int results = 0;
        int thrown = 0;

        // Act
        for (int i = 0; i < 30_000; i++) {
            int size = i % 3 == 0 ? random.nextInt(300) : valid.length;
            byte[] buffer = new byte[size];
            random.nextBytes(buffer);
            if (i % 3 == 2) {
                System.arraycopy(valid, 0, buffer, 0, Math.min(size, valid.length));
                if (size > 0) {
                    buffer[random.nextInt(size)] ^= (byte) (1 + random.nextInt(255));
                }
            }
            try {
                if (BinaryPacker.unpackRepair(buffer, i % 9, handler) != null) {
                    results++;
                }
            } catch (RuntimeException | Error ex) {
                thrown++;
            }
        }

        // Assert
        PackbinTest.expectEq("EC hostile: 30,000 buffers return a result", 30_000, results);
        PackbinTest.expectEq("EC hostile: nothing is thrown", 0, thrown);
    }
}

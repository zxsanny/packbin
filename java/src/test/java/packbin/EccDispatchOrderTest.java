package packbin;

import java.util.ArrayList;
import java.util.List;

/** AZ-2694 AC-1: a duplicate type number among the handlers is refused before any byte is read and before the receive index moves. */
final class EccDispatchOrderTest {
    private static final byte[] NONCE = PackbinTest.parseHex("01000000000000000000000000000000");

    private EccDispatchOrderTest() {}

    static void run() {
        for (int parity : new int[] {0, 4}) {
            aDuplicateTypeNumberLeavesTheReceiveIndex(parity);
            aDuplicateTypeNumberIsRefusedBeforeAnyByteIsRead(parity);
        }
    }

    private static void aDuplicateTypeNumberLeavesTheReceiveIndex(int parity) {
        // Arrange
        byte[] seed = new byte[32];
        for (int i = 0; i < seed.length; i++) {
            seed[i] = (byte) (i + 1);
        }
        PackSession opener = PackSession.load(seed);
        PackSession waiter = PackSession.load(seed);
        PackbinTest.expectTrue("session opens", opener.start(NONCE) != null && waiter.join(NONCE));
        Scheme<PositionRow> scheme = EccSupport.positionScheme(parity);
        byte[] first = opener.pack(scheme, EccSupport.positionRow());
        byte[] second = opener.pack(scheme, EccSupport.positionRow());
        List<PositionRow> rows = new ArrayList<>();
        Scheme.Handler<PositionRow> handler = scheme.on(rows::add);

        // Act
        PackbinTest.expectThrows("AZ-2694 parity " + parity + " duplicate type number in a session",
                () -> waiter.unpackRepair(first, 0, handler, handler), "duplicate type number 64");
        Object readFirst = waiter.unpackRepair(first, 0, handler);
        Object readSecond = waiter.unpackRepair(second, 0, handler);

        // Assert
        PackbinTest.expectTrue("AZ-2694 parity " + parity + " the first payload is read at index 0",
                readFirst instanceof Packbin.Repaired);
        PackbinTest.expectTrue("AZ-2694 parity " + parity + " the second payload is read at index 1",
                readSecond instanceof Packbin.Repaired);
        PackbinTest.expectEq("AZ-2694 parity " + parity + " rows handed over", 2, rows.size());
        PackbinTest.expectTrue("AZ-2694 parity " + parity + " rows are the position fixture",
                EccSupport.isPosition(rows.get(0), 1) && EccSupport.isPosition(rows.get(1), 1));
    }

    private static void aDuplicateTypeNumberIsRefusedBeforeAnyByteIsRead(int parity) {
        // Arrange
        Scheme<PositionRow> scheme = EccSupport.positionScheme(parity);
        List<PositionRow> rows = new ArrayList<>();
        Scheme.Handler<PositionRow> handler = scheme.on(rows::add);

        // Act
        PackbinTest.expectThrows("AZ-2694 parity " + parity + " duplicate type number by the static unpack",
                () -> BinaryPacker.unpackRepair(new byte[0], 0, handler, handler), "duplicate type number 64");

        // Assert
        PackbinTest.expectEq("AZ-2694 parity " + parity + " no row handed over", 0, rows.size());
    }
}

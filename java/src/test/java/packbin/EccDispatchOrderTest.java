package packbin;

import java.util.ArrayList;
import java.util.List;

/** AZ-2694 AC-1 and AZ-2704: a duplicate type number among the handlers is refused before any byte is read and before the receive index moves. */
final class EccDispatchOrderTest {
    private static final byte[] NONCE = PackbinTest.parseHex("01000000000000000000000000000000");

    private EccDispatchOrderTest() {}

    static void run() {
        for (int parity : new int[] {0, 4}) {
            aDuplicateTypeNumberLeavesTheReceiveIndex(parity);
            aDuplicateTypeNumberIsRefusedBeforeAnyByteIsRead(parity);
            noHandlerLeavesTheReceiveIndex(parity);
            aDuplicateTypeIsRefusedBeforeAParityMixOrABadLimit(parity);
        }
    }

    private static PackSession[] openPair() {
        byte[] seed = new byte[32];
        for (int i = 0; i < seed.length; i++) {
            seed[i] = (byte) (i + 1);
        }
        PackSession opener = PackSession.load(seed);
        PackSession waiter = PackSession.load(seed);
        PackbinTest.expectTrue("session opens", opener.start(NONCE) != null && waiter.join(NONCE));
        return new PackSession[] {opener, waiter};
    }

    /** AZ-2704 AC-2: an empty handler list is refused before the receive index moves. */
    private static void noHandlerLeavesTheReceiveIndex(int parity) {
        // Arrange
        PackSession[] pair = openPair();
        Scheme<PositionRow> scheme = EccSupport.positionScheme(parity);
        byte[] first = pair[0].pack(scheme, EccSupport.positionRow());
        List<PositionRow> rows = new ArrayList<>();
        Scheme.Handler<PositionRow> handler = scheme.on(rows::add);

        // Act
        PackbinTest.expectThrows("AZ-2704 parity " + parity + " no handler in a session",
                () -> pair[1].unpackRepair(first, 0), "unpack needs at least one handler");
        PackbinTest.expectThrows("AZ-2704 parity " + parity + " no handler by the static unpack",
                () -> BinaryPacker.unpackRepair(first, 0), "unpack needs at least one handler");
        Object readFirst = pair[1].unpackRepair(first, 0, handler);

        // Assert
        PackbinTest.expectTrue("AZ-2704 parity " + parity + " the first payload is read at index 0",
                readFirst instanceof Packbin.Repaired);
        PackbinTest.expectEq("AZ-2704 parity " + parity + " one row handed over", 1, rows.size());
    }

    /** AZ-2704 AC-3: the duplicate type is the refusal when the list also mixes parity counts or the limit is bad. */
    private static void aDuplicateTypeIsRefusedBeforeAParityMixOrABadLimit(int parity) {
        // Arrange
        PackSession[] pair = openPair();
        Scheme.Handler<PositionRow> handler = EccSupport.positionScheme(parity).on(row -> {});
        Scheme.Handler<PositionRow> mixed = EccSupport.positionScheme(parity == 0 ? 4 : 0).on(row -> {});

        // Act and Assert
        PackbinTest.expectThrows("AZ-2704 parity " + parity + " duplicate before the parity mix",
                () -> pair[1].unpackRepair(new byte[4], 0, handler, mixed, handler), "duplicate type number 64");
        PackbinTest.expectThrows("AZ-2704 parity " + parity + " duplicate before the limit",
                () -> BinaryPacker.unpackRepair(new byte[4], 9, handler, handler), "duplicate type number 64");
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

package packbin;

import java.util.ArrayList;
import java.util.List;

/** AZ-2694 AC-1 and AZ-2704: a duplicate type number among the handlers is refused before any byte is read. */
final class EccDispatchOrderTest {
    private EccDispatchOrderTest() {}

    static void run() {
        for (int parity : new int[] {0, 4}) {
            aDuplicateTypeNumberIsRefusedBeforeAnyByteIsRead(parity);
            noHandlerIsRefused(parity);
            aDuplicateTypeIsRefusedBeforeAParityMixOrABadLimit(parity);
        }
    }

    /** AZ-2704 AC-2: an empty handler list is refused. */
    private static void noHandlerIsRefused(int parity) {
        // Arrange
        byte[] first = BinaryPacker.pack(EccSupport.positionScheme(parity), EccSupport.positionRow());

        // Act and Assert
        PackbinTest.expectThrows("AZ-2704 parity " + parity + " no handler by the static unpack",
                () -> BinaryPacker.unpackRepair(first, 0), "unpack needs at least one handler");
    }

    /** AZ-2704 AC-3: the duplicate type is the refusal when the list also mixes parity counts or the limit is bad. */
    private static void aDuplicateTypeIsRefusedBeforeAParityMixOrABadLimit(int parity) {
        // Arrange
        Scheme.Handler<PositionRow> handler = EccSupport.positionScheme(parity).on(row -> {});
        Scheme.Handler<PositionRow> mixed = EccSupport.positionScheme(parity == 0 ? 4 : 0).on(row -> {});

        // Act and Assert
        PackbinTest.expectThrows("AZ-2704 parity " + parity + " duplicate before the parity mix",
                () -> BinaryPacker.unpackRepair(new byte[4], 0, handler, mixed, handler), "duplicate type number 64");
        PackbinTest.expectThrows("AZ-2704 parity " + parity + " duplicate before the limit",
                () -> BinaryPacker.unpackRepair(new byte[4], 9, handler, handler), "duplicate type number 64");
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

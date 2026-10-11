package packbin;

import static packbin.MemberCases.refused;
import static packbin.MemberCases.row;

import java.math.BigDecimal;
import java.math.BigInteger;
import java.util.List;
import java.util.Map;

/**
 * AZ-2361 (loop 20): G1 a fraction in a u2, bits or packed slot is refused naming the field, a whole BigDecimal
 * packs; F30 a u64 count above int range is refused for sized and bits instead of being cut to an int; F29 the
 * output buffer grows in long arithmetic and stops at the array limit.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class CountsFractionsSinkTest {
    private CountsFractionsSinkTest() {}

    private static final int MAX_ARRAY = ByteSink.MAX_ARRAY;

    private static Scheme<Map> u2Of(String name) {
        return Maps.scheme(1, Packbin.u2(Packbin.u2Slot(0, Access.get(name), Access.set(name))));
    }

    private static Scheme<Map> bitsOf() {
        return Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.bits(1, Access.get("b"), Access.set("b"), 0));
    }

    private static Scheme<Map> packedOf() {
        return Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.packed(2, 1, Access.get("b"), Access.set("b"), 0, 0));
    }

    private static Scheme<Map> u64Count(Field counted) {
        return Maps.scheme(1, Packbin.u64(0, Access.get("n"), Access.set("n")), counted);
    }

    static void run() {
        ac1AFractionIsRefused();
        ac2AU64CountAboveIntRange();
        ac3TheSinkGrowsWithoutOverflow();
    }

    private static void ac1AFractionIsRefused() {
        BigDecimal half = new BigDecimal("1.5");
        BigDecimal one = new BigDecimal("1");
        refused("AC-1 u2 BigDecimal 1.5", u2Of("a"), row("a", half), "0: expected 2-bit int");
        refused("AC-1 bits BigDecimal 1.5", bitsOf(), row("n", 1, "b", List.of(half)), "1: expected 0 or 1");
        refused("AC-1 packed BigDecimal 1.5", packedOf(), row("n", 1, "b", List.of(half)), "1: expected 0..3");
        refused("AC-1 u2 BigDecimal 0.1 (cut to 0 before)", u2Of("a"), row("a", new BigDecimal("0.1")), "0: expected 2-bit int");
        refused("AC-1 u2 Long 2^32 + 1 (cut to 1 before)", u2Of("a"), row("a", 4_294_967_297L), "0: expected 2-bit int");
        refused("AC-1 bits BigInteger 2^32 + 1 (cut to 1 before)", bitsOf(),
                row("n", 1, "b", List.of(BigInteger.ONE.shiftLeft(32).add(BigInteger.ONE))), "1: expected 0 or 1");
        MemberCases.packs("AC-1 u2 BigDecimal 1", u2Of("a"), row("a", 1), "0101");
        PackbinTest.expectEq("AC-1 u2 whole BigDecimal packs", "0101",
                PackbinTest.toHex(BinaryPacker.pack(u2Of("a"), row("a", one))));
        PackbinTest.expectEq("AC-1 u2 BigDecimal 1.0 packs", "0101",
                PackbinTest.toHex(BinaryPacker.pack(u2Of("a"), row("a", new BigDecimal("1.0")))));
        PackbinTest.expectEq("AC-1 bits whole BigDecimal packs", "010101",
                PackbinTest.toHex(BinaryPacker.pack(bitsOf(), row("n", 1, "b", List.of(one)))));
        PackbinTest.expectEq("AC-1 packed whole BigDecimal packs", "010101",
                PackbinTest.toHex(BinaryPacker.pack(packedOf(), row("n", 1, "b", List.of(one)))));
    }

    private static void ac2AU64CountAboveIntRange() {
        String over = "1: count 4294967299 is above the limit of 2147483647 items";
        Scheme<Map> sized = u64Count(Packbin.sized(1, Access.get("b"), Access.set("b"), 0));
        Scheme<Map> bits = u64Count(Packbin.bits(1, Access.get("b"), Access.set("b"), 0));
        refused("AC-2 sized, count 2^32 + 3", sized, row("n", 4_294_967_299L, "b", new byte[3]), over);
        refused("AC-2 bits, count 2^32 + 3", bits, row("n", 4_294_967_299L, "b", List.of(1, 0, 1)), over);
        PackbinTest.expectEq("AC-2 sized, count 3 still packs", "010300000000000000000000",
                PackbinTest.toHex(BinaryPacker.pack(sized, row("n", 3L, "b", new byte[3]))));
        PackbinTest.expectEq("AC-2 bits, count 3 still packs", "01030000000000000005",
                PackbinTest.toHex(BinaryPacker.pack(bits, row("n", 3L, "b", List.of(1, 0, 1)))));
    }

    /** F29: 2^30 + 1 bytes used to overflow the doubling (int) and copy the buffer on every append after it. */
    private static void ac3TheSinkGrowsWithoutOverflow() {
        PackbinTest.expectEq("AC-3 doubling below 2^30", 1 << 30, ByteSink.grown(1 << 29, (1 << 29) + 1L, MAX_ARRAY));
        PackbinTest.expectEq("AC-3 past 2^30 stops at the array limit", MAX_ARRAY,
                ByteSink.grown(1 << 30, (1 << 30) + 1L, MAX_ARRAY));
        PackbinTest.expectEq("AC-3 just under the limit", MAX_ARRAY, ByteSink.grown(MAX_ARRAY - 1, MAX_ARRAY, MAX_ARRAY));
        PackbinTest.expectEq("AC-3 exactly the limit", MAX_ARRAY, ByteSink.grown(MAX_ARRAY, MAX_ARRAY, MAX_ARRAY));
        PackbinTest.expectEq("AC-3 one past the limit", -1, ByteSink.grown(MAX_ARRAY, MAX_ARRAY + 1L, MAX_ARRAY));
        PackbinTest.expectEq("AC-3 a far larger append", -1, ByteSink.grown(32, 5_000_000_000L, MAX_ARRAY));
        PackbinTest.expectEq("AC-3 the budget caps the doubling", 100, ByteSink.grown(64, 70, 100));
        PackbinTest.expectEq("AC-3 small buffers double", 64, ByteSink.grown(32, 33, 16_777_216));
        PackbinTest.expectEq("AC-3 a large append wins over doubling", 1000, ByteSink.grown(32, 1000, 16_777_216));
    }
}
